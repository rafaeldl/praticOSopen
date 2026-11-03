<script setup lang="ts">
// Checklists (checklist.list.*, checklist.view.*): "Seus checklists" and
// "Prontos para usar" of the segment, only for who manages them (manageForms:
// owner, admin, supervisor). The app opens this screen for any role and its
// actions fail on save; here the route is closed. Each list has its own
// loading and error (the app hides a failed ready-made list), a ready-made one
// already copied does not show again, and deleting keeps the row on a failure.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import Layer from '@/components/Layer.vue'
import TemplateEditor from '@/components/forms/TemplateEditor.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { deleteTemplate, importReady, loadReadyTemplates, loadSubscription, watchTemplates } from '@/lib/forms/data'
import { activeCount, byTitle, descriptionOf, fitsOneMore, hasPhotoQuestion, labelOf, planLimit, readyNotCopied, titleOf, type Template } from '@/lib/forms/model'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/forms.css'

const route = useRoute()
const router = useRouter()
const templates = shallowRef<Template[] | null>(null)
const failed = ref(false)
const ready = shallowRef<Template[] | null>(null)
const readyFailed = ref(false)
const subscription = shallowRef<unknown>(null)
/** The plan, read once; unread (or failed) it does not block anyone. */
let plan: Promise<unknown> = Promise.resolve(null)
const planKnown = ref(false)
const removing = ref<Template | null>(null)
const using = ref<Template | null>(null)
const preview = ref<Template | null>(null)
const busy = ref(false)
const limitNote = ref('')
let stop: (() => void) | undefined

const editingId = computed(() => (typeof route.query.checklist === 'string' ? route.query.checklist : null))
const editing = computed(() => (editingId.value === 'new' ? null : (templates.value?.find((item) => item.id === editingId.value) ?? null)))
const editorOpen = computed(() => editingId.value === 'new' || !!editing.value)
const sorted = computed(() => [...(templates.value ?? [])].sort(byTitle))
const readyList = computed(() => (ready.value && templates.value ? readyNotCopied(ready.value, templates.value).sort(byTitle) : []))
const active = computed(() => activeCount(templates.value ?? []))
const limit = computed(() => (planKnown.value ? planLimit(subscription.value, new Date()) : -1))
const fits = computed(() => fitsOneMore(active.value, limit.value))
const state = computed(() => (failed.value ? 'failed' : templates.value === null ? 'loading' : 'ready'))
const bothEmpty = computed(() => state.value === 'ready' && !sorted.value.length && ready.value !== null && !readyList.value.length)

const questionsText = (template: Template) => [t('checklistQuestions', { count: template.items.length }), hasPhotoQuestion(template) ? t('checklistWithPhotos') : ''].filter(Boolean).join(' · ')

async function listen() {
  failed.value = false
  stop?.()
  try {
    stop = await watchTemplates(
      (list) => (templates.value = list),
      (error) => {
        console.error('forms: templates failed', error)
        failed.value = true
      },
    )
  } catch (error) {
    console.error('forms: templates failed', error)
    failed.value = true
  }
}

async function loadReady() {
  readyFailed.value = false
  try {
    ready.value = await loadReadyTemplates()
  } catch (error) {
    console.error('forms: ready-made failed', error)
    readyFailed.value = true
  }
}

/** One more active checklist must fit the plan, checked before opening (the app checks only on save). */
function roomForOne(): boolean {
  if (fits.value) return true
  limitNote.value = t('planLimitChecklists', { used: active.value, limit: limit.value })
  showToast(limitNote.value)
  announce(limitNote.value)
  return false
}

async function openEditor(id: string) {
  if (id === 'new') {
    await plan
    if (!roomForOne()) return
  }
  void router.push({ query: { ...route.query, checklist: id } })
}

function closeEditor() {
  const { checklist: _drop, ...rest } = route.query
  void router.replace({ query: rest })
}

async function remove() {
  const template = removing.value
  if (!template || busy.value) return
  busy.value = true
  try {
    await deleteTemplate(template.id)
    removing.value = null
    const message = t('web.forms.deleted', { name: template.title })
    showToast(message)
    announce(message)
  } catch (error) {
    removing.value = null
    // The row stays: it was not deleted (the app takes it off anyway).
    showToast(`${t('web.forms.deleteFailed')} ${t(errorMessageKey(error))}`.trim())
  } finally {
    busy.value = false
  }
}

async function useReady() {
  const template = using.value
  if (!template || busy.value) return
  await plan
  if (template.isActive && !roomForOne()) {
    using.value = null
    return
  }
  busy.value = true
  try {
    await importReady(template)
    using.value = null
    preview.value = null
    const message = t('web.forms.imported', { name: titleOf(template, locale.value) })
    showToast(message)
    announce(message)
  } catch (error) {
    using.value = null
    showToast(`${t('couldNotImportProcedure')} ${t(errorMessageKey(error))}`.trim())
  } finally {
    busy.value = false
  }
}

