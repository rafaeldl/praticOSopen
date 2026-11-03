<script setup lang="ts">
// "Já recebido" (pay.order.view, pay.widget.row): payments and discounts, the
// newest day first, with who registered, how it came in and the proof. Remover
// and Desfazer pagamentos ask first and say the consequence; the Asaas ones and
// the shares of a receipt over several orders cannot leave from here.
import { computed, ref, shallowRef } from 'vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { country, money } from '@/lib/orders/text'
import { canRemove, paymentsOf, undoAllState, type Payment } from '@/lib/receive/model'
import { proofProblem } from '@/lib/receive/proof'
import '@/styles/receive.css'

const props = defineProps<{ order: Order; canReceive: boolean; canDiscount: boolean; canAttach?: boolean; busy?: boolean }>()
const emit = defineEmits<{ remove: [payment: Payment]; undoAll: []; attach: [payment: Payment, file: File]; detach: [payment: Payment] }>()

const payments = computed(() => paymentsOf(props.order.transactions, props.order.documents ?? []))
const undo = computed(() => undoAllState(payments.value))
const asking = shallowRef<Payment | 'all' | null>(null)
// Proof (pay.order.attach-proof): attach, replace and take out, on the manual payments
// only (Asaas brings its own; a share of a receipt keeps the receipt's file).
const proofFor = (payment: Payment) => !!props.canAttach && payment.type === 'payment' && !payment.isAsaas && !payment.receiptGroupId && !!payment.id
const picking = shallowRef<Payment | null>(null)
const takingOut = shallowRef<Payment | null>(null)
const proofError = ref('')
const fileInput = ref<HTMLInputElement | null>(null)
function choose(payment: Payment) {
  picking.value = payment
  proofError.value = ''
  fileInput.value?.click()
}
function picked(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  const payment = picking.value
  picking.value = null
  if (!file || !payment) return
  const problem = proofProblem(file)
  if (problem) proofError.value = problem === 'type' ? t('web.receive.proofType') : t('web.receive.proofSize')
  else emit('attach', payment, file)
}
const explain = ref(false)

const METHOD: Record<string, () => string> = {
  pix: () => t('paymentMethodPix'),
  cash: () => t('paymentMethodCash'),
  card: () => t('paymentMethodCard'),
  other: () => t('paymentMethodOther'),
}
function how(payment: Payment): string {
  if (payment.type === 'discount') return t('discount')
  if (payment.isAsaas) {
    const type = (payment.billingType ?? '').toUpperCase()
    if (type === 'PIX') return t('receiveViaPix')
    if (type === 'BOLETO') return t('receiveViaBoleto')
    if (type.includes('CARD')) return t('receiveViaCard')
    return t('receiveViaLink')
  }
  return payment.method && METHOD[payment.method] ? METHOD[payment.method]!() : t('payment')
}
const removable = (payment: Payment) => canRemove(payment) && (payment.type === 'discount' ? props.canDiscount : props.canReceive)

function confirmDetach() {
  const target = takingOut.value
  takingOut.value = null
  if (target) emit('detach', target)
}

function confirm() {
  const target = asking.value
  asking.value = null
  if (target === 'all') emit('undoAll')
  else if (target) emit('remove', target)
}
</script>

<template>
  <section v-if="payments.length" class="pay-history" aria-labelledby="od-paid-title" data-testid="payment-history">
    <h3 id="od-paid-title">{{ t('receiveAlreadyReceived') }}</h3>
    <ul class="pay-list">
      <li v-for="(payment, index) in payments" :key="payment.id ?? index" class="pay-row" data-testid="payment-row">
        <span class="pay-main">
          <span class="num">{{ payment.type === 'discount' ? '− ' : '' }}{{ money(payment.amount) }}</span>
          <span> · {{ how(payment) }}</span>
          <span class="sub">
            {{ payment.paidOn ? formatDate(payment.paidOn, country()) : '' }}<template v-if="payment.createdBy?.name"> · {{ t('web.receive.by', { name: payment.createdBy.name }) }}</template>
          </span>
          <span v-if="payment.receiptGroupId" class="sub">{{ t('web.receive.partOfReceipt') }}</span>
        </span>
        <span class="pay-acts">
          <a v-if="payment.proofUrl" class="link" :href="payment.proofUrl" target="_blank" rel="noopener noreferrer">{{ t('receiveViewReceipt') }}</a>
          <template v-if="proofFor(payment)">
            <button type="button" class="link" :disabled="busy" :aria-label="payment.proofUrl ? t('web.receive.replaceProofOf', { amount: money(payment.amount) }) : t('web.receive.attachProofOf', { amount: money(payment.amount) })" @click="choose(payment)">
              {{ payment.proofUrl ? t('web.receive.replaceProof') : t('receiveAttachReceipt') }}
            </button>
            <button v-if="payment.proofUrl" type="button" class="link link--danger" :disabled="busy" :aria-label="t('web.receive.removeProofOf', { amount: money(payment.amount) })" @click="takingOut = payment">
              {{ t('receiveRemoveReceipt') }}
            </button>
          </template>
          <button v-if="removable(payment)" type="button" class="link link--danger" :disabled="busy" :aria-label="t('web.receive.removeOne', { amount: money(payment.amount) })" @click="asking = payment">
            {{ t('web.receive.remove') }}
          </button>
        </span>
      </li>
    </ul>
    <input v-if="canAttach" ref="fileInput" type="file" class="sr" accept="image/*,application/pdf" tabindex="-1" aria-hidden="true" data-testid="proof-input" @change="picked" />
    <p v-if="proofError" class="field-error" role="alert">{{ proofError }}</p>
    <template v-if="canDiscount && undo !== 'none'">
      <button v-if="undo === 'allowed'" type="button" class="link link--danger" :disabled="busy" data-testid="undo-all" @click="asking = 'all'">{{ t('receiveUndoPayments') }}</button>
      <template v-else>
        <button type="button" class="link" @click="explain = !explain">{{ t('receiveUndoPayments') }}</button>
        <p v-if="explain" class="sub" role="status">{{ t('receiptPartOfGroup') }}</p>
      </template>
    </template>
    <ConfirmDialog
      v-if="takingOut"
      :title="t('web.receive.removeProofTitle')"
      :body="t('web.receive.removeProofBody', { amount: money(takingOut.amount) })"
      :confirm="t('receiveRemoveReceipt')"
      :keep="t('cancel')"
      danger
      @confirm="confirmDetach"
      @close="takingOut = null"
    />
    <ConfirmDialog
      v-else-if="asking === 'all'"
      :title="t('receiveUndoPayments')"
      :body="t('web.receive.undoAllBody')"
      :confirm="t('receiveUndoPayments')"
      :keep="t('cancel')"
      danger
      @confirm="confirm"
      @close="asking = null"
    />
    <ConfirmDialog
      v-else-if="asking"
      :title="t('web.receive.removeTitle')"
      :body="t('web.receive.removeBody', { what: how(asking), amount: money(asking.amount) })"
      :confirm="t('web.receive.remove')"
      :keep="t('cancel')"
      danger
      @confirm="confirm"
      @close="asking = null"
    />
  </section>
</template>
