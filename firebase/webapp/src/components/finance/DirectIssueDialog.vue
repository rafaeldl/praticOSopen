<script setup lang="ts">
// Emitir nota fiscal pelo motor direto (spec §4.6, docs/NFSE_DIRECT.md): the
// server's preview, then one request to the nfseApi. Top to bottom: "Emitir
// por" (the CNPJ the server marked; another only when there are several), "Para"
// (the customer or its "Nota fiscal para"; another only for this nota), what
// is missing to complete, the value, the description, the MEI warning and
// "Emitir". The government answers at once: issued, refused in plain words
// with what fixes it, or no clear answer yet (the nota shows when it comes).
import { computed, nextTick, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import Combobox, { type ComboboxGroup, type ComboboxItem } from '@/components/Combobox.vue'
import Layer from '@/components/Layer.vue'
import ChoiceDialog from '@/components/orders/ChoiceDialog.vue'
import { locale, t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { loadCustomerDirectory } from '@/lib/customers/data'
import type { CustomerRow } from '@/lib/customers/model'
import {
  cepDigits,
  directBlocker,
  directFailure,
  emitterSummaries,
  fillAddress,
  issueDirect,
  lookupPostalCode,
  meiWarningText,
  previewDirect,
  problemText,
  recipientInput,
  type DirectFailure,
  type DirectPreview,
  type EmitterSummary,
  type FiscalAddress,
  type RecipientField,
} from '@/lib/nfse/direct-issue'
import { money, orderShort } from '@/lib/orders/text'
import { session } from '@/lib/session'
import { formatTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import '@/styles/finance.css'

const props = defineProps<{ orderIds: string[]; customerId?: string | null }>()
const emit = defineEmits<{ done: []; close: [] }>()
const router = useRouter()

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const preview = shallowRef<DirectPreview | null>(null)
/** The CNPJ picked in this sheet (null: the one the server marks). */
const emitterId = ref<string | null>(null)
/** Another customer receives this nota only (null: the usual one). */
const recipientId = ref<string | null>(null)
const description = ref('')
const asking = ref<RecipientField[]>([])
const taxId = ref('')
const email = ref('')
const address = ref<FiscalAddress>({})
const busy = ref(false)
const failure = ref<DirectFailure | null>(null)
const touched = ref(false)
const picking = ref<'emitter' | 'recipient' | null>(null)
const lookingUp = ref(false)

const isAdmin = computed(() => session.role === 'owner' || session.role === 'admin')

async function load(keepText = false) {
  if (!preview.value) state.value = 'loading'
  try {
    let data: DirectPreview
    try {
      data = await previewDirect({ orderIds: props.orderIds, emitterId: emitterId.value, recipientCustomerId: recipientId.value })
    } catch (error) {
      // Several CNPJs and none marked: the first one is offered, the sheet lets the user switch.
      if (!(error instanceof ApiError) || error.code !== 'EMITTER_NOT_FOUND' || emitterId.value) throw error
      const first = (await emitterSummaries().catch(() => []))[0]
      if (!first) throw error
      emitterId.value = first.id
      data = await previewDirect({ orderIds: props.orderIds, emitterId: first.id, recipientCustomerId: recipientId.value })
    }
    preview.value = data
    if (!keepText) description.value = data.description
    // The fields open with what is missing (or all, after a refusal about the customer); what was typed stays.
    const wanted = new Set<RecipientField>([...(keepText ? asking.value : []), ...data.missing])
    asking.value = (['taxId', 'address', 'email'] as RecipientField[]).filter((f) => wanted.has(f))
    prefill(data)
    state.value = 'ready'
  } catch (error) {
    failure.value = directFailure(error, locale.value)
    state.value = 'failed'
  }
}
onMounted(() => void load())

/** The fields start with what the recipient already has; nothing typed is replaced. */
function prefill(data: DirectPreview) {
  const r = data.recipient
  if (!taxId.value.trim() && r.taxId) taxId.value = formatTaxId(r.taxId)
  if (!email.value.trim() && r.email) email.value = r.email
  if (r.address) {
    const typed = Object.fromEntries(Object.entries(address.value).filter(([, v]) => typeof v === 'string' && v.trim()))
    address.value = { ...r.address, ...typed }
  }
}

const form = computed(() => ({ asking: asking.value, taxId: taxId.value, email: email.value, address: address.value }))
const blocker = computed(() => (preview.value ? directBlocker(preview.value, form.value) : null))
const blockerText = computed(() => {
  const b = blocker.value
  if (!b) return ''
  if (b.kind === 'invoiced') return t('nfseAlreadyIssued', { numbers: b.numbers })
  if (b.kind === 'zero') return t('nfseNothingToIssue')
  if (b.kind === 'emitter') return '' // said under "Emitir por"
  if (b.kind === 'taxId') return t('nfseTaxIdMissing')
  if (b.kind === 'address') return t('web.nfseDirect.addressMissing')
  return t('web.nfseDirect.emailMissing')
})

const emitterLine = (e: EmitterSummary) => `${e.legalName} · ${formatTaxId(e.taxId)}`
const regimeText = (e: EmitterSummary) => (e.regime === 'mei' ? t('nfseDirectRegimeMei') : e.regime === 'simples' ? t('nfseDirectRegimeSimples') : '')
const recipientLine = computed(() => {
  const r = preview.value?.recipient
  if (!r) return ''
  const name = r.legalName ?? r.name ?? ''
  if (!r.taxId) return name
  const kind = r.taxId.length === 11 ? 'CPF' : 'CNPJ'
  return `${name} · ${kind} ${formatTaxId(r.taxId)}`
})
const meiText = computed(() => (preview.value ? meiWarningText(preview.value.meiWarning) : null))
const discounted = computed(() => preview.value?.orders.some((o) => o.discount > 0) ?? false)

const emitterChoices = computed(() =>
  (preview.value?.emitters ?? []).map((e) => ({
    id: e.id,
    label: emitterLine(e),
    sub: e.problem ? problemText(e.problem) : [regimeText(e), e.isDefault ? t('nfseDirectDefault') : ''].filter(Boolean).join(' · '),
    current: e.id === preview.value?.emitter.id,
  })),
)

async function pickEmitter(id: string) {
  picking.value = null
  if (id === preview.value?.emitter.id) return
  emitterId.value = id
  failure.value = null
  // The description follows the CNPJ's style, unless it was edited.
  const edited = description.value.trim() !== (preview.value?.description ?? '').trim()
  await load(edited)
}

// "Para": another customer for this nota only.
const customers = shallowRef<CustomerRow[]>([])
const customersLoading = ref(false)
async function openRecipient() {
  picking.value = 'recipient'
  if (customers.value.length) return
  customersLoading.value = true
  try {
    customers.value = (await loadCustomerDirectory()).rows
  } catch {
    showToast(t('web.error.generic'))
  } finally {
    customersLoading.value = false
  }
}
const fold = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
const recipientGroups = (query: string): ComboboxGroup[] => {
  const term = fold(query.trim())
  const digits = query.replace(/\D/g, '')
  const hits = customers.value.filter(
    (c) => !term || fold(c.name).includes(term) || (digits.length >= 3 && (c.taxId ?? '').replace(/\D/g, '').includes(digits)),
  )
  return [{ items: hits.slice(0, 50).map((c) => ({ id: c.id, label: c.name, sub: c.taxId ? formatTaxId(c.taxId) : undefined })) }]
}
async function pickRecipient(item: ComboboxItem) {
  picking.value = null
  // The one already receiving it changes nothing; any other (the order's own customer too) is for this nota only.
  if (item.id === preview.value?.recipient.customerId) return
  await setRecipient(item.id)
}
async function setRecipient(id: string | null) {
  if (id === recipientId.value) return
  recipientId.value = id
  // Another customer: its own data, not what was typed for the previous one.
  taxId.value = ''
  email.value = ''
  address.value = {}
  asking.value = []
  failure.value = null
  await load(true)
}

// CEP → street, district, city, UF and the IBGE code.
async function onCep() {
  const cep = cepDigits(address.value.postalCode)
  if (cep.length !== 8 || lookingUp.value) return
  lookingUp.value = true
  try {
    const found = await lookupPostalCode(cep)
    if (found) address.value = fillAddress(address.value, found)
  } finally {
    lookingUp.value = false
  }
}

async function openSetup() {
  const id = preview.value?.emitter.id
  emit('close')
  await nextTick()
  await router.push({ path: '/invoices/direct', query: id ? { e: id } : {} })
}

async function send() {
  const p = preview.value
  if (!p || blocker.value || busy.value) return
  busy.value = true
  failure.value = null
  try {
    const edited = description.value.trim() && description.value.trim() !== p.description.trim() ? description.value.trim() : undefined
    const invoice = await issueDirect({
      orderIds: props.orderIds,
      emitterId: p.emitter.id,
      ...(edited ? { description: edited } : {}),
      recipient: recipientInput(form.value, recipientId.value),
    })
    touched.value = false
    if (invoice.status === 'creating') showToast(t('web.nfseDirect.waitingGov'))
    else showToast(invoice.number ? t('nfseStatusIssuedNumber', { number: invoice.number }) : t('nfseStatusIssued'))
    emit('done')
  } catch (error) {
    const result = directFailure(error, locale.value)
    failure.value = result
    if (result.fields) {
      // Every field of "Para" opens, filled with what the customer has; the text typed stays.
      asking.value = ['taxId', 'address', 'email']
      await load(true)
    }
  } finally {
    busy.value = false
  }
}

const guard = async () => !touched.value || window.confirm(t('web.nfse.discard'))
const mark = () => (touched.value = true)
</script>

<template>
  <Layer kind="drawer" :label="t('nfseIssueAction')" :guard="guard" @close="emit('close')">
    <template #default="{ close }">
      <form class="issue" data-testid="nfse-direct-issue" @submit.prevent="send" @input="mark">
        <div class="layer-head">
          <h2 class="layer-title">{{ preview ? t('web.nfse.issueTitle', { amount: money(preview.value) }) : t('nfseIssueAction') }}</h2>
        </div>
        <div class="layer-body">
          <p v-if="state === 'loading'" role="status">{{ t('web.loading') }}</p>
          <template v-else-if="state === 'failed'">
            <p class="field-error" role="alert" data-testid="nfse-refusal">{{ failure?.text }}</p>
            <p v-if="failure?.setup" class="sub" data-testid="nfse-setup-hint">
              <template v-if="isAdmin">{{ t('web.nfseDirect.setupAdmin') }} <button type="button" class="link" @click="openSetup">{{ t('web.nfseDirect.openSetup') }}</button></template>
              <template v-else>{{ t('web.nfseDirect.setupOther') }}</template>
            </p>
          </template>
          <template v-else-if="preview">
            <p class="sub">{{ t('web.nfseDirect.goesToGov') }}</p>

            <section class="dx-row" :aria-label="t('web.nfseDirect.issueBy')" data-testid="nfse-emitter">
              <span class="field-label">{{ t('web.nfseDirect.issueBy') }}</span>
              <span class="dx-line">
                <span>{{ emitterLine(preview.emitter) }}<span v-if="regimeText(preview.emitter)" class="sub"> · {{ regimeText(preview.emitter) }}</span></span>
                <button v-if="preview.emitters.length > 1" type="button" class="link" data-testid="nfse-emitter-change" @click="picking = 'emitter'">{{ t('web.nfseDirect.change') }}</button>
              </span>
              <p v-if="preview.emitter.problem" class="field-error" role="alert" data-testid="nfse-emitter-problem">
                {{ problemText(preview.emitter.problem) }}
                <template v-if="isAdmin"> <button type="button" class="link" @click="openSetup">{{ t('web.nfseDirect.openSetup') }}</button></template>
              </p>
            </section>

            <section class="dx-row" :aria-label="t('web.nfseDirect.to')" data-testid="nfse-recipient">
              <span class="field-label">{{ t('web.nfseDirect.to') }}</span>
              <span class="dx-line">
                <span data-testid="nfse-recipient-line">{{ recipientLine }}</span>
                <button type="button" class="link" data-testid="nfse-recipient-change" @click="openRecipient">{{ t('web.nfseDirect.change') }}</button>
              </span>
              <p v-if="preview.recipient.viaInvoiceRecipient && !recipientId" class="sub" data-testid="nfse-via">{{ t('web.nfseDirect.viaInvoiceRecipient', { name: preview.customer.name ?? '' }) }}</p>
              <p v-if="recipientId" class="sub" data-testid="nfse-recipient-once">
                {{ t('web.nfseDirect.onlyThisNota') }}
                <button type="button" class="link" @click="setRecipient(null)">{{ t('web.nfseDirect.backToUsual', { name: preview.customer.name ?? '' }) }}</button>
              </p>
            </section>

            <fieldset v-if="asking.length" class="issue-contact" data-testid="nfse-fields">
              <legend class="field-label">{{ t('web.nfseDirect.fieldsIntro') }}</legend>
              <template v-if="asking.includes('taxId')">
                <label class="field-label" for="dx-taxid">{{ t('web.nfseDirect.taxId') }}</label>
                <input id="dx-taxid" v-model="taxId" class="field" inputmode="text" autocomplete="off" maxlength="20" />
              </template>
              <template v-if="asking.includes('address')">
                <label class="field-label" for="dx-cep">{{ t('nfsePostalCode') }}</label>
                <input id="dx-cep" v-model="address.postalCode" class="field" inputmode="numeric" maxlength="9" autocomplete="off" :aria-busy="lookingUp" @blur="onCep" @change="onCep" />
                <label class="field-label" for="dx-street">{{ t('nfseStreet') }}</label>
                <input id="dx-street" v-model="address.street" class="field" autocomplete="off" />
                <div class="dx-pair">
                  <span>
                    <label class="field-label" for="dx-number">{{ t('web.nfse.addressNumber') }}</label>
                    <input id="dx-number" v-model="address.number" class="field" autocomplete="off" />
                  </span>
                  <span>
                    <label class="field-label" for="dx-complement">{{ t('nfseAddressComplement') }}</label>
                    <input id="dx-complement" v-model="address.complement" class="field" autocomplete="off" />
                  </span>
                </div>
                <label class="field-label" for="dx-district">{{ t('nfseDistrict') }}</label>
                <input id="dx-district" v-model="address.district" class="field" autocomplete="off" />
                <div class="dx-pair">
                  <span>
                    <label class="field-label" for="dx-city">{{ t('invoiceCity') }}</label>
                    <input id="dx-city" v-model="address.cityName" class="field" autocomplete="off" />
                  </span>
                  <span class="dx-uf">
                    <label class="field-label" for="dx-state">{{ t('invoiceState') }}</label>
                    <input id="dx-state" v-model="address.state" class="field" maxlength="2" autocomplete="off" />
                  </span>
                </div>
                <label class="field-label" for="dx-ibge">{{ t('web.nfseDirect.cityCode') }}</label>
                <input id="dx-ibge" v-model="address.cityCode" class="field" inputmode="numeric" maxlength="7" autocomplete="off" aria-describedby="dx-ibge-hint" />
                <p id="dx-ibge-hint" class="sub">{{ t('web.nfseDirect.cityCodeHint') }}</p>
              </template>
              <template v-if="asking.includes('email')">
                <label class="field-label" for="dx-email">{{ t('email') }}</label>
                <input id="dx-email" v-model="email" class="field" type="email" autocomplete="off" />
              </template>
              <p class="sub">{{ t('web.nfseDirect.savedOnCustomer') }}</p>
            </fieldset>

            <ul class="issue-lines">
              <li v-for="o in preview.orders" :key="o.orderId" class="pay-row">
                <span>{{ t('web.fin.orderNumber', { order: orderShort(), number: o.orderNumber ?? '' }) }}</span>
                <span class="num">{{ money(o.value) }}</span>
              </li>
            </ul>
            <p class="issue-total"><span>{{ t('nfseValueLabel') }}</span> <b class="num" data-testid="nfse-value">{{ money(preview.value) }}</b></p>
            <p v-if="preview.hasProducts" class="sub" role="note" data-testid="nfse-products-out">{{ t('nfseOnlyServicesNote') }}</p>
            <p v-if="discounted" class="sub" role="note">{{ t('nfseDiscountNote') }}</p>

            <label class="field-label" for="dx-text">{{ t('nfseDescriptionLabel') }}</label>
            <textarea id="dx-text" v-model="description" class="field" rows="4" maxlength="2000" aria-describedby="dx-info"></textarea>
            <p id="dx-info" class="sub dx-small" data-testid="nfse-info">{{ preview.complementaryInfo }}</p>

            <p v-if="meiText" class="dx-warning" role="note" data-testid="nfse-mei">{{ meiText }}</p>

            <div v-if="failure" class="field-error" role="alert" data-testid="nfse-refusal">
              <p>{{ failure.text }}</p>
              <p v-if="failure.detail" class="sub">{{ failure.detail }}</p>
              <p v-if="failure.setup" class="sub" data-testid="nfse-setup-hint">
                <template v-if="isAdmin">{{ t('web.nfseDirect.setupAdmin') }} <button type="button" class="link" @click="openSetup">{{ t('web.nfseDirect.openSetup') }}</button></template>
                <template v-else>{{ t('web.nfseDirect.setupOther') }}</template>
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
  <ChoiceDialog
    v-if="picking === 'emitter' && preview"
    :title="t('web.nfseDirect.issueByQuestion')"
    :choices="emitterChoices"
    :suggested="preview.emitter.id"
    @pick="pickEmitter"
    @close="picking = null"
  />
  <Layer v-if="picking === 'recipient' && preview" kind="sheet" :label="t('web.nfseDirect.toQuestion')" @close="picking = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('web.nfseDirect.toQuestion') }}</h2>
        <p class="sub">{{ t('web.nfseDirect.onlyThisNota') }}</p>
      </div>
      <div class="layer-body" data-testid="nfse-recipient-pick">
        <Combobox
          id="dx-recipient"
          :label="t('customer')"
          :placeholder="t('web.nfseDirect.searchCustomer')"
          :groups="recipientGroups"
          :selected-id="recipientId ?? preview.recipient.customerId"
          :loading="customersLoading"
          autofocus
          @pick="pickRecipient"
          @cancel="close()"
        />
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>

<style scoped>
.dx-row { display: grid; gap: 0.2rem; padding: 0.5rem 0; border-bottom: 1px solid var(--color-rule); }
.dx-line { display: flex; flex-wrap: wrap; gap: 0.25rem 0.75rem; align-items: baseline; justify-content: space-between; }
.dx-line .link { min-height: 2.75rem; }
.dx-pair { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; }
.dx-pair > span { display: grid; gap: 0.4rem; min-width: 0; }
.dx-uf { max-width: 6rem; }
.dx-small { font-size: 0.8125rem; }
.dx-warning { color: var(--color-warning-text); font-weight: 600; }
</style>
