<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { db, ui, go, customerOf, deviceOf, rest, total, paid, act, chargeOf, createCharge, greeting, clientLink, methodLabel, servicesOf, partsOf, phone } from '../store.js'
import { NOW, brl, brlShort, plural, dayMonth } from '../format.js'
import FinanceHead from './FinanceHead.vue'

const MONTHS = 6
const orders = computed(() => db.value.orders)
const history = computed(() => db.value.history || [])
// Early in the month there is little to read, so it opens on the month that just closed.
const offset = ref(NOW.getDate() <= 7 ? 1 : 0)
const tab = ref('received')
const cursor = ref(0)
const snoozed = ref([])
const showAll = ref(false)

const monthStart = (off) => new Date(NOW.getFullYear(), NOW.getMonth() - off, 1)
const inMonth = (at, off) => { const d = new Date(at); const m = monthStart(off); return d.getFullYear() === m.getFullYear() && d.getMonth() === m.getMonth() }
const monthName = (off) => monthStart(off).toLocaleDateString('pt-BR', { month: 'long' })
const monthShort = (off) => monthStart(off).toLocaleDateString('pt-BR', { month: 'short' }).replace('.', '')
const monthYear = (off) => monthStart(off).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
const nameOf = (id) => db.value.customers.find((c) => c.id === id)?.name || 'Sem cliente'

function receivedIn(off) {
  const live = orders.value.flatMap((o) => o.payments.filter((p) => inMonth(p.at, off)).map((p) => ({
    key: p.id, at: p.at, amount: p.amount, method: p.method, number: o.number, customerId: o.customerId, orderId: o.id,
  })))
  const old = history.value.filter((h) => inMonth(h.paidAt, off)).map((h) => ({
    key: h.id + 'p', at: h.paidAt, amount: h.total, method: h.method, number: h.number, customerId: h.customerId, orderId: null,
  }))
  return [...live, ...old].sort((a, b) => new Date(b.at) - new Date(a.at))
}
function soldIn(off) {
  const live = orders.value.filter((o) => o.status !== 'canceled' && inMonth(o.createdAt, off)).map((o) => ({
    key: 'o' + o.id, at: o.createdAt, total: total(o), services: servicesOf(o), parts: partsOf(o), number: o.number, customerId: o.customerId, orderId: o.id,
    items: o.items.map((i) => ({ name: i.name, value: i.qty * i.price })),
  }))
  const old = history.value.filter((h) => inMonth(h.at, off)).map((h) => ({ ...h, key: h.id, orderId: null }))
  return [...live, ...old].sort((a, b) => new Date(b.at) - new Date(a.at))
}
const sumOf = (list, k) => list.reduce((s, x) => s + x[k], 0)

const received = computed(() => receivedIn(offset.value))
const sold = computed(() => soldIn(offset.value))
const receivedSum = computed(() => sumOf(received.value, 'amount'))
const soldSum = computed(() => sumOf(sold.value, 'total'))
const compare = computed(() => {
  if (offset.value === 0 || offset.value >= MONTHS - 1) return ''
  const diff = receivedSum.value - sumOf(receivedIn(offset.value + 1), 'amount')
  const prev = monthName(offset.value + 1)
  if (!diff) return `Igual a ${prev}`
  return `${brlShort(Math.abs(diff))} a ${diff > 0 ? 'mais' : 'menos'} que em ${prev}`
})

const bars = computed(() => Array.from({ length: MONTHS }, (_, i) => {
  const off = MONTHS - 1 - i
  return { off, value: sumOf(receivedIn(off), 'amount'), label: monthShort(off), name: monthName(off) }
}))
const barMax = computed(() => Math.max(1, ...bars.value.map((b) => b.value)))
const short = (v) => (v >= 1000 ? `${(v / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 })} mil` : brlShort(v).replace('R$', '').trim())

const services = computed(() => sumOf(sold.value, 'services'))
const parts = computed(() => sumOf(sold.value, 'parts'))
const servicesShare = computed(() => { const t = services.value + parts.value; return t ? Math.round(services.value / t * 100) : 0 })

function top(list) { return [...list.entries()].map(([id, value]) => ({ id, value })).sort((a, b) => b.value - a.value).slice(0, 5) }
const topCustomers = computed(() => {
  const m = new Map(); sold.value.forEach((s) => m.set(s.customerId, (m.get(s.customerId) || 0) + s.total))
  return top(m).map((t) => ({ ...t, name: nameOf(t.id) }))
})
const topItems = computed(() => {
  const m = new Map(); sold.value.forEach((s) => s.items.forEach((i) => m.set(i.name, (m.get(i.name) || 0) + i.value)))
  return top(m)
})

const owedOrders = computed(() => orders.value.filter((o) => o.status === 'done' && rest(o) > 0))
const running = computed(() => orders.value.filter((o) => ['approved', 'progress'].includes(o.status)))
const inProgress = computed(() => running.value.filter((o) => paid(o) === 0))
const owedSum = computed(() => sumOf(owedOrders.value.map((o) => ({ v: rest(o) })), 'v'))
const progressSum = computed(() => sumOf(inProgress.value.map((o) => ({ v: total(o) })), 'v'))
const owedPeople = computed(() => new Set(owedOrders.value.map((o) => o.customerId)).size)

