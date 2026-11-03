<script setup lang="ts">
// Catálogo: the services and products the company puts in orders
// (catalog.list.*). Services | Products with counts (only the kinds the role
// sees), search by name without accents, "Mais usados" of this kind, and the
// price only for who sees values: the API leaves it out for the others. Rows
// open the editor only for who manages the kind (C3). On a big screen,
// selected rows change price together, and a spreadsheet brings many at once.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Package, Upload, Wrench } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import CatalogForm from '@/components/catalog/CatalogForm.vue'
import PriceDialog from '@/components/catalog/PriceDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { applyPrices, changedSince, loadCatalogList, type CatalogList } from '@/lib/catalog/data'
import { itemMatches, pickKind, sortByName, visibleKinds, type CatalogItem, type CatalogKind, type PriceChange } from '@/lib/catalog/model'
import { money } from '@/lib/orders/text'
import { forgetLists } from '@/lib/orders/catalog'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import '@/styles/customers.css'
import '@/styles/catalog.css'

const PAGE = 200
const route = useRoute()
const router = useRouter()
const kinds = visibleKinds((permission) => can(permission))
const kind = ref<CatalogKind | null>(pickKind(route.query.kind, kinds))
const lists = shallowRef<Partial<Record<CatalogKind, CatalogList>>>({})
const failed = ref<Partial<Record<CatalogKind, boolean>>>({})
const search = ref(typeof route.query.q === 'string' ? route.query.q : '')
const searchEl = ref<HTMLInputElement | null>(null)
const shown = ref(PAGE)
const selected = ref<Set<string>>(new Set())
const form = ref<{ item: CatalogItem | null } | null>(null)
const pricing = ref(false)
const priceBusy = ref(false)
const priceError = ref('')

const labels = computed(() => segmentLabels())
// A segment may name products its own way ("Peça", "Componente"); services keep the app's word.
const labeled = computed(() => !!labels.value['product._entity'])
const plural = (k: CatalogKind) => (k === 'service' ? t('services') : resolveLabel('product._entity_plural', labels.value, (key) => t(key), t('products')))
const singular = (k: CatalogKind) => (k === 'service' ? t('service') : resolveLabel('product._entity', labels.value, (key) => t(key), t('product')))
const list = computed(() => (kind.value ? lists.value[kind.value] : undefined))
const state = computed(() => (!kind.value ? 'none' : failed.value[kind.value] ? 'failed' : list.value ? 'ready' : 'loading'))
const items = computed(() => sortByName(list.value?.items ?? []))
const prices = computed(() => !!list.value?.prices)
const canManage = computed(() => !!kind.value && can(kind.value === 'service' ? 'manageServices' : 'manageProducts'))
const canBulk = computed(() => canManage.value && prices.value && can('editPrices'))
const query = computed(() => search.value.trim())
const visible = computed(() => (query.value ? items.value.filter((item) => itemMatches(item, query.value)) : items.value))
const mostUsed = computed(() => {
  if (query.value || !list.value) return []
  const byId = new Map(items.value.map((item) => [item.id, item]))
  return list.value.mostUsed.map((id) => byId.get(id)).filter((item): item is CatalogItem => !!item)
})
const selectedItems = computed(() => items.value.filter((item) => selected.value.has(item.id)))
const allSelected = computed(() => visible.value.length > 0 && visible.value.slice(0, shown.value).every((item) => selected.value.has(item.id)))
const newText = computed(() => {
  if (!kind.value) return ''
  if (kind.value === 'product' && labeled.value) return t('web.catalog.newLabeled', { entity: singular('product').toLocaleLowerCase() })
  return kind.value === 'service' ? t('catalogNewService') : t('catalogNewProduct')
})
const emptyTitle = computed(() => {
  if (kind.value === 'product' && labeled.value) return t('web.catalog.emptyLabeled', { entities: plural('product').toLocaleLowerCase() })
  return kind.value === 'service' ? t('catalogEmptyServices') : t('catalogEmptyProducts')
})
const columns = computed(() => 2 + (canBulk.value ? 1 : 0) + (prices.value ? 1 : 0))

async function load(which: CatalogKind, fresh = false) {
  failed.value = { ...failed.value, [which]: false }
  try {
    const result = await loadCatalogList(which, fresh)
    lists.value = { ...lists.value, [which]: result }
    if (which === kind.value) announce(t('catalogKindWithCount', { kind: plural(which), count: result.items.length }))
  } catch (error) {
    console.error('catalog: list failed', error)
    failed.value = { ...failed.value, [which]: true }
  }
}

/** Both kinds load, for the counts on the switch (catalog.list.switch); a failure stays in its own kind. */
function loadAll(fresh = false) {
  for (const which of kinds) void load(which, fresh)
}

function setKind(next: CatalogKind) {
  if (next === kind.value) return
  kind.value = next
  // Changing the kind clears the search and the selection, as in the app.
  search.value = ''
  selected.value = new Set()
  shown.value = PAGE
  void router.replace({ query: { ...route.query, kind: next === kinds[0] ? undefined : next, q: undefined } })
}

