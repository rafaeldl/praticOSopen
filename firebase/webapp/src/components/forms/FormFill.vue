<script setup lang="ts">
// A checklist of the order (checklist.fill.*, checklist.question.*), in a
// drawer. On a big screen every question is on the page, answered in place:
// Tab goes from question to question, the arrows walk the options, Space or a
// number picks one (1 = the first), Enter on a text goes on. A pick, a text
// with Enter or "Pronto" of a multiple choice moves to the next question
// without an answer; with nothing left, the checklist is completed and closes
// (the app does it after the last question).
//
// Each answer is saved alone: a transaction reads the checklist again and
// changes only that question (lib/forms/data.ts saveAnswer), so the app and
// the web can answer at the same time. An answer that did not reach the
// server stays on screen marked "não foi salvo", with "Tentar de novo".
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight, ImagePlus, MoreHorizontal, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import ChoiceDialog from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { locale, t } from '@/i18n'
import { addPhotos, FormCompleted, removePhoto, saveAnswer, setFormStatus } from '@/lib/forms/data'
import {
  answerText,
  applyChange,
  canFinishAnyway,
  firstUnanswered,
  isAnswered,
  labelOf,
  missingCount,
  numberAnswer,
  optionsOf,
  PHOTO_TYPES,
  splitPhotos,
  requiredMissing,
  responseOf,
  statusAfter,
  titleOf,
  type AnswerChange,
  type FormItem,
  type FormsAccess,
  type OrderForm,
} from '@/lib/forms/model'
import type { DeviceAggr } from '@/lib/orders/model'
import { parseMoney } from '@/lib/format'
import { session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{ orderId: string; form: OrderForm; access: FormsAccess; devices: DeviceAggr[]; start?: boolean }>()
const emit = defineEmits<{ close: [] }>()
const router = useRouter()

interface Pending {
  change: AnswerChange
  state: 'saving' | 'failed'
  /** Which send this is: a newer answer to the same question replaces it. */
  seq: number
  /** Refused because the checklist was completed meanwhile (B1 of #524). */
  completed?: boolean
}
let sequence = 0
/** Answers on their way (or that did not arrive), shown over what the server has. */
const pending = reactive<Record<string, Pending>>({})
const drafts = reactive<Record<string, string>>({})
const invalid = reactive<Record<string, boolean>>({})
const uploading = reactive<Record<string, number>>({})
const busy = ref(false)
const viewer = ref<{ itemId: string; index: number } | null>(null)
const removing = ref<{ itemId: string; url: string } | null>(null)
const missingList = ref<FormItem[] | null>(null)
const menuOpen = ref(false)
const menuButton = ref<HTMLElement | null>(null)
const layer = ref<InstanceType<typeof Layer> | null>(null)
/** Closed on its own after completing: nothing more to announce. */
let finished = false

const view = computed<OrderForm>(() => {
  let responses = props.form.responses
  for (const entry of Object.values(pending)) if (!entry.completed) responses = applyChange(responses, entry.change)
  return { ...props.form, responses, status: statusAfter(props.form.status, responses) }
})
const completed = computed(() => props.form.status === 'completed')
const editable = computed(() => props.access.fill && !completed.value)
const missing = computed(() => missingCount(view.value))
const answeredAny = computed(() => missing.value < view.value.items.length)
const title = computed(() => titleOf(props.form, locale.value))
const device = computed(() => {
  const found = props.form.deviceId ? props.devices.find((item) => item.id === props.form.deviceId) : null
  return found ? [found.name, found.serial].filter(Boolean).join(' · ') : null
})
const status = computed(() => {
  if (completed.value) return { dot: 'success', text: t('checklistStatusDone') }
  if (missing.value > 0) return { dot: 'warning', text: t('orderChecklistMissing', { count: missing.value }) }
  return { dot: 'accent', text: t('checklistRemaining', { count: 0 }) }
})
const words = { yes: t('yes'), no: t('no'), photos: (count: number) => t('nPhotosCount', { count }) }
const country = computed(() => session.company?.country)

const choices = (item: FormItem): string[] => (item.type === 'boolean' ? [t('yes'), t('no')] : optionsOf(item, locale.value))
/** The value saved for choice `index`: true/false, or the template's own option (shown translated). */
const valueAt = (item: FormItem, index: number): unknown => (item.type === 'boolean' ? index === 0 : (item.options ?? [])[index])
const isPicked = (item: FormItem, index: number) => {
  const value = responseOf(view.value, item.id)?.value
  const wanted = valueAt(item, index)
  return item.type === 'checklist' ? Array.isArray(value) && value.includes(wanted) : value === wanted
}
const pickedIndex = (item: FormItem) => choices(item).findIndex((_, index) => isPicked(item, index))
const textOf = (item: FormItem) => drafts[item.id] ?? String(responseOf(view.value, item.id)?.value ?? '')

function focusQuestion(index: number) {
  void nextTick(() => {
    const box = document.querySelector<HTMLElement>(`[data-q-index="${index}"]`)
    const target = box?.querySelector<HTMLElement>('[tabindex="0"][role], input, button:not([disabled])')
    ;(target ?? box)?.focus()
    box?.scrollIntoView({ block: 'nearest' })
  })
}

/** After a "commit": the next question without an answer, or completing when nothing is left. */
function advance(from: number) {
  const next = firstUnanswered(view.value, from) ?? firstUnanswered(view.value)
  if (next !== null) focusQuestion(next)
}

/**
 * Answers go to the server one after the other, in the order given: two ticks
 * of the same question in quick succession must land in that order (two
 * transactions at once could finish the other way around).
 */
let queue: Promise<unknown> = Promise.resolve()

function send(item: FormItem, change: AnswerChange, commit: boolean): Promise<void> {
  const index = view.value.items.findIndex((entry) => entry.id === item.id)
  const seq = ++sequence
  pending[item.id] = { change, state: 'saving', seq }
  const complete = commit && missingCount(view.value) === 0
  if (commit && !complete) advance(index)
  const next = queue.then(() => write(item, change, complete, seq))
  queue = next.catch(() => {})
  return next
}

async function write(item: FormItem, change: AnswerChange, complete: boolean, seq: number) {
  try {
    const saved = await saveAnswer(props.orderId, props.form.id, change, complete)
    // A newer answer to the same question may be on its way: only that one stays.
    if (pending[item.id]?.seq === seq) delete pending[item.id]
    if (saved.status === 'completed' && complete && !finished) {
      finished = true
      const message = t('web.forms.completed', { name: title.value })
      showToast(message)
      announce(message)
      emit('close')
    }
  } catch (error) {
    console.warn('forms: answer not saved', error)
    const completed = error instanceof FormCompleted
    if (pending[item.id]?.seq === seq) pending[item.id] = { change, state: 'failed', seq, completed }
    announce(completed ? t('web.forms.completedElsewhere') : t('checklistAnswerSaveFailed'))
  }
}

function retry(item: FormItem) {
  const entry = pending[item.id]
  if (entry) void send(item, entry.change, false)
}

function pick(item: FormItem, index: number) {
  if (!editable.value) return
  if (item.type === 'checklist') return toggle(item, index)
  void send(item, { kind: 'value', itemId: item.id, value: valueAt(item, index) }, true)
}

function toggle(item: FormItem, index: number) {
  const current = responseOf(view.value, item.id)?.value
  const list = Array.isArray(current) ? current.map(String) : []
  const option = String(valueAt(item, index))
  const next = list.includes(option) ? list.filter((entry) => entry !== option) : [...list, option]
  // In the template's order, like the app's buttons.
  const ordered = (item.options ?? []).filter((entry) => next.includes(entry))
  void send(item, { kind: 'value', itemId: item.id, value: ordered }, false)
}

/** Text and number: saved on leaving the field, or with Enter (which goes on). */
function commitText(item: FormItem, goOn: boolean) {
  // Completed meanwhile (here or in the app): what was typed does not go in (B1 of #524).
  if (!editable.value) {
    delete drafts[item.id]
    return
  }
  const draft = drafts[item.id]
  const index = view.value.items.findIndex((entry) => entry.id === item.id)
  if (draft === undefined) {
    if (goOn) advanceOrFinish(index)
    return
  }
  let value: string | null = draft.trim()
  if (item.type === 'number') value = numberAnswer(draft, (text) => parseMoney(text, country.value))
  if (value === null) {
    invalid[item.id] = true
    return
  }
  invalid[item.id] = false
  delete drafts[item.id]
  const saved = String(responseOf(view.value, item.id)?.value ?? '')
  // Erasing the text saves "" and the question goes back to no answer, as in the app.
  if (value !== saved) void send(item, { kind: 'value', itemId: item.id, value }, goOn)
  else if (goOn) advanceOrFinish(index)
}

/** Enter on an answer that did not change: go on; nothing left completes it. */
function advanceOrFinish(index: number) {
  if (missing.value === 0 && editable.value) void finish()
  else advance(index)
}

function onOptionKey(event: KeyboardEvent, item: FormItem, index: number) {
  const count = choices(item).length
  const move = (to: number) => {
    event.preventDefault()
    const target = (event.currentTarget as HTMLElement).parentElement?.children[(to + count) % count] as HTMLElement | undefined
    target?.focus()
  }
  if (event.key === 'ArrowDown' || event.key === 'ArrowRight') return move(index + 1)
  if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') return move(index - 1)
  if (event.key === ' ' || (event.key === 'Enter' && item.type !== 'checklist')) {
    event.preventDefault()
    return pick(item, index)
  }
  if (event.key === 'Enter' && item.type === 'checklist') {
    event.preventDefault()
    return doneMulti(item)
  }
}

/** 1 to 9 on a question picks (or ticks) that option. */
function onQuestionKey(event: KeyboardEvent, item: FormItem) {
  if (!editable.value || event.ctrlKey || event.metaKey || event.altKey) return
  if ((event.target as HTMLElement).matches('input, textarea')) return
  if (!/^[1-9]$/.test(event.key)) return
  const index = Number(event.key) - 1
  if (index >= choices(item).length) return
  event.preventDefault()
  pick(item, index)
  if (item.type === 'checklist') {
    const box = (event.currentTarget as HTMLElement).querySelectorAll<HTMLElement>('[role="checkbox"]')[index]
    box?.focus()
  }
}

/** "Pronto" of a multiple choice: goes on (each tick is already saved). */
function doneMulti(item: FormItem) {
  const index = view.value.items.findIndex((entry) => entry.id === item.id)
  advanceOrFinish(index)
}

async function onFiles(item: FormItem, files: FileList | File[] | null | undefined) {
  if (!editable.value) return
  // JPEG, PNG and WebP under 10 MB: what the app and the PDF show (B2 of #524).
  const { ok, refused: tooBig } = splitPhotos([...(files ?? [])])
  if (!ok.length && !tooBig) return
  uploading[item.id] = (uploading[item.id] ?? 0) + ok.length
  try {
    const { failed } = ok.length ? await addPhotos(props.orderId, props.form.id, item.id, ok) : { failed: 0 }
    const bad = failed + tooBig
    const message = bad ? t('web.forms.photosFailed', { count: bad }) : t('web.order.photoAdded', { count: ok.length })
    showToast(message)
    announce(message)
  } catch (error) {
    console.warn('forms: photos not saved', error)
    showToast(t('couldNotSendPhotos'))
  } finally {
    uploading[item.id] = Math.max(0, (uploading[item.id] ?? 0) - ok.length)
  }
}

/** An image pasted while a question has the focus goes to it (when it takes photos). */
function onPaste(event: ClipboardEvent, item: FormItem) {
  const files = [...(event.clipboardData?.files ?? [])].filter((file) => file.type.startsWith('image/'))
  if (!editable.value) return
  if (!files.length || !(item.allowPhotos || item.type === 'photo_only')) return
  event.preventDefault()
  // Not the order's photos too (OrderPhotos listens on the window).
  event.stopPropagation()
  void onFiles(item, files)
}

async function confirmRemovePhoto() {
  const target = removing.value
  removing.value = null
  if (!target) return
  try {
    await removePhoto(props.orderId, props.form.id, target.itemId, target.url)
    viewer.value = null
    showToast(t('orderPhotoDeleted'))
  } catch (error) {
    console.warn('forms: photo not removed', error)
    showToast(t('orderPhotoDeleteError'))
  }
}

async function finish() {
  const open = requiredMissing(view.value)
  if (open.length) {
    missingList.value = open
    return
  }
  if (busy.value) return
  busy.value = true
  try {
    await setFormStatus(props.orderId, props.form.id, 'completed')
    finished = true
    const message = t('web.forms.completed', { name: title.value })
    showToast(message)
    announce(message)
    emit('close')
  } catch (error) {
    console.warn('forms: not completed', error)
    showToast(t('couldNotCompleteForm'))
  } finally {
    busy.value = false
  }
}

/** As in the editor: the menu leaves through the history, then "Reabrir" runs. */
let reopenPicked = false
function pickReopen() {
  reopenPicked = true
  router.back()
}
function onMenuClosed() {
  menuOpen.value = false
  if (reopenPicked) {
    reopenPicked = false
    void reopen()
  }
}

async function reopen() {
  menuOpen.value = false
  if (busy.value) return
  busy.value = true
  try {
    await setFormStatus(props.orderId, props.form.id, 'in_progress')
    announce(t('web.forms.reopened'))
    showToast(t('web.forms.reopened'))
  } catch (error) {
    console.warn('forms: not reopened', error)
    showToast(t('couldNotReopenForm'))
  } finally {
    busy.value = false
  }
}

function startOrContinue() {
  const index = firstUnanswered(view.value)
  if (index !== null) focusQuestion(index)
}

const viewed = computed(() => {
  const at = viewer.value
  if (!at) return null
  const photos = responseOf(view.value, at.itemId)?.photoUrls ?? []
  return photos.length ? { photos, index: Math.min(at.index, photos.length - 1), itemId: at.itemId } : null
})
function step(by: number) {
  const current = viewed.value
  if (!current || !viewer.value) return
  viewer.value = { ...viewer.value, index: (current.index + by + current.photos.length) % current.photos.length }
}

// Opened right after being added, with nothing answered: straight to the first question (checklist.fill.auto-open).
const autoStart = props.start && editable.value && props.form.items.length > 0 && props.form.responses.length === 0
onMounted(() => {
  if (autoStart) focusQuestion(0)
})
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" @close="emit('close')">
    <div class="drawer fill" data-testid="form-fill">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
        <button v-if="completed && access.reopen" ref="menuButton" type="button" class="icon-btn" :aria-label="t('orderMoreActions')" data-testid="fill-menu" @click="menuOpen = true">
          <MoreHorizontal :size="18" aria-hidden="true" />
        </button>
      </div>
      <div class="drawer-body">
        <header class="fill-head">
          <p v-if="device" class="sub" data-testid="fill-device">{{ device }}</p>
          <p class="fill-status" data-testid="fill-status"><span class="dot" :class="`dot--${status.dot}`" aria-hidden="true"></span> {{ status.text }}</p>
          <div v-if="editable && view.items.length" class="row-actions">
            <button v-if="missing === 0" type="button" class="btn btn--primary" :disabled="busy" data-testid="fill-finish" :data-autofocus="autoStart ? undefined : ''" @click="finish">{{ t('checklistFinish') }}</button>
            <button v-else type="button" class="btn btn--primary" data-testid="fill-start" :data-autofocus="autoStart ? undefined : ''" @click="startOrContinue">{{ answeredAny ? t('continue_') : t('checklistStart') }}</button>
            <button v-if="canFinishAnyway(view)" type="button" class="link" data-testid="fill-finish-anyway" @click="finish">{{ t('checklistFinishAnyway') }}</button>
          </div>
          <p v-if="editable && view.items.length > 0" class="sub field-hint hide-phone">{{ t('web.forms.keysHint') }}</p>
        </header>

        <p v-if="!view.items.length" class="muted">{{ t('web.forms.noQuestions') }}</p>
        <ol class="fill-list" :aria-label="t('checklistQuestionsTitle')">
          <li
            v-for="(item, index) in view.items"
            :key="item.id"
            class="fill-q"
            :class="{ 'is-open': editable && !isAnswered(item, responseOf(view, item.id)) }"
            :data-q-index="index"
            :data-item="item.id"
            @dragover.prevent
            @drop.prevent="(item.allowPhotos || item.type === 'photo_only') && onFiles(item, $event.dataTransfer?.files)"
          >
            <fieldset class="fill-set" :aria-describedby="`fq-${item.id}-state`" @keydown="onQuestionKey($event, item)" @paste="onPaste($event, item)">
              <legend :id="`fq-${item.id}-label`" class="fill-label">
                <span class="num q-num" aria-hidden="true">{{ index + 1 }}</span>{{ labelOf(item, locale) }}
                <span v-if="item.required" class="sub"> · {{ t('checklistQuestionRequired') }}</span>
              </legend>

              <template v-if="!editable">
                <p class="fill-answer" :class="{ muted: !isAnswered(item, responseOf(view, item.id)) }">
                  {{ answerText(item, responseOf(view, item.id), locale, words) ?? t('checklistNoAnswer') }}
                </p>
              </template>
              <template v-else-if="item.type === 'boolean' || item.type === 'select' || item.type === 'checklist'">
                <div class="fill-opts" :role="item.type === 'checklist' ? 'group' : 'radiogroup'" :aria-labelledby="`fq-${item.id}-label`">
                  <button
                    v-for="(choice, at) in choices(item)"
                    :key="at"
                    type="button"
                    class="fill-opt"
                    :role="item.type === 'checklist' ? 'checkbox' : 'radio'"
                    :aria-checked="isPicked(item, at)"
                    :tabindex="at === Math.max(0, pickedIndex(item)) ? 0 : -1"
                    :data-autofocus="autoStart && index === 0 && at === 0 ? '' : undefined"
                    @click="pick(item, at)"
                    @keydown="onOptionKey($event, item, at)"
                  >
                    <kbd v-if="at < 9" aria-hidden="true">{{ at + 1 }}</kbd><span>{{ choice }}</span><span v-if="isPicked(item, at)" class="check-mark" aria-hidden="true">✓</span>
                  </button>
                </div>
                <button v-if="item.type === 'checklist'" type="button" class="btn fill-done" @click="doneMulti(item)">{{ t('checklistQuestionDone') }}</button>
              </template>
              <template v-else-if="item.type === 'text' || item.type === 'number'">
                <label class="sr" :for="`fq-${item.id}-input`">{{ labelOf(item, locale) }}</label>
                <input
                  :id="`fq-${item.id}-input`"
                  class="field"
                  :inputmode="item.type === 'number' ? 'decimal' : 'text'"
                  autocomplete="off"
                  :placeholder="t('checklistTextPlaceholder')"
                  :value="textOf(item)"
                  :aria-invalid="invalid[item.id] ? 'true' : undefined"
                  :data-autofocus="autoStart && index === 0 ? '' : undefined"
                  @input="drafts[item.id] = ($event.target as HTMLInputElement).value; invalid[item.id] = false"
                  @blur="commitText(item, false)"
                  @keydown.enter.prevent="commitText(item, true)"
                />
                <p v-if="invalid[item.id]" class="field-error" role="alert">{{ t('invalidFormat') }}</p>
              </template>

              <div v-if="(responseOf(view, item.id)?.photoUrls.length ?? 0) > 0 || (editable && (item.allowPhotos || item.type === 'photo_only'))" class="photos fill-photos">
                <button
                  v-for="(url, at) in responseOf(view, item.id)?.photoUrls ?? []"
                  :key="url"
                  type="button"
                  class="photo"
                  :aria-label="t('web.forms.viewPhoto', { number: at + 1, name: labelOf(item, locale) })"
                  @click="viewer = { itemId: item.id, index: at }"
                >
                  <img :src="url" alt="" loading="lazy" />
                </button>
                <label v-if="editable && (item.allowPhotos || item.type === 'photo_only')" class="photo photo-add">
                  <ImagePlus :size="18" aria-hidden="true" />
                  <span class="photo-add-text">{{ uploading[item.id] ? t('orderUploading') : t('web.order.addPhoto') }}</span>
                  <input
                    class="sr"
                    type="file"
                    :accept="PHOTO_TYPES"
                    multiple
                    :aria-label="t('web.forms.addPhotoTo', { name: labelOf(item, locale) })"
                    :data-testid="`photo-input-${item.id}`"
                    :data-autofocus="autoStart && index === 0 && item.type === 'photo_only' ? '' : undefined"
                    @change="onFiles(item, ($event.target as HTMLInputElement).files); ($event.target as HTMLInputElement).value = ''"
                  />
                </label>
              </div>

              <p :id="`fq-${item.id}-state`" class="fill-state" :data-state="pending[item.id]?.state ?? (isAnswered(item, responseOf(view, item.id)) ? 'saved' : 'open')">
                <template v-if="pending[item.id]?.state === 'failed'">
                  <span class="fill-failed" role="alert">{{ pending[item.id]?.completed ? t('web.forms.completedElsewhere') : t('checklistAnswerSaveFailed') }}</span>
                  <button v-if="!pending[item.id]?.completed" type="button" class="link" @click="retry(item)">{{ t('web.tryAgain') }}</button>
                </template>
                <span v-else-if="pending[item.id]?.state === 'saving'" class="sub">{{ t('web.newOrder.saving') }}</span>
                <span v-else-if="editable && !isAnswered(item, responseOf(view, item.id))" class="sub sr">{{ t('checklistNoAnswer') }}</span>
              </p>
            </fieldset>
          </li>
        </ol>
      </div>
    </div>
  </Layer>

  <ChoiceDialog v-if="menuOpen" :anchor="menuButton" :title="title" :choices="[{ id: 'reopen', label: t('reopen') }]" @pick="pickReopen" @close="onMenuClosed" />
  <Layer v-if="viewed && !removing" kind="dialog" :label="t('photo')" @close="viewer = null">
    <template #default="{ close }">
      <div class="layer-body fill-viewer" data-testid="fill-viewer" @keydown.left.prevent="step(-1)" @keydown.right.prevent="step(1)">
        <img class="photo-full" :src="viewed.photos[viewed.index]" :alt="t('web.forms.photoOf', { number: viewed.index + 1 })" />
        <p v-if="viewed.photos.length > 1" class="sub fill-viewer-nav">
          <button type="button" class="icon-btn" :aria-label="t('previous')" @click="step(-1)"><ChevronLeft :size="18" aria-hidden="true" /></button>
          <span class="num">{{ t('checklistPhotoPosition', { current: viewed.index + 1, total: viewed.photos.length }) }}</span>
          <button type="button" class="icon-btn" :aria-label="t('next')" @click="step(1)"><ChevronRight :size="18" aria-hidden="true" /></button>
        </p>
      </div>
      <div class="layer-foot">
        <button v-if="editable" type="button" class="btn btn--ghost link--danger" data-testid="photo-remove" @click="removing = { itemId: viewed.itemId, url: viewed.photos[viewed.index] as string }">{{ t('removePhoto') }}</button>
        <button type="button" class="btn" data-autofocus @click="close()">{{ t('close') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog v-if="removing" :title="t('orderPhotoDeleteTitle')" :body="t('web.forms.photoRemoveBody')" :confirm="t('removePhoto')" :keep="t('cancel')" danger @confirm="confirmRemovePhoto" @close="removing = null" />
  <Layer v-if="missingList" kind="dialog" :label="t('web.forms.requiredTitle')" @close="missingList = null">
    <template #default="{ close }">
      <div class="layer-head"><h2 class="layer-title">{{ t('web.forms.requiredTitle') }}</h2></div>
      <div class="layer-body" data-testid="fill-required">
        <p>{{ t('web.forms.requiredBody') }}</p>
        <ul>
          <li v-for="item in missingList" :key="item.id">{{ labelOf(item, locale) }}</li>
        </ul>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--primary" data-autofocus @click="close(); focusQuestion(view.items.findIndex((entry) => entry.id === missingList?.[0]?.id))">{{ t('web.forms.answerNow') }}</button>
      </div>
    </template>
  </Layer>
</template>