onMounted(() => {
  void listen()
  void loadReady()
  plan = loadSubscription()
    .then((value) => {
      subscription.value = value
      planKnown.value = true
    })
    .catch((error) => console.warn('forms: plan not read', error))
})
onBeforeUnmount(() => {
  stop?.()
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('checklistsTitle') }}</h1>
      <p class="page-sub" data-testid="checklists-summary">
        {{ t('checklistsSubtitle') }}<template v-if="state === 'ready' && limit !== -1"> · {{ t('web.forms.activeOfLimit', { used: active, limit }) }}</template>
      </p>
    </div>
    <button type="button" class="btn btn--primary" data-testid="new-checklist" @click="openEditor('new')">{{ t('checklistNew') }}</button>
  </header>

  <div class="workspace">
    <div class="list-pane forms-page">
      <p v-if="limitNote" class="field-error" role="status" data-testid="checklists-limit">{{ limitNote }}</p>
      <section aria-labelledby="checklists-yours">
        <h2 id="checklists-yours" class="forms-h">{{ t('checklistsYours') }}</h2>
        <LoadingState v-if="state === 'loading'" />
        <ErrorState v-else-if="state === 'failed'" :body="t('errorLoadingProcedures')" :retry="listen" />
        <EmptyState v-else-if="bothEmpty" :title="t('checklistsEmpty')" data-testid="checklists-empty">
          <button type="button" class="btn btn--primary" @click="openEditor('new')">{{ t('checklistNew') }}</button>
        </EmptyState>
        <p v-else-if="!sorted.length" class="muted forms-none">{{ t('web.forms.noneYet') }}</p>
        <ul v-else class="forms-list" data-testid="checklists-list">
          <li v-for="template in sorted" :key="template.id" class="forms-row" :data-template="template.id">
            <button type="button" class="row-btn forms-row-main" @click="openEditor(template.id)">
              <span class="who"><span class="sr">{{ t('web.forms.open', { name: '' }) }}</span>{{ titleOf(template, locale) }}</span>
              <span class="sub">
                <template v-if="!template.isActive"><span class="dot dot--hollow" aria-hidden="true"></span> {{ t('checklistOff') }} · </template>{{ questionsText(template) }}
              </span>
            </button>
            <button type="button" class="link link--danger" :aria-label="t('web.forms.deleteNamed', { name: titleOf(template, locale) })" @click="removing = template">{{ t('web.forms.delete') }}</button>
          </li>
        </ul>
      </section>

      <section aria-labelledby="checklists-ready" class="forms-ready">
        <h2 id="checklists-ready" class="forms-h">{{ t('checklistsReady') }}</h2>
        <LoadingState v-if="ready === null && !readyFailed" />
        <ErrorState v-else-if="readyFailed" :body="t('errorLoadingProcedures')" :retry="loadReady" />
        <p v-else-if="!readyList.length" class="muted forms-none" data-testid="ready-none">{{ t('web.forms.readyNone') }}</p>
        <ul v-else class="forms-list" data-testid="ready-list">
          <li v-for="template in readyList" :key="template.id" class="forms-row" :data-ready="template.id">
            <button type="button" class="row-btn forms-row-main" @click="preview = template">
              <span class="who"><span class="sr">{{ t('web.forms.preview', { name: '' }) }}</span>{{ titleOf(template, locale) }}</span>
              <span class="sub">{{ questionsText(template) }}</span>
            </button>
            <button type="button" class="btn" :aria-label="t('web.forms.useNamed', { name: titleOf(template, locale) })" @click="using = template">{{ t('checklistUse') }}</button>
          </li>
        </ul>
      </section>
    </div>
  </div>

  <TemplateEditor
    v-if="editorOpen && templates"
    :key="editingId ?? ''"
    :template="editing"
    :room="fits"
    :limit-text="t('planLimitChecklists', { used: active, limit })"
    @saved="closeEditor"
    @close="closeEditor"
  />
  <Layer v-if="preview && !using" kind="dialog" :label="titleOf(preview, locale)" @close="preview = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ titleOf(preview, locale) }}</h2>
        <p class="sub">{{ t('checklistQuestions', { count: preview.items.length }) }}</p>
      </div>
      <div class="layer-body" data-testid="ready-preview">
        <p v-if="descriptionOf(preview, locale)">{{ descriptionOf(preview, locale) }}</p>
        <ol class="forms-preview">
          <li v-for="item in preview.items" :key="item.id">{{ labelOf(item, locale) }}</li>
        </ol>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" data-autofocus @click="close()">{{ t('close') }}</button>
        <button type="button" class="btn btn--primary" @click="using = preview">{{ t('checklistUse') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="using"
    :title="t('web.forms.useTitle', { name: titleOf(using, locale) })"
    :body="t('web.forms.useBody')"
    :confirm="t('checklistUse')"
    :keep="t('cancel')"
    @confirm="useReady"
    @close="using = null"
  />
  <ConfirmDialog
    v-if="removing"
    :title="t('checklistDeleteTitle')"
    :body="t('checklistDeleteMessage', { name: removing.title })"
    :confirm="t('checklistDelete')"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="removing = null"
  />
</template>