const since = (o) => o.sentAt || o.createdAt
const nextDebtor = computed(() => {
  const m = new Map()
  owedOrders.value.filter((o) => !chargeOf(o) && !snoozed.value.includes(o.customerId)).forEach((o) => {
    const g = m.get(o.customerId) || { id: o.customerId, orders: [], total: 0, since: since(o) }
    g.orders.push(o); g.total += rest(o)
    if (new Date(since(o)) < new Date(g.since)) g.since = since(o)
    m.set(o.customerId, g)
  })
  return [...m.values()].sort((a, b) => new Date(a.since) - new Date(b.since))[0] || null
})
function sendCharge() {
  const d = nextDebtor.value
  const c = customerOf(d.orders[0])
  ui.assist = {
    title: `Mandar cobrança a ${c.name}?`,
    body: 'Uma mensagem com link de pagamento. Nada sai sem a sua confirmação.',
    lines: d.orders.map((o) => ({ id: o.id, text: `OS ${o.number}`, right: brl(rest(o)) })),
    sample: `Olá, ${greeting(c)}! Aqui é da ${db.value.company}. Ficou em aberto ${brl(d.total)} do serviço. Você paga por Pix, boleto ou cartão neste link: ${clientLink(d.orders[0])}.`,
    label: 'Mandar cobrança',
    onApply: () => act(`Cobrança enviada para ${c.name}`, () => createCharge(d.orders)),
  }
}

