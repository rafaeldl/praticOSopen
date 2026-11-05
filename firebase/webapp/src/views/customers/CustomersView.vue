<script setup lang="ts">
// Clientes: everyone of the company, by initial, with the orders that are open
// or late on each row (customer.list.*). Search by name, phone or plate (from
// 3 characters). The open customer sits beside the list, its id in the URL.
// Read from the API, filtered by role on the server: the app's list loses the
// badges and the plate search for consultant and technician (defect 2).
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Upload } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import CustomerDetail from '@/components/customers/CustomerDetail.vue'
import CustomerForm from '@/components/customers/CustomerForm.vue'
import DirectoryTabs from '@/components/customers/DirectoryTabs.vue'
import { t } from '@/i18n'
import { registerSearcher } from '@/lib/commands'
import { loadCustomerDirectory, loadDevice, loadDeviceDirectory } from '@/lib/customers/data'
import { badgeOf, canOfferCreate, customerMatches, draftFromSearch, groupByInitial, plateMatches, type CustomerRow, type DeviceRow } from '@/lib/customers/model'
import { money } from '@/lib/orders/text'
import { formatPhone } from '@/lib/phone'
import { useRoutePanel } from '@/lib/route-layer'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { announce, ui } from '@/lib/ui'
import '@/styles/customers.css'

const PAGE = 200
const route = useRoute()
const router = useRouter()
const panel = useRoutePanel('customer')
const rows = shallowRef<CustomerRow[]>([])
const devices = shallowRef<DeviceRow[]>([])
const partial = ref(false)
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const search = ref(typeof route.query.q === 'string' ? route.query.q : '')
const shown = ref(PAGE)
const searchEl = ref<HTMLInputElement | null>(null)
const form = ref<{ draft: { name: string; phone: string } } | null>(null)

const canManage = computed(() => can('manageCustomers'))
/** The server sends what each one owes only to who reads the Financeiro. */
const showOwed = computed(() => rows.value.some((row) => typeof row.owed === 'number'))
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const serialLabel = computed(() => label('device.serial'))
const country = computed(() => session.company?.country)
const panelOpen = computed(() => !!panel.value.value)
const query = computed(() => search.value.trim())
const visible = computed(() => (query.value ? rows.value.filter((row) => customerMatches(row, query.value)) : rows.value))
const plates = computed(() => plateMatches(devices.value, query.value))
const groups = computed(() =>
  query.value ? [{ initial: '', rows: visible.value.slice(0, shown.value) }] : groupByInitial(visible.value.slice(0, shown.value)),
)
const offerCreate = computed(() => canManage.value && !!query.value && canOfferCreate(rows.value, query.value))

async function load(fresh = false) {
  state.value = 'loading'
  try {
    const [directory, deviceList] = await Promise.all([loadCustomerDirectory(fresh), loadDeviceDirectory(fresh).catch(() => null)])
    rows.value = [...directory.rows].sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }))
    partial.value = directory.partial
    devices.value = deviceList?.rows ?? []
    state.value = 'ready'
    announce(t('customersCount', { count: rows.value.length }))
  } catch (error) {
    console.error('customers: list failed', error)
    state.value = 'failed'
  }
}

function open(id: string) {
  void panel.open(id)
}

/** A plate found: its owner opens (customer of the newest order); without one, the device. */
async function openPlate(device: DeviceRow) {
  try {
    const detail = await loadDevice(device.id)
    if (detail.owner) return open(detail.owner.id)
  } catch (error) {
    console.warn('customers: owner not read', error)
  }
  void router.push({ path: '/devices', query: { device: device.id } })
}

function startCreate(fromSearch = false) {
  form.value = { draft: fromSearch ? draftFromSearch(query.value) : { name: '', phone: '' } }
}

/** Saved from the list: the new customer opens at once (customer.list.empty-add). */
async function onSaved(id: string) {
  search.value = ''
  // The drawer's history entry becomes the new customer: Voltar goes to the list, not to an empty form.
  await router.replace({ path: '/customers', query: { customer: id } })
  form.value = null
  await load(true)
}

/** Deleted in the panel: back to the list, without the panel and its confirmation. */
async function onRemoved() {
  await router.replace({ path: '/customers', query: query.value ? { q: query.value } : {} })
  await load(true)
}

/** "Abrir cliente" in the repeated phone warning: the one that already exists. */
async function onOpenExisting(id: string) {
  await router.replace({ path: '/customers', query: { customer: id } })
  form.value = null
}

