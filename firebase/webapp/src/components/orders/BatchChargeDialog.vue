<script setup lang="ts">
// "Mandar cobrança" for the selected orders (home.batch.charge): one Asaas link
// per customer (several orders of one customer go in one link, as on the
// customer screen), created through the API only after the person sees the
// list and confirms. Left out, and said why: no customer, nothing owed, a link
// already open, no valid CPF/CNPJ on the record (send those from the order).
// Then each link goes by WhatsApp; "Desfazer" cancels the links just made.
import { computed, onMounted, ref, shallowRef } from 'vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import { t } from '@/i18n'
import { firestoreLite } from '@/lib/firebase'
import { loadCustomer } from '@/lib/customers/data'
import { formatDate, formatMoney } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { orderShort, ordersShort } from '@/lib/orders/text'
import { whatsappNumber } from '@/lib/phone'
import { cancelCustomerCharge, cancelOrderCharge, chargeErrorKey, createCustomerCharge, createOrderCharge, customerCharges } from '@/lib/receive/data'
import { addDays, asaasUrl, chargeOf, fromCents, isOpenCharge, localDay, openChargeOf, receivableOf, toCents, whatsappLink } from '@/lib/receive/model'
import { session } from '@/lib/session'
import { isValidTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature, handlePlanFeatureError } from '@/lib/plan-feature-gate'
import { announce } from '@/lib/ui'
import '@/styles/receive.css'

const props = defineProps<{ orders: Order[] }>()
const emit = defineEmits<{ close: [] }>()

// Asaas charges in R$ (ChargeDialog).
const BR = 'BR'
const today = localDay(new Date())
interface Group {
  customerId: string
  name: string
  phone: string
  orders: Order[]
  value: number
}
interface Made {
  group: Group
  id: string
  url: string | null
}
const state = ref<'reading' | 'plan' | 'saving' | 'done' | 'error'>('reading')
const groups = shallowRef<Group[]>([])
const leftOut = shallowRef<{ name: string; why: string }[]>([])
const due = ref(addDays(today, 3))
const made = shallowRef<Made[]>([])
const failed = shallowRef<{ name: string; why: string }[]>([])
const asking = ref(false)
const undoing = ref(false)

const count = computed(() => groups.value.reduce((sum, group) => sum + group.orders.length, 0))
const title = computed(() => (count.value ? t('web.batchCharge.title', { count: count.value, order: ordersShort(count.value) }) : t('chargeLinkTitle')))
const ordersText = (orders: Order[]) => `${orderShort()} ${orders.map((o) => o.number ?? '').join(', ')}`

async function hasOpenLink(orderId: string): Promise<boolean> {
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', orderId, 'charges'))
  return !!openChargeOf(snap.docs.map((d) => chargeOf(d.id, d.data())))
}

onMounted(async () => {
  try {
    const out: { name: string; why: string }[] = []
    const byCustomer = new Map<string, Order[]>()
    for (const order of props.orders) {
      // What Receber counts (receivableOf): done with a balance, or in progress with a down payment.
      const owed = receivableOf(order) ?? 0
      if (!order.customer?.id) out.push({ name: `${orderShort()} ${order.number ?? ''}`, why: t('web.batchCharge.noCustomer') })
      else if (toCents(owed) <= 0) out.push({ name: `${orderShort()} ${order.number ?? ''} · ${order.customer.name ?? ''}`, why: t('web.batchCharge.nothingOwed') })
      else byCustomer.set(order.customer.id, [...(byCustomer.get(order.customer.id) ?? []), order])
    }
    const found: Group[] = []
    for (const [customerId, orders] of byCustomer) {
      const name = orders[0]?.customer?.name ?? ''
      // An open link of the order or of the customer (customerCharges) covering it: no new one.
      const [record, own, ofCustomer] = await Promise.all([
        loadCustomer(customerId).then((d) => d.customer).catch(() => null),
        Promise.all(orders.map((o) => hasOpenLink(o.id))),
        customerCharges(customerId).then((list) => list.filter(isOpenCharge)),
      ])
      const covered = new Set(ofCustomer.flatMap((charge) => charge.orderIds ?? []))
      const open = orders.map((o, i) => own[i] || covered.has(o.id))
      const free = orders.filter((_, i) => !open[i])
      orders.filter((_, i) => open[i]).forEach((o) => out.push({ name: `${orderShort()} ${o.number ?? ''} · ${name}`, why: t('web.batchCharge.openLink') }))
      if (!free.length) continue
      if (!isValidTaxId(record?.taxId ?? '')) {
        out.push({ name: record?.name ?? name, why: t('web.batchCharge.noTaxId') })
        continue
      }
      const cents = free.reduce((sum, o) => sum + toCents(receivableOf(o) ?? 0), 0)
      found.push({ customerId, name: record?.name ?? name, phone: record?.phone ?? '', orders: free, value: fromCents(cents) })
    }
    groups.value = found
    leftOut.value = out
    state.value = 'plan'
  } catch (error) {
    console.warn('batch charge: not read', error)
    state.value = 'error'
  }
})

