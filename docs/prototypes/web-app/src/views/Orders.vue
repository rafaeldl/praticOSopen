<script setup>
import { computed, ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { ArrowUp, ArrowDown } from 'lucide-vue-next'
import {
  db, ui, go, route, customerOf, deviceOf, isOpen, isToday, lateDays, isHeld, rest, total, whenLabel, setStatus, act, STATUS, filterHint, phone, phonePanel } from '../store.js'
import { brl, matches, plural } from '../format.js'
import StatusLabel from '../components/StatusLabel.vue'
import OrderDetail from '../components/OrderDetail.vue'
import OrdersHead from './OrdersHead.vue'

const VIEWS = [
  { id: 'open', label: 'Em aberto', fn: isOpen },
  { id: 'late', label: 'Atrasadas', fn: (o) => lateDays(o) > 0, danger: true },
  { id: 'today', label: 'Para hoje', fn: (o) => isOpen(o) && isToday(o) },
  { id: 'held', label: 'Paradas', fn: isHeld },
  { id: 'quote', label: 'Orçamentos', fn: (o) => o.status === 'quote' },
  { id: 'unpaid', label: 'Sem receber', fn: (o) => o.status === 'done' && rest(o) > 0 },
  { id: 'all', label: 'Todas', fn: () => true },
]
const filter = ref(route.query.f || 'open')
const text = ref(route.query.q || '')
const who = ref('')
const sort = ref({ key: 'number', dir: -1 })
const openId = ref(route.id || null)
phonePanel(openId)
const searchEl = ref(null)
const orders = computed(() => db.value.orders)
const counts = computed(() => Object.fromEntries(VIEWS.map((v) => [v.id, orders.value.filter(v.fn).length])))
const visibleViews = computed(() => VIEWS.filter((v) => counts.value[v.id] > 0 || ['open', 'all'].includes(v.id) || v.id === filter.value))
const hay = (o) => { const c = customerOf(o); const d = deviceOf(o); return `${o.number} ${c.name} ${c.phone} ${d?.label || ''} ${d?.tag || ''}` }
const rows = computed(() => {
  const fn = VIEWS.find((v) => v.id === filter.value).fn
  const list = orders.value.filter((o) => fn(o) && (!text.value || matches(hay(o), text.value)) && (!who.value || o.assignee === who.value))
  const key = {
    number: (o) => o.number, value: (o) => total(o), who: (o) => o.assignee || '',
    name: (o) => customerOf(o).name, when: (o) => o.dueAt || o.scheduledAt || '',
  }[sort.value.key]
  return [...list].sort((a, b) => (key(a) > key(b) ? 1 : key(a) < key(b) ? -1 : 0) * sort.value.dir)
})
const openCount = computed(() => counts.value.open)
const title = computed(() => {
  if (!orders.value.length) return 'Nenhuma OS ainda'
  const parts = [plural(openCount.value, 'em aberto', 'em aberto')]
  if (counts.value.late) parts.push(plural(counts.value.late, 'atrasada', 'atrasadas'))
  return parts.join(', ')
})
const selected = computed(() => ui.selected.map((id) => orders.value.find((o) => o.id === id)).filter(Boolean))
const selRest = computed(() => selected.value.reduce((s, o) => s + rest(o), 0))

function setSort(k) {
  sort.value = sort.value.key === k ? { key: k, dir: -sort.value.dir } : { key: k, dir: k === 'name' || k === 'who' ? 1 : -1 }
}
const ariaSort = (k) => (sort.value.key === k ? (sort.value.dir > 0 ? 'ascending' : 'descending') : undefined)
function open(o) { openId.value = o.id }
function move(step) {
  const i = rows.value.findIndex((o) => o.id === openId.value)
  const n = rows.value[Math.max(0, Math.min(rows.value.length - 1, i + step))]
  if (n) { openId.value = n.id; nextTick(() => document.getElementById('row-' + n.id)?.scrollIntoView({ block: 'nearest' })) }
}
function toggle(o) {
  const i = ui.selected.indexOf(o.id)
  if (i >= 0) ui.selected.splice(i, 1); else ui.selected.push(o.id)
}
function clear() { ui.selected = [] }
function batchStatus() {
  ui.picker = {
    title: 'Qual a situação?', sub: plural(selected.value.length, 'OS selecionada', 'OS selecionadas'),
    options: Object.entries(STATUS).filter(([k]) => k !== 'canceled').map(([id, s]) => ({ id, label: s.label, dot: s.dot })),
    onPick: (id) => {
      const list = selected.value
      act(`${plural(list.length, 'OS', 'OS')}: ${STATUS[id].label}`, () => list.forEach((o) => { o.status = id; if (id === 'done' || id === 'quote') o.hold = null }))
      clear()
    },
  }
}
function batchWho() {
  ui.picker = {
    title: 'Quem é o responsável?', sub: plural(selected.value.length, 'OS selecionada', 'OS selecionadas'),
    options: [{ id: '', label: 'Ninguém' }, ...db.value.team.map((p) => ({ id: p, label: p }))],
    onPick: (id) => {
      const list = selected.value
      act(id ? `Responsável: ${id}` : 'Sem responsável', () => list.forEach((o) => { o.assignee = id || null }))
      clear()
    },
  }
}
function keys(e) {
  if (ui.layers) return
  const typing = e.target.matches('input, textarea, select')
  if (typing) {
    if (e.key === 'Escape' && e.target === searchEl.value) { text.value = ''; e.target.blur() }
    if (e.key === 'ArrowDown' && e.target === searchEl.value) { e.preventDefault(); e.target.blur(); move(0) }
    return
  }
  if (e.ctrlKey || e.metaKey) {
    if (e.key === 'Enter' && openId.value) { e.preventDefault(); go('os', { id: openId.value, query: { page: 1 } }) }
    return
  }
  const k = e.key
  if (k === 'j' || k === 'ArrowDown') { e.preventDefault(); move(1) }
  else if (k === 'k' || k === 'ArrowUp') { e.preventDefault(); move(-1) }
  else if (k === '/') { e.preventDefault(); searchEl.value?.focus() }
  else if (k === ' ') {
    if (e.target.matches('button, a, label')) return
    e.preventDefault(); const o = rows.value.find((x) => x.id === openId.value); if (o) toggle(o)
  } else if (k === 'Enter' && !e.target.matches('button')) {
    e.preventDefault(); document.querySelector('[data-od-focus]')?.focus()
  } else if (k === 'Escape') {
    if (ui.selected.length) clear(); else openId.value = null
  }
}
watch(() => [route.id, route.query.q, route.query.f], ([id, q, f]) => {
  if (q !== undefined) text.value = q
  if (f) filter.value = f
  if (id) {
    openId.value = id
    if (!rows.value.some((o) => o.id === id)) { filter.value = 'all'; text.value = '' }
    nextTick(() => document.getElementById('row-' + id)?.scrollIntoView({ block: 'nearest' }))
  }
})
// An order that leaves the filter stays open in the panel; only a new filter picks another one.
watch([filter, text, who], () => { if (openId.value && !rows.value.some((o) => o.id === openId.value)) openId.value = rows.value[0]?.id ?? null })
onMounted(() => {
  window.addEventListener('keydown', keys)
  ui.cursorClose = () => { openId.value = null }
  if (!openId.value && rows.value.length && window.innerWidth >= 1100) openId.value = rows.value[0].id
  if (route.id && !rows.value.some((o) => o.id === route.id)) filter.value = 'all'
})
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>

<template>
  <OrdersHead :title="title">
    <button v-if="!selected.length" class="btn hide-phone" :class="{ 'btn--primary': !openId }" @click="ui.newOrderSeed = null; ui.newOrder = true">Nova OS <kbd>N</kbd></button>
  </OrdersHead>

  <template v-if="orders.length">
    <div class="toolbar">
      <div v-if="selected.length" class="batchbar" role="region" aria-label="Ações em lote">
        <strong>{{ plural(selected.length, 'selecionada', 'selecionadas') }}</strong>
        <button v-if="selRest" class="btn btn--primary" @click="ui.receive = [...ui.selected]">Receber {{ brl(selRest) }}</button>
        <button class="btn" @click="batchStatus">Mudar situação</button>
        <button class="btn" @click="batchWho">Responsável</button>
        <button class="btn btn--ghost" @click="clear">Limpar <kbd>Esc</kbd></button>
      </div>
      <template v-else>
        <div class="chips" role="group" aria-label="Filtros">
          <button v-for="v in visibleViews" :key="v.id" class="chip" :class="{ 'chip--danger': v.danger && counts[v.id] }" :aria-pressed="filter === v.id" @click="filter = v.id">
            {{ v.label }} <span class="num">{{ counts[v.id] }}</span>
          </button>
        </div>
        <span class="spacer"></span>
        <select v-model="who" class="field select-mini" aria-label="Responsável">
          <option value="">Toda a equipe</option><option v-for="p in db.team" :key="p">{{ p }}</option>
        </select>
        <input ref="searchEl" v-model="text" class="field search-mini" aria-label="Filtrar a lista" :placeholder="filterHint">
      </template>
    </div>

    <div class="workspace" :class="{ 'has-panel': openId }">
      <div class="list-pane" :tabindex="phone ? 0 : undefined" :aria-label="phone ? 'Lista de OS' : undefined">
        <table v-if="rows.length" class="grid">
          <thead>
            <tr>
              <th class="c-check"><span class="sr">Selecionar</span></th>
              <th class="c-num" :aria-sort="ariaSort('number')"><button @click="setSort('number')">OS <ArrowDown v-if="sort.key === 'number' && sort.dir < 0" :size="12" /><ArrowUp v-if="sort.key === 'number' && sort.dir > 0" :size="12" /></button></th>
              <th :aria-sort="ariaSort('name')"><button @click="setSort('name')">Cliente <ArrowUp v-if="sort.key === 'name'" :size="12" /></button></th>
              <th class="c-device">{{ db.labels.device }}</th>
              <th>Situação</th>
              <th :aria-sort="ariaSort('when')"><button @click="setSort('when')">Quando <ArrowUp v-if="sort.key === 'when'" :size="12" /></button></th>
              <th class="c-who" :aria-sort="ariaSort('who')"><button @click="setSort('who')">Responsável</button></th>
              <th class="c-money" :aria-sort="ariaSort('value')"><button @click="setSort('value')">Valor <ArrowDown v-if="sort.key === 'value'" :size="12" /></button></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="o in rows" :id="'row-' + o.id" :key="o.id" :class="{ 'is-open': o.id === openId }" :aria-selected="o.id === openId" @click="open(o)" @dblclick="go('os', { id: o.id, query: { page: 1 } })">
              <td class="c-check" @click.stop><input class="check" type="checkbox" :checked="ui.selected.includes(o.id)" :aria-label="`Selecionar OS ${o.number}`" @change="toggle(o)"></td>
              <td class="c-num"><span class="num">{{ o.number }}</span></td>
              <td>
                <span class="who">{{ customerOf(o).name }}</span>
                <span class="sub sub--device">{{ deviceOf(o)?.label }} <span v-if="db.labels.tagLabel === 'Placa'" class="num">{{ deviceOf(o)?.tag }}</span></span>
              </td>
              <td class="c-device"><span class="sub">{{ deviceOf(o)?.label }} <span class="num">{{ deviceOf(o)?.tag }}</span></span></td>
              <td><StatusLabel :order="o" /></td>
              <td class="c-when"><span class="sub" style="font-size: inherit">{{ whenLabel(o) }}</span></td>
              <td class="c-who">{{ o.assignee || '' }}</td>
              <td class="c-money"><span class="num">{{ brl(total(o)) }}</span><span v-if="o.status === 'done' && rest(o) > 0" class="owed">falta {{ brl(rest(o)) }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-else-if="text" class="empty">
          <h2>Nada com “{{ text }}”</h2>
          <p>Tente o nome, a placa, o telefone ou o número da OS.</p>
          <button class="btn" @click="text = ''">Limpar a busca</button>
        </div>
        <div v-else class="empty">
          <h2>Nenhuma OS aqui</h2>
          <p>Nada nesse filtro agora.</p>
          <button class="btn" @click="filter = 'all'; who = ''">Ver todas</button>
        </div>
      </div>
      <OrderDetail v-if="openId" :key="openId" :order-id="openId" />
    </div>
  </template>

  <div v-else class="empty">
    <h2>Sua primeira OS começa aqui</h2>
    <p>Escolha o cliente, o que vai ser feito e pronto. Leva menos de um minuto.</p>
    <button class="btn" @click="ui.newOrder = true">Criar a primeira OS</button>
  </div>
</template>
