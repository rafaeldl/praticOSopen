<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue'
import { db, ui, go, customerOf, deviceOf, rest, doneAge, act, chargeOf, chargeLabel, createCharge, simulatePaid, clientLink, greeting } from '../store.js'
import { brl, plural } from '../format.js'
import FinanceHead from './FinanceHead.vue'

const filter = ref('all')
const selected = ref([])
const cursor = ref(null)
const pending = computed(() => db.value.orders.filter((o) => o.status === 'done' && rest(o) > 0))
const FILTERS = {
  all: () => true, old: (o) => doneAge(o) >= 7, link: (o) => !!chargeOf(o), nolink: (o) => !chargeOf(o),
}
const list = computed(() => pending.value.filter(FILTERS[filter.value]))
const groups = computed(() => {
  const m = new Map()
  list.value.forEach((o) => {
    const c = customerOf(o)
    if (!m.has(c.id)) m.set(c.id, { c, orders: [], total: 0, oldest: 0 })
    const g = m.get(c.id); g.orders.push(o); g.total += rest(o); g.oldest = Math.max(g.oldest, doneAge(o))
  })
  return [...m.values()].sort((a, b) => b.oldest - a.oldest)
})
const flat = computed(() => groups.value.flatMap((g) => g.orders))
const sum = computed(() => pending.value.reduce((s, o) => s + rest(o), 0))
const people = computed(() => new Set(pending.value.map((o) => o.customerId)).size)
const title = computed(() => (sum.value ? `${brl(sum.value)} para receber de ${plural(people.value, 'cliente', 'clientes')}` : 'Nada para receber'))
const picked = computed(() => selected.value.map((id) => pending.value.find((o) => o.id === id)).filter(Boolean))
const pickedSum = computed(() => picked.value.reduce((s, o) => s + rest(o), 0))
const pickedPeople = computed(() => new Set(picked.value.map((o) => o.customerId)).size)
const isOn = (o) => selected.value.includes(o.id)
function toggle(o) {
  selected.value = isOn(o) ? selected.value.filter((x) => x !== o.id) : [...selected.value, o.id]
}
const groupOn = (g) => g.orders.every(isOn)
function toggleGroup(g) {
  const ids = g.orders.map((o) => o.id)
  selected.value = groupOn(g) ? selected.value.filter((x) => !ids.includes(x)) : [...new Set([...selected.value, ...ids])]
}
const allOn = computed(() => flat.value.length && flat.value.every(isOn))
function toggleAll() { selected.value = allOn.value ? [] : flat.value.map((o) => o.id) }
function receive() { ui.receive = [...selected.value]; const stop = setInterval(() => { if (!ui.receive) { selected.value = selected.value.filter((id) => pending.value.some((o) => o.id === id)); clearInterval(stop) } }, 200) }
function charge() {
  const orders = picked.value
  const bySomeone = new Map()
  orders.forEach((o) => { const c = customerOf(o); const g = bySomeone.get(c.id); bySomeone.set(c.id, { name: c.name, v: (g?.v || 0) + rest(o), orders: [...(g?.orders || []), o] }) })
  const first = [...bySomeone.values()][0]
  ui.assist = {
    title: `Mandar cobrança a ${plural(bySomeone.size, 'cliente', 'clientes')}?`,
    body: 'Uma mensagem com link de pagamento para cada um. Quem deve mais de uma OS paga tudo no mesmo link. Nada sai sem a sua confirmação.',
    lines: [...bySomeone.values()].map((p) => ({ id: p.name, text: p.name, right: brl(p.v) })),
    sample: `Olá, ${greeting(customerOf(first.orders[0]))}! Aqui é da ${db.value.company}. Ficou em aberto ${brl(first.v)} do serviço. Você paga por Pix, boleto ou cartão neste link: ${clientLink(first.orders[0])}.`,
    label: `Mandar para ${plural(bySomeone.size, 'cliente', 'clientes')}`,
    onApply: () => {
      act(`Cobrança enviada para ${plural(bySomeone.size, 'cliente', 'clientes')}`, () => [...bySomeone.values()].forEach((p) => createCharge(p.orders)))
      selected.value = []
    },
  }
}
function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select') && e.target.type !== 'checkbox') return
  const i = flat.value.findIndex((o) => o.id === cursor.value)
  if (e.key === 'j' || e.key === 'ArrowDown') { e.preventDefault(); cursor.value = flat.value[Math.min(flat.value.length - 1, i + 1)]?.id }
  if (e.key === 'k' || e.key === 'ArrowUp') { e.preventDefault(); cursor.value = flat.value[Math.max(0, i - 1)]?.id }
  if (e.key === ' ' && cursor.value) { e.preventDefault(); toggle(flat.value[i]) }
  if (e.key === 'r' && selected.value.length) { e.preventDefault(); receive() }
  if (e.key === 'Escape') selected.value = []
}
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>
<template>
  <FinanceHead :title="title" :sub="sum ? 'Marque quem já pagou ou mande cobrança para vários de uma vez.' : ''" />
  <template v-if="pending.length">
    <div class="toolbar">
      <div v-if="picked.length" class="batchbar" role="region" aria-label="Ações em lote">
        <strong>{{ plural(picked.length, 'OS', 'OS') }} de {{ plural(pickedPeople, 'cliente', 'clientes') }}: <span class="num">{{ brl(pickedSum) }}</span></strong>
        <button class="btn btn--primary" @click="receive">Marcar como recebido <kbd>R</kbd></button>
        <button class="btn" @click="charge">Mandar cobrança</button>
        <button class="btn btn--ghost" @click="selected = []">Limpar <kbd>Esc</kbd></button>
      </div>
      <div v-else class="chips" role="group" aria-label="Filtros">
        <button class="chip" :aria-pressed="filter === 'all'" @click="filter = 'all'">Todas <span class="num">{{ pending.length }}</span></button>
        <button class="chip" :aria-pressed="filter === 'old'" @click="filter = 'old'">Há mais de 7 dias <span class="num">{{ pending.filter(FILTERS.old).length }}</span></button>
        <button class="chip" :aria-pressed="filter === 'link'" @click="filter = 'link'">Com link enviado <span class="num">{{ pending.filter(FILTERS.link).length }}</span></button>
        <button class="chip" :aria-pressed="filter === 'nolink'" @click="filter = 'nolink'">Sem link <span class="num">{{ pending.filter(FILTERS.nolink).length }}</span></button>
      </div>
    </div>
    <div class="recv">
      <table class="grid">
        <thead>
          <tr>
            <th class="c-check"><input class="check" type="checkbox" :checked="allOn" aria-label="Selecionar todas" @change="toggleAll"></th>
            <th>Cliente e OS</th><th class="c-age">Pronta há</th><th class="c-money">Falta receber</th>
          </tr>
        </thead>
        <tbody v-for="g in groups" :key="g.c.id">
          <tr class="group" @click="toggleGroup(g)">
            <td class="c-check" @click.stop><input class="check" type="checkbox" :checked="groupOn(g)" :aria-label="`Selecionar tudo de ${g.c.name}`" @change="toggleGroup(g)"></td>
            <td>{{ g.c.name }} <span class="sub">{{ g.c.phone }}</span></td>
            <td class="c-age"></td>
            <td class="c-money"><span class="num">{{ brl(g.total) }}</span></td>
          </tr>
          <tr v-for="o in g.orders" :key="o.id" :class="{ 'is-open': cursor === o.id }" @click="toggle(o)">
            <td class="c-check" @click.stop><input class="check" type="checkbox" :checked="isOn(o)" :aria-label="`Selecionar OS ${o.number}`" @change="toggle(o)"></td>
            <td>
              <button class="link" @click.stop="ui.peek = o.id">OS {{ o.number }}</button>
              <span class="sub"> {{ deviceOf(o)?.label }}</span>
              <span v-if="chargeOf(o)" class="sub block-line">{{ chargeLabel(o) }} <button class="proto-sim" @click.stop="simulatePaid(chargeOf(o))">Simular: pagou</button></span>
            </td>
            <td class="c-age"><span :class="{ 'muted': doneAge(o) < 7 }">{{ plural(Math.max(1, doneAge(o)), 'dia', 'dias') }}</span></td>
            <td class="c-money"><span class="num">{{ brl(rest(o)) }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </template>
  <div v-else class="empty">
    <h2>Tudo recebido</h2>
    <p>Quando uma OS ficar pronta sem pagamento, ela aparece aqui.</p>
    <button class="btn" @click="go('os')">Ver as OS</button>
  </div>
</template>
