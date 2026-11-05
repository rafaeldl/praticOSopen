<script setup lang="ts">
// The open device (device.detail.*): what it is, whose it is (customer of the
// newest order), the next maintenance, its data and orders. Consultant and
// technician open it too, with the orders they read: in the app the whole
// screen is an error for them (defect 1). Edit and delete only for who may
// (the app shows them to everyone, defect 12).
import { computed, onMounted, ref, shallowRef } from 'vue'
import { MoreHorizontal, X } from '@lucide/vue'
import DateField from '@/components/DateField.vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import OrderStatus from './OrderStatus.vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { locale, t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { deleteDevice, loadDevice, setNextMaintenance, type DeviceDetail } from '@/lib/customers/data'
import { addMonths, type DeviceRow, type DeviceStatus } from '@/lib/customers/model'
import { formatDate, formatDateLong, formatNumber, fromIsoDay, toIsoDay } from '@/lib/format'
import { canCreateOrders } from '@/lib/orders/model'
import { money, orderShort } from '@/lib/orders/text'
import { fieldTitle, groupBySection, namespaceFields, readCustom, type FormField } from '@/lib/segment-fields'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import { deviceReading, formatReading, readingFieldOf } from '@/lib/device-reading'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import DeviceForm from './DeviceForm.vue'
import { loadOrderTexts } from '@/i18n'
import { loadContracts, type ContractOrder } from '@/lib/contracts/data'
import { dayText, repeatText } from '@/lib/contracts/text'
import { resetDeclines } from '@/lib/orders/maintenance-offer'

const props = defineProps<{ deviceId: string; devices: DeviceRow[] }>()
const emit = defineEmits<{ close: []; changed: []; removed: [] }>()

const state = ref<'loading' | 'ready' | 'failed' | 'notFound'>('loading')
const detail = shallowRef<DeviceDetail | null>(null)
const dialog = ref<null | 'menu' | 'delete' | 'edit' | 'maintenance' | 'removeMaintenance'>(null)
const menuButton = ref<HTMLElement | null>(null)
const busy = ref(false)
const day = ref<string | null>(null)
const failed = ref('')

const country = computed(() => session.company?.country)
const management = (session.company as { useDeviceManagement?: boolean } | null)?.useDeviceManagement === true
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const device = computed(() => detail.value?.device ?? null)
const canManage = can('manageDevices')
const canCreate = canCreateOrders(session.role, can('createOrder'))
const title = computed(() => device.value?.name || label('device._entity'))
const today = toIsoDay(new Date())
/** Owner: the customer of the newest order (device.detail.owner). */
const owner = computed(() => detail.value?.owner ?? null)
const maintenance = computed(() => device.value?.nextMaintenanceDate ?? null)
const lateMaintenance = computed(() => !!maintenance.value && maintenance.value < today)
const menuChoices = computed<Choice[]>(() =>
  canManage ? [{ id: 'edit', label: t('edit') }, { id: 'delete', label: t('deleteAction'), danger: true }] : [],
)
const statusText = computed(() => {
  const status = device.value?.status as DeviceStatus | null
  if (!management || !status) return ''
  return { active: t('deviceStatusActive'), maintenance: t('deviceStatusMaintenance'), inactive: t('deviceStatusInactive'), decommissioned: t('deviceStatusDecommissioned') }[status] ?? ''
})
const deviceFields = computed(() => namespaceFields('device', ['device.category', 'device.brand', 'device.model', 'device.serial']))
// The last reading (98.000 km) next to the serial, and the one of each order in the history (docs/DEVICE_READING.md).
const reading = computed(() => readingFieldOf(deviceFields.value))
const readingText = computed(() => (reading.value ? formatReading(reading.value, deviceReading(device.value?.customData, reading.value), country.value) : ''))
const orderReading = (order: { deviceReadings?: Record<string, number> }) =>
  reading.value && device.value ? formatReading(reading.value, order.deviceReadings?.[device.value.id], country.value) : ''
const customFields = computed(() => {
  const data = device.value?.customData
  const fields = deviceFields.value.filter((field) => field.key !== reading.value?.key)
  return groupBySection(fields, locale.value, t('web.customers.general'))
    .map((group) => ({ title: group.title, fields: group.fields.map((field) => ({ field, text: customText(field, readCustom(data, field)) })).filter((item) => item.text) }))
    .filter((group) => group.fields.length)
})

/** Numbers grouped on reading (98.000), except a year; the saved value does not change. */
function customText(field: FormField, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  if (field.type === 'date' && typeof value === 'string') return formatDate(fromIsoDay(value.slice(0, 10)), country.value)
  if (field.type === 'number' && typeof value === 'number') return /year|ano/i.test(field.key) ? String(value) : formatNumber(value, country.value)
  return String(value)
}

/**
 * Active contracts with this device (device.detail.contracts): "OS 12 · Todo mês"
 * and the next one, each opening its order. An active contract sets the next
 * maintenance (device.detail.maintenance-contract): no other date is asked.
 * A failure only hides the section.
 */
const contracts = shallowRef<ContractOrder[]>([])
async function loadDeviceContracts() {
  try {
    const [list] = await Promise.all([loadContracts(), loadOrderTexts()])
    contracts.value = list.filter((order) => order.contract?.active && order.devices.some((item) => item.id === props.deviceId))
  } catch {
    contracts.value = []
  }
}
const contractDue = computed(() => contracts.value.map((order) => order.contract?.nextDueDate).filter((day): day is string => !!day).sort()[0] ?? null)

async function load() {
  state.value = 'loading'
  void loadDeviceContracts()
  try {
    detail.value = await loadDevice(props.deviceId)
    state.value = 'ready'
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) state.value = 'notFound'
    else {
      console.error('device: not loaded', error)
      state.value = 'failed'
    }
  }
}

