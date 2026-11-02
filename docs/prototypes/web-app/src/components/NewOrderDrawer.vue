<script setup>
import { computed, ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { X, Check, Trash2 } from 'lucide-vue-next'
import { db, ui, go, createOrder, createCustomer, createDevice, toast, assistantRead, customerOf, touch } from '../store.js'
import { brl, matches, parseWhen, longDay, hhmm, norm, modKey, parseMoney, moneyText, vMoney } from '../format.js'
import Layer from './Layer.vue'
import Combobox from './Combobox.vue'

const customer = ref(null); const device = ref(null); const items = ref([])
const whenText = ref(''); const assignee = ref(''); const request = ref('')
const assist = ref(''); const proposal = ref(null); const assistMsg = ref(''); const aiMarked = ref(false)
const custRef = ref(null); const devRef = ref(null); const svcRef = ref(null)
const labels = computed(() => db.value.labels)
const when = computed(() => (touch.value ? (whenText.value ? new Date(whenText.value) : null) : parseWhen(whenText.value)))
const total = computed(() => items.value.reduce((s, i) => s + i.qty * i.price, 0))
const dirty = computed(() => customer.value || items.value.length || request.value)
const canSave = computed(() => !!customer.value)
const missing = computed(() => (customer.value ? '' : 'Escolha o cliente para salvar'))

const lastOrder = computed(() => customer.value && db.value.orders.find((o) => o.customerId === customer.value.id && o.items.length))
function customerGroups(q) {
  const all = db.value.customers
  const hay = (c) => `${c.name} ${c.phone} ${c.devices.map((d) => `${d.label} ${d.tag}`).join(' ')}`
  const items = (q ? all.filter((c) => matches(hay(c), q)) : all.slice(0, 5)).slice(0, 6)
    .map((c) => ({ id: c.id, label: c.name, sub: c.devices.map((d) => `${d.label} ${d.tag}`).join(', '), c }))
  const create = q ? [{ id: 'new', label: `+ Cadastrar “${q}”`, create: true }] : []
  return [{ title: q ? '' : 'Recentes', items }, { title: '', items: create }]
}
async function pickCustomer(it, q) {
  customer.value = it.create ? createCustomer(q) : it.c
  device.value = null
  await nextTick()
  devRef.value?.focus()
}
function deviceGroups(q) {
  const list = customer.value.devices.filter((d) => !q || matches(`${d.label} ${d.tag}`, q)).map((d) => ({ id: d.id, label: d.label, sub: d.tag, d }))
  const create = q ? [{ id: 'new', label: `+ Cadastrar “${q}”`, create: true }] : []
  return [{ title: '', items: [...list, ...create] }]
}
async function pickDevice(it, q) {
  device.value = it.create ? createDevice(customer.value, q) : it.d
  await nextTick()
  svcRef.value?.focus()
}
function serviceGroups(q) {
  const repeat = !q && lastOrder.value && !items.value.length
    ? [{ id: 'repeat', label: `Repetir a OS ${lastOrder.value.number}`, sub: lastOrder.value.items.map((i) => i.name).join(', '), repeat: true }]
    : []
  const list = db.value.catalog.filter((c) => !q || matches(c.name, q)).slice(0, 6)
    .map((c) => ({ id: c.key, label: c.name, sub: c.kind === 'part' ? 'Peça' : 'Serviço', right: brl(c.price), c }))
  const create = q ? [{ id: 'new', label: `+ Usar “${q}” nesta OS`, create: true }] : []
  return [{ title: '', items: repeat }, { title: q ? '' : 'Mais usados', items: list }, { title: '', items: create }]
}
function pickService(it, q) {
  if (it.repeat) { items.value = lastOrder.value.items.map((i) => ({ ...i })); return }
  const c = it.create ? { kind: 'service', name: q, price: 0 } : it.c
  items.value.unshift({ id: 'd' + Math.random(), kind: c.kind, name: c.name, qty: 1, price: c.price, ai: false })
  if (it.create) nextTick(() => document.querySelector('.drawer-items input')?.focus())
}
function askAssistant() {
  assistMsg.value = ''; proposal.value = null
  if (!assist.value.trim()) return
  const r = assistantRead(assist.value)
  const words = norm(assist.value)
  const person = db.value.customers.find((c) => norm(c.name).split(' ').some((w) => w.length > 3 && words.includes(w)))
  if (r.blocked && !person) { assistMsg.value = r.blocked; return }
  proposal.value = { customer: person || null, items: r.items || [] }
}
async function applyProposal() {
  const p = proposal.value
  if (p.customer) {
    customer.value = p.customer
    const words = norm(assist.value)
    device.value = p.customer.devices.find((d) => norm(d.label).split(/\W+/).some((w) => w.length > 3 && words.includes(w))) || (p.customer.devices.length === 1 ? p.customer.devices[0] : null)
  }
  p.items.forEach((c) => items.value.unshift({ id: 'd' + Math.random(), kind: c.kind, name: c.name, qty: 1, price: c.price, ai: true }))
  aiMarked.value = true
  proposal.value = null; assist.value = ''
}
function save() {
  if (!canSave.value) { custRef.value?.focus(); return }
  const o = createOrder({
    customerId: customer.value.id, deviceId: device.value?.id, items: items.value, request: request.value,
    assignee: assignee.value || null, scheduledAt: when.value?.toISOString() || null,
  })
  ui.newOrder = false
  go('os', { id: o.id })
  toast(`OS ${o.number} criada`)
}
function close() {
  if (!dirty.value) { ui.newOrder = false; return }
  ui.confirm = { title: 'Descartar esta OS?', body: 'O que você preencheu vai se perder.', label: 'Descartar', keep: 'Continuar', danger: true, onOk: () => { ui.newOrder = false } }
}
function onKey(e) {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); save() }
}
function setPrice(i, e) {
  const v = parseMoney(e.target.value)
  if (v !== null) i.price = v
}
watch(dirty, (v) => { ui.dirty = !!v })
onBeforeUnmount(() => { ui.dirty = false; ui.closeNewOrder = null })
ui.closeNewOrder = close
onMounted(() => { if (ui.newOrderSeed) { customer.value = ui.newOrderSeed; nextTick(() => devRef.value?.focus()) } })
</script>

