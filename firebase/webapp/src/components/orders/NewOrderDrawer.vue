<script setup lang="ts">
// Nova OS by keyboard (WEB_APP_DESIGN, "menos de 45 segundos"): N opens with the
// cursor on Cliente; Enter picks; the device is suggested; each item enters with
// the catalog price; Ctrl+Enter saves from any field. Nothing is saved before
// that. Closing with something filled in asks first (also the browser's Voltar).
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { Check, Trash2, X } from '@lucide/vue'
import Combobox, { type ComboboxGroup, type ComboboxItem } from '@/components/Combobox.vue'
import Layer from '@/components/Layer.vue'
import RepeatFields, { type RepeatForm } from '@/components/contracts/RepeatFields.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { firestoreLite } from '@/lib/firebase'
import { orderCreated } from '@/lib/orders/bus'
import { markOffer } from '@/lib/forms/offer'
import { forgetLists, loadCatalog, loadCustomers, loadDevices, loadTeam, search, type CatalogItem, type Customer, type Device, type Member } from '@/lib/orders/catalog'
import { createStatuses, type OrderStatus } from '@/lib/orders/model'
import { startContract } from '@/lib/contracts/data'
import { newContract } from '@/lib/contracts/model'
import { toIsoDay } from '@/lib/format'
import { deviceLabel, lineKindText, money, orderShort, statusText, country } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { mostUsedKeys, ownerOf, plateHits, recentCustomers, type Named } from '@/lib/orders/pickers'
import { api, can, session } from '@/lib/session'
import { formatPhone } from '@/lib/phone'
import { isMac } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'

interface Line {
  key: string
  item: CatalogItem
  value: number | null
  quantity: number
  /** Outside the catalog ("+ Usar «texto» nesta OS"): added after the order exists, by POST /items without catalogId. */
  free?: boolean
}

const router = useRouter()
const layer = ref<InstanceType<typeof Layer> | null>(null)
const customerRef = ref<InstanceType<typeof Combobox> | null>(null)
const deviceRef = ref<InstanceType<typeof Combobox> | null>(null)
const itemRef = ref<InstanceType<typeof Combobox> | null>(null)
const customers = shallowRef<Customer[]>([])
const devices = shallowRef<Device[]>([])
const catalog = shallowRef<CatalogItem[]>([])
const team = shallowRef<Member[]>([])
const customerDevices = shallowRef<Device[]>([])
const recents = shallowRef<Named[]>([])
const mostUsed = shallowRef<string[]>([])
const customer = ref<Customer | null>(null)
const device = ref<Device | null>(null)
const lines = ref<Line[]>([])
const due = ref('')
const request = ref('')
const status = ref<OrderStatus>('quote')
const visit = ref('')
const assignee = ref('')
const more = ref(false)
const saving = ref(false)
const failed = ref('')
const loading = ref(true)
const devicesLoading = ref(false)
let allowClose = false

const showsMoney = can('viewPrices')
const editPrices = showsMoney && can('editPrices')
const statuses = createStatuses(session.role)
const useScheduling = (session.company as { useScheduling?: boolean } | null)?.useScheduling !== false
// "Novo contrato" from Contratos: the order is created and then gets its contract (order.new.repeat).
const repeat = !!ui.newOrderSeed?.repeat
const today = toIsoDay(new Date())
const repeatForm = ref<RepeatForm>({ repeat: { frequency: 'monthly', interval: 1 }, startDay: today, endDay: null, autoGenerate: true })
const title = computed(() => (repeat ? t('contractNew') : t('orderNewTitle', { order: orderShort() })))
const dirty = computed(() => !!(customer.value || device.value || lines.value.length || request.value.trim() || due.value || visit.value))
const total = computed(() => lines.value.reduce((sum, line) => sum + (line.value ?? 0) * line.quantity, 0))
const unpriced = computed(() => lines.value.filter((line) => line.value === null).length)
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'
const moreSummary = computed(() => {
  const parts: string[] = []
  if (status.value !== 'quote') parts.push(statusText(status.value))
  if (visit.value) parts.push(t('orderScheduleLabel'))
  const person = team.value.find((member) => member.id === assignee.value)
  if (person) parts.push(person.name)
  return parts.length ? parts.join(' · ') : t('orderMoreOptionsHint')
})