function newOrder() {
  if (!device.value) return
  ui.newOrderSeed = {
    ...(owner.value ? { customer: { id: owner.value.id, name: owner.value.name } } : {}),
    device: { id: device.value.id, name: device.value.name ?? label('device._entity'), serial: device.value.serial },
  }
  ui.newOrder = true
}

function openMaintenance() {
  failed.value = ''
  day.value = maintenance.value && maintenance.value >= today ? maintenance.value : toIsoDay(addMonths(new Date(), 6))
  dialog.value = 'maintenance'
}

async function saveMaintenance(next: string | null) {
  if (!device.value || busy.value) return
  if (next !== null && (!next || next < today)) {
    failed.value = t('web.devices.futureDate')
    return
  }
  busy.value = true
  try {
    await setNextMaintenance(device.value.id, next)
    // A date set here resets the refusals of the question after done (device.maintenance.limit).
    if (next) resetDeclines()
    dialog.value = null
    const message = next ? t('nextMaintenanceOn', { date: formatDateLong(fromIsoDay(next), country.value) }) : t('web.devices.maintenanceRemoved')
    showToast(message)
    announce(message)
    await load()
    emit('changed')
  } catch (error) {
    failed.value = `${t('nextMaintenanceSaveError')}. ${t(errorMessageKey(error))}`
    if (dialog.value !== 'maintenance') showToast(failed.value)
  } finally {
    busy.value = false
  }
}