<template>
  <Layer kind="drawer" label="Nova OS" @close="close">
    <div style="display: contents" @keydown="onKey">
      <div class="drawer-head">
        <button class="icon-btn" aria-label="Fechar" @click="close"><X :size="18" /></button>
        <h2 class="layer-title">Nova OS</h2>
        <span class="muted small">{{ db.company }}</span>
      </div>
      <div class="drawer-body">
        <div class="step">
          <label class="field-label" for="no-cust">Cliente</label>
          <div v-if="customer" class="chosen">
            <span><strong>{{ customer.name }}</strong><span v-if="aiMarked" class="ai"> ✦</span></span>
            <button class="link" @click="customer = null; device = null; nextTick(() => custRef?.focus())">Trocar</button>
          </div>
          <Combobox v-else id="no-cust" ref="custRef" label="Cliente" placeholder="Nome, telefone ou placa" :groups="customerGroups" autofocus @pick="pickCustomer" />
        </div>
        <div v-if="customer" class="step">
          <label class="field-label" for="no-dev">{{ labels.device }}</label>
          <div v-if="device" class="chosen">
            <span>{{ device.label }} <span class="num">{{ device.tag }}</span></span>
            <button class="link" @click="device = null; nextTick(() => devRef?.focus())">Trocar</button>
          </div>
          <Combobox v-else id="no-dev" ref="devRef" :label="labels.device" :placeholder="labels.deviceQ" :groups="deviceGroups" preselect @pick="pickDevice" />
        </div>
        <div class="step">
          <label class="field-label" for="no-svc">O que vai ser feito?</label>
          <Combobox id="no-svc" ref="svcRef" label="O que vai ser feito?" placeholder="Digite o serviço ou a peça" :groups="serviceGroups" @pick="pickService" />
          <ul v-if="items.length" class="drawer-items">
            <li v-for="i in items" :key="i.id">
              <span><span v-if="i.ai" class="ai">✦ </span>{{ i.name }}</span>
              <span class="cell-price"><span aria-hidden="true">R$</span><input v-money class="field price-in" :value="i.price ? moneyText(i.price) : ''" placeholder="0,00" :aria-label="`Valor de ${i.name}`" @change="setPrice(i, $event)"></span>
              <button class="remove" :aria-label="`Tirar ${i.name}`" @click="items = items.filter((x) => x !== i)"><Trash2 :size="14" /></button>
            </li>
          </ul>
        </div>
        <div class="step">
          <label class="field-label" for="no-when">Quando, se já souber</label>
          <input id="no-when" v-model="whenText" class="field" :type="touch ? 'datetime-local' : 'text'" :placeholder="touch ? undefined : 'sex 14, amanhã 9, 12/11 10h'">
          <span v-if="whenText && !touch" class="muted small">{{ when ? `${longDay(when)}, ${hhmm(when)}` : 'Escreva o dia e a hora' }}</span>
        </div>
        <div class="step">
          <label class="field-label" for="no-who">Responsável, se já souber</label>
          <select id="no-who" v-model="assignee" class="field"><option value="">Ninguém</option><option v-for="p in db.team" :key="p">{{ p }}</option></select>
        </div>
        <div class="step">
          <label class="field-label" for="no-ai"><span class="ai">✦</span> Ou peça ao assistente</label>
          <form @submit.prevent="askAssistant"><input id="no-ai" v-model="assist" class="field" :placeholder="db.sample"></form>
          <div v-if="proposal" class="assist-note" role="status">
            <span>Posso preencher assim?</span>
            <ul>
              <li v-if="proposal.customer">Cliente: {{ proposal.customer.name }}</li>
              <li v-for="c in proposal.items" :key="c.key">{{ c.name }}, {{ brl(c.price) }}</li>
            </ul>
            <div class="row"><button class="btn" @click="applyProposal">Preencher</button><button class="btn btn--ghost" @click="proposal = null">Agora não</button></div>
          </div>
          <span v-if="assistMsg" class="muted small" role="status">{{ assistMsg }}</span>
        </div>
      </div>
      <div class="drawer-foot">
        <span class="hint">{{ missing || (total ? `Total ${brl(total)}` : 'Pode salvar sem valor') }}</span>
        <button class="btn btn--primary" :aria-disabled="!canSave" @click="save"><Check :size="16" aria-hidden="true" />Criar OS <kbd>{{ modKey }} Enter</kbd></button>
      </div>
    </div>
  </Layer>
</template>