onMounted(async () => {
  // Opened from a customer or device screen: it comes with them (customer.detail.new-order, device.detail.new-order).
  const seed = ui.newOrderSeed
  ui.newOrderSeed = null
  if (seed?.customer) customer.value = { ...seed.customer }
  if (seed?.device) device.value = { ...seed.device }
  try {
    const [c, d, k] = await Promise.all([loadCustomers(), loadDevices(), loadCatalog()])
    customers.value = c
    devices.value = d
    catalog.value = k
    loading.value = false
    // "Recentes" and "Mais usados" come after the lists; a failure only hides the section.
    void recentCustomers().then((list) => (recents.value = list), () => {})
    void mostUsedKeys().then((keys) => (mostUsed.value = keys), () => {})
    // Only the customer: their devices are suggested first, none is picked (the app's rule).
    if (seed?.customer && !seed.device) customerDevices.value = await devicesOf(seed.customer.id)
    if (can('assignOrder')) team.value = await loadTeam()
  } catch (error) {
    console.warn('new order: lists not loaded', error)
    failed.value = t(errorMessageKey(error))
  } finally {
    loading.value = false
  }
})

/** Devices this customer brought before: suggested first, the only one is picked. */
async function devicesOf(customerId: string): Promise<Device[]> {
  try {
    let rows: { devices?: Device[]; device?: Device }[] = []
    if (showsMoney) {
      const [db, { collection, getDocs, limit, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
      const filters = [where('customer.id', '==', customerId), ...(can('viewAllOrders') ? [] : [where('createdBy.id', '==', session.uid)])]
      rows = (await getDocs(query(collection(db, 'companies', session.companyId as string, 'orders'), ...filters, limit(10)))).docs.map((doc) => doc.data())
    } else {
      const body = await api<{ data?: typeof rows }>(`/v1/app/orders?limit=10&customerId=${encodeURIComponent(customerId)}`, { raw: true })
      rows = body.data ?? []
    }
    const found = new Map<string, Device>()
    for (const row of rows) for (const item of row.devices?.length ? row.devices : row.device ? [row.device] : []) if (item?.id) found.set(item.id, item)
    return [...found.values()]
  } catch (error) {
    // Only the suggestion is lost: the device can still be searched.
    console.warn('new order: devices of the customer not read', error)
    return []
  }
}

const NEW = '__new'
/** Item outside the catalog: the API accepts a line without catalogId with #516 (writes.API_516). */
const FREE_ITEMS = writes.API_516
/** One per Nova OS opened: a "Salvar" again after a network failure never creates a second order (API_516). */
const clientOrderId = crypto.randomUUID()

const PLATE = 'plate:'
const customerRow = (c: Customer) => ({ id: c.id, label: c.name, sub: formatPhone(c.phone) || undefined })
const customerGroups = (query: string): ComboboxGroup[] => [
  // A plate brings the device and its owner together (customer.picker.plate).
  { title: t('web.newOrder.byPlate'), items: plateHits(devices.value, query).map((d) => ({ id: `${PLATE}${d.id}`, label: `${d.serial} · ${d.name}` })) },
  // "Recentes": the customers of the last orders, only without a search (customer.picker.recents).
  {
    title: t('pickerRecent'),
    items: query.trim() ? [] : recents.value.map((r) => customers.value.find((c) => c.id === r.id) ?? r).map(customerRow),
  },
  {
    title: query ? undefined : t('web.newOrder.customers'),
    items: search(query.trim() ? customers.value : customers.value.filter((c) => !recents.value.some((r) => r.id === c.id)), query, (c) => c.phone ?? '', 8).map(customerRow),
  },
  // A new customer right here (POST /v1/app/customers): the name, or the phone when only digits were typed.
  // Only once the list is in: an Enter typed before it loads must find the existing customer, never create a copy.
  { items: query.trim() && !loading.value && can('manageCustomers') ? [{ id: NEW, label: t('web.newOrder.register', { name: query.trim() }) }] : [] },
]

async function createCustomer(text: string): Promise<Customer | null> {
  const digits = /^[\d\s()+-]+$/.test(text) && /\d{6}/.test(text.replace(/\D/g, ''))
  const body = digits ? { name: text, phone: text } : { name: text }
  try {
    const created = await api<{ id: string; name: string }>('/v1/app/customers', { method: 'POST', body })
    const fresh: Customer = { id: created.id, name: created.name, ...(digits ? { phone: text } : {}) }
    customers.value = [...customers.value, fresh]
    forgetLists()
    announce(t('web.newOrder.registered', { name: fresh.name }))
    return fresh
  } catch (error) {
    failed.value = t(errorMessageKey(error))
    return null
  }
}

/** The plate's device and its owner (the customer of its latest order); without an owner, only the device. */
async function pickPlate(deviceId: string) {
  const found = devices.value.find((d) => d.id === deviceId) ?? null
  const owner = await ownerOf(deviceId)
  if (owner) customer.value = customers.value.find((c) => c.id === owner.id) ?? owner
  device.value = found
  customerDevices.value = found ? [found] : []
  await nextTick()
  if (customer.value) itemRef.value?.focus()
}

async function pickCustomer(item: ComboboxItem, query = '') {
  if (item.id.startsWith(PLATE)) return pickPlate(item.id.slice(PLATE.length))
  const chosen =
    item.id === NEW ? await createCustomer(query.trim()) : (customers.value.find((c) => c.id === item.id) ?? recents.value.find((c) => c.id === item.id) ?? null)
  customer.value = chosen
  device.value = null
  customerDevices.value = []
  if (!chosen) return
  // The cursor goes to the device at once, so nothing typed meanwhile is lost.
  devicesLoading.value = true
  await nextTick()
  deviceRef.value?.focus()
  const found = await devicesOf(chosen.id)
  // Another customer was picked meanwhile (compare ids: customer.value is a reactive proxy).
  if (customer.value?.id !== chosen.id) return
  customerDevices.value = found
  devicesLoading.value = false
  // The only device of this customer comes in by itself, unless the person already typed.
  const input = document.getElementById('no-device') as HTMLInputElement | null
  if (found.length === 1 && !device.value && input && !input.value && document.activeElement === input) {
    device.value = found[0] as Device
    await nextTick()
    itemRef.value?.focus()
  }
}

const deviceGroups = (query: string): ComboboxGroup[] => {
  // While this customer's devices load, nothing to pick yet (an Enter waits for them).
  if (devicesLoading.value) return []
  const own = search(customerDevices.value, query, (d) => d.serial ?? '', 5)
  // Without known devices of this customer (the consultant only reads their own orders), list the company's.
  const others = search(devices.value.filter((d) => !own.some((o) => o.id === d.id)), query, (d) => d.serial ?? '', query || !own.length ? 6 : 0)
  const row = (d: Device) => ({ id: d.id, label: d.name, sub: d.serial ?? undefined })
  return [
    { title: own.length ? t('web.newOrder.fromCustomer') : undefined, items: own.map(row) },
    { title: others.length && own.length ? t('web.newOrder.otherDevices', { device: deviceLabel().toLocaleLowerCase() }) : undefined, items: others.map(row) },
    { items: query.trim() && !loading.value && can('manageDevices') ? [{ id: NEW, label: t('web.newOrder.register', { name: query.trim() }) }] : [] },
  ]
}
async function pickDevice(item: ComboboxItem, query = '') {
  if (item.id === NEW) {
    try {
      const created = await api<{ id: string; name: string }>('/v1/app/devices', { method: 'POST', body: { name: query.trim() } })
      const fresh: Device = { id: created.id, name: created.name ?? query.trim() }
      devices.value = [...devices.value, fresh]
      forgetLists()
      device.value = fresh
    } catch (error) {
      failed.value = t(errorMessageKey(error))
      return
    }
  } else device.value = devices.value.find((d) => d.id === item.id) ?? customerDevices.value.find((d) => d.id === item.id) ?? null
  await nextTick()
  itemRef.value?.focus()
}

const itemRow = (item: CatalogItem) => ({
  id: `${item.kind}:${item.id}`,
  label: item.name,
  sub: lineKindText(item.kind),
  right: showsMoney ? (item.value === null ? t('catalogNoPrice') : money(item.value)) : undefined,
})
const itemGroups = (query: string): ComboboxGroup[] => [
  // "Mais usados" of the last orders, only without a search (order.item-search.most-used).
  {
    title: t('orderMostUsed'),
    items: query.trim() ? [] : mostUsed.value.map((key) => catalog.value.find((entry) => `${entry.kind}:${entry.id}` === key)).filter((item): item is CatalogItem => !!item).map(itemRow),
  },
  {
    title: query ? undefined : t('orderAllItems'),
    items: search(catalog.value, query, (item) => lineKindText(item.kind), 8).map((item) => ({
      id: `${item.kind}:${item.id}`,
      label: item.name,
      sub: lineKindText(item.kind),
      right: showsMoney ? (item.value === null ? t('catalogNoPrice') : money(item.value)) : undefined,
    })),
  },
  { items: FREE_ITEMS && query.trim() && !loading.value ? [{ id: NEW, label: t('web.newOrder.useFree', { name: query.trim() }) }] : [] },
]
function pickItem(picked: ComboboxItem, query = '') {
  const free = picked.id === NEW && query.trim() ? { id: '', kind: 'service' as const, name: query.trim(), value: null } : null
  const item = free ?? catalog.value.find((entry) => `${entry.kind}:${entry.id}` === picked.id)
  if (!item) return
  lines.value = [...lines.value, { key: crypto.randomUUID(), item, value: item.value, quantity: 1, ...(free ? { free: true } : {}) }]
  announce(t('web.order.itemAdded', { name: item.name }))
}

// The picker gives the company's local time; saved as the app saves it, without a zone (revisão do #521, M1).
const isoOrUndefined = (value: string) => (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value) ? `${value}:00.000` : undefined)

async function save() {
  if (saving.value) return
  // A price being typed is read on blur: let it commit before saving.
  ;(document.activeElement as HTMLElement | null)?.blur?.()
  await nextTick()
  if (!customer.value) {
    failed.value = t('orderSaveNeedsCustomer')
    customerRef.value?.focus()
    return
  }
  // Something typed and not chosen is never thrown away in silence.
  const pendingDevice = deviceRef.value?.pending()
  const pendingItem = itemRef.value?.pending()
  if (pendingDevice || pendingItem) {
    failed.value = t('web.newOrder.pending', { text: (pendingDevice || pendingItem) as string, field: pendingDevice ? deviceLabel() : t('pickerItemTitle') })
    ;(pendingDevice ? deviceRef : itemRef).value?.focus()
    return
  }
  saving.value = true
  failed.value = ''
  try {
    // Own price only when it differs from the catalog (and only who may edit prices).
    const own = (line: Line) => (editPrices && line.value !== line.item.value ? { value: line.value } : {})
    const catalogLines = lines.value.filter((l) => !l.free)
    const created = await writes.createOrder({
      clientOrderId,
      customerId: customer.value.id,
      ...(device.value ? { deviceId: device.value.id } : {}),
      services: catalogLines.filter((l) => l.item.kind === 'service').map((l) => ({ serviceId: l.item.id, ...own(l) })),
      products: catalogLines.filter((l) => l.item.kind === 'product').map((l) => ({ productId: l.item.id, quantity: l.quantity, ...own(l) })),
      status: status.value,
      ...(due.value ? { dueDate: isoOrUndefined(due.value) } : {}),
      ...(visit.value ? { scheduledDate: isoOrUndefined(visit.value) } : {}),
    })
    // The rest after the id: a failure here says what did not stay, the order is already saved.
    const after: Promise<unknown>[] = []
    // Items outside the catalog, one after the other so they keep their order.
    const free = lines.value.filter((l) => l.free)
    if (free.length) {
      after.push(free.reduce<Promise<unknown>>((chain, line) => chain.then(() => writes.addItem(created.id, { kind: 'service', description: line.item.name, ...own(line) })), Promise.resolve()))
    }
    if (assignee.value) after.push(writes.patchOrder(created.id, { assignedTo: assignee.value }))
    if (request.value.trim()) after.push(writes.addComment(created.id, request.value.trim(), true))
    if (repeat) after.push(startContract(created.id, newContract(repeatForm.value, today)))
    const results = await Promise.allSettled(after)
    allowClose = true
    orderCreated(created.id)
    // With a device and not saved done: the order asks for the check-in checklist (order.offer.checklist).
    if (device.value && status.value !== 'done') markOffer(created.id)
    const message = t('web.newOrder.created', { order: `${orderShort()} ${created.number}` })
    showToast(results.some((r) => r.status === 'rejected') ? t('web.newOrder.createdPartly', { order: `${orderShort()} ${created.number}` }) : message)
    announce(message)
    // The drawer's history entry becomes the new order: Voltar goes to the list, not to an empty drawer.
    await router.replace({ path: repeat ? '/contracts' : '/', query: { order: created.id } })
    ui.newOrder = false
  } catch (error) {
    console.warn('new order: not saved', error)
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    event.stopPropagation()
    void save()
  }
}

/**
 * Asked before closing with something filled in (Esc, X, Voltar), the text of
 * the request included. The browser's own confirm, as Layer's other guards: it
 * answers inside the navigation guard without opening a second layer.
 */
function guard(): boolean {
  if (allowClose || !dirty.value) return true
  const ok = window.confirm(`${t('orderDiscardTitle')}\n${t('orderDiscardMessage')}`)
  if (ok) allowClose = true
  return ok
}

// Closing the tab or reloading with something typed asks too (defect 17).
const beforeUnload = (event: BeforeUnloadEvent) => {
  if (dirty.value && !allowClose) event.preventDefault()
}
onMounted(() => window.addEventListener('beforeunload', beforeUnload))
onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload))
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="ui.newOrder = false">
    <div class="drawer" data-testid="new-order-drawer" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
        <span class="muted small">{{ session.company?.name }}</span>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div class="step">
          <div v-if="customer" class="chosen">
            <span><span class="field-label">{{ t('customer') }}</span><strong>{{ customer.name }}</strong></span>
            <button type="button" class="link" @click="customer = null; device = null; $nextTick(() => customerRef?.focus())">{{ t('web.newOrder.change') }}</button>
          </div>
          <Combobox v-else id="no-customer" ref="customerRef" :label="t('customer')" :placeholder="t('web.newOrder.customerHint')" :groups="customerGroups" :loading="loading" autofocus @pick="pickCustomer" />
        </div>
        <div v-if="customer" class="step">
          <div v-if="device" class="chosen">
            <span><span class="field-label">{{ deviceLabel() }}</span>{{ device.name }} <span v-if="device.serial" class="num">{{ device.serial }}</span></span>
            <button type="button" class="link" @click="device = null; $nextTick(() => deviceRef?.focus())">{{ t('web.newOrder.change') }}</button>
          </div>
          <Combobox v-else id="no-device" ref="deviceRef" :label="t('web.newOrder.deviceOptional', { device: deviceLabel() })" :groups="deviceGroups" :loading="devicesLoading" :preselect="devicesLoading || customerDevices.length > 0" @pick="pickDevice" @next="itemRef?.focus()" />
        </div>
        <div class="step">
          <Combobox id="no-item" ref="itemRef" :label="t('pickerItemTitle')" :placeholder="t('orderItemSearchPlaceholder')" :groups="itemGroups" :loading="loading" @pick="pickItem" />
          <ul v-if="lines.length" class="drawer-items" :aria-label="t('orderItemsSection')">
            <li v-for="line in lines" :key="line.key">
              <span>{{ line.item.name }} <small class="sub">{{ lineKindText(line.item.kind) }}</small></span>
              <MoneyInput v-if="editPrices" :id="`no-price-${line.key}`" v-model="line.value" class="line-price" :label="t('web.newOrder.priceOf', { name: line.item.name })" :country="country()" />
              <span v-else-if="showsMoney" class="num">{{ line.value === null ? t('catalogNoPrice') : money(line.value) }}</span>
              <span v-else></span>
              <button type="button" class="icon-btn" :aria-label="t('web.newOrder.removeLine', { name: line.item.name })" @click="lines = lines.filter((l) => l !== line)"><Trash2 :size="15" aria-hidden="true" /></button>
            </li>
          </ul>
        </div>
        <div class="step">
          <label class="field-label" for="no-due">{{ t('web.newOrder.due') }}</label>
          <input id="no-due" v-model="due" class="field" type="datetime-local" />
        </div>
        <div class="step">
          <label class="field-label" for="no-request">{{ t('orderCustomerRequestTitle') }}</label>
          <textarea id="no-request" v-model="request" class="field" rows="2" maxlength="2000" :placeholder="t('orderCustomerRequestPlaceholder', { segment: session.company?.segment ?? 'other' })"></textarea>
        </div>
        <section v-if="repeat" class="step" aria-labelledby="no-repeat-title" data-testid="new-order-repeat">
          <h3 id="no-repeat-title" class="form-section">{{ t('orderRepeatRow') }}</h3>
          <RepeatFields v-model="repeatForm" id-prefix="no" :today="today" />
        </section>
        <details class="step more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('orderMoreOptions') }} <span class="sub">{{ moreSummary }}</span></summary>
          <div class="more-body">
            <div v-if="statuses.length > 1">
              <label class="field-label" for="no-status">{{ t('orderStatusLabel') }}</label>
              <select id="no-status" v-model="status" class="field">
                <option v-for="item in statuses" :key="item" :value="item">{{ statusText(item) }}</option>
              </select>
            </div>
            <div v-if="useScheduling">
              <label class="field-label" for="no-visit">{{ t('orderScheduleLabel') }}</label>
              <input id="no-visit" v-model="visit" class="field" type="datetime-local" />
            </div>
            <div v-if="team.length">
              <label class="field-label" for="no-assignee">{{ t('orderAddResponsible') }}</label>
              <select id="no-assignee" v-model="assignee" class="field">
                <option value="">{{ t('web.order.nobody') }}</option>
                <option v-for="member in team" :key="member.id" :value="member.id">{{ member.name }}</option>
              </select>
            </div>
          </div>
        </details>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">
          {{ !customer ? t('orderSaveNeedsCustomer') : showsMoney && lines.length ? `${t('total')} ${money(total)}` : '' }}
          <template v-if="showsMoney && unpriced"> · {{ t('orderUnpricedCount', { count: unpriced }) }}</template>
        </span>
        <button type="button" class="btn btn--primary" :aria-disabled="!customer || saving" data-testid="save-order" @click="save">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('web.newOrder.save', { order: orderShort() }) }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </div>
  </Layer>
</template>
