<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue'
import { X, ChevronLeft, MoreHorizontal } from 'lucide-vue-next'
import {
  db, ui, go, route, toast, customerOf, orderById, canInvoice, invoiceValue, partsOf, invoiceNeeds, issueInvoices, INVOICE_STATUS, act, phone } from '../store.js'
import { NOW, brl, dayMonth, plural } from '../format.js'
import Layer from '../components/Layer.vue'

const auto = ref('manual')
const tab = ref('todo')
const selected = ref(route.query.o ? [route.query.o] : [])
const clientOnly = ref(route.query.c || null)
const openId = ref(null)
const invoices = computed(() => db.value.invoices)
const isRefused = (o) => invoices.value.some((n) => n.status === 'error' && n.orderIds.includes(o.id))
const pending = computed(() => db.value.orders.filter((o) => canInvoice(o) && !isRefused(o) && (!clientOnly.value || o.customerId === clientOnly.value)))
const issued = computed(() => invoices.value.filter((n) => ['sent', 'issued'].includes(n.status)))
const refused = computed(() => invoices.value.filter((n) => n.status === 'error'))
const shown = computed(() => (tab.value === 'issued' ? issued.value : tab.value === 'error' ? refused.value : invoices.value))
const current = computed(() => shown.value.find((n) => n.id === openId.value) || null)
const AUTO = [['manual', 'Só quando eu pedir'], ['paid', 'Quando a OS for paga'], ['done', 'Quando a OS for concluída']]
function menu() {
  ui.picker = {
    title: 'Notas fiscais',
    options: [...(issued.value.length ? [{ id: 'accountant', label: 'Mandar ao contador' }] : []), { id: 'auto', label: `Quando emitir: ${AUTO.find(([k]) => k === auto.value)[1]}` }],
    onPick: (id) => {
      if (id === 'accountant') sendAccountant()
      else ui.picker = { title: 'Quando emitir?', options: AUTO.map(([k, label]) => ({ id: k, label, current: k === auto.value })), onPick: (k) => { auto.value = k } }
    },
  }
}
const title = computed(() => {
  if (refused.value.length) return `${plural(refused.value.length, 'nota recusada', 'notas recusadas')}, ${plural(pending.value.length, 'nota para fazer', 'notas para fazer')}`
  return pending.value.length ? `${plural(pending.value.length, 'OS pronta', 'OS prontas')} para a nota` : 'Nenhuma nota para emitir'
})
const missing = (o) => invoiceNeeds(customerOf(o))
const picked = computed(() => selected.value.map(orderById).filter(Boolean))
const pickedSum = computed(() => picked.value.reduce((s, o) => s + invoiceValue(o), 0))
const sameClient = computed(() => picked.value.length > 1 && new Set(picked.value.map((o) => o.customerId)).size === 1)
const isOn = (o) => selected.value.includes(o.id)
function toggle(o) { selected.value = isOn(o) ? selected.value.filter((x) => x !== o.id) : [...selected.value, o.id] }
const allOn = computed(() => pending.value.length && pending.value.every(isOn))
function toggleAll() { selected.value = allOn.value ? [] : pending.value.map((o) => o.id) }

