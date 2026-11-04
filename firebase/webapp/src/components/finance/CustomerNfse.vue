<script setup lang="ts">
// The customer's notas (customer.detail.nfse-list, customer.detail.nfse-several,
// nfse.orders.pick): "Notas fiscais · N emitidas" opening "Notas de X" (only
// when the customer has one), and "Emitir uma nota com várias OS": which orders
// go in (several, search by number), then the same issue sheet as the order.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { customerOrdersForNfse, nfseSettings, watchInvoicesOf } from '@/lib/nfse/data'
import { canHaveNfse, eligibleOrderIds, isIssued, nfseValueOf, type NfseInvoice } from '@/lib/nfse/model'
import { country, money, orderShort } from '@/lib/orders/text'
import { showToast } from '@/lib/toast'
import IssueInvoiceDialog from './IssueInvoiceDialog.vue'

const props = defineProps<{ customerId: string; customerName: string }>()

const invoices = shallowRef<NfseInvoice[]>([])
const ready = ref(true)
/** Notas on for the company (nfseEnabled, Asaas connected): nothing shows otherwise. */
const available = ref(false)
let stop: (() => void) | undefined
onMounted(async () => {
  const settings = await nfseSettings().catch(() => null)
  if (!settings?.available) return
  available.value = true
  ready.value = settings.ready
  stop = await watchInvoicesOf({ customerId: props.customerId }, (list) => (invoices.value = list), () => {})
  full.value = await customerOrdersForNfse(props.customerId).catch(() => [])
})
onBeforeUnmount(() => stop?.())

const issued = computed(() => invoices.value.filter(isIssued).length)
/** The customer's orders with their lines (the API's list has only totals). */
const full = shallowRef<Awaited<ReturnType<typeof customerOrdersForNfse>>>([])
/** May go in a nota now: services of some value, not a quote nor canceled, no active nota (B7, as the app). */
const eligible = computed(() => {
  const ids = new Set(eligibleOrderIds(full.value, invoices.value))
  return full.value.filter((o) => ids.has(o.id)).sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''))
})
/** Some order could ever have a nota (the button stays; all already with a nota says so). */
const anyBillable = computed(() => full.value.some((o) => canHaveNfse(o.order)))
const picking = ref(false)
const picked = ref<string[]>([])
const query = ref('')
const shown = computed(() => {
  const digits = query.value.replace(/\D/g, '')
  return digits ? eligible.value.filter((o) => String(o.number ?? '').includes(digits)) : eligible.value
})
const issuing = shallowRef<string[] | null>(null)

function start() {
  // Not set up: the sheet says so first (nfse.access.not-ready).
  if (!ready.value) {
    issuing.value = eligible.value.slice(0, 1).map((o) => o.id)
    if (!issuing.value.length) issuing.value = null
    else return
  }
  if (!eligible.value.length) {
    showToast(t('nfseNoOrdersToPick'))
    return
  }
  picked.value = []
  query.value = ''
  picking.value = true
}

function toggle(id: string) {
  picked.value = picked.value.includes(id) ? picked.value.filter((item) => item !== id) : [...picked.value, id]
}

function confirm() {
  if (!picked.value.length) return
  picking.value = false
  issuing.value = [...picked.value]
}

function done() {
  issuing.value = null
}
</script>

<template>
  <div v-if="available && (invoices.length || anyBillable)" class="cust-nfse" data-testid="customer-nfse">
    <RouterLink v-if="invoices.length" class="link" :to="{ path: '/invoices', query: { customer: customerId } }" data-testid="customer-nfse-list">
      {{ t('nfseListTitle') }} · {{ t('web.nfse.issuedCount', { count: issued }) }}
    </RouterLink>
    <button v-if="anyBillable" type="button" class="link" data-testid="customer-nfse-several" @click="start">{{ t('nfseIssueSeveralAction') }}</button>
  </div>
  <Layer v-if="picking" kind="sheet" :label="t('nfsePickOrdersTitle')" @close="picking = false">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('nfsePickOrdersTitle') }}</h2>
        <p class="sub">{{ customerName }}</p>
      </div>
      <div class="layer-body" data-testid="nfse-pick">
        <input v-if="eligible.length > 10" v-model="query" class="field" type="search" inputmode="numeric" :aria-label="t('web.nfse.searchOrder')" :placeholder="t('web.nfse.searchOrder')" />
        <div v-for="order in shown" :key="order.id" class="check-row pick-row">
          <input :id="`np-${order.id}`" class="check" type="checkbox" :checked="picked.includes(order.id)" @change="toggle(order.id)" />
          <label :for="`np-${order.id}`">
            {{ orderShort() }} {{ order.number }}
            <span class="sub"> · {{ t('nfsePickOrderSubtitle', { value: money(nfseValueOf(order.order)), date: order.createdAt ? formatDate(order.createdAt, country()) : '' }) }}</span>
          </label>
        </div>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" :disabled="!picked.length" data-testid="nfse-pick-ok" @click="confirm">{{ t('web.nfse.pickContinue', { count: picked.length }) }}</button>
      </div>
    </template>
  </Layer>
  <IssueInvoiceDialog v-if="issuing" :order-ids="issuing" :customer-id="customerId" @done="done" @close="issuing = null" />
</template>

<style scoped>
.cust-nfse { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: center; }
.pick-row { min-height: 2.75rem; }
</style>