async function create() {
  // One run only: a second click while it runs does nothing (B1).
  if (state.value !== 'plan' || !due.value || due.value < today) return
  // Charges are Starter (#724).
  if (!ensurePlanFeature('charges')) return
  state.value = 'saving'
  const list: Made[] = []
  const errors: { name: string; why: string }[] = []
  for (const group of groups.value) {
    try {
      // One order: its own link (as the order screen); several: one link of the customer.
      const response =
        group.orders.length === 1
          ? await createOrderCharge(group.orders[0]!.id, { value: group.value, mode: 'single', dueDate: due.value })
          : await createCustomerCharge(group.customerId, { orderIds: group.orders.map((o) => o.id), value: group.value, dueDate: due.value })
      list.push({ group, id: String(response.id ?? ''), url: asaasUrl(response.invoiceUrl) ?? null })
    } catch (error) {
      console.warn('batch charge: not created', group.customerId, error)
      if (handlePlanFeatureError(error)) {
        state.value = 'plan'
        return
      }
      errors.push({ name: `${group.name} · ${ordersText(group.orders)}`, why: t(chargeErrorKey(error)) })
    }
  }
  made.value = list
  failed.value = errors
  state.value = 'done'
  announce(t('web.batchCharge.made', { count: list.length }))
}

function message(item: Made): string {
  const hello = item.group.name ? t('web.share.msgHello', { name: item.group.name }) : t('web.share.msgHelloNoName')
  const body = t('web.charge.msg', { amount: formatMoney(item.group.value, BR), orders: ordersText(item.group.orders), date: formatDate(`${due.value}T12:00:00`, BR) })
  return `${hello} ${body}\n${item.url ?? ''}`
}
const wa = (item: Made) => whatsappNumber(item.group.phone, session.company?.country)

async function copy(item: Made) {
  try {
    await navigator.clipboard.writeText(item.url ?? '')
    showToast(t('chargeLinkCopied'))
  } catch {
    showToast(t('web.share.copyFailed'))
  }
}

/** Undo: cancels the links just made (a link already paid is refused by the server and said). */
async function undo() {
  asking.value = false
  if (undoing.value) return
  undoing.value = true
  let errors = 0
  for (const item of made.value) {
    try {
      if (item.group.orders.length === 1) await cancelOrderCharge(item.group.orders[0]!.id, item.id)
      else await cancelCustomerCharge(item.group.customerId, item.id)
    } catch (error) {
      console.warn('batch charge: not canceled', item.id, error)
      errors++
    }
  }
  const canceled = made.value.length - errors
  showToast(errors ? t('web.batchCharge.cancelPartial', { canceled, failed: errors }) : t('web.batchCharge.canceled', { count: canceled }))
  emit('close')
}
</script>

