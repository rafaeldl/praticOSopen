<script setup lang="ts">
// "Checklists" of the open order (order.checklist.*): one row per checklist
// with "x de y respondidas" or "Completo", opening it to fill. Adding asks the
// device first when the order has two or more (one checklist per device chosen,
// or "Geral"), then "Qual checklist?". Removing is on the row, with a
// confirmation. Who may add or remove follows canManageOrderForms (technician
// only in a quote, supervisor until done). Loaded on demand with the order.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import ErrorState from '@/components/ErrorState.vue'
import FormFill from './FormFill.vue'
import TemplateEditor from './TemplateEditor.vue'
import TemplatePicker from './TemplatePicker.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { addOrderForm, deleteOrderForm, loadReadyTemplates, loadSubscription, watchOrderForms, watchTemplates } from '@/lib/forms/data'
import { activeCount, activeLimit, answeredCount, completedStatus, fitsOneMore, formsAccess, titleOf, WEB_PLAN_LIMITS_ENFORCED, type OrderForm, type Template } from '@/lib/forms/model'
import { declinedCount, offerDone, offerWaiting, rememberDecline, shouldOffer } from '@/lib/forms/offer'
import { orderRoleOf, type Order } from '@/lib/orders/model'
import { deviceLabel } from '@/lib/orders/text'
import { orderPermissions } from '@/lib/rules/order-rules'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/forms.css'

const props = defineProps<{ order: Order }>()
const emit = defineEmits<{ forms: [list: OrderForm[]] }>()

const forms = shallowRef<OrderForm[] | null>(null)
const failed = ref(false)
const templates = shallowRef<Template[] | null>(null)
const templatesFailed = ref(false)
const subscription = shallowRef<unknown>(null)
/** The plan was read: before that the limit is unknown and blocks nobody (B3 of #524). */
const planKnown = ref(false)
/** The segment's ready-made ones, offered in "Qual checklist?" as in the app. */
const ready = shallowRef<Template[] | null>(null)
type Step = { kind: 'device' } | { kind: 'pick'; deviceId: string | null } | { kind: 'create'; deviceId: string | null } | { kind: 'remove'; form: OrderForm } | { kind: 'offer' }
const step = shallowRef<Step | null>(null)
const filling = ref<{ id: string; start: boolean } | null>(null)
const adding = ref(false)
let stopForms: (() => void) | undefined
let stopTemplates: (() => void) | undefined
let offerWanted = false
let createdId: string | null = null
let createdFor: string | null = null

const access = computed(() => {
  const role = orderRoleOf(session.role)
  const isCreator = !!session.uid && props.order.createdBy?.id === session.uid
  const base = role ? orderPermissions(role, isCreator, props.order.status) : null
  return formsAccess(session.role, !!base?.canManageForms, can('fillForms'), !!base?.canAccess)
})
const fillingForm = computed(() => (filling.value ? (forms.value?.find((form) => form.id === filling.value?.id) ?? null) : null))
const deviceName = (id: string | null) => {
  const found = id ? props.order.devices.find((device) => device.id === id) : null
  return found ? [found.name, found.serial].filter(Boolean).join(' · ') : null
}
const deviceChoices = computed<Choice[]>(() => [
  ...props.order.devices.filter((device) => device.id).map((device) => ({ id: device.id as string, label: device.name ?? '', sub: device.serial ?? undefined })),
  { id: '__none', label: t('generalNoDevice') },
])
const active = computed(() => activeCount(templates.value ?? []))
const limit = computed(() => (planKnown.value ? activeLimit(subscription.value, new Date()) : -1))

async function listen() {
  failed.value = false
  stopForms?.()
  try {
    stopForms = await watchOrderForms(
      props.order.id,
      (list) => {
        forms.value = list
        emit('forms', list)
      },
      (error) => {
        console.error('forms: order checklists failed', error)
        failed.value = true
      },
    )
  } catch (error) {
    console.error('forms: order checklists failed', error)
    failed.value = true
  }
}