/* Before anything goes to the city hall the person sees the value and fixes what is missing here. */
const issuing = ref(null)
const issueOrders = computed(() => (issuing.value?.ids || []).map(orderById).filter(Boolean))
const issueClients = computed(() => [...new Map(issueOrders.value.map((o) => [o.customerId, customerOf(o)])).values()])
const issueBlocked = computed(() => issueClients.value.filter((c) => invoiceNeeds(c).length))
const issueCount = computed(() => (issuing.value?.joined ? 1 : issueOrders.value.length))
const issueSum = computed(() => issueOrders.value.reduce((s, o) => s + invoiceValue(o), 0))
const issueParts = computed(() => issueOrders.value.some((o) => partsOf(o) > 0))
function askIssue(ids, joined = false) { issuing.value = { ids, joined } }
function confirmIssue() {
  if (issueBlocked.value.length) return
  const orders = issueOrders.value
  issueInvoices(issuing.value.joined ? [orders] : orders.map((o) => [o]))
  ui.live = 'Enviado à prefeitura'
  toast(`${plural(issueCount.value, 'nota enviada', 'notas enviadas')} à prefeitura`)
  issuing.value = null; selected.value = []; clientOnly.value = null; tab.value = 'issued'; openId.value = null
}
const statusOf = (n) => INVOICE_STATUS[n.status]
const ordersOf = (n) => n.orderIds.map(orderById).filter(Boolean)
const nameOf = (n) => db.value.customers.find((c) => c.id === n.customerId)?.name || 'Cliente'
function retry(n) { askIssue([...n.orderIds]) }
function cancel(n) {
  ui.confirm = {
    title: `Cancelar a nota ${n.number}?`, body: 'O pedido vai para a prefeitura. A OS fica livre para outra nota.',
    label: 'Cancelar nota', keep: 'Manter nota', danger: true,
    onOk: () => act(`Nota ${n.number} cancelada`, () => { n.status = 'canceled' }),
  }
}
function sendClient(n) {
  navigator.clipboard?.writeText(`Olá! Aqui é da ${db.value.company}. Sua nota fiscal nº ${n.number}: praticos.web.app/nota/exemplo-${n.number}`).catch(() => {})
  toast('Mensagem copiada. Cole no WhatsApp do cliente.')
}
const month = NOW.toLocaleDateString('pt-BR', { month: 'long' })
function sendAccountant() {
  const list = issued.value.filter((n) => n.status === 'issued')
  ui.assist = {
    title: `Mandar as notas de ${month} ao contador?`,
    body: 'Preparei um link com as notas. Você cola no e-mail ou no WhatsApp do contador.',
    lines: [{ id: 'q', text: plural(list.length, 'nota emitida', 'notas emitidas'), right: brl(list.reduce((s, n) => s + n.value, 0)) }],
    label: 'Copiar link', onApply: () => toast('Link copiado'),
  }
}
function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select') && e.target.type !== 'checkbox') return
  if (e.key === 'Escape') selected.value = []
}
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p class="page-sub">A nota leva só os serviços. As peças ficam de fora.</p>
    </div>
    <span class="spacer"></span>
    <button class="icon-btn" aria-label="Mais ações" title="Mais ações" @click="menu"><MoreHorizontal :size="18" aria-hidden="true" /></button>
  </header>
  <div class="toolbar">
    <div v-if="tab === 'todo' && picked.length" class="batchbar" role="region" aria-label="Ações em lote">
      <strong>{{ plural(picked.length, 'OS', 'OS') }}: <span class="num">{{ brl(pickedSum) }}</span></strong>
      <button class="btn btn--primary" @click="askIssue([...selected])">{{ picked.length === 1 ? 'Emitir nota' : `Emitir ${picked.length} notas` }}</button>
      <button v-if="sameClient" class="btn" @click="askIssue([...selected], true)">Uma nota só</button>
      <button class="btn btn--ghost" @click="selected = []">Limpar <kbd>Esc</kbd></button>
    </div>
    <div v-else class="chips" role="group" aria-label="Filtros">
      <button class="chip" :aria-pressed="tab === 'todo'" @click="tab = 'todo'">Falta fazer <span class="num">{{ pending.length }}</span></button>
      <button class="chip" :aria-pressed="tab === 'issued'" @click="tab = 'issued'">Emitidas <span class="num">{{ issued.length }}</span></button>
      <button v-if="refused.length" class="chip chip--danger" :aria-pressed="tab === 'error'" @click="tab = 'error'">Recusadas <span class="num">{{ refused.length }}</span></button>
      <button class="chip" :aria-pressed="tab === 'all'" @click="tab = 'all'">Todas <span class="num">{{ invoices.length }}</span></button>
      <span v-if="clientOnly" class="muted small">Só {{ db.customers.find((c) => c.id === clientOnly)?.name }}. <button class="link" @click="clientOnly = null">Ver todos</button></span>
    </div>
  </div>
  <div v-if="tab === 'todo'" class="recv">
    <table v-if="pending.length" class="grid">
      <thead><tr>
        <th class="c-check"><input class="check" type="checkbox" :checked="allOn" aria-label="Selecionar todas" @change="toggleAll"></th>
        <th>Cliente e OS</th><th>Falta para emitir</th><th class="c-money">Valor da nota</th>
      </tr></thead>
      <tbody>
        <tr v-for="o in pending" :key="o.id" @click="toggle(o)">
          <td class="c-check" @click.stop><input class="check" type="checkbox" :checked="isOn(o)" :aria-label="`Selecionar OS ${o.number}`" @change="toggle(o)"></td>
          <td><span class="who">{{ customerOf(o).name }}</span><span class="sub"> <button class="link" @click.stop="ui.peek = o.id">OS {{ o.number }}</button></span></td>
          <td><span v-if="missing(o).length" class="status status--warn"><span class="dot dot--warning" aria-hidden="true"></span>Falta {{ missing(o).join(' e ') }}</span><span v-else class="status"><span class="dot dot--success" aria-hidden="true"></span>Nada, pode emitir</span></td>
          <td class="c-money"><span class="num">{{ brl(invoiceValue(o)) }}</span></td>
        </tr>
      </tbody>
    </table>
    <div v-else class="empty">
      <h2>Nenhuma OS esperando nota</h2>
      <p>Quando uma OS com serviço for concluída, ela aparece aqui.</p>
      <button class="btn" @click="go('os')">Ver as OS</button>
    </div>
  </div>
  <div v-else class="workspace" :class="{ 'has-panel': current }">
    <div class="list-pane">
      <table v-if="shown.length" class="grid">
        <thead><tr><th>Nota</th><th>Cliente</th><th>Situação</th><th class="c-money">Valor</th></tr></thead>
        <tbody>
          <tr v-for="n in shown" :key="n.id" :class="{ 'is-open': n.id === openId }" @click="openId = n.id">
            <td><button class="row-btn num" :aria-label="`Abrir nota de ${nameOf(n)}`" @click.stop="openId = n.id">{{ n.number || 'Sem número' }}</button><span class="sub block-line">{{ dayMonth(n.at) }}</span></td>
            <td><span class="who">{{ nameOf(n) }}</span><span class="sub block-line">OS {{ ordersOf(n).map((o) => o.number).join(', ') }}</span></td>
            <td><span class="status" :class="{ 'status--late': n.status === 'error' }"><span class="dot" :class="'dot--' + statusOf(n).dot" aria-hidden="true"></span>{{ statusOf(n).label }}</span></td>
            <td class="c-money"><span class="num">{{ brl(n.value) }}</span></td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty"><h2>Nenhuma nota aqui</h2><button class="btn" @click="tab = 'todo'">Ver o que falta emitir</button></div>
    </div>
    <section v-if="current" class="od" :aria-label="`Nota de ${nameOf(current)}`">
      <div class="od-scroll">
        <div class="od-top"><span class="num">{{ current.number ? `Nota ${current.number}` : 'Nota sem número' }}</span><span class="spacer"></span><button class="icon-btn" :aria-label="phone ? 'Voltar' : 'Fechar'" title="Fechar" @click="openId = null"><ChevronLeft v-if="phone" :size="22" /><X v-else :size="18" /></button></div>
        <header class="od-head">
          <h2 class="od-h"><span class="od-name od-name--plain">{{ nameOf(current) }}</span></h2>
          <div class="od-state"><span class="status" :class="{ 'status--late': current.status === 'error' }"><span class="dot" :class="'dot--' + statusOf(current).dot" aria-hidden="true"></span>{{ statusOf(current).label }}</span><span class="od-sentence num">{{ brl(current.value) }}</span></div>
          <div class="od-actions">
            <button v-if="current.status === 'issued'" class="btn btn--primary" @click="sendClient(current)">Mandar ao cliente</button>
            <button v-if="current.status === 'error'" class="btn btn--primary" @click="retry(current)">Emitir de novo</button>
          </div>
        </header>
        <section v-if="current.error" class="od-sec"><p class="warn warn--danger" role="status">{{ current.error }}</p></section>
        <section class="od-sec">
          <h3>Serviços na nota</h3>
          <template v-for="o in ordersOf(current)" :key="o.id">
            <div v-for="i in o.items.filter((x) => x.kind === 'service')" :key="i.id" class="pay-row"><span>{{ i.name }}</span><span class="num">{{ brl(i.qty * i.price) }}</span></div>
          </template>
        </section>
        <section class="od-sec">
          <h3>OS</h3>
          <button v-for="o in ordersOf(current)" :key="o.id" class="link hist-link" @click="ui.peek = o.id">OS {{ o.number }}</button>
        </section>
        <section v-if="current.status === 'issued'" class="od-sec"><button class="link link--danger" @click="cancel(current)">Cancelar nota</button></section>
      </div>
    </section>
  </div>
  <Layer v-if="issuing" label="Emitir nota" @close="issuing = null">
    <div class="layer-pad">
      <h2 class="layer-title">Emitir {{ plural(issueCount, 'nota', 'notas') }} de {{ brl(issueSum) }}?</h2>
      <p class="muted">Vai para a prefeitura. Depois disso, só cancelando.</p>
      <div class="preview-list"><div v-for="o in issueOrders" :key="o.id" class="pay-row"><span>{{ customerOf(o).name }}, OS {{ o.number }}</span><span class="num">{{ brl(invoiceValue(o)) }}</span></div></div>
      <p v-if="issueParts" class="muted small">As peças dessas OS não entram, porque a nota é só de serviço.</p>
      <div v-for="c in issueBlocked" :key="c.id" class="fix">
        <p class="warn" role="status">Para emitir, falta {{ invoiceNeeds(c).join(' e ') }} de {{ c.name }}.</p>
        <div class="fix-grid">
          <div v-if="!c.email"><label class="field-label" :for="'f-m' + c.id">E-mail</label><input :id="'f-m' + c.id" v-model.lazy="c.email" class="field"></div>
          <div v-if="!c.address"><label class="field-label" :for="'f-a' + c.id">Endereço</label><input :id="'f-a' + c.id" v-model.lazy="c.address" class="field"></div>
          <div v-if="!c.zip"><label class="field-label" :for="'f-z' + c.id">CEP</label><input :id="'f-z' + c.id" v-model.lazy="c.zip" class="field"></div>
        </div>
      </div>
    </div>
    <div class="layer-foot"><button class="btn" data-autofocus @click="issuing = null">Voltar</button><button class="btn btn--primary" :disabled="issueBlocked.length > 0" @click="confirmIssue">Emitir</button></div>
  </Layer>
</template>
