<script setup lang="ts">
// "Receber" and "Dar desconto". The id of the transaction is made once when the
// dialog opens: pressing again after a network failure sends the same id, and
// the server books it once (WEB_API, clientTransactionId).
import { computed, ref, shallowRef } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { newTransactionId } from '@/lib/orders/writes'
import { country, money } from '@/lib/orders/text'
import { roundMoney } from '@/lib/rules/order-rules'
import { localDay, paidAtFor, toCents } from '@/lib/receive/model'
import { proofProblem } from '@/lib/receive/proof'
import '@/styles/receive.css'

const props = defineProps<{ kind: 'receive' | 'discount'; remaining: number; total: number; busy?: boolean; createdAt?: string | null; linkNote?: string; canAttach?: boolean }>()
const emit = defineEmits<{ save: [value: { amount: number; paymentMethod?: string; paidAt?: string; clientTransactionId: string; proof?: File }]; close: [] }>()

const transactionId = newTransactionId()
const amount = ref<number | null>(props.kind === 'receive' ? props.remaining : null)
const method = ref('')
// Proof (pay.widget.sheet): an image or PDF, sent with the payment. Without attachPhotos the row is not there.
const proof = shallowRef<File | null>(null)
const proofError = ref('')
const proofInput = ref<HTMLInputElement | null>(null)
function pickProof(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  const problem = proofProblem(file)
  proofError.value = problem === 'type' ? t('web.receive.proofType') : problem === 'size' ? t('web.receive.proofSize') : ''
  if (!problem) proof.value = file
}
// "Quando": today by default, never in the future nor before the order (server: INVALID_PAID_AT).
const today = localDay(new Date())
const day = ref(today)
// One day of slack before the order, like the server (24 h by the company's zone). Today is always fine.
const minDay = props.createdAt ? localDay(new Date(Date.parse(props.createdAt) - 86_400_000)) : undefined
const dayValid = computed(() => day.value === today || (!!day.value && day.value < today && (!minDay || day.value >= minDay)))
const title = computed(() => (props.kind === 'receive' ? t('receiveTitle') : t('receiveGiveDiscount')))
// Never above what is left, like ReceivePaymentSheet (max: remaining). The balance follows the order live.
const tooMuch = computed(() => (amount.value ?? 0) > props.remaining + 0.001)
const valid = computed(() => (amount.value ?? 0) > 0 && !tooMuch.value && (props.kind === 'discount' || dayValid.value))
// Discount: the new total. Receive: "Quita a OS." or "Ficam R$ X." (receive.amount-preview in the app), in cents.
const preview = computed(() => {
  if (!valid.value) return ''
  if (props.kind === 'discount') return t('receiveDiscountNewTotal', { from: money(props.total), to: money(roundMoney(props.total - (amount.value ?? 0))) })
  const left = toCents(props.remaining) - toCents(amount.value ?? 0)
  return left <= 0 ? t('receivePreviewAll', { count: 1 }) : t('receivePreviewLeft', { amount: money(left / 100) })
})
const METHODS = [
  { id: 'pix', label: () => t('paymentMethodPix') },
  { id: 'cash', label: () => t('paymentMethodCash') },
  { id: 'card', label: () => t('paymentMethodCard') },
  { id: 'other', label: () => t('paymentMethodOther') },
]

function save() {
  if (!valid.value || props.busy) return
  const when = props.kind === 'receive' && day.value !== today ? { paidAt: paidAtFor(day.value, new Date()) } : {}
  emit('save', {
    amount: amount.value as number,
    ...(method.value ? { paymentMethod: method.value } : {}),
    ...when,
    clientTransactionId: transactionId,
    ...(proof.value ? { proof: proof.value } : {}),
  })
}
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
          <p class="sub">{{ t('receiveMissing') }}: <span class="num">{{ money(remaining) }}</span></p>
        </div>
        <div class="layer-body">
          <MoneyInput id="money-amount" v-model="amount" :label="kind === 'receive' ? t('receiveCustomerAmountLabel') : t('discount')" :country="country()" required />
          <p v-if="tooMuch" class="field-error" role="alert">{{ kind === 'discount' ? t('web.order.discountTooMuch', { amount: money(remaining) }) : t('web.order.receiveTooMuch', { amount: money(remaining) }) }}</p>
          <p v-else-if="preview" class="sub" data-testid="receive-preview" aria-live="polite">{{ preview }}</p>
          <p v-if="kind === 'receive' && linkNote" class="sub" role="note">{{ linkNote }}</p>
          <template v-if="kind === 'receive'">
            <label class="field-label" for="money-method">{{ t('receivePaymentMethodQuestion') }} <span class="muted">({{ t('receivePaymentMethodOptional') }})</span></label>
            <select id="money-method" v-model="method" class="field">
              <option value="">{{ t('receivePaymentMethodNone') }}</option>
              <option v-for="item in METHODS" :key="item.id" :value="item.id">{{ item.label() }}</option>
            </select>
            <label class="field-label" for="money-day">{{ t('receiveWhen') }}</label>
            <input id="money-day" v-model="day" class="field" type="date" :max="today" required />
            <p v-if="!dayValid" class="field-error" role="alert">{{ t('web.receive.dayInvalid') }}</p>
            <template v-if="canAttach">
              <span class="field-label" id="money-proof-label">{{ t('receipt') }} <span class="muted">({{ t('receivePaymentMethodOptional') }})</span></span>
              <div v-if="proof" class="proof-chip" data-testid="receive-proof">
                <span class="proof-name">{{ proof.name }}</span>
                <button type="button" class="link link--danger" @click="proof = null">{{ t('receiveRemoveReceipt') }}</button>
              </div>
              <template v-else>
                <button type="button" class="btn" aria-describedby="money-proof-label" @click="proofInput?.click()">{{ t('receiveAttachReceipt') }}</button>
                <input ref="proofInput" type="file" class="sr" accept="image/*,application/pdf" tabindex="-1" aria-hidden="true" data-testid="receive-proof-input" @change="pickProof" />
              </template>
              <p v-if="proofError" class="field-error" role="alert">{{ proofError }}</p>
            </template>
          </template>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="!valid || busy">
            {{ kind === 'receive' ? t('receiveMarkReceived') : t('receiveGiveDiscount') }}
          </button>
        </div>
      </form>
    </template>
  </Layer>
</template>

