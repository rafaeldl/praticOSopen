<script setup lang="ts">
// "Recebimentos" of a customer (customer.detail.receipts, receipt.detail.*):
// each receipt with its orders, the printable receipt (the browser saves it as
// PDF) and "Desfazer recebimento", asked first with what it changes. An undone
// receipt shows "Desfeito" and no action. The list comes filtered by the server:
// financial roles see all, a consultant the ones they registered.
import { computed, nextTick, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { formatDate } from '@/lib/format'
import { country, money, orderShort } from '@/lib/orders/text'
import { cancelReceipt, listReceipts, openOrders, type Receipt } from '@/lib/receive/data'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ReceiptPrint from './ReceiptPrint.vue'
import '@/styles/receive.css'

const props = defineProps<{ customerId: string; customerName: string }>()
const emit = defineEmits<{ close: []; changed: [] }>()
const router = useRouter()

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const receipts = shallowRef<Receipt[]>([])
/** Open amount per order now; null when it could not be read (the lines then show only number and amount). */
const balances = shallowRef<Map<string, number> | null>(null)
function line(part: Receipt['allocations'][number]): string {
  const params = { number: part.orderNumber ?? '', amount: money(part.amount) }
  if (!balances.value) return `${orderShort()} ${params.number} · ${params.amount}`
  const left = balances.value.get(part.orderId) ?? 0
  return left > 0 ? t('receiptRowOpen', { ...params, left: money(left) }) : t('receiptRowSettled', params)
}
const undoing = shallowRef<Receipt | null>(null)
const printing = shallowRef<Receipt | null>(null)
const busy = ref(false)
const financial = can('viewFinancialReports')
const sorted = computed(() => [...receipts.value].sort((a, b) => (b.paidAt ?? '').localeCompare(a.paidAt ?? '')))
const canUndo = (receipt: Receipt) => receipt.status === 'active' && !receipt.id.startsWith('asaas_') && (financial || receipt.createdBy?.id === session.uid)

async function load() {
  state.value = 'loading'
  try {
    // What each order still owes today: "quitada" or "falta R$ X" (receipt.detail.view).
    const [list, open] = await Promise.all([listReceipts(props.customerId), openOrders(props.customerId).catch(() => null)])
    receipts.value = list
    balances.value = open ? new Map(open.map((order) => [order.id, order.open])) : null
    state.value = 'ready'
  } catch (error) {
    console.warn('receive: receipts not read', error)
    state.value = 'failed'
  }
}
onMounted(load)

async function undo() {
  const receipt = undoing.value
  undoing.value = null
  if (!receipt || busy.value) return
  busy.value = true
  try {
    await cancelReceipt(props.customerId, receipt.id)
    showToast(t('receiptUndone'))
    announce(t('receiptUndone'))
    emit('changed')
    await load()
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

async function print(receipt: Receipt) {
  printing.value = receipt
  await nextTick()
  window.addEventListener('afterprint', () => (printing.value = null), { once: true })
  requestAnimationFrame(() => window.print())
}

function openOrder(id: string) {
  emit('close')
  void router.push({ path: '/', query: { order: id } })
}
</script>

<template>
  <Layer kind="drawer" :label="t('receiptsSection')" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('receiptsSection') }}</h2>
        <p class="sub">{{ customerName }}</p>
      </div>
      <div class="layer-body" data-testid="receipts">
        <p v-if="state === 'loading'" role="status">{{ t('web.loading') }}</p>
        <div v-else-if="state === 'failed'" class="empty" role="alert">
          <p>{{ t('web.error.generic') }}</p>
          <button type="button" class="btn" @click="load">{{ t('web.tryAgain') }}</button>
        </div>
        <p v-else-if="!sorted.length" class="muted">{{ t('web.receive.noReceipts') }}</p>
        <ul v-else class="pay-list">
          <li v-for="receipt in sorted" :key="receipt.id" class="receipt-item" data-testid="receipt-row">
            <p>
              <strong class="num">{{ money(receipt.amount) }}</strong>
              <span class="sub"> · {{ t('receiptListSubtitle', { date: receipt.paidAt ? formatDate(receipt.paidAt, country()) : '', count: receipt.allocations.length }) }}</span>
            </p>
            <p v-if="receipt.status === 'canceled'" class="sub"><strong>{{ t('web.receive.undone') }}</strong></p>
            <ul class="receipt-orders">
              <li v-for="part in receipt.allocations" :key="part.orderId">
                <button type="button" class="link" @click="openOrder(part.orderId)">{{ line(part) }}</button>
              </li>
            </ul>
            <p v-if="receipt.createdBy?.name" class="sub">{{ t('pdfReceiptRecordedBy', { name: receipt.createdBy.name }) }}</p>
            <div v-if="receipt.status === 'active'" class="row-actions">
              <button type="button" class="link" @click="print(receipt)">{{ t('web.receive.printReceipt') }}</button>
              <button v-if="canUndo(receipt)" type="button" class="link link--danger" :disabled="busy" @click="undoing = receipt">{{ t('receiptUndo') }}</button>
            </div>
          </li>
        </ul>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="undoing"
    :title="t('receiptUndoTitle', { amount: money(undoing.amount) })"
    :body="t('receiptUndoMessage', { count: undoing.allocations.length })"
    :confirm="t('receiptUndo')"
    :keep="t('cancel')"
    danger
    @confirm="undo"
    @close="undoing = null"
  />
  <ReceiptPrint v-if="printing" :receipt="printing" :customer-name="customerName" />
</template>