function closePanel() {
  const id = panel.value.value
  panel.close()
  void nextTick(() => setTimeout(() => (document.querySelector(`#customer-${CSS.escape(id ?? '')} .row-btn`) as HTMLElement | null)?.focus(), 0))
}

function move(step: number) {
  const list = visible.value.slice(0, shown.value)
  if (!list.length) return
  const index = list.findIndex((row) => row.id === panel.value.value)
  const next = list[Math.max(0, Math.min(list.length - 1, index < 0 ? 0 : index + step))]
  if (!next) return
  open(next.id)
  void nextTick(() => document.getElementById(`customer-${next.id}`)?.scrollIntoView({ block: 'nearest' }))
}

function onKeys(event: KeyboardEvent) {
  if (ui.layers || event.altKey || event.ctrlKey || event.metaKey) return
  const target = event.target as HTMLElement
  if (target.matches('input, textarea, select, [contenteditable]')) {
    if (event.key === 'Escape' && target === searchEl.value && search.value) search.value = ''
    else if (event.key === 'ArrowDown' && target === searchEl.value) {
      event.preventDefault()
      target.blur()
      move(0)
    }
    return
  }
  if (target.closest('.panel')) return
  if (event.key === 'j' || event.key === 'ArrowDown') {
    event.preventDefault()
    move(1)
  } else if (event.key === 'k' || event.key === 'ArrowUp') {
    event.preventDefault()
    move(-1)
  } else if (event.key === 'Enter' && !target.matches('button, a')) {
    const focusable = document.querySelector<HTMLElement>('[data-od-focus]')
    if (focusable) {
      event.preventDefault()
      focusable.focus()
    }
  } else if (event.key === 'Escape' && panelOpen.value) closePanel()
}

let typing: ReturnType<typeof setTimeout> | undefined
watch(search, (text) => {
  shown.value = PAGE
  clearTimeout(typing)
  typing = setTimeout(() => {
    void router.replace({ query: { ...route.query, q: text.trim() || undefined } })
    if (text.trim()) announce(t('web.customers.found', { count: visible.value.length }))
  }, 250)
})

const removers: (() => void)[] = []
/** ⌘K "Cadastrar cliente «…»" (and "Novo cliente") arrive as ?new=: the form opens with what was typed. */
async function createFromQuery() {
  const text = route.query.new
  if (typeof text !== 'string' || !canManage.value) return
  const { new: _drop, ...rest } = route.query
  await router.replace({ query: rest })
  form.value = { draft: text.trim() ? draftFromSearch(text) : { name: '', phone: '' } }
}
watch(() => route.query.new, () => void createFromQuery())

