<script setup lang="ts">
// The open customer (customer.detail.*): who, what is pending and the next
// step in blue ("Nova OS para Ana"), then contact (e-mail, CPF/CNPJ, address
// and the segment fields too: the app hides them, defect 8), devices and
// orders. Read by id from the API, never a stale copy (defects 19 and 20).
// Consultant and technician see only their orders, and the screen says so.
import { computed, defineAsyncComponent, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { MoreHorizontal, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import OrderStatus from './OrderStatus.vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { loadTexts, locale, t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { deleteCustomer, loadCustomer, type CustomerDetail } from '@/lib/customers/data'
import { firstName, mapsUrl, type CustomerRow } from '@/lib/customers/model'
import { formatDate, fromIsoDay } from '@/lib/format'
import { canCreateOrders } from '@/lib/orders/model'
import { money, orderShort } from '@/lib/orders/text'
import { dialable, formatPhone, whatsappNumber } from '@/lib/phone'
import { fieldTitle, groupBySection, namespaceFields, readCustom, type FormField } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { formatTaxId, usesTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import CustomerForm from './CustomerForm.vue'
import DeviceForm from './DeviceForm.vue'
// Several orders in one receipt, and the customer's receipts (pay.customer.view, customer.detail.receipts).
const ReceiveCustomerDialog = defineAsyncComponent(() => import('@/components/orders/receive/ReceiveCustomerDialog.vue'))
const ReceiptsDialog = defineAsyncComponent(() => import('@/components/orders/receive/ReceiptsDialog.vue'))
// The customer's notas (customer.detail.nfse-*): their own chunk and texts, only for who issues.
const CustomerNfse = defineAsyncComponent(() => Promise.all([import('@/components/finance/CustomerNfse.vue'), loadTexts('finance')]).then(([m]) => m))

const props = defineProps<{ customerId: string; directory: CustomerRow[] }>()
const emit = defineEmits<{ close: []; changed: []; removed: [] }>()
const router = useRouter()

const state = ref<'loading' | 'ready' | 'failed' | 'notFound'>('loading')
const detail = shallowRef<CustomerDetail | null>(null)
const dialog = ref<null | 'menu' | 'delete' | 'edit' | 'device' | 'receive' | 'receipts'>(null)
// Who receives also sees receipts: the server lists all for financial roles, a consultant's own.
const canReceipts = computed(() => effectiveUseFinancial() && (can('viewFinancialReports') || session.role === 'consultant'))
const menuButton = ref<HTMLElement | null>(null)
const busy = ref(false)

const country = computed(() => session.company?.country)
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const customer = computed(() => detail.value?.customer ?? null)
const canManage = can('manageCustomers')
const canCreate = canCreateOrders(session.role, can('createOrder'))
const phone = computed(() => customer.value?.phone ?? '')
const wa = computed(() => whatsappNumber(phone.value, country.value))
const map = computed(() => (customer.value ? mapsUrl(customer.value.address, customer.value.latitude, customer.value.longitude) : null))
const owed = computed(() => detail.value?.owed ?? 0)
const spent = computed(() => detail.value?.spent ?? 0)
const receivable = computed(() => detail.value?.receivable ?? [])
const menuChoices = computed<Choice[]>(() =>
  canManage ? [{ id: 'edit', label: t('editCustomer') }, { id: 'delete', label: t('deleteAction'), danger: true }] : [],
)
/** What the customer has, counted on the server over everything, not only what the person reads (revisão M2). */
const deleteLinks = computed(() => {
  const links = detail.value?.links
  if (!links || !(links.orders || links.receipts || links.charges)) return ''
  return t('web.customers.deleteLinks', { orders: links.orders, receipts: links.receipts, charges: links.charges })
})
const customFields = computed(() => {
  const data = customer.value?.customData
  const fields = namespaceFields('customer', ['customer.name', 'customer.phone', 'customer.email', 'customer.address', 'customer.taxId'])
  return groupBySection(fields, locale.value, t('web.customers.general'))
    .map((group) => ({ title: group.title, fields: group.fields.map((field) => ({ field, text: customText(field, readCustom(data, field)) })).filter((item) => item.text) }))
    .filter((group) => group.fields.length)
})

function customText(field: FormField, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  if (field.type === 'date' && typeof value === 'string') return formatDate(fromIsoDay(value.slice(0, 10)), country.value)
  if (typeof value === 'boolean') return value ? t('web.yes') : t('web.no')
  return String(value)
}

async function load() {
  state.value = 'loading'
  try {
    detail.value = await loadCustomer(props.customerId)
    state.value = 'ready'
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) state.value = 'notFound'
    else {
      console.error('customer: not loaded', error)
      state.value = 'failed'
    }
  }
}

/** Nova OS with this customer only, never a device (customer.detail.new-order). */
function newOrder() {
  if (!customer.value) return
  ui.newOrderSeed = { customer: { id: customer.value.id, name: customer.value.name, phone: customer.value.phone ?? undefined } }
  ui.newOrder = true
}

/** One order: straight to it; several: one receipt over them (customer.detail.receive, pay.customer.view). */
function receive() {
  const ids = receivable.value
  if (ids.length === 1) void router.push({ path: '/', query: { order: ids[0] } })
  else if (customer.value) dialog.value = 'receive'
}

async function onReceived() {
  dialog.value = null
  await load()
  emit('changed')
}

function openOrder(id: string) {
  void router.push({ path: '/', query: { order: id } })
}

function openDevice(id: string) {
  void router.push({ path: '/devices', query: { device: id } })
}

function onMenu(id: string) {
  dialog.value = id === 'edit' ? 'edit' : id === 'delete' ? 'delete' : null
}

async function remove() {
  if (!customer.value || busy.value) return
  busy.value = true
  try {
    await deleteCustomer(customer.value.id)
    const name = customer.value.name
    showToast(t('web.customers.deleted', { name }))
    announce(t('web.customers.deleted', { name }))
    // The list takes over: it leaves the customer and the confirmation in one navigation.
    emit('removed')
  } catch (error) {
    // The app lets this error loose (defect 10): here it says so and nothing changes.
    dialog.value = null
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

/** Someone saved this customer while it was being edited: say so and show the new version (revisão M1). */
async function onChangedElsewhere() {
  dialog.value = null
  showToast(t('web.customers.changedElsewhere'))
  await load()
  emit('changed')
}

async function onEdited() {
  dialog.value = null
  showToast(t('web.customers.saved'))
  await load()
  emit('changed')
}

async function onDeviceSaved(id: string, notice?: string) {
  // The new device opens. It is not tied to this customer until it enters an order (no owner field yet).
  await router.replace({ path: '/devices', query: { device: id } })
  dialog.value = null
  if (notice) showToast(notice)
}

onMounted(load)
</script>

<template>
  <section class="od" :aria-label="customer?.name ?? t('customer')" data-testid="customer-detail">
    <div class="od-top">
      <span class="num">{{ label('customer._entity') }}</span>
      <span class="spacer"></span>
      <button v-if="customer && menuChoices.length" ref="menuButton" type="button" class="icon-btn" :aria-label="t('customerActions')" data-testid="customer-menu" @click="dialog = 'menu'">
        <MoreHorizontal :size="18" aria-hidden="true" />
      </button>
      <button type="button" class="icon-btn" :aria-label="t('close')" @click="emit('close')"><X :size="18" aria-hidden="true" /></button>
    </div>

    <LoadingState v-if="state === 'loading'" />
    <div v-else-if="state === 'notFound'" class="empty" role="alert" data-testid="customer-not-found">
      <h2>{{ t('web.customers.notFound') }}</h2>
      <p>{{ t('web.customers.notFoundBody') }}</p>
      <button type="button" class="btn" @click="emit('close')">{{ t('back') }}</button>
    </div>
    <ErrorState v-else-if="state === 'failed'" :retry="load" />

    <div v-else-if="customer && detail" class="od-scroll" tabindex="-1" data-od-focus>
      <header class="od-head">
        <h2 class="od-h"><span class="od-name">{{ customer.name || t('customerWithoutName') }}</span></h2>
        <div v-if="owed > 0 || spent > 0" class="od-state" data-testid="customer-money">
          <span v-if="owed > 0" class="od-sentence">
            {{ t('customerOwesValue', { value: money(owed) }) }}
            <template v-if="receivable.length"> · <button type="button" class="link" data-testid="customer-receive" @click="receive">{{ t('web.customers.receive') }}</button></template>
          </span>
          <span v-if="spent > 0" class="muted">{{ t('customerSpentValue', { value: money(spent) }) }}</span>
          <button v-if="canReceipts" type="button" class="link" data-testid="customer-receipts" @click="dialog = 'receipts'">{{ t('receiptsSection') }}</button>
        </div>
        <CustomerNfse v-if="can('chargeOrder') && effectiveUseFinancial()" :key="customer.id" :customer-id="customer.id" :customer-name="customer.name" />
        <p v-if="detail.partial" class="sub">{{ t('web.customers.partial') }}</p>
        <p v-if="canCreate" class="od-ask">{{ t('askOrderForCustomer', { name: firstName(customer.name) }) }}</p>
        <div class="od-actions">
          <button v-if="canCreate" type="button" class="btn btn--primary" data-testid="customer-new-order" @click="newOrder">
            {{ t('newOrderFor', { name: firstName(customer.name) }) }}
          </button>
          <a v-if="phone" class="btn" :href="`tel:${dialable(phone)}`" data-testid="customer-call">{{ t('callAction') }}</a>
          <a v-if="wa" class="btn" :href="`https://wa.me/${wa}`" target="_blank" rel="noopener" data-testid="customer-whatsapp">{{ t('whatsapp') }}</a>
        </div>
      </header>

      <section class="od-sec" :aria-label="t('web.customers.contact')">
        <h3>{{ t('web.customers.contact') }}</h3>
        <dl class="kv" data-testid="customer-contact">
          <template v-if="phone"><dt>{{ label('customer.phone') }}</dt><dd class="num">{{ formatPhone(phone, country) }}</dd></template>
          <template v-if="customer.email"><dt>{{ label('customer.email') }}</dt><dd>{{ customer.email }}</dd></template>
          <template v-if="customer.taxId && usesTaxId(country)"><dt>{{ t('cpfCnpj') }}</dt><dd class="num">{{ formatTaxId(customer.taxId) }}</dd></template>
          <template v-if="customer.address || map">
            <dt>{{ label('customer.address') }}</dt>
            <dd>
              <span v-if="customer.address">{{ customer.address }}</span>
              <a v-if="map" class="link" :href="map" target="_blank" rel="noopener" data-testid="customer-map">{{ t('openInMaps') }}</a>
            </dd>
          </template>
        </dl>
        <p v-if="!phone && !customer.email && !customer.address && !customer.taxId" class="muted">{{ t('web.customers.noContact') }}</p>
        <template v-for="group in customFields" :key="group.title">
          <h4 class="od-group">{{ group.title }}</h4>
          <dl class="kv" data-testid="customer-custom">
            <template v-for="item in group.fields" :key="item.field.key"><dt>{{ fieldTitle(item.field, locale) }}</dt><dd>{{ item.text }}</dd></template>
          </dl>
        </template>
      </section>

      <section class="od-sec" :aria-label="label('device._entity_plural')">
        <h3>
          {{ label('device._entity_plural') }}
          <button v-if="can('manageDevices')" type="button" class="link" data-testid="customer-add-device" @click="dialog = 'device'">{{ t('web.customers.addDevice', { device: label('device._entity').toLocaleLowerCase() }) }}</button>
        </h3>
        <ul v-if="detail.devices.length" class="dir-list" data-testid="customer-devices">
          <li v-for="device in detail.devices" :key="device.id">
            <button type="button" class="row-btn" @click="openDevice(device.id)">{{ device.name || label('device._entity') }}</button>
            <span class="sub"><template v-if="device.serial"><span class="num">{{ device.serial }}</span> · </template>{{ t('web.customers.orderCount', { count: device.count, order: orderShort() }) }}</span>
          </li>
        </ul>
        <p v-else class="muted">{{ t('web.customers.noDevices', { devices: label('device._entity_plural').toLocaleLowerCase() }) }}</p>
      </section>

      <section class="od-sec" :aria-label="t('web.customers.orders')">
        <h3>{{ t('web.customers.orders') }}</h3>
        <ul v-if="detail.orders.length" class="dir-list" data-testid="customer-orders">
          <li v-for="order in detail.orders" :key="order.id" class="dir-order">
            <button type="button" class="row-btn" @click="openOrder(order.id)"><span class="num">{{ orderShort() }} {{ order.number }}</span></button>
            <OrderStatus :status="order.status" />
            <span v-if="order.total !== undefined" class="num dir-money">{{ money(order.total) }}</span>
            <span v-if="order.createdAt" class="sub">{{ formatDate(order.createdAt, country) }}</span>
          </li>
        </ul>
        <p v-else class="muted">{{ t('web.customers.noOrders') }}</p>
        <p v-if="detail.ordersTruncated" class="sub" data-testid="orders-truncated">{{ t('web.customers.ordersTruncated', { count: detail.orders.length }) }}</p>
      </section>
    </div>

    <ChoiceDialog v-if="dialog === 'menu' && customer" :anchor="menuButton" :title="customer.name" :choices="menuChoices" @pick="onMenu" @close="dialog = null" />
    <ConfirmDialog
      v-else-if="dialog === 'delete' && customer"
      :title="t('deleteCustomerTitle', { name: customer.name })"
      :body="`${deleteLinks} ${t('deleteCustomerKeepsOrders')}`.trim()"
      :confirm="t('deleteAction')"
      :keep="t('cancel')"
      danger
      @confirm="remove"
      @close="dialog = null"
    />
    <CustomerForm v-else-if="dialog === 'edit' && customer" :customer="customer" :version="detail?.version" :directory="directory" @saved="onEdited" @changed="onChangedElsewhere" @close="dialog = null" />
    <DeviceForm v-else-if="dialog === 'device'" :devices="[]" @saved="onDeviceSaved" @close="dialog = null" />
    <ReceiveCustomerDialog v-else-if="dialog === 'receive' && customer" :customer-id="customer.id" :customer-name="customer.name" :checked="receivable" @done="onReceived" @close="dialog = null" />
    <ReceiptsDialog v-else-if="dialog === 'receipts' && customer" :customer-id="customer.id" :customer-name="customer.name" @changed="load" @close="dialog = null" />
  </section>
</template>