<template>
  <Layer kind="sheet" :label="title" :guard="() => state !== 'saving'" @close="emit('close')">
    <template #default="{ close }">
      <template v-if="state !== 'done'">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
        </div>
        <div class="layer-body">
          <p v-if="state === 'reading'" role="status">{{ t('web.loading') }}</p>
          <p v-else-if="state === 'error'" role="alert">{{ t('web.error.generic') }}</p>
          <template v-else>
            <p v-if="!groups.length">{{ t('web.batchCharge.none') }}</p>
            <ul v-else class="batch-lines" data-testid="batch-charge-plan">
              <li v-for="group in groups" :key="group.customerId" class="pay-row">
                <span>{{ group.name }} <small class="muted">· {{ ordersText(group.orders) }}</small></span>
                <span class="num">{{ formatMoney(group.value, BR) }}</span>
              </li>
            </ul>
            <div v-if="leftOut.length" data-testid="batch-charge-left-out">
              <p class="sub">{{ t('web.batchCharge.leftOut', { count: leftOut.length }) }}</p>
              <ul class="batch-lines">
                <li v-for="(item, i) in leftOut" :key="i" class="pay-row">
                  <span>{{ item.name }}</span><span class="muted">{{ item.why }}</span>
                </li>
              </ul>
            </div>
            <template v-if="groups.length">
              <label class="field-label" for="batch-charge-due">{{ t('chargeDueDate') }}</label>
              <input id="batch-charge-due" v-model="due" class="field" type="date" :min="today" :data-empty="!due || undefined" />
              <p v-if="!due || due < today" class="sub">{{ t('web.charge.dueInvalid') }}</p>
            </template>
          </template>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" data-autofocus @click="close()">{{ t('cancel') }}</button>
          <button
            v-if="groups.length"
            type="button"
            class="btn btn--primary"
            :disabled="state !== 'plan' || !due || due < today"
            data-testid="batch-charge-create"
            @click="create"
          >
            {{ t('web.batchCharge.create', { count: groups.length }) }}
          </button>
        </div>
      </template>
      <template v-else>
        <div class="layer-head">
          <h2 class="layer-title">{{ t('web.batchCharge.doneTitle') }}</h2>
          <p class="sub">{{ t('web.batchCharge.doneSub', { date: formatDate(`${due}T12:00:00`, BR) }) }}</p>
        </div>
        <div class="layer-body">
          <div v-if="failed.length" role="alert" data-testid="batch-charge-failed">
            <p>{{ t('web.batchCharge.failed', { count: failed.length }) }}</p>
            <ul class="batch-lines">
              <li v-for="(item, i) in failed" :key="i" class="pay-row"><span>{{ item.name }}</span><span class="muted">{{ item.why }}</span></li>
            </ul>
          </div>
          <ul class="batch-lines">
            <li v-for="item in made" :key="item.id" class="pay-row">
              <span>{{ item.group.name }} · {{ formatMoney(item.group.value, BR) }}</span>
              <span class="batch-send">
                <button v-if="item.url" type="button" class="btn" @click="copy(item)">{{ t('chargeCopyLink') }}</button>
                <a
                  v-if="item.url && wa(item)"
                  class="btn btn--primary"
                  :href="whatsappLink(wa(item), message(item))"
                  target="_blank"
                  rel="noopener noreferrer"
                  data-testid="batch-charge-whatsapp"
                  :aria-label="`${t('shareSendWhatsApp')}: ${item.group.name}`"
                  >{{ t('shareSendWhatsApp') }}</a
                >
              </span>
            </li>
          </ul>
        </div>
        <div class="layer-foot">
          <button v-if="made.length" type="button" class="btn" @click="asking = true">{{ t('web.batch.undo') }}</button>
          <span class="spacer"></span>
          <button type="button" class="btn" data-autofocus @click="close()">{{ t('close') }}</button>
        </div>
      </template>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="asking"
    :title="t('web.batchCharge.cancelTitle', { count: made.length })"
    :body="t('web.batchCharge.cancelBody')"
    :confirm="t('web.batchCharge.cancelConfirm')"
    :keep="t('web.batchCharge.keep')"
    danger
    @confirm="undo"
    @close="asking = false"
  />
</template>
