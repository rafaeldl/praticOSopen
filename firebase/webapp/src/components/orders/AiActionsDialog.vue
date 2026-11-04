<script setup lang="ts">
// "Confere?" (order.ai.money-card, order.ai.money-run): receber, desconto e
// status ditos ao assistente. Nothing is saved before Confirmar; then, through
// the API and in the app's order, discount, approve, payment and status, stopping
// at the first refusal. "Desfazer" starts from the last step; an issued nota is
// never canceled. Only with financeActions on (the server sends `actions`).
import { computed, onMounted, reactive, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { t } from '@/i18n'
import { logAiEvent } from '@/lib/analytics'
import { errorMessageKey } from '@/lib/api'
import { contextOf, paymentAmount, planAiActions, stepsOf, type ActionsEdits, type DraftActions, type NfseMoment } from '@/lib/orders/ai-actions'
import { noticeText } from '@/lib/orders/ai-actions-text'
import { orderChanged } from '@/lib/orders/bus'
import { totals, type Order, type OrderStatus } from '@/lib/orders/model'
import { country, money, statusText } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { localDay, paidAtFor } from '@/lib/receive/model'
import { removeTransaction } from '@/lib/receive/data'
import { effectiveUseFinancial, session } from '@/lib/session'
import { showToast } from '@/lib/toast'

const props = defineProps<{ order: Order; actions: DraftActions; nfse: NfseMoment | null; pendingChecklists: number; sub?: string }>()
/** done: the note to show and, when something changed, how to undo it (the parent adds the draft's own undo). */
const emit = defineEmits<{ close: []; done: [note: string, undo: (() => Promise<void>) | null] }>()

const edits = reactive<ActionsEdits>({})
const ctx = computed(() => contextOf(props.order, session.role, session.uid, effectiveUseFinancial(), props.pendingChecklists, props.nfse))
const plan = computed(() => planAiActions(props.actions, ctx.value, edits))
const running = ref(false)
/** Confirmar was pressed: the close that follows is not "Agora não". */
let confirmed = false

// The app's ai_action_proposed: the kinds of step, never the amounts (AiActionsPlan.types).
onMounted(() => {
  const types = [plan.value.payment && 'payment', plan.value.discount && 'discount', (plan.value.approveFirst || plan.value.status) && 'status'].filter(Boolean).join(',')
  logAiEvent('ai_action_proposed', { types })
})
function onClose() {
  if (!confirmed) logAiEvent('ai_action_dismissed')
  emit('close')
}
const today = localDay(new Date())

const METHODS = [
  { id: 'pix', label: () => t('paymentMethodPix') },
  { id: 'cash', label: () => t('paymentMethodCash') },
  { id: 'card', label: () => t('paymentMethodCard') },
  { id: 'other', label: () => t('paymentMethodOther') },
]
const status = (s: OrderStatus) => statusText(s).toLocaleLowerCase()


const paymentSub = computed(() => {
  const step = plan.value.payment
  if (!step) return ''
  const parts: string[] = []
  const method = METHODS.find((m) => m.id === step.method)
  if (method) parts.push(method.label())
  if (step.amount === null) parts.push(t('aiActionsTypeAmount'))
  else parts.push(step.paysOff ? t('aiActionsPaidOff') : t('aiActionsLeft', { amount: money(step.left) }))
  return parts.join(' · ')
})

interface Done {
  discountId?: string
  paymentId?: string
  statusBefore?: OrderStatus
  statusAfter?: OrderStatus
  amount?: number
  discount?: number
}

async function confirm() {
  const current = plan.value
  if (!current.canConfirm || running.value) return
  running.value = true
  confirmed = true
  logAiEvent('ai_action_confirmed', { edited: Object.keys(edits).length ? 1 : 0 })
  const done: Done = {}
  let failed: string | null = null
  let order = props.order
  const apply = (response: { order?: Record<string, unknown>; transactionId?: string }) => {
    const fresh = writes.orderOf(response, order.showsMoney)
    if (fresh) {
      order = fresh
      orderChanged(fresh)
    }
    return response.transactionId
  }
  for (const step of stepsOf(current)) {
    try {
      if (step === 'discount' && current.discount) {
        done.discountId = apply(await writes.giveDiscount(order.id, { amount: current.discount.amount, clientTransactionId: writes.newTransactionId() }, order.version))
        done.discount = current.discount.amount
      } else if (step === 'approve') {
        done.statusBefore ??= order.status
        apply(await writes.patchOrder(order.id, { status: 'approved' }, order.version))
        done.statusAfter = 'approved'
      } else if (step === 'payment' && current.payment) {
        const amount = paymentAmount(current.payment, totals(order).remaining)
        const day = current.payment.paidDay && current.payment.paidDay <= today ? current.payment.paidDay : today
        done.paymentId = apply(
          await writes.receivePayment(
            order.id,
            { amount, ...(current.payment.method ? { paymentMethod: current.payment.method } : {}), paidAt: paidAtFor(day, new Date()), clientTransactionId: writes.newTransactionId() },
            order.version,
          ),
        )
        done.amount = amount
      } else if (step === 'status' && current.status) {
        done.statusBefore ??= order.status
        apply(await writes.patchOrder(order.id, { status: current.status }, order.version))
        done.statusAfter = current.status
      }
    } catch (error) {
      console.warn('ai actions: step failed', step, error)
      // The app's step names: approving is a status change there.
      logAiEvent('ai_action_failed', { step: step === 'approve' ? 'status' : step })
      failed = step === 'status' || step === 'approve' ? t('orderStatusSaveError') : t(errorMessageKey(error))
      break
    }
  }
  running.value = false
  const parts: string[] = []
  if (done.discount) parts.push(t('aiActionsDiscount', { amount: money(done.discount) }))
  if (done.amount) parts.push(t('aiActionsReceived', { amount: money(done.amount) }))
  if (done.discount || done.amount) {
    const left = totals(order).remaining
    parts.push(left > 0.009 ? t('aiActionsLeft', { amount: money(left) }) : t('aiActionsPaidOff'))
  }
  if (done.statusAfter) parts.push(statusText(done.statusAfter))
  const note = [parts.join(' · '), failed].filter(Boolean).join('. ')
  const changed = !!(done.discountId || done.paymentId || done.statusAfter)
  emit('done', note, changed ? () => undo(order, done, current.issuesNfse) : null)
}

/** Last step first: payment, status, discount. A status the person cannot bring back stays, and says so. */
async function undo(order: Order, done: Done, couldIssue: boolean) {
  logAiEvent('ai_action_undone')
  const notes: string[] = []
  try {
    if (done.paymentId) await removeTransaction(order.id, done.paymentId, 'payment')
    if (done.statusBefore && done.statusAfter) {
      if (ctx.value.canChangeStatus(done.statusAfter, done.statusBefore)) await writes.patchOrder(order.id, { status: done.statusBefore })
      else notes.push(t('aiActionsStatusKept', { status: status(done.statusAfter) }))
    }
    if (done.discountId) await removeTransaction(order.id, done.discountId, 'discount')
    if (couldIssue) notes.push(t('aiActionsNfseStays'))
    if (notes.length) showToast(notes.join(' '))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}
</script>

<template>
  <Layer kind="sheet" :label="t('aiActionsTitle')" :guard="() => !running" @close="onClose">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('aiActionsTitle') }}</h2>
        <p v-if="sub" class="sub">{{ sub }}</p>
      </div>
      <div class="layer-body ai-actions" data-testid="ai-actions">
        <ul class="ai-steps">
          <li v-if="plan.discount" data-testid="ai-step-discount">
            <span><span class="ai" aria-hidden="true">✦</span> {{ t('aiActionsDiscount', { amount: money(plan.discount.amount) }) }}
              <small class="sub">{{ t('aiActionsNewTotal', { amount: money(ctx.total - plan.discount.amount) }) }}</small></span>
            <MoneyInput id="ai-discount" class="line-price" :label="t('discount')" :model-value="plan.discount.amount" :country="country()" @update:model-value="(v) => (edits.discount = v ?? undefined)" />
          </li>
          <li v-if="plan.approveFirst" data-testid="ai-step-approve">
            <span><span class="ai" aria-hidden="true">✦</span> {{ t('aiActionsMarkAs', { status: status('approved') }) }}</span>
          </li>
          <li v-if="plan.payment" data-testid="ai-step-payment">
            <span><span class="ai" aria-hidden="true">✦</span> {{ plan.payment.amount === null ? t('aiActionsReceiveNoAmount') : t('aiActionsReceive', { amount: money(plan.payment.amount) }) }}
              <small class="sub">{{ paymentSub }}</small></span>
            <MoneyInput id="ai-payment" class="line-price" :label="t('aiActionsReceiveNoAmount')" :model-value="plan.payment.amount" :country="country()" @update:model-value="(v) => (edits.payment = v ?? undefined)" />
            <label class="sr" for="ai-method">{{ t('receivePaymentMethodQuestion') }}</label>
            <select id="ai-method" class="field" :value="plan.payment.method ?? ''" @change="edits.method = ($event.target as HTMLSelectElement).value || null">
              <option value="">{{ t('receivePaymentMethodNone') }}</option>
              <option v-for="m in METHODS" :key="m.id" :value="m.id">{{ m.label() }}</option>
            </select>
            <label class="sr" for="ai-day">{{ t('receiveWhen') }}</label>
            <input id="ai-day" class="field" type="date" :max="today" :value="plan.payment.paidDay ?? today" @change="edits.paidDay = ($event.target as HTMLInputElement).value || null" />
          </li>
          <li v-if="plan.status" data-testid="ai-step-status">
            <span><span class="ai" aria-hidden="true">✦</span> {{ t('aiActionsMarkAs', { status: status(plan.status) }) }}</span>
          </li>
        </ul>
        <p v-for="notice in plan.notices" :key="notice.kind" class="sub" role="note">{{ noticeText(notice) }}</p>
        <p v-if="plan.issuesNfse" class="sub" role="note" data-testid="ai-nfse">{{ t('aiActionsIssuesNfse') }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" :disabled="running" @click="close()">{{ t('notNow') }}</button>
        <button type="button" class="btn btn--primary" :disabled="!plan.canConfirm || running" data-testid="ai-confirm" @click="confirm().then(() => close())">{{ t('confirm') }}</button>
      </div>
    </template>
  </Layer>
</template>