async function loadTemplates() {
  templatesFailed.value = false
  if (ready.value === null) {
    // Optional, as in the app: without them the company's still show.
    void loadReadyTemplates()
      .then((list) => (ready.value = list))
      .catch((error) => {
        console.warn('forms: ready-made not read', error)
        ready.value = []
      })
  }
  if (stopTemplates) return
  try {
    stopTemplates = await watchTemplates(
      (list) => {
        templates.value = list
        afterTemplates()
      },
      (error) => {
        console.error('forms: templates failed', error)
        templatesFailed.value = true
        stopTemplates?.()
        stopTemplates = undefined
      },
    )
  } catch (error) {
    console.error('forms: templates failed', error)
    templatesFailed.value = true
  }
}

function retryTemplates() {
  stopTemplates?.()
  stopTemplates = undefined
  void loadTemplates()
}

/** Start: the device first with two or more (checklist.pick.device-first). */
function startAdd() {
  if (!access.value.manage) return
  void loadTemplates()
  step.value = props.order.devices.length >= 2 ? { kind: 'device' } : { kind: 'pick', deviceId: props.order.devices[0]?.id ?? null }
}

async function add(template: Template, deviceId: string | null) {
  step.value = null
  if (adding.value) return
  adding.value = true
  try {
    const form = await addOrderForm(props.order.id, template, deviceId)
    announce(t('web.forms.added', { name: titleOf(template, locale.value) }))
    // Straight to the questions, like the app.
    filling.value = { id: form.id, start: true }
  } catch (error) {
    // The app fails silently here (defect 68).
    showToast(`${t('web.forms.addFailed')} ${t(errorMessageKey(error))}`.trim())
  } finally {
    adding.value = false
  }
}

/** "Novo checklist" in the picker: created, then chosen for this order (the app only reloads the list). */
function create(deviceId: string | null) {
  step.value = { kind: 'create', deviceId }
  // Only where plan limits apply (not in the browser, like the app); read meanwhile, never assumed Free.
  if (WEB_PLAN_LIMITS_ENFORCED && !planKnown.value) {
    void loadSubscription()
      .then((value) => {
        subscription.value = value
        planKnown.value = true
      })
      .catch((error) => console.warn('forms: plan not read', error))
  }
}
function onCreated(id: string) {
  const deviceId = step.value?.kind === 'create' ? step.value.deviceId : null
  step.value = null
  createdId = id
  createdFor = deviceId
  afterTemplates()
}

function afterTemplates() {
  const list = templates.value
  if (!list) return
  if (createdId) {
    const made = list.find((template) => template.id === createdId)
    if (made) {
      createdId = null
      void add(made, createdFor)
    }
  }
  if (offerWanted) {
    offerWanted = false
    offerDone(props.order.id)
    const companyId = session.companyId as string
    const ok = shouldOffer({
      hasDevice: props.order.devices.length > 0,
      isContract: false,
      canManageForms: access.value.manage,
      declined: declinedCount(companyId),
      activeTemplates: activeCount(list),
    })
    if (ok && !step.value) step.value = { kind: 'offer' }
  }
}

function answerOffer(yes: boolean) {
  rememberDecline(session.companyId as string, !yes)
  step.value = null
  if (yes) startAdd()
}

async function remove(form: OrderForm) {
  step.value = null
  try {
    await deleteOrderForm(props.order.id, form.id)
    const message = t('web.forms.removed', { name: titleOf(form, locale.value) })
    showToast(message)
    announce(message)
  } catch (error) {
    showToast(`${t('web.forms.removeFailed')} ${t(errorMessageKey(error))}`.trim())
  }
}

/** The order screen opens a pending checklist when "concluir" is blocked (order.status.pending-checklist). */
function open(formId: string) {
  filling.value = { id: formId, start: false }
}
defineExpose({ open, startAdd })

function statusText(form: OrderForm) {
  if (form.status !== 'completed') return t('orderChecklistProgress', { answered: answeredCount(form), total: form.items.length })
  const done = completedStatus(form)
  return t(done.key, { count: done.count })
}

