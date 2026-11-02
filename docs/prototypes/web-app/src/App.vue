<script setup>
import { computed, onMounted, onBeforeUnmount, watchEffect } from 'vue'
import { Home, ClipboardList, CalendarDays, Wallet, Users, Search, SlidersHorizontal, FileText, Tags, Menu, Plus, Upload } from 'lucide-vue-next'
import { prefs, savePrefs, db, route, go, routeFromHash, ui, isOpen, rest, touch } from './store.js'
import Orders from './views/Orders.vue'
import Board from './views/Board.vue'
import Agenda from './views/Agenda.vue'
import Receive from './views/Receive.vue'
import HomeView from './views/Home.vue'
import Finance from './views/Finance.vue'
import Customers from './views/Customers.vue'
import Invoices from './views/Invoices.vue'
import Catalog from './views/Catalog.vue'
import Import from './views/Import.vue'
import Entry from './views/Entry.vue'
import OrderDetail from './components/OrderDetail.vue'
import NewOrderDrawer from './components/NewOrderDrawer.vue'
import Palette from './components/Palette.vue'
import Overlays from './components/Overlays.vue'
import Layer from './components/Layer.vue'
import { modKey } from './format.js'

const NAV = computed(() => [
  { key: 'inicio', label: 'Início', icon: Home, on: ['inicio'] },
  { key: 'os', label: 'Ordens de serviço', icon: ClipboardList, on: ['os', 'quadro'], count: db.value.orders.filter(isOpen).length },
  { key: 'agenda', label: 'Agenda', icon: CalendarDays, on: ['agenda'] },
  { key: 'financeiro', label: 'Financeiro', icon: Wallet, on: ['financeiro', 'receber'], count: db.value.orders.filter((o) => o.status === 'done' && rest(o) > 0).length },
  { key: 'clientes', label: 'Clientes', icon: Users, on: ['clientes', 'importar'] },
  { key: 'notas', label: 'Notas fiscais', icon: FileText, on: ['notas'] },
  { key: 'catalogo', label: 'Catálogo', icon: Tags, on: ['catalogo'] },
])
const TABS = computed(() => [
  { key: 'inicio', label: 'Início', icon: Home, on: ['inicio'] },
  { key: 'os', label: 'OS', icon: ClipboardList, on: ['os', 'quadro'] },
  { key: 'agenda', label: 'Agenda', icon: CalendarDays, on: ['agenda'] },
  { key: 'financeiro', label: 'Financeiro', icon: Wallet, on: ['financeiro', 'receber'], count: NAV.value.find((n) => n.key === 'financeiro').count },
])
const MORE = [
  { key: 'clientes', label: 'Clientes', icon: Users }, { key: 'notas', label: 'Notas fiscais', icon: FileText },
  { key: 'catalogo', label: 'Catálogo', icon: Tags }, { key: 'importar', label: 'Importar clientes', icon: Upload },
]
const moreOn = computed(() => !TABS.value.some((t) => t.on.includes(route.name)))
function goMore(key) { ui.more = false; go(key) }
function openProto() { ui.more = false; ui.proto = true }
const VIEWS = { inicio: HomeView, os: Orders, quadro: Board, agenda: Agenda, receber: Receive, financeiro: Finance, clientes: Customers, notas: Invoices, catalogo: Catalog, importar: Import }
const view = computed(() => VIEWS[route.name])

watchEffect(() => {
  const r = document.documentElement
  const dark = prefs.theme === 'dark' || (prefs.theme === 'system' && matchMedia('(prefers-color-scheme: dark)').matches)
  r.setAttribute('data-theme', dark ? 'dark' : 'light')
  r.setAttribute('data-action', prefs.action)
  r.setAttribute('data-density', prefs.density)
  r.setAttribute('data-font', prefs.font)
  savePrefs()
})