onMounted(() => {
  void load()
  void createFromQuery()
  window.addEventListener('keydown', onKeys)
  removers.push(registerShortcut({ keys: '/', label: 'web.shortcuts.filter', run: () => searchEl.value?.focus() }))
  // ⌘K finds customers by name, phone or plate (busca rápida).
  removers.push(
    registerSearcher('customers', (text) => [
      ...plateMatches(devices.value, text, 3).map((device) => ({
        id: `plate:${device.id}`,
        label: 'customer' as const,
        text: `${device.serial ?? ''} · ${device.name ?? ''}`,
        sub: serialLabel.value,
        run: () => void openPlate(device),
      })),
      ...rows.value
        .filter((row) => customerMatches(row, text))
        .slice(0, 6)
        .map((row) => ({ id: `customer:${row.id}`, label: 'customer' as const, text: row.name, sub: formatPhone(row.phone, country.value) || t('customer'), run: () => open(row.id) })),
    ]),
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
      <h1 class="page-title" tabindex="-1" data-page-title>{{ label('customer._entity_plural') }}</h1>
      <p class="page-sub page-answer" data-testid="customers-summary">
        <template v-if="state === 'ready'">{{ query ? t('web.customers.found', { count: visible.length }) : t('customersCount', { count: rows.length }) }}</template>
      </p>
    </div>
    <RouterLink v-if="canManage" class="btn hide-phone" to="/customers/import" data-testid="import-link"><Upload :size="15" aria-hidden="true" />{{ t('web.customers.import') }}</RouterLink>
    <button v-if="canManage" type="button" class="btn" :class="{ 'btn--primary': !panelOpen }" data-testid="new-customer" @click="startCreate()">
      {{ t('web.customers.new') }}
    </button>
  </header>

  <div class="toolbar">
    <DirectoryTabs current="customers" />
    <span class="spacer"></span>
    <label class="sr" for="customers-search">{{ t('searchCustomerPlaceholder', { serial: serialLabel.toLocaleLowerCase() }) }}</label>
    <input
      id="customers-search"
      ref="searchEl"
      v-model="search"
      class="field search-mini"
      type="search"
      autocomplete="off"
      :placeholder="t('searchCustomerPlaceholder', { serial: serialLabel.toLocaleLowerCase() })"
    />
  </div>

  <div class="workspace" :class="{ 'has-panel': panelOpen }">
    <div class="list-pane">
      <p v-if="partial && state === 'ready'" class="sub list-note">{{ t('web.customers.partialBadges') }}</p>
      <LoadingState v-if="state === 'loading'" />
      <ErrorState v-else-if="state === 'failed'" :body="t('customerLookupError')" :retry="() => load(true)" />
      <EmptyState v-else-if="!rows.length" :title="t('noCustomersYet')" :body="t('web.customers.emptyBody')" data-testid="customers-empty">
        <div v-if="canManage" class="row-actions">
          <button type="button" class="btn btn--primary" data-testid="first-customer" @click="startCreate()">{{ t('web.customers.first') }}</button>
          <RouterLink class="btn" to="/customers/import">{{ t('web.customers.import') }}</RouterLink>
        </div>
      </EmptyState>
      <template v-else>
        <ul v-if="plates.length" class="plate-hits" :aria-label="t('web.customers.plateHits', { serial: serialLabel })" data-testid="plate-hits">
          <li v-for="device in plates" :key="device.id">
            <button type="button" class="row-btn" @click="openPlate(device)">
              <span class="num">{{ device.serial }}</span><span v-if="device.name"> · {{ device.name }}</span>
            </button>
          </li>
        </ul>
        <div v-if="!visible.length" class="empty" data-testid="customers-no-match">
          <h2>{{ t('web.customers.noMatch', { query }) }}</h2>
          <div class="row-actions">
            <button v-if="offerCreate" type="button" class="btn btn--primary" data-testid="create-from-search" @click="startCreate(true)">
              {{ t('web.newOrder.register', { name: query }) }}
            </button>
            <button type="button" class="btn btn--ghost" @click="search = ''">{{ t('web.orders.clearSearch') }}</button>
          </div>
        </div>
        <table v-else class="grid dir-customers" data-testid="customers-table">
          <caption class="sr">{{ label('customer._entity_plural') }}</caption>
          <thead>
            <tr>
              <th scope="col">{{ t('customer') }}</th>
              <th scope="col">{{ t('phone') }}</th>
              <th scope="col">{{ t('web.customers.ordersColumn') }}</th>
              <th v-if="showOwed" scope="col" class="num">{{ t('web.customers.owedColumn') }}</th>
            </tr>
          </thead>
          <tbody v-for="group in groups" :key="group.initial || 'all'">
            <tr v-if="group.initial" class="group-row no-click">
              <th :colspan="showOwed ? 4 : 3" scope="rowgroup">{{ group.initial }}</th>
            </tr>
            <tr v-for="row in group.rows" :id="`customer-${row.id}`" :key="row.id" :class="{ 'is-open': row.id === panel.value.value }" @click="open(row.id)">
              <td>
                <button type="button" class="row-btn who" @click.stop="open(row.id)">{{ row.name || t('customerWithoutName') }}</button>
              </td>
              <td><span class="num">{{ formatPhone(row.phone, country) }}</span></td>
              <td>
                <span v-if="badgeOf(row)" class="status" :class="{ 'status--late': badgeOf(row)!.kind === 'late' }">
                  <span class="dot" :class="badgeOf(row)!.kind === 'late' ? 'dot--danger' : 'dot--warning'" aria-hidden="true"></span>
                  <span>{{ badgeOf(row)!.kind === 'late' ? t('web.customers.lateBadge', { count: badgeOf(row)!.count }) : t('web.customers.openBadge', { count: badgeOf(row)!.count }) }}</span>
                </span>
              </td>
              <td v-if="showOwed" class="num dir-money" data-testid="customer-owed">{{ row.owed ? money(row.owed) : '' }}</td>
            </tr>
          </tbody>
        </table>
        <div v-if="visible.length > shown" class="more-rows">
          <button type="button" class="btn btn--ghost" @click="shown += PAGE">{{ t('web.orders.loadMore') }}</button>
        </div>
      </template>
    </div>
    <aside v-if="panelOpen" class="panel" :aria-label="t('customer')">
      <CustomerDetail :key="panel.value.value ?? ''" :customer-id="panel.value.value as string" :directory="rows" @close="closePanel" @changed="load(true)" @removed="onRemoved" />
    </aside>
  </div>

  <CustomerForm v-if="form" :draft="form.draft" :directory="rows" @saved="onSaved" @open="onOpenExisting" @close="form = null" />
</template>