const rows = computed(() => {
  if (tab.value === 'received') return received.value.map((r) => ({
    key: r.key, name: nameOf(r.customerId), number: r.number, sub: `${dayMonth(r.at)}, ${methodLabel(r.method)}`, amount: r.amount,
    open: () => (r.orderId ? (ui.peek = r.orderId) : go('clientes', { id: r.customerId })),
  }))
  if (tab.value === 'sold') return sold.value.map((s) => ({
    key: s.key, name: nameOf(s.customerId), number: s.number, sub: dayMonth(s.at), amount: s.total,
    open: () => (s.orderId ? (ui.peek = s.orderId) : go('clientes', { id: s.customerId })),
  }))
  return inProgress.value.map((o) => ({
    key: 'l' + o.id, name: customerOf(o).name, number: o.number, sub: deviceOf(o)?.label || '', amount: total(o), open: () => { ui.peek = o.id },
  }))
})
const listTitle = computed(() => ({
  received: `Recebido em ${monthName(offset.value)}`, sold: `Vendido em ${monthName(offset.value)}`, progress: 'Em andamento hoje',
}[tab.value]))
const emptyText = computed(() => ({
  received: `Nenhum pagamento em ${monthName(offset.value)}.`, sold: `Nenhuma OS em ${monthName(offset.value)}.`, progress: 'Nenhuma OS em andamento sem pagamento.',
}[tab.value]))
const title = computed(() => {
  const m = monthName(offset.value)
  if (!receivedSum.value) return `Nada entrou em ${m}`
  return offset.value ? `Em ${m} entraram ${brl(receivedSum.value)}` : `Em ${m}, até hoje, entraram ${brl(receivedSum.value)}`
})
const PHONE_ROWS = 8
const visibleRows = computed(() => (phone.value && !showAll.value ? rows.value.slice(0, PHONE_ROWS) : rows.value))
function pick(t) { tab.value = t; cursor.value = 0; showAll.value = false }
function step(n) { offset.value = Math.min(MONTHS - 1, Math.max(0, offset.value + n)); cursor.value = 0 }
function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select')) return
  if (e.key === 'ArrowLeft') { e.preventDefault(); step(1) }
  if (e.key === 'ArrowRight') { e.preventDefault(); step(-1) }
  if (e.key === 'j' || e.key === 'ArrowDown') { e.preventDefault(); cursor.value = Math.min(rows.value.length - 1, cursor.value + 1) }
  if (e.key === 'k' || e.key === 'ArrowUp') { e.preventDefault(); cursor.value = Math.max(0, cursor.value - 1) }
  if (e.key === 'Enter' && !e.target.matches('button')) rows.value[cursor.value]?.open()
}
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>
<template>
  <template v-if="orders.length || history.length">
    <FinanceHead :title="title" sub="Só conta o que veio das OS. Despesas não entram aqui.">
      <div class="fin-month" role="group" aria-label="Mês">
        <button class="icon-btn" :disabled="offset >= MONTHS - 1" aria-label="Mês anterior" @click="step(1)"><ChevronLeft :size="18" aria-hidden="true" /></button>
        <span aria-live="polite">{{ monthYear(offset) }}</span>
        <button class="icon-btn" :disabled="offset === 0" aria-label="Mês seguinte" @click="step(-1)"><ChevronRight :size="18" aria-hidden="true" /></button>
      </div>
    </FinanceHead>
    <div class="fin">
      <div v-if="nextDebtor" class="next fin-next">
        <p><strong>Próxima cobrança</strong>{{ customerOf(nextDebtor.orders[0]).name }} deve {{ brl(nextDebtor.total) }} desde {{ dayMonth(nextDebtor.since) }}.</p>
        <button class="btn btn--primary" @click="sendCharge">Mandar cobrança</button>
        <button class="btn btn--ghost" @click="snoozed = [...snoozed, nextDebtor.id]">Agora não</button>
      </div>
      <div class="fin-cards">
        <div class="fin-group">
          <h2>Em {{ monthName(offset) }}</h2>
          <div>
            <button class="fin-card" :aria-pressed="tab === 'received'" @click="pick('received')"><span>Recebido</span><b>{{ brl(receivedSum) }}</b><small>{{ compare || plural(received.length, 'pagamento', 'pagamentos') }}</small></button>
            <button class="fin-card" :aria-pressed="tab === 'sold'" @click="pick('sold')"><span>Vendido</span><b>{{ brl(soldSum) }}</b><small>{{ plural(sold.length, 'OS', 'OS') }}</small></button>
          </div>
        </div>
        <div class="fin-group">
          <h2>Hoje</h2>
          <div>
            <button class="fin-card" @click="go('receber')"><span>Falta receber</span><b>{{ brl(owedSum) }}</b><small>{{ owedPeople ? `De ${plural(owedPeople, 'cliente', 'clientes')}` : 'Tudo em dia' }}</small></button>
            <button class="fin-card" :aria-pressed="tab === 'progress'" @click="pick('progress')"><span>Em andamento</span><b>{{ brl(progressSum) }}</b><small>{{ plural(inProgress.length, 'OS', 'OS') }}</small></button>
          </div>
        </div>
      </div>
      <div class="fin-body">
        <div class="fin-side">
          <section aria-labelledby="f-bars">
            <h2 id="f-bars">Recebido por mês</h2>
            <div class="fin-bars">
              <button v-for="b in bars" :key="b.off" class="fin-bar" :aria-pressed="b.off === offset" :aria-label="`${b.name}: ${brl(b.value)}`" :title="`${b.name}: ${brl(b.value)}`" @click="offset = b.off">
                <span class="fin-bar-val num">{{ short(b.value) }}</span>
                <span class="fin-bar-track"><i :style="{ height: Math.max(2, b.value / barMax * 100) + '%' }"></i></span>
                <span class="fin-bar-name">{{ b.label }}</span>
              </button>
            </div>
            <p v-if="offset === 0 || bars[MONTHS - 1].off === 0" class="sub">{{ monthName(0) }} vai até hoje.</p>
          </section>
          <section v-if="services + parts" aria-labelledby="f-mix">
            <h2 id="f-mix">Serviços e peças em {{ monthName(offset) }}</h2>
            <div class="fin-mix" aria-hidden="true"><i :style="{ width: servicesShare + '%' }"></i><u></u></div>
            <dl class="fin-legend">
              <div><dt><i class="sw sw--a"></i>Serviços, {{ servicesShare }}%</dt><dd class="num">{{ brl(services) }}</dd></div>
              <div><dt><i class="sw sw--b"></i>Peças, {{ 100 - servicesShare }}%</dt><dd class="num">{{ brl(parts) }}</dd></div>
            </dl>
          </section>
          <section v-if="topCustomers.length" aria-labelledby="f-top">
            <h2 id="f-top">Quem mais comprou</h2>
            <button v-for="c in topCustomers" :key="c.id" class="fin-rank" @click="go('clientes', { id: c.id })"><span>{{ c.name }}</span><span class="num">{{ brl(c.value) }}</span></button>
          </section>
          <section v-if="topItems.length" aria-labelledby="f-items">
            <h2 id="f-items">O que mais vendeu</h2>
            <div v-for="i in topItems" :key="i.id" class="fin-rank fin-rank--plain"><span>{{ i.id }}</span><span class="num">{{ brl(i.value) }}</span></div>
          </section>
        </div>
        <section class="fin-list" aria-labelledby="f-list">
          <div class="fin-list-head"><h2 id="f-list">{{ listTitle }}</h2></div>
          <template v-for="(r, i) in visibleRows" :key="r.key">
            <button class="fin-row" :class="{ 'is-open': cursor === i }" @click="cursor = i; r.open()">
              <span><span class="who">{{ r.name }}</span> <span class="sub num">OS {{ r.number }}</span><span class="sub fin-row-sub">{{ r.sub }}</span></span>
              <span class="num">{{ brl(r.amount) }}</span>
            </button>
          </template>
          <button v-if="visibleRows.length < rows.length" class="btn fin-all" @click="showAll = true">Ver todos os {{ rows.length }}</button>
          <p v-if="!rows.length" class="muted fin-none">{{ emptyText }}</p>
        </section>
      </div>
    </div>
  </template>
  <template v-else>
    <FinanceHead title="Financeiro" />
    <div class="empty">
      <h2>O financeiro aparece depois da primeira OS</h2>
      <p>Quando você anotar um recebimento, ele entra aqui, mês a mês.</p>
      <button class="btn" @click="ui.newOrder = true">Criar a primeira OS <kbd>N</kbd></button>
    </div>
  </template>
</template>
