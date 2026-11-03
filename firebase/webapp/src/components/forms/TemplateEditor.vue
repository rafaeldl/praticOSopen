<script setup lang="ts">
// New or edit checklist (checklist.form.*), in a drawer. Name, description and
// the questions, which reorder by mouse or keyboard (Alt + ↑/↓ on a question,
// or its buttons): a big screen extra; in the app only the edit screen
// reorders, by dragging. Saving says what is missing (name, question or both).
// "Parar de usar"/"Voltar a usar" and "Apagar" are in "…" and act at once.
// Closing with changes asks, also when leaving the page. Saving over a
// version someone changed since is refused and the list is read again.
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowDown, ArrowUp, Check, MoreHorizontal, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import QuestionDialog from './QuestionDialog.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { createTemplate, deleteTemplate, setTemplateActive, TemplateChanged, updateTemplate } from '@/lib/forms/data'
import { labelOf, moveItem, saveProblem, titleOf, type FormItem, type ItemType, type Template } from '@/lib/forms/model'
import { isMac } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{
  /** Editing this one; without it, a new checklist. */
  template: Template | null
  /** One more active checklist fits the plan (a new one, or turning one back on). */
  room: boolean
  limitText: string
}>()
const emit = defineEmits<{ saved: [id: string]; close: [] }>()

const router = useRouter()
const editing = !!props.template
let seen = props.template?.updatedAt ?? null
const initial = reactive({ title: props.template?.title ?? '', description: props.template?.description ?? '', items: (props.template?.items ?? []) as FormItem[] })
const form = reactive({ title: initial.title, description: initial.description, items: [...initial.items] as FormItem[] })
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const question = ref<{ item: FormItem | null } | null>(null)
const dialog = ref<null | 'menu' | 'delete'>(null)
const menuButton = ref<HTMLElement | null>(null)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const active = ref(props.template?.isActive ?? true)
/** Saved elsewhere since it was opened (M2 of #524): the drawer stays, with what was typed. */
const conflict = ref(false)
let allowClose = false

const title = computed(() => (editing ? titleOf(props.template as Template, locale.value) || t('checklist') : t('checklistNew')))
const dirty = computed(() => form.title !== initial.title || form.description !== initial.description || JSON.stringify(form.items) !== JSON.stringify(initial.items))
const problem = computed(() => saveProblem(form.title, form.items))
const problemText = computed(() =>
  problem.value === 'both' ? t('checklistSaveNeedsNameAndQuestion') : problem.value === 'question' ? t('checklistSaveNeedsQuestion') : problem.value === 'name' ? t('web.forms.needsName') : '',
)
const canSave = computed(() => !problem.value && !saving.value)
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'
const menuChoices = computed<Choice[]>(() =>
  editing ? [{ id: 'toggle', label: active.value ? t('checklistStopUsing') : t('checklistUseAgain') }, { id: 'delete', label: t('checklistDelete'), danger: true }] : [],
)
const typeName = (type: ItemType) =>
  ({
    boolean: t('formItemTypeBoolean'),
    select: t('formItemTypeSelect'),
    checklist: t('formItemTypeChecklist'),
    text: t('formItemTypeText'),
    number: t('formItemTypeNumber'),
    photo_only: t('formItemTypePhoto'),
  })[type]
const itemSub = (item: FormItem) =>
  [typeName(item.type), item.required ? t('checklistQuestionRequiredShort') : '', item.allowPhotos && item.type !== 'photo_only' ? t('checklistQuestionWithPhoto') : ''].filter(Boolean).join(' · ')

function onQuestion(item: FormItem) {
  removed.value = null
  const index = form.items.findIndex((entry) => entry.id === item.id)
  if (index >= 0) form.items.splice(index, 1, item)
  else form.items.push(item)
  question.value = null
  announce(t('web.saved'))
}