async function remove() {
  if (!device.value || busy.value) return
  busy.value = true
  try {
    await deleteDevice(device.value.id)
    showToast(t('web.customers.deleted', { name: title.value }))
    emit('removed')
  } catch (error) {
    dialog.value = null
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

async function onChangedElsewhere() {
  dialog.value = null
  showToast(t('web.devices.changedElsewhere', { device: label('device._entity').toLocaleLowerCase() }))
  await load()
  emit('changed')
}

async function onEdited(_id: string, notice?: string) {
  dialog.value = null
  showToast(notice ?? t('web.customers.saved'))
  await load()
  emit('changed')
}

function onMenu(id: string) {
  dialog.value = id === 'edit' ? 'edit' : id === 'delete' ? 'delete' : null
}

onMounted(load)
</script>

<template>
  <section class="od" :aria-label="title" data-testid="device-detail">
    <div class="od-top">
      <span class="num">{{ label('device._entity') }}</span>
      <span class="spacer"></span>
      <button v-if="device && menuChoices.length" ref="menuButton" type="button" class="icon-btn" :aria-label="t('deviceActions')" data-testid="device-menu" @click="dialog = 'menu'">
        <MoreHorizontal :size="18" aria-hidden="true" />
      </button>
      <button type="button" class="icon-btn" :aria-label="t('close')" @click="emit('close')"><X :size="18" aria-hidden="true" /></button>
    </div>

    <LoadingState v-if="state === 'loading'" />
    <div v-else-if="state === 'notFound'" class="empty" role="alert" data-testid="device-not-found">
      <h2>{{ t('web.devices.notFound', { device: label('device._entity') }) }}</h2>
      <p>{{ t('web.customers.notFoundBody') }}</p>
      <button type="button" class="btn" @click="emit('close')">{{ t('back') }}</button>
    </div>
    <ErrorState v-else-if="state === 'failed'" :retry="load" />

    <div v-else-if="device && detail" class="od-scroll" tabindex="-1" data-od-focus>
      <header class="od-head">
        <img v-if="device.photo" class="dev-thumb" :src="device.photo" width="72" height="72" alt="" data-testid="device-detail-photo" />
        <h2 class="od-h"><span class="od-name">{{ title }}</span></h2>
        <p class="od-device-line" data-testid="device-owner">
          <template v-if="device.serial"><span class="num">{{ device.serial }}</span></template>
          <template v-if="readingText">{{ device.serial ? ' · ' : '' }}<span class="num" data-testid="device-reading">{{ readingText }}</span></template>
          <template v-if="owner">
            {{ device.serial || readingText ? ' · ' : '' }}{{ t('web.devices.of') }}
            <RouterLink class="link" :to="{ path: '/customers', query: { customer: owner.id } }">{{ owner.name }}</RouterLink>
          </template>
        </p>
        <span v-if="statusText" class="status"><span class="dot" :class="device.status === 'active' ? 'dot--success' : device.status === 'maintenance' ? 'dot--warning' : 'dot--neutral'" aria-hidden="true"></span>{{ statusText }}</span>
        <p v-if="detail.partial" class="sub">{{ t('web.customers.partial') }}</p>
        <p v-if="canCreate" class="od-ask">{{ t('askOrderForDevice', { device: label('device._entity').toLocaleLowerCase() }) }}</p>
        <div class="od-actions">
          <button v-if="canCreate" type="button" class="btn btn--primary" data-testid="device-new-order" @click="newOrder">{{ t('newOrderButton') }}</button>
        </div>
      </header>

      <section v-if="contracts.length" class="od-sec" aria-labelledby="dd-contracts-title" data-testid="device-contracts">
        <h3 id="dd-contracts-title">{{ t('web.devices.contracts') }}</h3>
        <ul class="dir-orders">
          <li v-for="order in contracts" :key="order.id" class="dir-order">
            <RouterLink class="row-btn" :to="{ path: '/', query: { order: order.id } }">
              <span class="num">{{ orderShort() }} {{ order.number }}</span> · {{ order.contract ? repeatText(order.contract) : '' }}
            </RouterLink>
            <span v-if="order.contract?.nextDueDate" class="sub">{{ t('web.devices.contractNext', { date: dayText(order.contract.nextDueDate) }) }}</span>
          </li>
        </ul>
      </section>

      <section v-if="contractDue" class="od-sec" :aria-label="t('nextMaintenanceSet')" data-testid="device-maintenance">
        <h3>{{ t('web.devices.maintenance') }}</h3>
        <p class="od-sentence">{{ t('web.devices.contractNext', { date: dayText(contractDue) }) }}</p>
        <p class="sub">{{ t('nextMaintenanceByContract') }}</p>
      </section>
      <section v-else-if="maintenance || canManage" class="od-sec" :aria-label="t('nextMaintenanceSet')" data-testid="device-maintenance">
        <h3>{{ t('web.devices.maintenance') }}</h3>
        <template v-if="maintenance">
          <p :class="{ 'od-sentence--late': lateMaintenance }" class="od-sentence">
            {{ t('nextMaintenanceOn', { date: formatDateLong(fromIsoDay(maintenance), country) }) }}
          </p>
          <p v-if="device.nextMaintenanceLastService" class="sub">{{ t('maintenanceLastService', { service: device.nextMaintenanceLastService }) }}</p>
          <div v-if="canManage" class="row-actions">
            <button type="button" class="btn" data-testid="maintenance-change" @click="openMaintenance">{{ t('web.devices.changeMaintenance') }}</button>
            <button type="button" class="btn btn--ghost" data-testid="maintenance-remove" @click="dialog = 'removeMaintenance'">{{ t('nextMaintenanceRemove') }}</button>
          </div>
        </template>
        <button v-else type="button" class="btn" data-testid="maintenance-set" @click="openMaintenance">{{ t('nextMaintenanceSet') }}</button>
      </section>

      <section class="od-sec" :aria-label="t('deviceDetailsLabel')">
        <h3>{{ t('deviceDetailsLabel') }}</h3>
        <dl class="kv" data-testid="device-data">
          <template v-if="device.manufacturer"><dt>{{ label('device.brand') }}</dt><dd>{{ device.manufacturer }}</dd></template>
          <template v-if="device.category"><dt>{{ t('deviceCategory') }}</dt><dd>{{ device.category }}</dd></template>
          <template v-if="device.description"><dt>{{ label('device.description') }}</dt><dd>{{ device.description }}</dd></template>
        </dl>
        <p v-if="!device.manufacturer && !device.category && !device.description && !customFields.length" class="muted">{{ t('web.devices.noData') }}</p>
        <template v-for="group in customFields" :key="group.title">
          <h4 class="od-group">{{ group.title }}</h4>
          <dl class="kv" data-testid="device-custom">
            <template v-for="item in group.fields" :key="item.field.key"><dt>{{ fieldTitle(item.field, locale) }}</dt><dd>{{ item.text }}</dd></template>
          </dl>
        </template>
      </section>

      <section class="od-sec" :aria-label="t('web.customers.orders')">
        <h3>{{ t('web.customers.orders') }}</h3>
        <ul v-if="detail.orders.length" class="dir-list" data-testid="device-orders">
          <li v-for="order in detail.orders" :key="order.id" class="dir-order">
            <RouterLink class="row-btn" :to="{ path: '/', query: { order: order.id } }"><span class="num">{{ orderShort() }} {{ order.number }}</span></RouterLink>
            <OrderStatus :status="order.status" />
            <span v-if="order.total !== undefined" class="num dir-money">{{ money(order.total) }}</span>
            <span class="sub">{{ order.customer?.name }}<template v-if="order.createdAt"> · {{ formatDate(order.createdAt, country) }}</template><template v-if="orderReading(order)"> · <span class="num" data-testid="order-reading">{{ orderReading(order) }}</span></template></span>
          </li>
        </ul>
        <p v-else class="muted">{{ t('web.customers.noOrders') }}</p>
      </section>
    </div>

    <ChoiceDialog v-if="dialog === 'menu' && device" :anchor="menuButton" :title="title" :choices="menuChoices" @pick="onMenu" @close="dialog = null" />
    <ConfirmDialog
      v-else-if="dialog === 'delete' && device"
      :title="t('deleteDeviceTitle', { name: title })"
      :body="t('deleteDeviceKeepsOrders')"
      :confirm="t('deleteAction')"
      :keep="t('cancel')"
      danger
      @confirm="remove"
      @close="dialog = null"
    />
    <ConfirmDialog
      v-else-if="dialog === 'removeMaintenance'"
      :title="t('web.devices.removeMaintenanceTitle')"
      :confirm="t('nextMaintenanceRemove')"
      :keep="t('cancel')"
      danger
      @confirm="saveMaintenance(null)"
      @close="dialog = null"
    />
    <DeviceForm v-else-if="dialog === 'edit' && device" :device="device" :version="detail?.version" :devices="devices" @saved="onEdited" @changed="onChangedElsewhere" @close="dialog = null" />
    <Layer v-else-if="dialog === 'maintenance'" kind="dialog" :label="t('nextMaintenanceQuestion')" @close="dialog = null">
      <template #default="{ close }">
        <form class="layer-form" @submit.prevent="saveMaintenance(day)">
          <div class="layer-head"><h2 class="layer-title">{{ t('nextMaintenanceQuestion') }}</h2></div>
          <div class="layer-body">
            <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
            <DateField id="dm-day" v-model="day" :label="t('web.devices.maintenanceDay')" :country="country" :min="today" required />
          </div>
          <div class="layer-foot">
            <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
            <button type="submit" class="btn btn--primary" :aria-disabled="busy" data-testid="maintenance-save">{{ t('save') }}</button>
          </div>
        </form>
      </template>
    </Layer>
  </section>
</template>