function priceText(item: CatalogItem) {
  return typeof item.value === 'number' ? money(item.value) : t('catalogNoPrice')
}

function toggle(item: CatalogItem) {
  const next = new Set(selected.value)
  if (next.has(item.id)) next.delete(item.id)
  else next.add(item.id)
  selected.value = next
}

function toggleAll() {
  selected.value = allSelected.value ? new Set() : new Set(visible.value.slice(0, shown.value).map((item) => item.id))
}

function open(item: CatalogItem) {
  if (canManage.value) form.value = { item }
}

async function afterWrite() {
  forgetLists()
  if (kind.value) await load(kind.value, true)
}

async function onSaved() {
  form.value = null
  showToast(t('web.catalog.saved'))
  await afterWrite()
}

async function onChangedElsewhere() {
  form.value = null
  showToast(t('web.catalog.changedElsewhere'))
  await afterWrite()
}

async function onRemoved() {
  form.value = null
  await afterWrite()
}

/** Sends the changes; on success offers to put the old prices back. */
async function sendPrices(which: CatalogKind, changes: { id: string; from: number | null; to: number }[]) {
  return applyPrices(which, changes)
}

async function onApply(changes: PriceChange[]) {
  if (!kind.value || priceBusy.value) return
  const which = kind.value
  priceBusy.value = true
  priceError.value = ''
  try {
    const sent = changes.map((change) => ({ id: change.item.id, from: change.from, to: change.to }))
    await sendPrices(which, sent)
    pricing.value = false
    selected.value = new Set()
    const message = t('web.catalog.pricesDone', { count: changes.length })
    announce(message)
    showToast(message, {
      undo: () =>
        void sendPrices(which, sent.map((change) => ({ id: change.id, from: change.to, to: change.from as number })))
          .then(() => showToast(t('web.catalog.pricesUndone')))
          .catch((error) => showToast(changedSince(error) ? t('web.catalog.pricesChanged') : t(errorMessageKey(error))))
          .finally(() => afterWrite()),
    })
  } catch (error) {
    priceError.value = changedSince(error) ? t('web.catalog.pricesChanged') : `${t('web.catalog.pricesFailed')} ${t(errorMessageKey(error))}`
  } finally {
    priceBusy.value = false
    await afterWrite()
  }
}

function onKeys(event: KeyboardEvent) {
  if (ui.layers || event.altKey || event.ctrlKey || event.metaKey) return
  const target = event.target as HTMLElement
  if (event.key === 'Escape') {
    if (target === searchEl.value && search.value) search.value = ''
    else if (selected.value.size) selected.value = new Set()
  }
}

let typing: ReturnType<typeof setTimeout> | undefined
watch(search, (text) => {
  shown.value = PAGE
  clearTimeout(typing)
  typing = setTimeout(() => {
    void router.replace({ query: { ...route.query, q: text.trim() || undefined } })
    if (text.trim()) announce(t('web.catalog.found', { count: visible.value.length }))
  }, 250)
})