/**
 * "Apagar pergunta": only counts on "Salvar checklist", and a line in the
 * editor brings it back (the app has no undo). In the drawer, not in a toast:
 * the rest of the page is out of reach while the drawer is open.
 */
const removed = ref<{ item: FormItem; index: number } | null>(null)
function removeQuestion(item: FormItem) {
  const index = form.items.findIndex((entry) => entry.id === item.id)
  if (index < 0) return
  form.items.splice(index, 1)
  question.value = null
  removed.value = { item, index }
  announce(t('web.forms.questionRemoved', { name: labelOf(item, locale.value) }))
  void nextTick(() => document.getElementById('tf-undo')?.focus())
}
function undoRemove() {
  const last = removed.value
  if (!last) return
  form.items.splice(Math.min(last.index, form.items.length), 0, last.item)
  removed.value = null
  announce(t('web.forms.questionRestored'))
  void nextTick(() => document.querySelector<HTMLElement>(`[data-question="${last.item.id}"] .q-open`)?.focus())
}

async function move(index: number, step: -1 | 1) {
  const next = moveItem(form.items, index, step)
  if (next === form.items) return
  form.items = next
  const moved = form.items[index + step] as FormItem
  announce(t('web.forms.moved', { name: labelOf(moved, locale.value), position: index + step + 1, total: form.items.length }))
  await nextTick()
  document.querySelector<HTMLElement>(`[data-question="${moved.id}"] .q-open`)?.focus()
}

/** Alt + ↑/↓ on a question moves it (WCAG 2.5.7: dragging is never the only way). */
function onQuestionKey(event: KeyboardEvent, index: number) {
  if (!event.altKey || (event.key !== 'ArrowUp' && event.key !== 'ArrowDown')) return
  event.preventDefault()
  void move(index, event.key === 'ArrowUp' ? -1 : 1)
}

// Dragging with the mouse, as in the app's edit screen.
const dragFrom = ref<number | null>(null)
function onDrop(index: number) {
  const from = dragFrom.value
  dragFrom.value = null
  if (from === null || from === index) return
  const next = [...form.items]
  const [moved] = next.splice(from, 1)
  next.splice(index, 0, moved as FormItem)
  form.items = next
}

async function save() {
  tried.value = true
  if (problem.value) {
    failed.value = problemText.value
    if (problem.value !== 'question') document.getElementById('tf-title')?.focus()
    return
  }
  if (saving.value) return
  if (!editing && !props.room) {
    failed.value = props.limitText
    return
  }
  saving.value = true
  failed.value = ''
  const name = form.title.trim()
  const description = form.description.trim() || null
  try {
    let id: string
    if (editing) {
      const before = props.template as Template
      id = before.id
      await updateTemplate(id, seen, {
        title: name,
        description,
        items: form.items,
        // The app's translations stay only while the text is the same.
        ...(name !== before.title ? { titleI18n: null } : {}),
        ...(description !== before.description ? { descriptionI18n: null } : {}),
      })
    } else {
      id = await createTemplate({ title: name, description, items: form.items })
    }
    allowClose = true
    const message = t('web.forms.saved', { name })
    showToast(message)
    announce(message)
    emit('saved', id)
  } catch (error) {
    if (error instanceof TemplateChanged) return void showConflict()
    console.warn('forms: not saved', error)
    const key = errorMessageKey(error)
    failed.value = key === 'web.error.generic' ? t('checklistSaveError') : `${t('checklistSaveError')} ${t(key)}`
  } finally {
    saving.value = false
  }
}

