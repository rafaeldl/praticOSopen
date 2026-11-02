<script setup>
import { computed, ref, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { Plus, Trash2 } from 'lucide-vue-next'
import { db, ui, act, filterHint } from '../store.js'
import { brl, matches, plural, parseMoney, vMoney } from '../format.js'
import Layer from '../components/Layer.vue'

const text = ref(''); const filter = ref('all'); const selected = ref([]); const searchEl = ref(null)
const fmt = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const parse = parseMoney
const items = computed(() => db.value.catalog)
const services = computed(() => items.value.filter((i) => i.kind === 'service').length)
const rows = computed(() => items.value.filter((i) => (filter.value === 'all' || i.kind === filter.value) && (!text.value || matches(i.name, text.value))))
const soldIn = (i) => db.value.orders.filter((o) => o.items.some((x) => x.name === i.name)).length
const picked = computed(() => items.value.filter((i) => selected.value.includes(i.key)))
const allOn = computed(() => rows.value.length && rows.value.every((i) => selected.value.includes(i.key)))
function toggle(i) { selected.value = selected.value.includes(i.key) ? selected.value.filter((k) => k !== i.key) : [...selected.value, i.key] }
function toggleAll() { selected.value = allOn.value ? [] : rows.value.map((i) => i.key) }

function saveName(i, e) {
  const v = e.target.value.trim()
  if (!v) { e.target.value = i.name; return }
  if (v !== i.name) act('Nome salvo', () => { i.name = v })
}
function savePrice(i, e) {
  const v = parse(e.target.value)
  if (v === null) { e.target.value = fmt.format(i.price); return }
  e.target.value = fmt.format(v)
  if (v !== i.price) act(`${i.name}: ${brl(v)}`, () => { i.price = v })
}
function saveKind(i, e) { act('Tipo salvo', () => { i.kind = e.target.value }) }
function move(e, col, dir) {
  e.preventDefault()
  const here = e.target.closest('tr')
  const next = dir > 0 ? here.nextElementSibling : here.previousElementSibling
  e.target.blur()
  next?.querySelector(`[data-col="${col}"]`)?.select()
}
function revert(e, value) { e.target.value = value; e.target.blur() }

async function addItem() {
  text.value = ''; filter.value = 'all'
  const it = { key: 'n' + Date.now(), kind: 'service', name: 'Novo serviço', price: 0 }
  act('Item criado', () => db.value.catalog.unshift(it))
  await nextTick()
  document.querySelector('.cat [data-col="name"]')?.select()
}
function remove(i) {
  ui.confirm = {
    title: `Tirar ${i.name} do catálogo?`, body: 'As OS já feitas continuam com ele. Só deixa de aparecer nas sugestões.',
    label: 'Tirar do catálogo', keep: 'Manter', danger: true,
    onOk: () => act('Tirado do catálogo', () => { db.value.catalog = db.value.catalog.filter((x) => x !== i); selected.value = selected.value.filter((k) => k !== i.key) }),
  }
}

const pricing = ref(false); const way = ref('up'); const percent = ref('10'); const roundUp = ref(true)
const factor = computed(() => { const p = parse(percent.value) || 0; return way.value === 'up' ? 1 + p / 100 : Math.max(0, 1 - p / 100) })
const nextPrice = (i) => (roundUp.value ? Math.round(i.price * factor.value) : Math.round(i.price * factor.value * 100) / 100)
function applyPrices() {
  const list = picked.value
  act(`Preço de ${plural(list.length, 'item', 'itens')} atualizado`, () => list.forEach((i) => { i.price = nextPrice(i) }))
  pricing.value = false; selected.value = []
}
function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select') && e.target.type !== 'checkbox') return
  if (e.key === '/') { e.preventDefault(); searchEl.value?.focus() }
  if (e.key === 'Escape') selected.value = []
}
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ plural(services, 'serviço', 'serviços') }} e {{ items.length - services }} peças</h1>
      <p class="page-sub">Mude o preço direto na lista. As OS já feitas não mudam.</p>
    </div>
    <span class="spacer"></span>
    <button class="btn btn--primary" @click="addItem"><Plus :size="15" aria-hidden="true" />Novo item</button>
  </header>
  <div class="toolbar">
    <div v-if="picked.length" class="batchbar" role="region" aria-label="Ações em lote">
      <strong>{{ plural(picked.length, 'item', 'itens') }}</strong>
      <button class="btn" @click="pricing = true">Mudar preços</button>
      <button class="btn btn--ghost" @click="selected = []">Limpar <kbd>Esc</kbd></button>
    </div>
    <div v-else class="chips" role="group" aria-label="Filtros">
      <button class="chip" :aria-pressed="filter === 'all'" @click="filter = 'all'">Tudo <span class="num">{{ items.length }}</span></button>
      <button class="chip" :aria-pressed="filter === 'service'" @click="filter = 'service'">Serviços <span class="num">{{ services }}</span></button>
      <button class="chip" :aria-pressed="filter === 'part'" @click="filter = 'part'">Peças <span class="num">{{ items.length - services }}</span></button>
    </div>
    <span class="spacer"></span>
    <input ref="searchEl" v-model="text" class="field search-mini" aria-label="Filtrar catálogo" :placeholder="filterHint">
  </div>
  <div class="recv cat">
    <table v-if="rows.length" class="grid">
      <thead><tr>
        <th class="c-check"><input class="check" type="checkbox" :checked="allOn" aria-label="Selecionar todos" @change="toggleAll"></th>
        <th>Nome</th><th class="c-kind">Tipo</th><th class="c-money">Preço</th><th class="c-sold">Vendido em</th><th class="c-act"><span class="sr">Ações</span></th>
      </tr></thead>
      <tbody>
        <tr v-for="i in rows" :key="i.key" class="no-click">
          <td class="c-check"><input class="check" type="checkbox" :checked="selected.includes(i.key)" :aria-label="`Selecionar ${i.name}`" @change="toggle(i)"></td>
          <td><input class="cell" data-col="name" :value="i.name" :aria-label="`Nome de ${i.name}`" @change="saveName(i, $event)" @keydown.enter="move($event, 'name', 1)" @keydown.down="move($event, 'name', 1)" @keydown.up="move($event, 'name', -1)" @keydown.esc.stop="revert($event, i.name)"></td>
          <td class="c-kind"><select class="cell" :value="i.kind" :aria-label="`Tipo de ${i.name}`" @change="saveKind(i, $event)"><option value="service">Serviço</option><option value="part">Peça</option></select></td>
          <td class="c-money"><span class="cell-price"><span aria-hidden="true">R$</span><input v-money class="cell cell--num" data-col="price" :value="fmt.format(i.price)" :aria-label="`Preço de ${i.name}`" @change="savePrice(i, $event)" @keydown.enter="move($event, 'price', 1)" @keydown.down="move($event, 'price', 1)" @keydown.up="move($event, 'price', -1)" @keydown.esc.stop="revert($event, fmt.format(i.price))"></span></td>
          <td class="c-sold"><span class="muted">{{ soldIn(i) ? plural(soldIn(i), 'OS', 'OS') : 'Nenhuma OS' }}</span></td>
          <td class="c-act"><button class="remove" :aria-label="`Tirar ${i.name} do catálogo`" title="Tirar do catálogo" @click="remove(i)"><Trash2 :size="14" /></button></td>
        </tr>
      </tbody>
    </table>
    <div v-else class="empty"><h2>Nada com esse filtro</h2><button class="btn" @click="text = ''; filter = 'all'">Limpar filtro</button></div>
  </div>
  <Layer v-if="pricing" label="Mudar preços" @close="pricing = false">
    <form style="display: contents" @submit.prevent="applyPrices">
      <div class="layer-pad">
        <h2 class="layer-title">Mudar o preço de {{ plural(picked.length, 'item', 'itens') }}</h2>
        <div class="price-form">
          <div class="tabs"><button type="button" :aria-pressed="way === 'up'" @click="way = 'up'">Aumentar</button><button type="button" :aria-pressed="way === 'down'" @click="way = 'down'">Baixar</button></div>
          <label class="pct"><span class="sr">Porcentagem</span><input v-model="percent" class="field" inputmode="decimal" data-autofocus>%</label>
          <label class="tick"><input v-model="roundUp" class="check" type="checkbox">Arredondar para real inteiro</label>
        </div>
        <div class="preview-list">
          <div v-for="i in picked.slice(0, 6)" :key="i.key" class="pay-row"><span>{{ i.name }}</span><span class="num">{{ brl(i.price) }} → {{ brl(nextPrice(i)) }}</span></div>
          <p v-if="picked.length > 6" class="muted small">E mais {{ plural(picked.length - 6, 'item', 'itens') }}.</p>
        </div>
      </div>
      <div class="layer-foot"><button type="button" class="btn" @click="pricing = false">Voltar</button><button type="submit" class="btn btn--primary">Aplicar a {{ plural(picked.length, 'item', 'itens') }}</button></div>
    </form>
  </Layer>
</template>
