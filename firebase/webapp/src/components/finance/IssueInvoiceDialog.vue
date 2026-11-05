<script setup lang="ts">
// Emitir nota fiscal (nfse.issue.*): the server's preview first (value of each
// order, what is left out, the text and what is missing), then one request.
// "Emitir" stays grey with the first reason (nfse.issue.blockers). Refusals open
// what fixes them (nfse.issue.refusal). Nothing is sent before "Emitir".
import { computed, defineAsyncComponent, nextTick, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { addDays } from '@/lib/finance/period'
import { today } from '@/lib/finance/text'
import { issueInvoice, nfseSettings, previewInvoice } from '@/lib/nfse/data'
import { ALL_FIELDS, SETUP_ERRORS, askedFields, blockerOf, normalizeTaxId, type Contact, type CustomerField, type Preview } from '@/lib/nfse/model'
import { money, orderShort } from '@/lib/orders/text'
import { session } from '@/lib/session'
import { isValidTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import '@/styles/finance.css'

// The direct sheet (NFS-e direct, docs/NFSE_DIRECT.md) comes only when the company uses it.
const DirectIssueDialog = defineAsyncComponent(() => import('./DirectIssueDialog.vue'))
/** `direct`: the company issues by the NFS-e direct (nfseDirectEnabled): its own sheet, the Asaas one stays out. */
const props = defineProps<{ orderIds: string[]; customerId?: string | null; direct?: boolean }>()
const emit = defineEmits<{ done: []; close: [] }>()
const router = useRouter()
/** Closed first (the drawer takes its history entry out on unmount), then the setup opens. */
async function openSetup() {
  emit('close')
  await nextTick()
  await router.push('/invoices/setup')
}

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const preview = shallowRef<Preview | null>(null)
const description = ref('')
const day = ref(today())
const taxId = ref('')
const contact = ref<Contact>({})
const asking = ref<CustomerField[]>([])
const busy = ref(false)
/** Why the last attempt did not go: a text for people, never the raw server message alone. */
const refusal = ref<{ text: string; detail?: string; setup?: boolean } | null>(null)
const touched = ref(false)

const maxDay = addDays(today(), 60)

async function load(keepText = false) {
  state.value = preview.value ? state.value : 'loading'
  try {
    const data = await previewInvoice(props.orderIds, props.customerId)
    preview.value = data
    if (!keepText) description.value = data.serviceDescription
    contact.value = { ...data.customer.contact, ...stripEmpty(contact.value) }
    asking.value = asking.value.length ? asking.value : askedFields(data.customer.missingData)
    state.value = 'ready'
  } catch (error) {
    refusal.value = refusalOf(error)
    state.value = 'failed'
  }
}
/**
 * nfse.access.not-ready: with the setup not done, say so before asking the
 * server for a preview (the app's showNfseNotReady). A failed read goes on to
 * the preview, which refuses with the same sentence.
 */
onMounted(async () => {
  if (props.direct) return
  const settings = await nfseSettings().catch(() => null)
  if (settings && settings.available && !settings.ready) {
    refusal.value = { text: t('nfseNotReadyTitle'), setup: true }
    state.value = 'failed'
    return
  }
  void load()
})

function stripEmpty(value: Contact): Contact {
  return Object.fromEntries(Object.entries(value).filter(([, v]) => typeof v === 'string' && v.trim())) as Contact
}

const blocker = computed(() =>
  preview.value ? blockerOf(preview.value, { taxId: taxId.value, contact: contact.value, asking: asking.value }, isValidTaxId) : null,
)
const blockerText = computed(() => {
  const b = blocker.value
  if (!b) return ''
  if (b.kind === 'invoiced') return t('nfseAlreadyIssued', { numbers: b.numbers })
  if (b.kind === 'zero') return t('nfseNothingToIssue')
  if (b.kind === 'taxId') return t('nfseTaxIdMissing')
  return t('nfseCustomerDataMissing')
})
const several = computed(() => (preview.value?.orders.length ?? 0) > 1)
const productsOut = computed(() => preview.value?.hasProducts ?? false)
const discounted = computed(() => preview.value?.orders.some((o) => o.discount > 0) ?? false)
const isAdmin = computed(() => session.role === 'owner' || session.role === 'admin')

const ERROR_TEXT: Record<string, Parameters<typeof t>[0]> = {
  NFSE_NOT_ENABLED: 'nfseErrorNotEnabled',
  NFSE_NOT_READY: 'nfseErrorNotReady',
  NFSE_SETUP_NEEDED: 'nfseErrorSetupNeeded',
  NFSE_RECONNECT_NEEDED: 'nfseErrorReconnectNeeded',
  NFSE_SETUP_REJECTED: 'nfseErrorSetupRejected',
  NFSE_ORDER_NOT_ALLOWED: 'nfseErrorOrderNotAllowed',
  NO_SERVICES: 'nfseErrorNoServices',
  ORDER_HAS_INVOICE: 'nfseErrorOrderHasInvoice',
  ORDER_NOT_OF_CUSTOMER: 'nfseErrorOrderNotOfCustomer',
  TAX_ID_REQUIRED: 'nfseTaxIdMissing',
  INVALID_EFFECTIVE_DATE: 'nfseErrorInvalidDate',
  CUSTOMER_DATA_REQUIRED: 'nfseErrorCustomerData',
}

function refusalOf(error: unknown): { text: string; detail?: string; setup?: boolean } {
  if (error instanceof ApiError) {
    const key = ERROR_TEXT[error.code]
    if (error.code === 'ASAAS_VALIDATION_ERROR' && error.detail) return { text: t('nfseErrorAsaasSaid', { detail: error.detail }) }
    if (key) {
      const setup = SETUP_ERRORS.has(error.code)
      return { text: t(key), detail: error.code === 'NFSE_SETUP_REJECTED' || error.code === 'CUSTOMER_DATA_REQUIRED' ? error.detail : undefined, setup }
    }
  }
  return { text: t(errorMessageKey(error)) }
}

async function send() {
  const p = preview.value
  if (!p || blocker.value || busy.value) return
  busy.value = true
  refusal.value = null
  try {
    const customerData = asking.value.length
      ? (Object.fromEntries([...asking.value, 'complement'].map((field) => [field, (contact.value[field as keyof Contact] ?? '').trim()]).filter(([, v]) => v)) as Contact)
      : undefined
    await issueInvoice({
      orderIds: props.orderIds,
      customerId: p.customer.id,
      serviceDescription: description.value.trim() || undefined,
      // Today goes as nothing: the server issues at once.
      effectiveDate: day.value === today() ? null : day.value,
      customerTaxId: !p.customer.hasTaxId ? normalizeTaxId(taxId.value) : undefined,
      customerData,
    })
    touched.value = false
    showToast(t('nfseSent'))
    emit('done')
  } catch (error) {
    refusal.value = refusalOf(error)
    if (error instanceof ApiError && error.code === 'CUSTOMER_DATA_REQUIRED') {
      // Every contact field opens, filled with what Asaas has; the text typed stays.
      asking.value = ALL_FIELDS
      await load(true)
    }
  } finally {
    busy.value = false
  }
}

/** Closing with something typed asks first (the app's D14: the text was lost). */
const guard = async () => !touched.value || window.confirm(t('web.nfse.discard'))
const mark = () => (touched.value = true)
</script>

<template>
  <DirectIssueDialog v-if="direct" :order-ids="orderIds" :customer-id="customerId" @done="emit('done')" @close="emit('close')" />
  <Layer v-else kind="drawer" :label="t('nfseIssueAction')" :guard="guard" @close="emit('close')">
    <template #default="{ close }">
      <form class="issue" data-testid="nfse-issue" @submit.prevent="send" @input="mark">
        <div class="layer-head">
          <h2 class="layer-title">{{ preview ? t('web.nfse.issueTitle', { amount: money(preview.value) }) : t('nfseIssueAction') }}</h2>
        </div>
        <div class="layer-body">
          <p v-if="state === 'loading'" role="status">{{ t('web.loading') }}</p>
          <template v-else-if="state === 'failed'">
            <p class="field-error" role="alert" data-testid="nfse-refusal">{{ refusal?.text }}</p>
            <p v-if="refusal?.setup" class="sub" data-testid="nfse-setup-hint">
              <template v-if="isAdmin">{{ t('nfseNotReadyAdmin') }} <button type="button" class="link" @click="openSetup">{{ t('nfseSetupAction') }}</button></template>
              <template v-else>{{ t('nfseNotReadyOther') }}</template>
            </p>
          </template>
          <template v-else-if="preview">
            <p class="sub">{{ t('web.nfse.goesToCity') }}</p>
            <p v-if="several" class="sub">{{ t('nfseSeveralIntro', { count: preview.orders.length, name: preview.customer.name ?? '', numbers: preview.orders.map((o) => o.orderNumber).join(', ') }) }}</p>
            <ul class="issue-lines">
              <li v-for="o in preview.orders" :key="o.orderId" class="pay-row">
                <span>{{ t('web.fin.orderNumber', { order: orderShort(), number: o.orderNumber ?? '' }) }}<span v-if="preview.customer.name" class="sub"> · {{ preview.customer.name }}</span></span>
                <span class="num">{{ money(o.value) }}</span>
              </li>
            </ul>
            <p class="issue-total"><span>{{ t('nfseValueLabel') }}</span> <b class="num" data-testid="nfse-value">{{ money(preview.value) }}</b></p>
            <p v-if="productsOut" class="sub" role="note">{{ t('nfseOnlyServicesNote') }}</p>
            <p v-if="discounted" class="sub" role="note">{{ t('nfseDiscountNote') }}</p>
            <p class="sub">{{ t('nfseServiceRow') }}: {{ preview.municipalServiceName }}</p>

            <label class="field-label" for="nfse-text">{{ t('nfseDescriptionLabel') }}</label>
            <textarea id="nfse-text" v-model="description" class="field" rows="4" maxlength="2000"></textarea>

            <label class="field-label" for="nfse-day">{{ t('nfseDateLabel') }}</label>
            <input id="nfse-day" v-model="day" class="field" type="date" :min="today()" :max="maxDay" required />

            <template v-if="!preview.customer.hasTaxId">
              <label class="field-label" for="nfse-taxid">{{ t('web.nfse.taxId') }}</label>
              <input id="nfse-taxid" v-model="taxId" class="field" inputmode="text" autocomplete="off" maxlength="20" aria-describedby="nfse-taxid-hint" />
              <p id="nfse-taxid-hint" class="sub">{{ t('nfseTaxIdHint') }}</p>
            </template>

            <fieldset v-if="asking.length" class="issue-contact">
              <legend class="field-label">{{ t('nfseCustomerDataIntro') }}</legend>
              <template v-if="asking.includes('email')">
                <label class="field-label" for="nfse-email">{{ t('email') }}</label>
                <input id="nfse-email" v-model="contact.email" class="field" type="email" autocomplete="off" />
              </template>
              <template v-if="asking.includes('postalCode')">
                <label class="field-label" for="nfse-cep">{{ t('nfsePostalCode') }}</label>
                <input id="nfse-cep" v-model="contact.postalCode" class="field" inputmode="numeric" maxlength="9" autocomplete="off" />
                <label class="field-label" for="nfse-street">{{ t('nfseStreet') }}</label>
                <input id="nfse-street" v-model="contact.address" class="field" autocomplete="off" />
                <label class="field-label" for="nfse-number">{{ t('web.nfse.addressNumber') }}</label>
                <input id="nfse-number" v-model="contact.addressNumber" class="field" autocomplete="off" />
                <label class="field-label" for="nfse-complement">{{ t('nfseAddressComplement') }}</label>
                <input id="nfse-complement" v-model="contact.complement" class="field" autocomplete="off" />
                <label class="field-label" for="nfse-district">{{ t('nfseDistrict') }}</label>
                <input id="nfse-district" v-model="contact.province" class="field" autocomplete="off" />
              </template>
            </fieldset>

            <div v-if="refusal" class="field-error" role="alert" data-testid="nfse-refusal">
              <p>{{ refusal.text }}</p>
              <p v-if="refusal.detail" class="sub">{{ refusal.detail }}</p>
              <p v-if="refusal.setup" class="sub">
                <template v-if="isAdmin">{{ t('nfseNotReadyAdmin') }} <button type="button" class="link" @click="openSetup">{{ t('nfseSetupAction') }}</button></template>
                <template v-else>{{ t('nfseNotReadyOther') }}</template>
              </p>
            </div>
            <p v-else-if="blockerText" class="sub" role="status" data-testid="nfse-blocker">{{ blockerText }}</p>
          </template>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="state !== 'ready' || !!blocker || busy" data-testid="nfse-send">{{ t('web.nfse.issue') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
