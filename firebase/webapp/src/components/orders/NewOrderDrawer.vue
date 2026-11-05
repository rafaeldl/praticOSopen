<script setup lang="ts">
// Nova OS by keyboard (WEB_APP_DESIGN, "menos de 45 segundos"): N opens with the
// cursor on Cliente; Enter picks; the device is suggested; each item enters with
// the catalog price; Ctrl+Enter saves from any field. Nothing is saved before
// that. Closing with something filled in asks first (also the browser's Voltar).
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, reactive, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { Check, Trash2, X } from '@lucide/vue'
import Combobox, { type ComboboxGroup, type ComboboxItem } from '@/components/Combobox.vue'
import Layer from '@/components/Layer.vue'
import RepeatFields, { type RepeatForm } from '@/components/contracts/RepeatFields.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import NewOrderAssist, { type AssistForm } from './NewOrderAssist.vue'
import NewOrderCustomFields from './NewOrderCustomFields.vue'
import { newOrderFields } from '@/lib/orders/new-order-fields'
import { requestField, withRequest } from '@/lib/orders/request'
import NewOrderPhotos from './NewOrderPhotos.vue'
import QuickCreate from './QuickCreate.vue'
import type { CustomerRow, DeviceRow } from '@/lib/customers/model'
import type { NewDevice } from '@/lib/orders/assist-draft'
import { fieldName, validateField, writeCustom } from '@/lib/segment-fields'
import { loadTexts, t } from '@/i18n'
import { logAiEvent } from '@/lib/analytics'
import { errorMessageKey } from '@/lib/api'
import { orderCreated } from '@/lib/orders/bus'
import { markOffer } from '@/lib/forms/offer'
import { canRegisterItem, sameName, forgetLists, loadCatalog, loadCustomers, loadDevices, loadTeam, search, type CatalogItem, type Customer, type Device, type Member } from '@/lib/orders/catalog'
import { createStatuses, type OrderStatus } from '@/lib/orders/model'
import { startContract } from '@/lib/contracts/data'
import { newContract } from '@/lib/contracts/model'
import { toIsoDay } from '@/lib/format'
import { deviceLabel, lineKindText, money, orderShort, statusText, country } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { askWhenOpened } from '@/lib/orders/maintenance-offer'
import { askNotificationsOnce } from '@/lib/push'
import { byName, devicesOfCustomer, mostUsedKeys, ownerOf, plateHits, plateOwnerName, recentCustomers, type Named } from '@/lib/orders/pickers'
import { api, can, session } from '@/lib/session'
import { formatPhone } from '@/lib/phone'
import { isMac } from '@/lib/shortcuts'
import { featureOn } from '@/lib/company-features'
import { segmentFieldService } from '@/lib/segments'
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

// The full forms behind "Mais dados" and the order's "+ WhatsApp" / "+ Placa" (order.quick.*), with the cadastros' texts.
const CustomerForm = defineAsyncComponent(() => Promise.all([import('@/components/customers/CustomerForm.vue'), loadTexts('customers')]).then(([m]) => m))
const DeviceForm = defineAsyncComponent(() => Promise.all([import('@/components/customers/DeviceForm.vue'), loadTexts('customers')]).then(([m]) => m))
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
/** The place of the order (order.new.more-options): only for companies that go to the customer, like the order's own Local. */
const address = ref('')
// Absent on the company: the segment's default, like the order's own Local (auth.gate.feature-defaults).
const fieldService = featureOn(session.company as Record<string, unknown> | null, 'fieldService', segmentFieldService())
// Photos before the ✓ (order.new.photos), the assistant's marks and what it heard (order.ai.*).
const photos = ref<File[]>([])
const marked = reactive(new Set<string>())
const newCustomer = ref<{ name: string; phone?: string } | null>(null)
const newDevice = ref<NewDevice | null>(null)
const aiActions = shallowRef<AssistForm['actions']>(null)
const assistForm = reactive({ customer, device, lines, request, due, photos, marked, newCustomer, newDevice, actions: aiActions }) as AssistForm
const startInAssistant = !!ui.newOrderSeed?.assist
// The segment's fields of the order (order.new.custom-fields), checked before the ✓.
const customFields = newOrderFields()
const customValues = reactive<Record<string, unknown>>({})
const customTried = ref(false)
const customInvalid = () => customFields.some((field) => !!validateField(field, customValues[fieldName(field)]))
const more = ref(false)
const saving = ref(false)
const failed = ref('')
const loading = ref(true)
const devicesLoading = ref(false)
let allowClose = false
/** "+ Cadastrar «X»" open as a block in place of its search (order.quick.*), and the full form behind "Mais dados". */
const quick = ref<{ kind: 'customer' | 'device' | 'item'; text: string } | null>(null)
const fullForm = ref<{ kind: 'customer'; draft: { name: string; phone: string } } | { kind: 'device'; draft: { name: string; serial: string } } | null>(null)