const inField = (t) => t.matches?.('input, textarea, select, [contenteditable]')
function onKey(e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); ui.palette = !ui.palette; return }
  if (e.ctrlKey || e.metaKey || e.altKey || inField(e.target) || route.name === 'entrada') return
  const peekOnly = ui.layers === 1 && ui.peek
  if (ui.layers && !peekOnly) return
  const k = e.key
  if (k === '?') { e.preventDefault(); ui.shortcuts = true; return }
  if (k.toLowerCase() === 'n' && !ui.layers) { e.preventDefault(); ui.newOrderSeed = null; ui.newOrder = true; return }
  if (!ui.layers && '1234567'.includes(k)) { go(NAV.value[+k - 1].key); return }
  if ('acvdmfsrp'.includes(k.toLowerCase()) && (ui.peek || route.name === 'os')) {
    ui.orderCmd = { k: k.toLowerCase(), n: Date.now(), ev: e.preventDefault() }
  }
}
onMounted(() => {
  routeFromHash()
  window.addEventListener('keydown', onKey)
  document.querySelector('[data-page-title]')?.focus({ preventScroll: true })
})
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Entry v-if="route.name === 'entrada'" />
  <div v-else class="shell">
    <aside class="side" aria-label="Navegação">
      <div>
        <div class="logo" aria-label="PraticOS">Prát<i>ic</i><b>OS</b></div>
        <div class="company">{{ db.company }}</div>
      </div>
      <button class="side-search" @click="ui.palette = true">
        <Search :size="16" aria-hidden="true" /><span>Buscar</span><kbd>{{ modKey }} K</kbd>
      </button>
      <nav>
        <button v-for="n in NAV" :key="n.key" class="nav-item" :aria-current="n.on.includes(route.name) ? 'page' : undefined" :aria-label="n.label" @click="go(n.key)">
          <component :is="n.icon" :size="18" aria-hidden="true" /><span>{{ n.label }}</span>
          <span v-if="n.count" class="count">{{ n.count }}</span>
        </button>
      </nav>
      <div class="side-foot">
        <p class="fiction">Dados fictícios.<template v-if="!touch"> Aperte <kbd>?</kbd> para ver os atalhos.</template></p>
        <button class="proto-btn" aria-label="Ajustes do protótipo" @click="ui.proto = !ui.proto"><SlidersHorizontal :size="15" aria-hidden="true" /><span>Ajustes do protótipo</span></button>
      </div>
    </aside>
    <header class="topbar">
      <div class="logo" aria-label="PraticOS">Prát<i>ic</i><b>OS</b></div>
      <span class="spacer"></span>
      <button class="topbar-btn" aria-label="Buscar" @click="ui.palette = true"><Search :size="21" aria-hidden="true" /></button>
      <button class="topbar-btn topbar-add" @click="ui.newOrderSeed = null; ui.newOrder = true"><Plus :size="18" aria-hidden="true" />Nova OS</button>
    </header>
    <main class="main">
      <OrderDetail v-if="route.name === 'os' && route.id && route.query.page" :key="route.id" :order-id="route.id" mode="page" />
      <component :is="view" v-else :key="route.name + prefs.seg + prefs.empty + (route.query.c || route.id || '')" />
    </main>
    <nav class="tabbar" aria-label="Abas">
      <button v-for="t in TABS" :key="t.key" :aria-current="t.on.includes(route.name) ? 'page' : undefined" @click="go(t.key)">
        <component :is="t.icon" :size="22" aria-hidden="true" /><span>{{ t.label }}</span>
        <span v-if="t.count" class="count num">{{ t.count }}</span>
      </button>
      <button :aria-current="moreOn ? 'page' : undefined" @click="ui.more = true"><Menu :size="22" aria-hidden="true" /><span>Mais</span></button>
    </nav>
  </div>
  <Layer v-if="ui.more" kind="sheet" label="Mais" @close="ui.more = false">
    <div class="more">
      <p class="more-co">{{ db.company }}</p>
      <button v-for="m in MORE" :key="m.key" class="more-row" @click="goMore(m.key)"><component :is="m.icon" :size="20" aria-hidden="true" />{{ m.label }}</button>
      <button class="more-row" @click="openProto"><SlidersHorizontal :size="20" aria-hidden="true" />Ajustes do protótipo</button>
    </div>
  </Layer>
  <Layer v-if="ui.peek" kind="drawer" :label="'OS ' + ui.peek" @close="ui.peek = null">
    <OrderDetail :key="ui.peek" :order-id="ui.peek" mode="peek" @close="ui.peek = null" />
  </Layer>
  <NewOrderDrawer v-if="ui.newOrder" />
  <Palette v-if="ui.palette" />
  <Overlays />
  <div class="sr" role="status" aria-live="polite">{{ ui.live }}</div>
</template>
