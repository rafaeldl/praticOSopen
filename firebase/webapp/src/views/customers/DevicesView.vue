<script setup lang="ts">
// The company's devices ("Veículos", "Aparelhos"): model, serial, brand and,
// with useDeviceManagement, the status (device.list.*). Search by model, brand
// or serial (without hyphen or space). Edit and delete are buttons, only for
// who may (the app opens the form to everyone, defects 12 and 17).
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import DeviceDetail from '@/components/customers/DeviceDetail.vue'
import DeviceForm from '@/components/customers/DeviceForm.vue'
import DirectoryTabs from '@/components/customers/DirectoryTabs.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { registerSearcher } from '@/lib/commands'
import { deleteDevice, loadDevice, loadDeviceDirectory, type DeviceDetail as Detail } from '@/lib/customers/data'
import { byName, deviceMatches, isBrazilianPlate, type DeviceRow, type DeviceStatus } from '@/lib/customers/model'
import { formatDate } from '@/lib/format'
import { useRoutePanel } from '@/lib/route-layer'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import '@/styles/customers.css'

const PAGE = 200
const route = useRoute()
const router = useRouter()
const panel = useRoutePanel('device')
const rows = shallowRef<DeviceRow[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const search = ref(typeof route.query.q === 'string' ? route.query.q : '')
const shown = ref(PAGE)
const searchEl = ref<HTMLInputElement | null>(null)
const form = ref<{ device: Detail['device'] | null; version?: string | null; draft?: { name: string; serial: string } } | null>(null)
const removing = ref<DeviceRow | null>(null)

const canManage = can('manageDevices')
const management = computed(() => (session.company as { useDeviceManagement?: boolean } | null)?.useDeviceManagement === true)
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const deviceWord = computed(() => label('device._entity'))
const country = computed(() => session.company?.country)
const query = computed(() => search.value.trim())
const visible = computed(() => (query.value ? rows.value.filter((row) => deviceMatches(row, query.value)) : rows.value))
const panelOpen = computed(() => !!panel.value.value)
const STATUS_DOT: Record<DeviceStatus, string> = { active: 'success', maintenance: 'warning', inactive: 'neutral', decommissioned: 'hollow' }
const statusText = (status: DeviceStatus) =>
  ({ active: t('deviceStatusActive'), maintenance: t('deviceStatusMaintenance'), inactive: t('deviceStatusInactive'), decommissioned: t('deviceStatusDecommissioned') })[status]

async function load(fresh = false) {
  state.value = 'loading'
  try {
    rows.value = [...(await loadDeviceDirectory(fresh)).rows].sort(byName)
    state.value = 'ready'
    announce(t('web.devices.count', { count: rows.value.length, devices: label('device._entity_plural').toLocaleLowerCase() }))
  } catch (error) {
    console.error('devices: list failed', error)
    state.value = 'failed'
  }
}

const open = (id: string) => void panel.open(id)

function startCreate(fromSearch = false) {
  const text = fromSearch ? query.value : ''
  // A Brazilian plate becomes the serial; anything else the model (device.list.pick-create).
  form.value = { device: null, draft: isBrazilianPlate(text) ? { name: '', serial: text.toUpperCase() } : { name: text, serial: '' } }
}

async function startEdit(row: DeviceRow) {
  try {
    const detail = await loadDevice(row.id)
    form.value = { device: detail.device, version: detail.version }
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}

async function onSaved(id: string, notice?: string) {
  const isNew = !form.value?.device
  if (isNew) await router.replace({ path: '/devices', query: { device: id } })
  form.value = null
  showToast(notice ?? t('web.customers.saved'))
  await load(true)
}

async function remove() {
  const row = removing.value
  if (!row) return
  try {
    // Waits for the server: the row only leaves when it is gone (the app removes it first, defect 11).
    await deleteDevice(row.id)
    removing.value = null
    showToast(t('web.customers.deleted', { name: row.name || row.serial || deviceWord.value }))
    if (panel.value.value === row.id) panel.close()
    await load(true)
  } catch (error) {
    removing.value = null
    showToast(t(errorMessageKey(error)))
  }
}

async function onChangedElsewhere() {
  form.value = null
  showToast(t('web.devices.changedElsewhere', { device: deviceWord.value.toLocaleLowerCase() }))
  await load(true)
}

async function onRemoved() {
  await router.replace({ path: '/devices', query: query.value ? { q: query.value } : {} })
  await load(true)
}

function closePanel() {
  const id = panel.value.value
  panel.close()
  void nextTick(() => setTimeout(() => (document.querySelector(`#device-${CSS.escape(id ?? '')} .row-btn`) as HTMLElement | null)?.focus(), 0))
}

function move(step: number) {
  const list = visible.value.slice(0, shown.value)
  if (!list.length) return
  const index = list.findIndex((row) => row.id === panel.value.value)
  const next = list[Math.max(0, Math.min(list.length - 1, index < 0 ? 0 : index + step))]
  if (next) open(next.id)
}

function onKeys(event: KeyboardEvent) {
  if (ui.layers || event.altKey || event.ctrlKey || event.metaKey) return
  const target = event.target as HTMLElement
  if (target.matches('input, textarea, select, [contenteditable]')) {
    if (event.key === 'Escape' && target === searchEl.value && search.value) search.value = ''
    return
  }
  if (target.closest('.panel')) return
  if (event.key === 'j' || event.key === 'ArrowDown') {
    event.preventDefault()
    move(1)
  } else if (event.key === 'k' || event.key === 'ArrowUp') {
    event.preventDefault()
    move(-1)
  } else if (event.key === 'Escape' && panelOpen.value) closePanel()
}

watch(search, (text) => {
  shown.value = PAGE
  void router.replace({ query: { ...route.query, q: text.trim() || undefined } })
})

const removers: (() => void)[] = []
onMounted(() => {
  void load()
  window.addEventListener('keydown', onKeys)
  removers.push(registerShortcut({ keys: '/', label: 'web.shortcuts.filter', run: () => searchEl.value?.focus() }))
  removers.push(
    registerSearcher('devices', (text) =>
      rows.value
        .filter((row) => deviceMatches(row, text))
        .slice(0, 6)
        .map((row) => ({ id: `device:${row.id}`, label: 'device' as const, text: [row.name, row.serial].filter(Boolean).join(' · '), sub: deviceWord.value, run: () => open(row.id) })),
    ),
  )
})
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeys)
  removers.forEach((remove) => remove())
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ label('device._entity_plural') }}</h1>
      <p class="page-sub page-answer" data-testid="devices-summary">
        <template v-if="state === 'ready'">{{ t('web.devices.count', { count: query ? visible.length : rows.length, devices: label('device._entity_plural').toLocaleLowerCase() }) }}</template>
      </p>
    </div>
    <button v-if="canManage" type="button" class="btn" :class="{ 'btn--primary': !panelOpen }" data-testid="new-device" @click="startCreate()">
      {{ t('web.devices.new', { device: deviceWord }) }}
    </button>
  </header>

  <div class="toolbar">
    <DirectoryTabs current="devices" />
    <span class="spacer"></span>
    <label class="sr" for="devices-search">{{ t('web.devices.searchHint', { serial: label('device.serial').toLocaleLowerCase() }) }}</label>
    <input id="devices-search" ref="searchEl" v-model="search" class="field search-mini" type="search" autocomplete="off" :placeholder="t('web.devices.searchHint', { serial: label('device.serial').toLocaleLowerCase() })" />
  </div>

  <div class="workspace" :class="{ 'has-panel': panelOpen }">
    <div class="list-pane">
      <LoadingState v-if="state === 'loading'" />
      <ErrorState v-else-if="state === 'failed'" :retry="() => load(true)" />
      <EmptyState v-else-if="!rows.length" :title="t('web.devices.empty', { devices: label('device._entity_plural').toLocaleLowerCase() })" :body="canManage ? t('web.devices.emptyBody') : undefined" data-testid="devices-empty">
        <button v-if="canManage" type="button" class="btn btn--primary" @click="startCreate()">{{ t('web.devices.new', { device: deviceWord }) }}</button>
      </EmptyState>
      <div v-else-if="!visible.length" class="empty" data-testid="devices-no-match">
        <h2>{{ t('web.customers.noMatch', { query }) }}</h2>
        <div class="row-actions">
          <button v-if="canManage" type="button" class="btn btn--primary" data-testid="device-create-from-search" @click="startCreate(true)">{{ t('web.newOrder.register', { name: query }) }}</button>
          <button type="button" class="btn btn--ghost" @click="search = ''">{{ t('web.orders.clearSearch') }}</button>
        </div>
      </div>
      <table v-else class="grid" data-testid="devices-table">
        <caption class="sr">{{ label('device._entity_plural') }}</caption>
        <thead>
          <tr>
            <th scope="col">{{ label('device.model') }}</th>
            <th scope="col">{{ label('device.serial') }}</th>
            <th v-if="management" scope="col">{{ t('web.devices.status') }}</th>
            <th scope="col">{{ t('web.devices.maintenance') }}</th>
            <th v-if="canManage" scope="col"><span class="sr">{{ t('web.devices.actions') }}</span></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in visible.slice(0, shown)" :id="`device-${row.id}`" :key="row.id" :class="{ 'is-open': row.id === panel.value.value }" @click="open(row.id)">
            <td>
              <button type="button" class="row-btn who" @click.stop="open(row.id)">{{ row.name || deviceWord }}</button>
              <span v-if="row.manufacturer" class="sub row-detail">{{ row.manufacturer }}</span>
            </td>
            <td><span class="num">{{ row.serial }}</span></td>
            <td v-if="management">
              <span v-if="row.status" class="status"><span class="dot" :class="`dot--${STATUS_DOT[row.status]}`" aria-hidden="true"></span>{{ statusText(row.status) }}</span>
            </td>
            <td><span v-if="row.nextMaintenanceDate" class="num">{{ formatDate(row.nextMaintenanceDate, country) }}</span></td>
            <td v-if="canManage" class="row-tools" @click.stop>
              <button type="button" class="btn btn--ghost btn--small" :aria-label="t('web.devices.editRow', { name: row.name || row.serial || deviceWord })" @click="startEdit(row)">{{ t('edit') }}</button>
              <button type="button" class="btn btn--ghost btn--small" :aria-label="t('web.devices.deleteRow', { name: row.name || row.serial || deviceWord })" @click="removing = row">{{ t('deleteAction') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="state === 'ready' && visible.length > shown" class="more-rows">
        <button type="button" class="btn btn--ghost" @click="shown += PAGE">{{ t('web.orders.loadMore') }}</button>
      </div>
    </div>
    <aside v-if="panelOpen" class="panel" :aria-label="deviceWord">
      <DeviceDetail :key="panel.value.value ?? ''" :device-id="panel.value.value as string" :devices="rows" @close="closePanel" @changed="load(true)" @removed="onRemoved" />
    </aside>
  </div>

  <DeviceForm v-if="form" :device="form.device" :version="form.version" :draft="form.draft" :devices="rows" @saved="onSaved" @changed="onChangedElsewhere" @close="form = null" />
  <ConfirmDialog
    v-if="removing"
    :title="t('deleteDeviceTitle', { name: removing.name || removing.serial || deviceWord })"
    :body="t('deleteDeviceKeepsOrders')"
    :confirm="t('deleteAction')"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="removing = null"
  />
</template>