watch(
  () => props.order.id,
  () => void listen(),
)
onMounted(() => {
  void listen()
  if (offerWaiting(props.order.id) && access.value.manage) {
    offerWanted = true
    void loadTemplates()
  }
})
onBeforeUnmount(() => {
  stopForms?.()
  stopTemplates?.()
})
</script>

<template>
  <section v-if="failed || (forms && (forms.length || access.manage))" class="od-sec od-sec--forms" aria-labelledby="od-forms-title" data-testid="order-forms">
    <h3 id="od-forms-title">
      {{ t('checklists') }}
      <button v-if="access.manage" type="button" class="link" data-testid="add-checklist" :disabled="adding" @click="startAdd">+ {{ t('web.forms.add') }}</button>
    </h3>
    <ErrorState v-if="failed" :body="t('errorLoadingProcedures')" :retry="listen" />
    <ul v-else-if="forms?.length" class="items">
      <li v-for="form in forms" :key="form.id" class="item" :data-form="form.id">
        <span>
          <button type="button" class="link-plain item-name" :aria-label="t('web.forms.openFill', { name: titleOf(form, locale) })" @click="filling = { id: form.id, start: false }">{{ titleOf(form, locale) }}</button>
          <span v-if="deviceName(form.deviceId)" class="sub">{{ deviceName(form.deviceId) }}</span>
          <span class="sub" data-testid="form-progress"><span class="dot" :class="form.status === 'completed' ? 'dot--success' : 'dot--warning'" aria-hidden="true"></span> {{ statusText(form) }}</span>
        </span>
        <button v-if="access.manage" type="button" class="link link--danger" :aria-label="t('web.forms.removeNamed', { name: titleOf(form, locale) })" @click="step = { kind: 'remove', form }">{{ t('remove') }}</button>
      </li>
    </ul>
    <p v-else class="muted">{{ t('web.forms.noneOnOrder') }}</p>
  </section>

  <ChoiceDialog
    v-if="step?.kind === 'device'"
    :title="t('pickerDeviceTitle', { device: deviceLabel().toLocaleLowerCase() })"
    :sub="t('web.forms.deviceSub')"
    :choices="deviceChoices"
    @pick="(id) => (step = { kind: 'pick', deviceId: id === '__none' ? null : id })"
    @close="step = null"
  />
  <TemplatePicker
    v-else-if="step?.kind === 'pick'"
    :templates="templates"
    :ready="ready"
    :failed="templatesFailed"
    :can-create="can('manageForms')"
    :sub="deviceName(step.deviceId) ?? undefined"
    @pick="(template) => add(template, step?.kind === 'pick' ? step.deviceId : null)"
    @create="create(step?.kind === 'pick' ? step.deviceId : null)"
    @retry="retryTemplates"
    @close="step = null"
  />
  <TemplateEditor
    v-else-if="step?.kind === 'create'"
    :template="null"
    :room="fitsOneMore(active, limit)"
    :limit-text="t('planLimitChecklists', { used: active, limit })"
    @saved="onCreated"
    @close="step = null"
  />
  <ConfirmDialog
    v-else-if="step?.kind === 'remove'"
    :title="t('web.forms.removeTitle', { name: titleOf(step.form, locale) })"
    :body="t('web.forms.removeBody')"
    :confirm="t('remove')"
    :keep="t('cancel')"
    danger
    @confirm="remove((step as { form: OrderForm }).form)"
    @close="step = null"
  />
  <ConfirmDialog
    v-else-if="step?.kind === 'offer'"
    :title="t('checklistOfferTitle')"
    :body="t('checklistOfferMessage', { device: order.devices[0]?.name ?? '' })"
    :confirm="t('checklistOfferAction')"
    :keep="t('notNow')"
    @confirm="answerOffer(true)"
    @close="answerOffer(false)"
  />
  <FormFill
    v-if="fillingForm"
    :key="fillingForm.id"
    :order-id="order.id"
    :form="fillingForm"
    :access="access"
    :devices="order.devices"
    :start="filling?.start"
    @close="filling = null"
  />
</template>