async function toggleActive() {
  dialog.value = null
  const template = props.template
  if (!template || saving.value) return
  const next = !active.value
  // Turning one back on must fit the plan (the app checks too).
  if (next && !props.room) {
    failed.value = props.limitText
    showToast(props.limitText)
    return
  }
  saving.value = true
  try {
    // Only over the version read; then "Salvar checklist" compares with the web's own write.
    seen = await setTemplateActive(template.id, seen, next)
    active.value = next
    const message = next ? t('web.forms.turnedOn') : t('web.forms.turnedOff')
    showToast(message)
    announce(message)
  } catch (error) {
    if (error instanceof TemplateChanged) return void showConflict()
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}

function showConflict() {
  conflict.value = true
  failed.value = ''
  announce(t('web.forms.changedElsewhere'))
  void nextTick(() => document.getElementById('tf-conflict')?.focus())
}

/** "Recarregar": the version saved now; what was typed here is discarded. */
function reload() {
  const latest = props.template
  if (!latest) return
  initial.title = latest.title
  initial.description = latest.description ?? ''
  initial.items = latest.items
  form.title = initial.title
  form.description = initial.description
  form.items = [...latest.items]
  seen = latest.updatedAt ?? null
  active.value = latest.isActive
  removed.value = null
  conflict.value = false
  announce(t('web.forms.reloaded'))
  void nextTick(() => document.getElementById('tf-title')?.focus())
}

/** "Copiar minhas perguntas": the name, the description and the questions typed, to paste elsewhere. */
async function copyMine() {
  const lines = [form.title.trim(), form.description.trim(), ...form.items.map((item, index) => `${index + 1}. ${labelOf(item, locale.value)}`)].filter(Boolean)
  try {
    await navigator.clipboard.writeText(lines.join('\n'))
    showToast(t('web.forms.copied'))
    announce(t('web.forms.copied'))
  } catch {
    failed.value = t('web.forms.copyFailed')
  }
}

async function remove() {
  const template = props.template
  if (!template || saving.value) return
  saving.value = true
  try {
    await deleteTemplate(template.id)
    allowClose = true
    showToast(t('web.forms.deleted', { name: template.title }))
    emit('close')
  } catch (error) {
    dialog.value = null
    failed.value = `${t('web.forms.deleteFailed')} ${t(errorMessageKey(error))}`.trim()
  } finally {
    saving.value = false
  }
}

/**
 * The menu closes through the history (Voltar), like Esc, and only then the
 * choice runs. Removed by the parent instead, its history entry would stay
 * behind and the drawer's X would need two clicks.
 */
let picked: string | null = null
function onPick(id: string) {
  picked = id
  router.back()
}
function onMenuClosed() {
  dialog.value = null
  const id = picked
  picked = null
  if (id === 'toggle') void toggleActive()
  else if (id === 'delete') dialog.value = 'delete'
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    event.stopPropagation()
    void save()
  }
}

function guard(): boolean {
  if (allowClose || !dirty.value) return true
  const ok = window.confirm(`${t('web.forms.discardTitle')}\n${t('web.forms.discardBody')}`)
  if (ok) allowClose = true
  return ok
}

