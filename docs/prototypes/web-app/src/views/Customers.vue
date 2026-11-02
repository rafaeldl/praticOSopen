<script setup>
import { computed, ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { X, Plus, ChevronLeft } from 'lucide-vue-next'
import { db, ui, go, route, rest, total, isOpen, samePhone, canInvoice, act, toast, createCustomer, createDevice, filterHint, phone, phonePanel } from '../store.js'
import { brl, matches, plural } from '../format.js'
import StatusLabel from '../components/StatusLabel.vue'
import Layer from '../components/Layer.vue'

const text = ref(''); const filter = ref('all'); const searchEl = ref(null)
const ordersOf = (c) => db.value.orders.filter((o) => o.customerId === c.id)
const owedBy = (c) => ordersOf(c).reduce((s, o) => s + (o.status === 'done' ? rest(o) : 0), 0)
const FILTERS = [
  { id: 'all', label: 'Todos', fn: () => true },
  { id: 'owing', label: 'Devendo', fn: (c) => owedBy(c) > 0 },
  { id: 'open', label: 'Com OS em aberto', fn: (c) => ordersOf(c).some(isOpen) },
]
const count = (f) => db.value.customers.filter(f.fn).length
const fn = computed(() => FILTERS.find((f) => f.id === filter.value).fn)
const rows = computed(() => db.value.customers.filter((c) => fn.value(c) && (!text.value || matches(`${c.name} ${c.phone} ${c.devices.map((d) => `${d.label} ${d.tag}`).join(' ')}`, text.value))))
const openId = ref(route.id || (phone.value ? null : db.value.customers[0]?.id) || null)
phonePanel(openId)
const c = computed(() => db.value.customers.find((x) => x.id === openId.value))
const history = computed(() => (c.value ? ordersOf(c.value) : []))
const owed = computed(() => (c.value ? owedBy(c.value) : 0))
const unpaid = computed(() => history.value.filter((o) => o.status === 'done' && rest(o) > 0))
const openCount = computed(() => history.value.filter(isOpen).length)
const spent = computed(() => history.value.filter((o) => o.status !== 'canceled').reduce((s, o) => s + total(o), 0))
const invoiceable = computed(() => history.value.filter(canInvoice))
const sentence = computed(() => {
  if (owed.value) return `Deve ${brl(owed.value)} de ${plural(unpaid.value.length, 'OS', 'OS')}`
  if (openCount.value) return `${plural(openCount.value, 'OS', 'OS')} em aberto`
  return history.value.length ? 'Nada pendente' : 'Ainda sem OS'
})
const start = () => { ui.newOrderSeed = c.value; ui.newOrder = true }
const clash = computed(() => c.value && samePhone(c.value.phone, c.value))
const adding = ref(false); const deviceText = ref(''); const deviceEl = ref(null)
async function addDevice() { adding.value = true; await nextTick(); deviceEl.value?.focus() }
function saveDevice() {
  if (deviceText.value.trim()) act(`${db.value.labels.device} adicionado`, () => createDevice(c.value, deviceText.value.trim()))
  deviceText.value = ''; adding.value = false
}
function copyPhone() { navigator.clipboard?.writeText(c.value.phone).catch(() => {}); toast('Telefone copiado') }

const creating = ref(false); const draft = ref({ name: '', phone: '' })
const draftClash = computed(() => samePhone(draft.value.phone))
function create() {
  if (!draft.value.name.trim() || draftClash.value) return
  const made = act('Cliente cadastrado', () => { const n = createCustomer(draft.value.name.trim()); n.phone = draft.value.phone; return n })
  openId.value = made.id; creating.value = false; draft.value = { name: '', phone: '' }; text.value = ''; filter.value = 'all'
}
function openExisting(x) { openId.value = x.id; creating.value = false; text.value = ''; filter.value = 'all' }

function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select')) return
  const i = rows.value.findIndex((x) => x.id === openId.value)
  if (e.key === '/') { e.preventDefault(); searchEl.value?.focus() }
  if (e.key === 'j' || e.key === 'ArrowDown') { e.preventDefault(); openId.value = rows.value[Math.min(rows.value.length - 1, i + 1)]?.id ?? openId.value }
  if (e.key === 'k' || e.key === 'ArrowUp') { e.preventDefault(); openId.value = rows.value[Math.max(0, i - 1)]?.id ?? openId.value }
}
watch(openId, () => nextTick(() => document.querySelector('.grid tr.is-open')?.scrollIntoView({ block: 'nearest' })))
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ db.customers.length ? plural(db.customers.length, 'cliente', 'clientes') : 'Nenhum cliente ainda' }}</h1>
    </div>
    <span class="spacer"></span>
    <button class="btn" @click="go('importar')">Importar planilha</button>
    <button class="btn" @click="creating = true"><Plus :size="15" aria-hidden="true" />Novo cliente</button>
  </header>
  <template v-if="db.customers.length">
    <div class="toolbar">
      <div class="chips" role="group" aria-label="Filtros">
        <button v-for="f in FILTERS" :key="f.id" class="chip" :aria-pressed="filter === f.id" @click="filter = f.id">{{ f.label }} <span class="num">{{ count(f) }}</span></button>
      </div>
      <span class="spacer"></span>
      <input ref="searchEl" v-model="text" class="field search-mini" aria-label="Filtrar clientes" :placeholder="filterHint">
    </div>
    <div class="workspace" :class="{ 'has-panel': c }">
      <div class="list-pane">
        <table v-if="rows.length" class="grid">
          <thead><tr><th>Cliente</th><th>Telefone</th><th class="c-num">OS</th><th class="c-money">Falta receber</th></tr></thead>
          <tbody>
            <tr v-for="r in rows" :key="r.id" :class="{ 'is-open': r.id === openId }" @click="openId = r.id">
              <td><span class="who"><button class="row-btn" :aria-label="`Abrir ${r.name}`" @click.stop="openId = r.id">{{ r.name }}</button></span><span class="sub block-line">{{ r.devices.map((d) => d.label).join(', ') }}</span></td>
              <td><span class="num">{{ r.phone }}</span></td>
              <td class="c-num hide-phone"><span class="num">{{ ordersOf(r).length }}</span></td>
              <td class="c-money"><span class="num">{{ owedBy(r) ? brl(owedBy(r)) : '' }}</span></td>
            </tr>
          </tbody>
        </table>
        <div v-else class="empty"><h2>Ninguém com esse filtro</h2><button class="btn" @click="text = ''; filter = 'all'">Limpar filtro</button></div>
      </div>
      <section v-if="c" class="od" :aria-label="c.name">
        <div class="od-scroll">
          <div class="od-top"><span class="num">{{ c.kind === 'company' ? 'Empresa' : 'Pessoa' }}</span><span class="spacer"></span><button class="icon-btn" :aria-label="phone ? 'Voltar' : 'Fechar'" title="Fechar" @click="openId = null"><ChevronLeft v-if="phone" :size="22" /><X v-else :size="18" /></button></div>
          <header class="od-head">
            <h2 class="od-h"><span class="od-name od-name--plain">{{ c.name }}</span></h2>
            <div class="od-state"><span class="od-sentence">{{ sentence }}</span><span v-if="spent" class="muted">{{ brl(spent) }} em serviços</span></div>
            <div class="od-actions">
              <button v-if="owed" class="btn btn--primary" @click="ui.receive = unpaid.map((o) => o.id)">Receber {{ brl(owed) }}</button>
              <button class="btn" :class="{ 'btn--primary': !owed }" @click="start">Nova OS</button>
            </div>
          </header>
          <section class="od-sec">
            <h3>Contato <button v-if="c.phone" class="link" @click="copyPhone">Copiar telefone</button></h3>
            <dl class="kv kv--fields">
              <dt><label :for="'c-phone'">Telefone</label></dt><dd><input id="c-phone" v-model.lazy="c.phone" class="field field--line" placeholder="Adicionar"></dd>
              <dt><label for="c-mail">E-mail</label></dt><dd><input id="c-mail" v-model.lazy="c.email" class="field field--line" placeholder="Adicionar"></dd>
              <dt><label for="c-addr">Endereço</label></dt><dd><input id="c-addr" v-model.lazy="c.address" class="field field--line" placeholder="Adicionar"></dd>
              <dt><label for="c-zip">CEP</label></dt><dd><input id="c-zip" v-model.lazy="c.zip" class="field field--line" placeholder="Adicionar"></dd>
            </dl>
            <p v-if="clash" class="warn" role="status">Esse telefone também é de {{ clash.name }}. <button class="link" @click="openExisting(clash)">Abrir</button></p>
          </section>
          <section class="od-sec">
            <h3>{{ c.devices.length > 1 ? (db.labels.device === 'Veículo' ? 'Veículos' : 'Equipamentos') : db.labels.device }} <button class="link" @click="addDevice">Adicionar</button></h3>
            <div v-for="d in c.devices" :key="d.id" class="pay-row"><span>{{ d.label }}</span><span class="num">{{ d.tag }}</span></div>
            <input v-if="adding" ref="deviceEl" v-model="deviceText" class="field" :aria-label="db.labels.deviceQ" :placeholder="db.labels.deviceQ" @keydown.enter="saveDevice" @keydown.esc.stop="adding = false" @blur="saveDevice">
          </section>
          <section class="od-sec">
            <h3>OS deste cliente <button v-if="invoiceable.length > 1" class="link" @click="go('notas', { query: { c: c.id } })">Uma nota com várias OS</button></h3>
            <button v-for="o in history" :key="o.id" class="hist" :aria-label="`Abrir OS ${o.number}`" @click="ui.peek = o.id">
              <span class="num">{{ o.number }}</span><StatusLabel :order="o" plain /><span class="num">{{ brl(total(o)) }}</span>
            </button>
            <p v-if="!history.length" class="muted">Nenhuma OS ainda.</p>
          </section>
        </div>
      </section>
    </div>
  </template>
  <div v-else class="empty">
    <h2>Os clientes aparecem aqui</h2>
    <p>Você cadastra o cliente na hora de criar a OS, ou traz todos de uma planilha.</p>
    <div class="row-gap"><button class="btn btn--primary" @click="go('importar')">Importar planilha</button><button class="btn" @click="ui.newOrder = true">Criar a primeira OS</button></div>
  </div>
  <Layer v-if="creating" label="Novo cliente" @close="creating = false">
    <form style="display: contents" @submit.prevent="create">
      <div class="layer-pad">
        <h2 class="layer-title">Novo cliente</h2>
        <div><label class="field-label" for="nc-name">Nome</label><input id="nc-name" v-model="draft.name" class="field" data-autofocus></div>
        <div><label class="field-label" for="nc-phone">WhatsApp</label><input id="nc-phone" v-model="draft.phone" class="field" inputmode="tel"></div>
        <p v-if="draftClash" class="warn" role="status">Esse número já é de {{ draftClash.name }}. <button type="button" class="link" @click="openExisting(draftClash)">Abrir cadastro</button></p>
      </div>
      <div class="layer-foot"><button type="button" class="btn" @click="creating = false">Voltar</button><button type="submit" class="btn btn--primary" :disabled="!draft.name.trim() || !!draftClash">Cadastrar</button></div>
    </form>
  </Layer>
</template>
