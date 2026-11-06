<script setup lang="ts">
// The nota of the order (order.nfse.row, order.nfse.issue-row): "Nota fiscal ·
// Emitida · nº 123" opening the nota, or, on an order without one (finished,
// or approved too with the NFS-e direct), "Não emitida" (the blue step offers
// it, once paid) or "Emitir" (the nota may come before the money). Live: the webhook changes it while the order is open.
import { computed, onBeforeUnmount, onMounted, shallowRef, watch } from 'vue'
import { t } from '@/i18n'
import { monthOf } from '@/lib/finance/period'
import { today } from '@/lib/finance/text'
import { watchInvoicesOf } from '@/lib/nfse/data'
import { currentInvoiceOf, nfseIssueRow, type NfseInvoice } from '@/lib/nfse/model'
import { DOT, invoiceStatusText } from '@/lib/nfse/text'
import type { Order } from '@/lib/orders/model'

const props = defineProps<{ order: Order; ready: boolean; remaining: number; direct?: boolean }>()
const emit = defineEmits<{ issue: []; current: [invoice: NfseInvoice | null]; loaded: [loaded: boolean] }>()

const invoices = shallowRef<NfseInvoice[]>([])
/**
 * The order's notas read at least once (B8). Until then, or when the read
 * failed, nothing offers "Emitir": a nota already issued could be issued again.
 */
const loaded = shallowRef(false)
const failed = shallowRef(false)
let stop: (() => void) | undefined
async function listen() {
  stop?.()
  failed.value = false
  try {
    stop = await watchInvoicesOf(
      { orderId: props.order.id },
      (list) => {
        invoices.value = list
        failed.value = false
        loaded.value = true
      },
      () => {
        failed.value = true
        loaded.value = false
      },
    )
  } catch {
    failed.value = true
  }
}
onMounted(listen)
onBeforeUnmount(() => stop?.())
watch(loaded, (value) => emit('loaded', value), { immediate: true })

const current = computed(() => currentInvoiceOf(invoices.value))
watch(current, (value) => emit('current', value), { immediate: true })
const issueRow = computed(() => (loaded.value ? nfseIssueRow(props.order, current.value, props.ready, props.direct === true, props.remaining) : null))
const day = today()
</script>

<template>
  <div v-if="failed" class="od-nfse" role="alert" data-testid="order-nfse-error">
    <span>{{ t('nfseRowTitle') }} · {{ t('web.nfse.rowError') }}</span>
    <button type="button" class="link" @click="listen">{{ t('web.tryAgain') }}</button>
  </div>
  <div v-if="current" class="od-nfse" data-testid="order-nfse">
    <span>{{ t('nfseRowTitle') }}</span>
    <RouterLink class="status link-plain" :to="{ path: '/invoices', query: { invoice: current.id, ...(current.effectiveDate && monthOf(current.effectiveDate) !== monthOf(day) ? { month: monthOf(current.effectiveDate) } : {}) } }">
      <span class="dot" :class="`dot--${DOT[current.status]}`" aria-hidden="true"></span><span>{{ invoiceStatusText(current, day) }}</span>
    </RouterLink>
  </div>
  <div v-if="issueRow" class="od-nfse" data-testid="order-nfse-issue-row">
    <span>{{ t('nfseRowTitle') }}</span>
    <span v-if="issueRow === 'notIssued'" class="sub">{{ t('nfseNotIssued') }}</span>
    <button v-else type="button" class="link" data-testid="order-nfse-issue" @click="emit('issue')">{{ t('nfseIssueLink') }}</button>
  </div>
</template>