const removers: (() => void)[] = []
onMounted(() => {
  if (kind.value && route.query.kind && route.query.kind !== kind.value) void router.replace({ query: { ...route.query, kind: undefined } })
  loadAll()
  window.addEventListener('keydown', onKeys)
  removers.push(registerShortcut({ keys: '/', label: 'web.shortcuts.filter', run: () => searchEl.value?.focus() }))
})
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeys)
  removers.forEach((remove) => remove())
  clearTimeout(typing)
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('catalogTitle') }}</h1>
      <p class="page-sub" data-testid="catalog-summary">
        <template v-if="state === 'ready' && query">{{ t('web.catalog.found', { count: visible.length }) }}</template>
        <template v-else>{{ t('catalogSubtitle') }}</template>
      </p>
    </div>
    <RouterLink v-if="canManage" class="btn hide-phone" :to="{ path: '/catalog/import', query: kind && kind !== kinds[0] ? { kind } : {} }" data-testid="catalog-import-link">
      <Upload :size="15" aria-hidden="true" />{{ t('web.catalog.import') }}
    </RouterLink>
    <button v-if="canManage" type="button" class="btn" :class="{ 'btn--primary': !selected.size }" data-testid="new-catalog-item" @click="form = { item: null }">{{ newText }}</button>
  </header>

  <div class="toolbar">
    <div v-if="selected.size" class="batchbar" role="region" :aria-label="t('web.catalog.selected', { count: selected.size })" data-testid="catalog-batch">
      <strong>{{ t('web.catalog.selected', { count: selected.size }) }}</strong>
      <button type="button" class="btn btn--primary" data-testid="change-prices" @click="priceError = ''; pricing = true">{{ t('web.catalog.changePrices') }}</button>
      <button type="button" class="btn btn--ghost" @click="selected = new Set()">{{ t('web.catalog.clearSelection') }} <kbd>Esc</kbd></button>
    </div>
    <div v-else-if="kinds.length > 1" class="tabs" role="group" :aria-label="t('web.catalog.kinds')" data-testid="catalog-kinds">
      <button v-for="which in kinds" :key="which" type="button" :aria-pressed="kind === which" :data-testid="`kind-${which}`" @click="setKind(which)">
        {{ lists[which] ? t('catalogKindWithCount', { kind: plural(which), count: lists[which]!.items.length }) : plural(which) }}
      </button>
    </div>
    <span class="spacer"></span>
    <label class="sr" for="catalog-search">{{ t('web.catalog.searchLabel') }}</label>
    <input id="catalog-search" ref="searchEl" v-model="search" class="field search-mini" type="search" autocomplete="off" :placeholder="t('web.catalog.searchLabel')" />
  </div>

  <div class="workspace">
    <div class="list-pane">
      <LoadingState v-if="state === 'loading'" />
      <ErrorState v-else-if="state === 'failed'" :body="t('catalogLoadError')" :retry="() => kind && load(kind, true)" />
      <EmptyState v-else-if="state === 'ready' && !items.length" :title="emptyTitle" :body="kind === 'service' ? t('catalogEmptyServicesHint') : t('catalogEmptyProductsHint')" data-testid="catalog-empty">
        <div v-if="canManage" class="row-actions">
          <button type="button" class="btn btn--primary" data-testid="first-catalog-item" @click="form = { item: null }">{{ newText }}</button>
          <RouterLink class="btn" :to="{ path: '/catalog/import', query: kind && kind !== kinds[0] ? { kind } : {} }">{{ t('web.catalog.import') }}</RouterLink>
        </div>
      </EmptyState>
      <template v-else-if="state === 'ready'">
        <p v-if="list?.truncated" class="sub list-note">{{ t('web.catalog.truncated', { count: items.length }) }}</p>
        <div v-if="!visible.length" class="empty" data-testid="catalog-no-match">
          <h2>{{ t('catalogNoMatch', { query }) }}</h2>
          <button type="button" class="btn btn--ghost" @click="search = ''">{{ t('web.orders.clearSearch') }}</button>
        </div>
        <table v-else class="grid cat-table" data-testid="catalog-table">
          <caption class="sr">{{ kind ? plural(kind) : '' }}</caption>
          <thead>
            <tr>
              <th v-if="canBulk" scope="col" class="c-check">
                <input class="check" type="checkbox" :checked="allSelected" :aria-label="t('web.catalog.selectAll')" data-testid="select-all" @change="toggleAll" />
              </th>
              <th scope="col" class="c-thumb"><span class="sr">{{ t('photo') }}</span></th>
              <th scope="col">{{ t('name') }}</th>
              <th v-if="prices" scope="col" class="c-money">{{ t('catalogPriceLabel') }}</th>
            </tr>
          </thead>
          <tbody v-for="group in [{ id: 'most', title: t('orderMostUsed'), rows: mostUsed }, { id: 'all', title: mostUsed.length ? t('all') : '', rows: visible.slice(0, shown) }]" :key="group.id" :data-testid="`catalog-group-${group.id}`">
            <tr v-if="group.title && group.rows.length" class="group-row no-click">
              <th :colspan="columns" scope="rowgroup">{{ group.title }}</th>
            </tr>
            <tr
              v-for="item in group.rows"
              :key="`${group.id}-${item.id}`"
              :class="{ 'no-click': !canManage, 'is-selected': selected.has(item.id) }"
              :data-item="item.id"
              @click="open(item)"
            >
              <td v-if="canBulk" class="c-check" @click.stop>
                <input class="check" type="checkbox" :checked="selected.has(item.id)" :aria-label="t('web.catalog.selectItem', { name: item.name })" @change="toggle(item)" />
              </td>
              <td class="c-thumb">
                <img v-if="item.photo" class="cat-thumb" :src="item.photo" alt="" loading="lazy" />
                <span v-else class="cat-thumb" aria-hidden="true"><Wrench v-if="kind === 'service'" :size="16" /><Package v-else :size="16" /></span>
              </td>
              <td>
                <button v-if="canManage" type="button" class="row-btn who" :aria-label="t('web.catalog.edit', { name: item.name })" @click.stop="open(item)">{{ item.name }}</button>
                <span v-else class="who">{{ item.name }}</span>
              </td>
              <td v-if="prices" class="c-money">
                <span :class="typeof item.value === 'number' ? 'num' : 'muted'">{{ priceText(item) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="visible.length > shown" class="more-rows">
          <button type="button" class="btn btn--ghost" @click="shown += PAGE">{{ t('web.orders.loadMore') }}</button>
        </div>
        <p v-if="!query" class="sub cat-tip">{{ t('catalogTip') }}</p>
      </template>
    </div>
  </div>

  <CatalogForm
    v-if="form && kind"
    :kind="kind"
    :item="form.item"
    :entity="singular(kind).toLocaleLowerCase()"
    :labeled="kind === 'product' && labeled"
    @saved="onSaved"
    @changed="onChangedElsewhere"
    @removed="onRemoved"
    @close="form = null"
  />
  <PriceDialog v-if="pricing" :items="selectedItems" :busy="priceBusy" :error="priceError" @apply="onApply" @close="pricing = false" />
</template>
