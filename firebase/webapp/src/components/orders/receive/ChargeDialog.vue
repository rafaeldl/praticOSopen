<script setup lang="ts">
// "Mandar cobrança" (charge.order.form, charge.customer.form): a payment link of
// Asaas for one order or for several of a customer. Value always in R$ (Asaas is
// Brazilian), due date today + 3 by default and never in the past, card
// installments only for one order. Creating and sending are one step (defect 6):
// once the link exists the dialog turns into "Mandar pelo WhatsApp" / "Copiar".
import { computed, onMounted, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { loadCustomer } from '@/lib/customers/data'
import { formatDate, formatMoney } from '@/lib/format'
import { whatsappNumber } from '@/lib/phone'
import { chargeErrorKey, createCustomerCharge, createOrderCharge } from '@/lib/receive/data'
import { addDays, asaasUrl, initialChargeValue, installmentValue, localDay, toCents, whatsappLink } from '@/lib/receive/model'
import { session } from '@/lib/session'
import { formatTaxId, isValidTaxId, normalizeTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature, handlePlanFeatureError } from '@/lib/plan-feature-gate'
import { announce } from '@/lib/ui'
import '@/styles/receive.css'

const props = defineProps<{
  /** One order: its id. Several: the customer's orders. */
  orderId?: string
  orderIds?: string[]
  /** "OS 12" or "OS 12, 15" for the text. */
  ordersText: string
  customerId?: string
  customerName?: string
  owed: number
  value?: number
}>()
const emit = defineEmits<{ close: []; created: [] }>()

const BR = 'BR'
const today = localDay(new Date())
const value = ref<number | null>(initialChargeValue(props.value, props.owed))
const due = ref(addDays(today, 3))
const installments = ref(1)
const taxId = ref('')
const needsTaxId = ref(false)
const reading = ref(!!props.customerId)
const phone = ref('')
const saving = ref(false)
const maybeCreated = ref(false)
const created = ref<{ url: string | null; value: number; dueDate: string } | null>(null)
const single = computed(() => !props.orderIds)

onMounted(async () => {
  if (!props.customerId) return
  try {
    // The CPF/CNPJ from the record: the copy inside the order is old (defect 46).
    const detail = await loadCustomer(props.customerId)
    needsTaxId.value = !isValidTaxId(detail.customer.taxId ?? '')
    phone.value = detail.customer.phone ?? ''
  } catch {
    needsTaxId.value = true
  } finally {
    reading.value = false
  }
})

/** The first thing missing, in the app's order (customer, value, balance, CPF/CNPJ). */
const problem = computed(() => {
  if (!props.customerId) return t('web.charge.noCustomer')
  const cents = toCents(value.value ?? 0)
  if (cents <= 0) return t('receiveCustomerZero')
  if (cents > toCents(props.owed)) return t('web.order.receiveTooMuch', { amount: formatMoney(props.owed, BR) })
  if (!due.value || due.value < today) return t('web.charge.dueInvalid')
  if (needsTaxId.value && !taxId.value.trim()) return t('chargeTaxIdHint')
  if (needsTaxId.value && !isValidTaxId(taxId.value)) return t('web.charge.taxIdInvalid')
  return ''
})
const ready = computed(() => !reading.value && !problem.value && !saving.value)
const options = computed(() => Array.from({ length: 11 }, (_, i) => i + 2).map((count) => ({ count, each: installmentValue(value.value ?? 0, count) })))

async function save() {
  if (!ready.value) return
  // Charges are Starter (#724): the server says the same (402 PLAN_FEATURE).
  if (!ensurePlanFeature('charges')) return
  saving.value = true
  maybeCreated.value = false
  const customerTaxId = needsTaxId.value ? normalizeTaxId(taxId.value) : undefined
  try {
    const amount = value.value as number
    const response = single.value
      ? await createOrderCharge(props.orderId as string, {
          value: amount,
          mode: installments.value > 1 ? 'cardInstallments' : 'single',
          ...(installments.value > 1 ? { installmentCount: installments.value } : {}),
          dueDate: due.value,
          ...(customerTaxId ? { customerTaxId } : {}),
        })
      : await createCustomerCharge(props.customerId as string, { orderIds: props.orderIds as string[], value: amount, dueDate: due.value, ...(customerTaxId ? { customerTaxId } : {}) })
    created.value = { url: asaasUrl(response.invoiceUrl) ?? null, value: amount, dueDate: due.value }
    emit('created')
    announce(t('web.charge.created'))
  } catch (error) {
    // A network error may hide a charge already made: stay open, the card shows it when it lands (defect 48).
    if (error instanceof ApiError && error.code === 'NETWORK') maybeCreated.value = true
    if (handlePlanFeatureError(error)) return
    showToast(t(chargeErrorKey(error)))
  } finally {
    saving.value = false
  }
}


const wa = computed(() => whatsappNumber(phone.value, session.company?.country))
const sendText = computed(() =>
  created.value
    ? `${props.customerName ? t('web.share.msgHello', { name: props.customerName }) : t('web.share.msgHelloNoName')} ${t('web.charge.msg', {
        amount: formatMoney(created.value.value, BR),
        orders: props.ordersText,
        date: formatDate(`${created.value.dueDate}T12:00:00`, BR),
      })}\n${created.value.url ?? ''}`
    : '',
)

async function copy() {
  try {
    await navigator.clipboard.writeText(created.value?.url ?? '')
    showToast(t('chargeLinkCopied'))
  } catch {
    showToast(t('web.share.copyFailed'))
  }
}
</script>

<template>
  <Layer kind="sheet" :label="t('chargeLinkTitle')" :guard="() => !saving" @close="emit('close')">
    <template #default="{ close }">
      <form v-if="!created" class="layer-form" @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('chargeLinkTitle') }}</h2>
          <p class="sub">{{ customerName ? t('chargeLinkIntro', { name: customerName }) : t('chargeLinkIntroNoName') }}</p>
          <p class="sub">{{ t('web.charge.orders', { orders: ordersText, owed: formatMoney(owed, BR) }) }}</p>
        </div>
        <div class="layer-body">
          <MoneyInput id="charge-value" v-model="value" :label="t('chargeValue')" country="BR" required />
          <label class="field-label" for="charge-due">{{ t('chargeDueDate') }}</label>
          <input id="charge-due" v-model="due" class="field" type="date" :min="today" required />
          <template v-if="single">
            <label class="field-label" for="charge-split">{{ t('chargeSplitQuestion') }}</label>
            <select id="charge-split" v-model.number="installments" class="field">
              <option :value="1">{{ t('chargeSplitNo') }} · {{ t('chargeSingleHint') }}</option>
              <option v-for="option in options" :key="option.count" :value="option.count">{{ t('chargeInstallmentOption', { count: option.count, value: formatMoney(option.each, BR) }) }}</option>
            </select>
          </template>
          <template v-if="needsTaxId">
            <label class="field-label" for="charge-taxid">{{ t('web.charge.taxId') }}</label>
            <input
              id="charge-taxid"
              class="field"
              inputmode="text"
              autocomplete="off"
              :value="taxId"
              :aria-describedby="'charge-taxid-hint'"
              @input="taxId = ($event.target as HTMLInputElement).value.toUpperCase()"
              @blur="taxId = isValidTaxId(taxId) ? formatTaxId(taxId) : taxId"
            />
            <p id="charge-taxid-hint" class="field-hint">{{ t('chargeTaxIdHint') }}</p>
          </template>
          <p v-if="reading" class="sub" role="status">{{ t('web.loading') }}</p>
          <p v-else-if="problem" class="sub" data-testid="charge-problem">{{ problem }}</p>
          <p v-if="maybeCreated" class="field-error" role="alert">{{ t('web.charge.maybeCreated') }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="!ready" data-testid="charge-create">{{ t('web.charge.create', { amount: formatMoney(value ?? 0, BR) }) }}</button>
        </div>
      </form>
      <template v-else>
        <div class="layer-head">
          <h2 class="layer-title">{{ t('web.charge.created') }}</h2>
          <p class="sub">{{ t('chargeDetailUntil', { value: formatMoney(created.value, BR), date: formatDate(`${created.dueDate}T12:00:00`, BR) }) }}</p>
        </div>
        <div class="layer-body">
          <label class="field-label" for="charge-text">{{ t('web.share.message') }}</label>
          <textarea id="charge-text" class="field" rows="5" readonly :value="sendText" data-testid="charge-text"></textarea>
        </div>
        <div class="layer-foot share-foot">
          <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
          <button v-if="created.url" type="button" class="btn" @click="copy">{{ t('chargeCopyLink') }}</button>
          <a v-if="wa && created.url" class="btn btn--primary" :href="whatsappLink(wa, sendText)" target="_blank" rel="noopener noreferrer" data-testid="charge-whatsapp">{{ t('shareSendWhatsApp') }}</a>
        </div>
      </template>
    </template>
  </Layer>
</template>