const showsMoney = can('viewPrices')
const editPrices = showsMoney && can('editPrices')
const statuses = createStatuses(session.role)
const useScheduling = (session.company as { useScheduling?: boolean } | null)?.useScheduling !== false
// "Novo contrato" from Contratos: the order is created and then gets its contract (order.new.repeat).
const repeat = !!ui.newOrderSeed?.repeat
const today = toIsoDay(new Date())
const repeatForm = ref<RepeatForm>({ repeat: { frequency: 'monthly', interval: 1 }, startDay: today, endDay: null, autoGenerate: true })
const title = computed(() => (repeat ? t('contractNew') : t('orderNewTitle', { order: orderShort() })))
const dirty = computed(() => !!(customer.value || device.value || lines.value.length || request.value.trim() || due.value || visit.value || address.value.trim() || photos.value.length || Object.values(customValues).some((v) => v !== null && v !== undefined && v !== '')))
const total = computed(() => lines.value.reduce((sum, line) => sum + (line.value ?? 0) * line.quantity, 0))
const unpriced = computed(() => lines.value.filter((line) => line.value === null).length)
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'
const moreSummary = computed(() => {
  const parts: string[] = []
  if (status.value !== 'quote') parts.push(statusText(status.value))
  if (visit.value) parts.push(t('orderScheduleLabel'))
  const person = team.value.find((member) => member.id === assignee.value)
  if (person) parts.push(person.name)
  if (address.value.trim()) parts.push(address.value.trim())
  if (repeat) parts.push(t('orderRepeatRow'))
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
    // A maintenance's "Abrir OS": the services of the last finished order, with the value it had.
    for (const seeded of seed?.items ?? []) {
      const item = k.find((entry) => entry.kind === 'service' && entry.id === seeded.id)
      if (item) lines.value = [...lines.value, { key: crypto.randomUUID(), item, value: showsMoney ? (seeded.value ?? item.value) : item.value, quantity: 1 }]
    }
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
const devicesOf = (customerId: string) => devicesOfCustomer(customerId, showsMoney)

const NEW = '__new'
/** Item outside the catalog: the API accepts a line without catalogId with #516 (writes.API_516). */
const FREE_ITEMS = writes.API_516
/** One per Nova OS opened: a "Salvar" again after a network failure never creates a second order (API_516). */
const clientOrderId = crypto.randomUUID()

const PLATE = 'plate:'
const customerRow = (c: Customer) => ({ id: c.id, label: c.name, sub: formatPhone(c.phone) || undefined })
const customerGroups = (query: string): ComboboxGroup[] => [
  // A plate brings the device and its owner together (customer.picker.plate).
  { title: t('web.newOrder.byPlate'), items: plateHits(devices.value, query).map((d) => ({ id: `${PLATE}${d.id}`, label: `${d.serial} · ${d.name}`, sub: plateOwnerName(d.id) })) },
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
  // Hidden when a customer already has that name (accents and case ignored): pick that one (customer.picker.create).
  { items: query.trim() && !loading.value && can('manageCustomers') && !sameName(customers.value, query) ? [{ id: NEW, label: t('web.newOrder.register', { name: query.trim() }) }] : [] },
]

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
  if (item.id === NEW) {
    quick.value = { kind: 'customer', text: query }
    return
  }
  await chooseCustomer(customers.value.find((c) => c.id === item.id) ?? recents.value.find((c) => c.id === item.id) ?? null)
}

async function chooseCustomer(chosen: Customer | null) {
  quick.value = null
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
  const others = search(byName(devices.value.filter((d) => !own.some((o) => o.id === d.id))), query, (d) => d.serial ?? '', query || !own.length ? 6 : 0)
  const row = (d: Device) => ({ id: d.id, label: d.name, sub: d.serial ?? undefined })
  return [
    { title: own.length ? t('web.newOrder.fromCustomer') : undefined, items: own.map(row) },
    { title: others.length && own.length ? t('web.newOrder.otherDevices', { device: deviceLabel().toLocaleLowerCase() }) : undefined, items: others.map(row) },
    { items: query.trim() && !loading.value && can('manageDevices') ? [{ id: NEW, label: t('web.newOrder.register', { name: query.trim() }) }] : [] },
  ]
}
async function pickDevice(item: ComboboxItem, query = '') {
  // A new one asks model and plate/serial right here (order.quick.device).
  if (item.id === NEW) {
    quick.value = { kind: 'device', text: query }
    return
  }
  await chooseDevice(devices.value.find((d) => d.id === item.id) ?? customerDevices.value.find((d) => d.id === item.id) ?? null)
}
async function chooseDevice(chosen: Device | null) {
  quick.value = null
  device.value = chosen
  await nextTick()
  itemRef.value?.focus()
}

/** The block registered it: the record is chosen and the order goes on. */
async function onQuickSaved(record: Customer | Device | CatalogItem) {
  const kind = quick.value?.kind
  if (kind === 'customer') {
    customers.value = [...customers.value, record as Customer]
    announce(t('web.newOrder.registered', { name: record.name }))
    await chooseCustomer(record as Customer)
  } else if (kind === 'device') {
    devices.value = [...devices.value, record as Device]
    announce(t('web.newOrder.registered', { name: record.name }))
    await chooseDevice(record as Device)
  } else if (kind === 'item') {
    const created = record as CatalogItem
    quick.value = null
    catalog.value = [...catalog.value, created]
    lines.value = [...lines.value, { key: crypto.randomUUID(), item: created, value: created.value, quantity: 1 }]
    announce(t('web.newOrder.itemRegistered', { name: created.name }))
    await nextTick()
    itemRef.value?.focus()
  }
}
async function onQuickCancel() {
  const kind = quick.value?.kind
  quick.value = null
  await nextTick()
  ;(kind === 'customer' ? customerRef : kind === 'device' ? deviceRef : itemRef).value?.focus()
}
function onQuickMore(draft: { name: string; phone?: string; serial?: string }) {
  if (quick.value?.kind === 'customer') fullForm.value = { kind: 'customer', draft: { name: draft.name, phone: draft.phone ?? '' } }
  else if (quick.value?.kind === 'device') fullForm.value = { kind: 'device', draft: { name: draft.name, serial: draft.serial ?? '' } }
}
/** Saved in the full form: read the lists again and choose it. */
async function onFullSaved(id: string) {
  const kind = fullForm.value?.kind
  fullForm.value = null
  forgetLists()
  if (kind === 'customer') {
    customers.value = await loadCustomers()
    await chooseCustomer(customers.value.find((c) => c.id === id) ?? null)
  } else {
    devices.value = await loadDevices()
    await chooseDevice(devices.value.find((d) => d.id === id) ?? null)
  }
}
/** The full form's "Já cadastrado › Abrir": that customer is chosen. */
function openExisting(id: string) {
  fullForm.value = null
  void chooseCustomer(customers.value.find((c) => c.id === id) ?? null)
}
const directory = computed(() => customers.value.map((c) => ({ id: c.id, name: c.name, phone: c.phone ?? null, email: null, taxId: null, address: null, open: 0, late: 0, owed: null }) as CustomerRow))
const deviceRows = computed(() => devices.value.map((d) => ({ id: d.id, name: d.name, serial: d.serial ?? null, manufacturer: null, category: null, status: null, photo: null, nextMaintenanceDate: null }) as DeviceRow))

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
  {
    items: [
      ...(FREE_ITEMS && query.trim() && !loading.value ? [{ id: NEW, label: t('web.newOrder.useFree', { name: query.trim() }) }] : []),
      ...(query.trim() && !loading.value && canRegisterItem(catalog.value, query) ? [{ id: REGISTER_ITEM, label: t('web.newOrder.registerItem', { name: query.trim() }) }] : []),
    ],
  },
]
const REGISTER_ITEM = '__register'
async function pickItem(picked: ComboboxItem, query = '') {
  // Kind and price asked right here (order.quick.item).
  if (picked.id === REGISTER_ITEM && query.trim()) {
    quick.value = { kind: 'item', text: query }
    return
  }
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
  // A register half done is never thrown away in silence: finish or cancel it first.
  if (quick.value) {
    failed.value = t('web.quick.finishFirst')
    return
  }
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
  // The segment's fields are checked before anything is saved (the app never checks them).
  if (customInvalid()) {
    customTried.value = true
    failed.value = t('web.newOrder.fixFields')
    return
  }
  saving.value = true
  failed.value = ''
  try {
    // Heard by the assistant and not in the register: registered only now, at the ✓ (AssistantRegistration).
    if (newCustomer.value && !customer.value.id) {
      const created = await api<{ id: string; name: string }>('/v1/app/customers', { method: 'POST', body: { name: newCustomer.value.name, ...(newCustomer.value.phone ? { phone: newCustomer.value.phone } : {}) } })
      customer.value = { ...customer.value, id: created.id }
      newCustomer.value = null
      forgetLists()
    }
    if (newDevice.value && device.value && !device.value.id) {
      const nd = newDevice.value
      const created = await api<{ id: string; name: string }>('/v1/app/devices', { method: 'POST', body: { name: nd.name, ...(nd.serial ? { serial: nd.serial } : {}), ...(nd.manufacturer ? { manufacturer: nd.manufacturer } : {}) } })
      device.value = { ...device.value, id: created.id }
      newDevice.value = null
      forgetLists()
    }
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
    // The app's ai_order_saved: a new order saved with something the assistant filled (still marked ✦).
    if (marked.size) logAiEvent('ai_order_saved')
    // The rest after the id: a failure here says what did not stay, the order is already saved.
    const after: Promise<unknown>[] = []
    // Items outside the catalog, one after the other so they keep their order.
    const free = lines.value.filter((l) => l.free)
    if (free.length) {
      after.push(free.reduce<Promise<unknown>>((chain, line) => chain.then(() => writes.addItem(created.id, { kind: 'service', description: line.item.name, ...own(line) })), Promise.resolve()))
    }
    if (assignee.value) after.push(writes.patchOrder(created.id, { assignedTo: assignee.value }))
    // Photos go up once the order has its id, one after the other; a failure is counted, never swallowed.
    if (photos.value.length) after.push(photos.value.reduce<Promise<unknown>>((chain, file) => chain.then(() => writes.uploadPhoto(created.id, file)), Promise.resolve()))
    // What the customer asked goes into the segment's field, as the app (order.new.request);
    // a segment without it keeps it as the first internal comment, also as the app.
    const asked = request.value.trim()
    const askedField = asked ? requestField() : undefined
    const fieldsData = customFields.length ? writeCustom(null, customFields, customValues) : null
    const customData = askedField ? withRequest(fieldsData, askedField, asked) : fieldsData
    if (customData) after.push(writes.updateOrderFields(created.id, { customData }))
    // The place: typed in "Mais opções", else the customer's address with its coordinates (order.customer.address-from-customer).
    const place = address.value.trim()
    if (place) after.push(writes.updateOrderFields(created.id, { address: place }))
    else if (customer.value.address) after.push(writes.updateOrderFields(created.id, { address: customer.value.address, latitude: customer.value.latitude ?? null, longitude: customer.value.longitude ?? null }))
    if (asked && !askedField) after.push(writes.addComment(created.id, asked, true))
    if (repeat) after.push(startContract(created.id, newContract(repeatForm.value, today)))
    const results = await Promise.allSettled(after)
    allowClose = true
    // Money said to the assistant: the "Confere?" card opens on the saved order (order.ai.money-card).
    if (aiActions.value) ui.aiActionsFor = { orderId: created.id, ...aiActions.value }
    orderCreated(created.id)
    // With a device and not saved done: the order asks for the check-in checklist (order.offer.checklist).
    if (device.value && status.value !== 'done') markOffer(created.id)
    // Saved already done with a device: the order asks for the next maintenance (device.maintenance.offer).
    if (device.value && status.value === 'done') askWhenOpened(created.id)
    // Then the browser's notifications, the first time (order.offer.notifications). One question at a
    // time: when the order will ask for a checklist or a maintenance, this waits for the next order.
    if (!device.value) askNotificationsOnce()
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
        <NewOrderAssist
          :form="assistForm"
          :catalog="catalog"
          :autofocus="startInAssistant"
          @other-customer="customer = null; $nextTick(() => customerRef?.focus())"
          @other-device="device = null; $nextTick(() => deviceRef?.focus())"
        />
        <div class="step">
          <div v-if="customer" class="chosen">
            <span><span class="field-label">{{ t('customer') }}</span><span v-if="marked.has('customer')" class="ai" :title="t('orderAssistantMarked')">✦ </span><strong>{{ customer.name }}</strong>
              <small v-if="newCustomer" class="sub"> · {{ [formatPhone(customer.phone), t('orderAssistantNewCustomer')].filter(Boolean).join(' · ') }}</small></span>
            <button type="button" class="link" @click="customer = null; device = null; newCustomer = null; newDevice = null; marked.delete('customer'); $nextTick(() => customerRef?.focus())">{{ t('web.newOrder.change') }}</button>
          </div>
          <QuickCreate v-else-if="quick?.kind === 'customer'" id="no-quick-customer" kind="customer" :text="quick.text" :customers="customers" @saved="onQuickSaved" @use="chooseCustomer" @more="onQuickMore" @cancel="onQuickCancel" />
          <Combobox v-else id="no-customer" ref="customerRef" :label="t('customer')" :placeholder="t('web.newOrder.customerHint')" :groups="customerGroups" :loading="loading" :autofocus="!startInAssistant" @pick="pickCustomer" />
        </div>
        <div v-if="customer" class="step">
          <div v-if="device" class="chosen">
            <span><span class="field-label">{{ deviceLabel() }}</span><span v-if="marked.has('device')" class="ai" :title="t('orderAssistantMarked')">✦ </span>{{ device.name }} <span v-if="device.serial" class="num">{{ device.serial }}</span>
              <small v-if="newDevice" class="sub"> · {{ t('orderAssistantNewDevice') }}</small></span>
            <button type="button" class="link" @click="device = null; newDevice = null; marked.delete('device'); $nextTick(() => deviceRef?.focus())">{{ t('web.newOrder.change') }}</button>
          </div>
          <QuickCreate v-else-if="quick?.kind === 'device'" id="no-quick-device" kind="device" :text="quick.text" @saved="onQuickSaved" @more="onQuickMore" @cancel="onQuickCancel" />
          <Combobox v-else id="no-device" ref="deviceRef" :label="t('web.newOrder.deviceOptional', { device: deviceLabel() })" :groups="deviceGroups" :loading="devicesLoading" :preselect="devicesLoading || customerDevices.length > 0" skippable @pick="pickDevice" @next="itemRef?.focus()" />
        </div>
        <div class="step">
          <QuickCreate v-if="quick?.kind === 'item'" id="no-quick-item" kind="item" :text="quick.text" @saved="onQuickSaved" @cancel="onQuickCancel" />
          <Combobox v-else id="no-item" ref="itemRef" :label="t('pickerItemTitle')" :placeholder="t('orderItemSearchPlaceholder')" :groups="itemGroups" :loading="loading" @pick="pickItem" />
          <ul v-if="lines.length" class="drawer-items" :aria-label="t('orderItemsSection')">
            <li v-for="line in lines" :key="line.key">
              <span><span v-if="marked.has(line.key)" class="ai" :title="t('orderAssistantMarked')">✦ </span>{{ line.item.name }} <small class="sub">{{ lineKindText(line.item.kind) }}</small></span>
              <MoneyInput v-if="editPrices" :id="`no-price-${line.key}`" v-model="line.value" class="line-price" :label="t('web.newOrder.priceOf', { name: line.item.name })" :country="country()" />
              <span v-else-if="showsMoney" class="num">{{ line.value === null ? t('catalogNoPrice') : money(line.value) }}</span>
              <span v-else></span>
              <button type="button" class="icon-btn" :aria-label="t('web.newOrder.removeLine', { name: line.item.name })" @click="lines = lines.filter((l) => l !== line)"><Trash2 :size="15" aria-hidden="true" /></button>
            </li>
          </ul>
        </div>
        <div class="step">
          <label class="field-label" for="no-due"><span v-if="marked.has('due')" class="ai" :title="t('orderAssistantMarked')">✦ </span>{{ t('web.newOrder.due') }}</label>
          <input id="no-due" v-model="due" class="field" type="datetime-local" :data-empty="!due || undefined" />
        </div>
        <div class="step">
          <label class="field-label" for="no-request"><span v-if="marked.has('request')" class="ai" :title="t('orderAssistantMarked')">✦ </span>{{ t('orderCustomerRequestTitle') }}</label>
          <textarea id="no-request" v-model="request" class="field" rows="2" maxlength="2000" :placeholder="t('orderCustomerRequestPlaceholder', { segment: session.company?.segment ?? 'other' })"></textarea>
        </div>
        <NewOrderPhotos v-if="can('attachPhotos')" v-model="photos" />
        <NewOrderCustomFields v-if="customFields.length" :values="customValues" :tried="customTried" />
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
              <input id="no-visit" v-model="visit" class="field" type="datetime-local" :data-empty="!visit || undefined" />
            </div>
            <div v-if="fieldService">
              <label class="field-label" for="no-address">{{ t('orderAddressLabel') }}</label>
              <input id="no-address" v-model="address" class="field" type="text" maxlength="500" :placeholder="customer?.address ?? ''" />
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
  <CustomerForm v-if="fullForm?.kind === 'customer'" :draft="fullForm.draft" :directory="directory" @saved="onFullSaved" @open="openExisting" @close="fullForm = null" />
  <DeviceForm v-else-if="fullForm?.kind === 'device'" :draft="fullForm.draft" :devices="deviceRows" @saved="onFullSaved" @close="fullForm = null" />
</template>
