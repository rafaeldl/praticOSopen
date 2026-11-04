<script setup lang="ts">
// The nota of the order (order.nfse.row, order.nfse.issue-row): "Nota fiscal ·
// Emitida · nº 123" opening the nota, or, on a finished order without one,
// "Não emitida" (the blue step offers it, once paid) or "Emitir" (the nota may
// come before the money). Live: the webhook changes it while the order is open.
import { computed, onBeforeUnmount, onMounted, shallowRef, watch } from 'vue'
import { t } from '@/i18n'
import { monthOf } from '@/lib/finance/period'
import { today } from '@/lib/finance/text'
import { watchInvoicesOf } from '@/lib/nfse/data'
import { canHaveNfse, currentInvoiceOf, isActive, type NfseInvoice } from '@/lib/nfse/model'
import { DOT, invoiceStatusText } from '@/lib/nfse/text'
import type { Order } from '@/lib/orders/model'

const props = defineProps<{ order: Order; ready: boolean; remaining: number }>()
const emit = defineEmits<{ issue: []; current: [invoice: NfseInvoice | null] }>()

const invoices = shallowRef<NfseInvoice[]>([])
const failed = shallowRef(false)
let stop: (() => void) | undefined
onMounted(async () => {
  stop = await watchInvoicesOf(
    { orderId: props.order.id },
    (list) => {
      invoices.value = list
      failed.value = false
    },
    () => (failed.value = true),
  )
})
onBeforeUnmount(() => stop?.())

const current = computed(() => currentInvoiceOf(invoices.value))
watch(current, (value) => emit('current', value), { immediate: true })
/** A finished order that can have a nota and has no active one. */
const canIssue = computed(() => props.ready && props.order.status === 'done' && canHaveNfse(props.order) && !(current.value && isActive(current.value)))
const day = today()
</script>

<template>
  <div v-if="current" class="od-nfse" data-testid="order-nfse">
    <span>{{ t('nfseRowTitle') }}</span>
    <RouterLink class="status link-plain" :to="{ path: '/invoices', query: { invoice: current.id, ...(current.effectiveDate && monthOf(current.effectiveDate) !== monthOf(day) ? { month: monthOf(current.effectiveDate) } : {}) } }">
      <span class="dot" :class="`dot--${DOT[current.status]}`" aria-hidden="true"></span><span>{{ invoiceStatusText(current, day) }}</span>
    </RouterLink>
  </div>
  <div v-if="canIssue" class="od-nfse" data-testid="order-nfse-issue-row">
    <span>{{ t('nfseRowTitle') }}</span>
    <span v-if="remaining <= 0" class="sub">{{ t('nfseNotIssued') }}</span>
    <button v-else type="button" class="link" data-testid="order-nfse-issue" @click="emit('issue')">{{ t('nfseIssueLink') }}</button>
  </div>
</template>