const beforeUnload = (event: BeforeUnloadEvent) => {
  if (allowClose || !dirty.value) return
  event.preventDefault()
  event.returnValue = ''
}
onMounted(() => window.addEventListener('beforeunload', beforeUnload))
onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload))
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="template-editor" novalidate @submit.prevent="save()" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
        <span v-if="editing && !active" class="sub" data-testid="template-off"><span class="dot dot--hollow" aria-hidden="true"></span> {{ t('checklistOff') }}</span>
        <button v-if="menuChoices.length" ref="menuButton" type="button" class="icon-btn" :aria-label="t('orderMoreActions')" data-testid="template-menu" @click="dialog = 'menu'">
          <MoreHorizontal :size="18" aria-hidden="true" />
        </button>
      </div>
      <div class="drawer-body">
        <div v-if="conflict" id="tf-conflict" class="q-conflict" role="alert" tabindex="-1" data-testid="template-conflict">
          <p>{{ t('web.forms.changedElsewhere') }}</p>
          <div class="row-actions">
            <button type="button" class="btn" @click="reload">{{ t('web.forms.reload') }}</button>
            <button type="button" class="btn btn--ghost" @click="copyMine">{{ t('web.forms.copyMine') }}</button>
          </div>
        </div>
        <p v-if="failed" class="field-error" role="alert" data-testid="template-error">{{ failed }}</p>
        <div>
          <label class="field-label" for="tf-title">{{ t('checklistNameLabel') }}</label>
          <input id="tf-title" v-model="form.title" class="field" autocomplete="off" :placeholder="t('checklistNamePlaceholder')" :aria-invalid="tried && !form.title.trim()" data-autofocus />
        </div>
        <div>
          <label class="field-label" for="tf-description">{{ t('description') }}</label>
          <textarea id="tf-description" v-model="form.description" class="field" rows="2"></textarea>
        </div>
        <section aria-labelledby="tf-questions">
          <h3 id="tf-questions" class="form-section">
            {{ t('checklistQuestionsTitle') }}<span v-if="form.items.length" class="muted"> · {{ t('checklistQuestions', { count: form.items.length }) }}</span>
          </h3>
          <p v-if="form.items.length > 1" id="tf-reorder-hint" class="sub field-hint">{{ t('web.forms.reorderHint') }}</p>
          <ol class="q-list" data-testid="template-questions">
            <li
              v-for="(item, index) in form.items"
              :key="item.id"
              class="q-row"
              :class="{ 'is-dragging': dragFrom === index }"
              :data-question="item.id"
              draggable="true"
              @dragstart="dragFrom = index"
              @dragover.prevent
              @drop.prevent="onDrop(index)"
              @dragend="dragFrom = null"
            >
              <span class="q-num num" aria-hidden="true">{{ index + 1 }}</span>
              <button
                type="button"
                class="row-btn q-open"
                :aria-describedby="form.items.length > 1 ? 'tf-reorder-hint' : undefined"
                @click="question = { item }"
                @keydown="onQuestionKey($event, index)"
              >
                <span class="who"><span class="sr">{{ t('web.forms.editQuestion', { position: index + 1, name: '' }) }}</span>{{ labelOf(item, locale) }}</span>
                <span class="sub">{{ itemSub(item) }}</span>
              </button>
              <span class="q-move">
                <button type="button" class="icon-btn" :disabled="index === 0" :aria-label="t('web.forms.moveUp', { name: labelOf(item, locale) })" @click="move(index, -1)"><ArrowUp :size="16" aria-hidden="true" /></button>
                <button type="button" class="icon-btn" :disabled="index === form.items.length - 1" :aria-label="t('web.forms.moveDown', { name: labelOf(item, locale) })" @click="move(index, 1)"><ArrowDown :size="16" aria-hidden="true" /></button>
              </span>
            </li>
          </ol>
          <p v-if="removed" class="q-removed" data-testid="question-removed">
            <span>{{ t('web.forms.questionRemoved', { name: labelOf(removed.item, locale) }) }}</span>
            <button id="tf-undo" type="button" class="link" @click="undoRemove">{{ t('orderAssistantUndo') }}</button>
          </p>
          <button type="button" class="link" data-testid="add-question" @click="question = { item: null }">+ {{ t('checklistAddQuestion') }}</button>
        </section>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite" data-testid="template-hint">{{ problemText }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !canSave }" data-testid="save-template">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('checklistSave') }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
  <QuestionDialog v-if="question" :item="question.item" @save="onQuestion" @remove="removeQuestion" @close="question = null" />
  <ChoiceDialog v-else-if="dialog === 'menu' && template" :anchor="menuButton" :title="title" :choices="menuChoices" @pick="onPick" @close="onMenuClosed" />
  <ConfirmDialog
    v-else-if="dialog === 'delete' && template"
    :title="t('checklistDeleteTitle')"
    :body="t('checklistDeleteMessage', { name: template.title })"
    :confirm="t('checklistDelete')"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="dialog = null"
  />
</template>
