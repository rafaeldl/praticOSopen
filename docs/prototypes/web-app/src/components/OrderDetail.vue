<script setup>
import { computed, ref, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { X, Maximize2, MoreHorizontal, ImagePlus, Image as ImageIcon, Trash2, Copy, Send, ChevronLeft } from 'lucide-vue-next'
import {
  db, ui, go, route, orderById, customerOf, deviceOf, STATUS, HOLD_REASONS, METHODS, methodLabel,
  subtotal, total, paid, rest, sentence, nextStep, lateDays, act, toast, setStatus, setHold, addItem, chargeOf, simulatePaid, invoiceOf, canInvoice,
  createCustomer, createDevice, assistantRead, undo, phone, touch } from '../store.js'
import { brl, friendlyWhen, friendlyDay, longDay, hhmm, matches, parseWhen, plural, parseMoney, moneyText, vMoney, localInput } from '../format.js'
import StatusLabel from './StatusLabel.vue'
import Combobox from './Combobox.vue'

const props = defineProps({ orderId: Number, mode: { type: String, default: 'panel' } })
const emit = defineEmits(['close'])
const o = computed(() => orderById(props.orderId))
const customer = computed(() => customerOf(o.value))
const device = computed(() => deviceOf(o.value))
const labels = computed(() => db.value.labels)
const step = computed(() => o.value && nextStep(o.value))
const editing = ref(null)
const fileInput = ref(null)
const addCombo = ref(null); const custCombo = ref(null); const devCombo = ref(null); const whoCombo = ref(null)
const discInput = ref(null)
const whenText = ref(''); const discText = ref('')
const whenParsed = computed(() => (touch.value ? (whenText.value ? new Date(whenText.value) : null) : parseWhen(whenText.value)))
const dateRows = computed(() => [
  { key: 'when', label: labels.value.visit, value: o.value.scheduledAt },
  ...(o.value.dueAt || ['approved', 'progress'].includes(o.value.status) ? [{ key: 'due', label: 'Prometido para', value: o.value.dueAt }] : []),
])
const priceEdit = ref(null); const priceText = ref('')
const comment = ref('')
const assist = ref(''); const proposal = ref(null); const assistMsg = ref('')
const over = ref(false)
const saved = ref(false)

const editors = { item: addCombo, customer: custCombo, device: devCombo, who: whoCombo, discount: discInput }
async function edit(what) {
  whenText.value = ''
  if (touch.value && (what === 'when' || what === 'due')) {
    const v = what === 'when' ? o.value.scheduledAt : o.value.dueAt
    if (v) whenText.value = localInput(v)
  }
  editing.value = what
  await nextTick()
  if (what === 'when' || what === 'due') document.getElementById('od-when')?.focus()
  else editors[what]?.value?.focus()
}

function runStep() {
  const s = step.value
  if (!s) return
  if (s.key === 'send') ui.send = o.value.id
  else if (s.key === 'approve') setStatus(o.value, 'approved')
  else if (s.key === 'start') setStatus(o.value, 'progress')
  else if (s.key === 'finish') setStatus(o.value, 'done')
  else if (s.key === 'resume') setHold(o.value, null)
  else if (s.key === 'receive') ui.receive = [o.value.id]
}
function chooseStatus() {
  ui.picker = {
    title: 'Qual a situação?', sub: `OS ${o.value.number}`,
    options: Object.entries(STATUS).filter(([k]) => k !== 'canceled').map(([id, s]) => ({ id, label: s.label, dot: s.dot, current: id === o.value.status })),
    onPick: (id) => setStatus(o.value, id),
  }
}
function chooseHold() {
  ui.picker = {
    title: 'Por que parou?', sub: `OS ${o.value.number}`,
    options: HOLD_REASONS.map((r) => ({ id: r, label: r })),
    onPick: (id) => setHold(o.value, id),
  }
}
function menu() {
  const held = !!o.value.hold
  const canHold = ['approved', 'progress'].includes(o.value.status)
  const opts = [
    { id: 'status', label: 'Mudar a situação' },
    ...(canHold ? [{ id: 'hold', label: held ? 'Voltar ao serviço' : 'Marcar como parada' }] : []),
    { id: 'discount', label: 'Dar desconto' },
    { id: 'send', label: 'Mandar ao cliente' },
    { id: 'link', label: 'Copiar link da OS' },
    { id: 'print', label: 'Imprimir' },
    ...(canInvoice(o.value) ? [{ id: 'invoice', label: 'Emitir nota fiscal' }] : []),
    ...(o.value.status !== 'canceled' ? [{ id: 'cancel', label: 'Cancelar OS', danger: true }] : []),
  ]
  ui.picker = {
    title: `OS ${o.value.number}`, options: opts,
    onPick: (id) => {
      if (id === 'status') chooseStatus()
      if (id === 'hold') held ? setHold(o.value, null) : chooseHold()
      if (id === 'discount') { discText.value = o.value.discount ? moneyText(o.value.discount) : ''; edit('discount') }
      if (id === 'send') ui.send = o.value.id
      if (id === 'link') copyLink()
      if (id === 'print') ui.print = o.value.id
      if (id === 'invoice') go('notas', { query: { o: o.value.id } })
      if (id === 'cancel') askCancel()
    },
  }
}
const charge = computed(() => o.value && chargeOf(o.value))
const invoice = computed(() => o.value && invoiceOf(o.value))
const track = computed(() => {
  const x = o.value
  if (!x?.sentAt) return []
  const ch = charge.value
  return [
    { id: 'sent', label: x.copiedOnly ? 'Mensagem copiada, falta mandar' : 'Enviado', at: x.sentAt },
    { id: 'open', label: x.openedAt ? 'Cliente abriu' : 'Cliente ainda não abriu', at: x.openedAt },
    ...(x.status === 'quote' || x.approvedAt ? [{ id: 'ok', label: x.approvedAt ? 'Cliente aprovou' : 'Cliente ainda não aprovou', at: x.approvedAt }] : []),
    ...(ch ? [{ id: 'pay', label: `Falta pagar ${brl(ch.value)}`, at: null }] : []),
  ]
})
/* What the customer's link still shows after the order changed. */
const staleValue = computed(() => {
  const x = o.value; const ch = charge.value
  if (!x?.sentAt) return null
  if (ch) return ch.orderIds.length === 1 && ch.value !== rest(x) ? ch.value : null
  return x.sentTotal !== undefined && x.sentTotal !== total(x) ? x.sentTotal : null
})
function simOpen() { act('Cliente abriu o link', () => { o.value.openedAt = new Date().toISOString(); if (charge.value) charge.value.openedAt = o.value.openedAt }) }
function simApprove() { act(`OS ${o.value.number}: cliente aprovou`, () => { o.value.approvedAt = new Date().toISOString(); o.value.openedAt ||= o.value.approvedAt; o.value.status = 'approved' }) }
function copyLink() {
  const link = `https://praticos.web.app/q/exemplo-${o.value.number}`
  navigator.clipboard?.writeText(link).catch(() => {})
  toast('Link copiado')
}
function askCancel() {
  ui.confirm = {
    title: `Cancelar a OS ${o.value.number}?`, body: 'Ela sai da lista de abertas. Os recebimentos continuam registrados.',
    label: 'Cancelar OS', keep: 'Manter OS', danger: true, onOk: () => setStatus(o.value, 'canceled'),
  }
}

function customerGroups(q) {
  const all = db.value.customers
  const items = (q ? all.filter((c) => matches(`${c.name} ${c.phone}`, q)) : all.slice(0, 6)).slice(0, 7)
    .map((c) => ({ id: c.id, label: c.name, sub: c.devices.map((d) => d.label).join(', '), c }))
  const create = q ? [{ id: 'new', label: `+ Cadastrar “${q}”`, create: true }] : []
  return [{ title: q ? '' : 'Recentes', items }, { title: '', items: create }]
}
function pickCustomer(it, q) {
  act('Cliente trocado', () => {
    const c = it.create ? createCustomer(q) : it.c
    o.value.customerId = c.id
    o.value.deviceId = c.devices.length === 1 ? c.devices[0].id : null
  })
  editing.value = null
}
function deviceGroups(q) {
  const list = customer.value.devices.filter((d) => !q || matches(`${d.label} ${d.tag}`, q))
    .map((d) => ({ id: d.id, label: d.label, sub: d.tag, d }))
  const none = q ? [] : [{ id: 'none', label: labels.value.deviceNone, none: true }]
  const create = q ? [{ id: 'new', label: `+ Cadastrar “${q}”`, create: true }] : []
  return [{ title: '', items: [...none, ...list, ...create] }]
}
function pickDevice(it, q) {
  act(`${labels.value.device} trocado`, () => {
    if (it.none) o.value.deviceId = null
    else o.value.deviceId = (it.create ? createDevice(customer.value, q) : it.d).id
  })
  editing.value = null
}
function itemGroups(q) {
  const list = db.value.catalog.filter((c) => !q || matches(c.name, q)).slice(0, 7)
    .map((c) => ({ id: c.key, label: c.name, right: brl(c.price), sub: c.kind === 'part' ? 'Peça' : 'Serviço', c }))
  const create = q ? [{ id: 'new', label: `+ Usar “${q}” nesta OS`, create: true }] : []
  return [{ title: q ? '' : 'Mais usados', items: list }, { title: '', items: create }]
}
function pickItem(it, q) {
  act('Item adicionado', () => addItem(o.value, it.create ? { kind: 'service', name: q, price: 0 } : it.c))
}
function removeItem(i) {
  act('Item tirado da OS', () => { o.value.items = o.value.items.filter((x) => x !== i) })
}
function startPrice(i) {
  priceEdit.value = i.id; priceText.value = moneyText(i.price)
  nextTick(() => document.getElementById('price-' + i.id)?.focus())
}
function commitPrice(i) {
  if (priceEdit.value !== i.id) return
  const v = parseMoney(priceText.value)
  priceEdit.value = null
  if (v === null || v === i.price) return
  act(`${i.name}: ${brl(v)}`, () => { i.price = v })
}
function commitDiscount() {
  if (editing.value !== 'discount') return
  const v = parseMoney(discText.value) || 0
  editing.value = null
  act(v ? `Desconto de ${brl(v)}` : 'Desconto tirado', () => { o.value.discount = v })
}
function whoGroups(q) {
  const list = db.value.team.filter((p) => !q || matches(p, q)).map((p) => ({ id: p, label: p }))
  return [{ title: '', items: [...(q ? [] : [{ id: 'none', label: 'Ninguém', none: true }]), ...list] }]
}
function pickWho(it) {
  act(it.none ? 'Sem responsável' : `Responsável: ${it.label}`, () => { o.value.assignee = it.none ? null : it.id })
  editing.value = null
}
function commitWhen() {
  const d = whenParsed.value
  if (!d) return
  const field = editing.value
  editing.value = null; whenText.value = ''
  if (field === 'due') { act(`Prometida para ${friendlyWhen(d)}`, () => { o.value.dueAt = d.toISOString() }); return }
  act(`Marcada para ${friendlyWhen(d)}`, () => { o.value.scheduledAt = d.toISOString() })
  const due = o.value.dueAt
  if (due && d >= new Date(due)) {
    ui.confirm = {
      title: 'Mudar a data prometida também?', body: `Ela está para ${friendlyWhen(due)}, antes da nova data.`,
      label: 'Mudar a data', keep: 'Manter', onOk: () => edit('due'),
    }
  }
}
function saveRequest(e) {
  if (e.target.value === o.value.request) return
  o.value.request = e.target.value
  saved.value = true; setTimeout(() => { saved.value = false }, 1500)
}
function addComment() {
  if (!comment.value.trim()) return
  o.value.comments.push({ id: 'n' + Date.now(), author: db.value.owner, text: comment.value.trim(), at: new Date().toISOString() })
  comment.value = ''
}
function addFiles(files) {
  [...files].filter((f) => f.type.startsWith('image/')).forEach((f) => {
    const r = new FileReader()
    r.onload = () => { o.value.photos.push({ id: 'n' + Math.random(), label: f.name.replace(/\.\w+$/, ''), src: r.result }); toast('Foto anexada') }
    r.readAsDataURL(f)
  })
}
function onPaste(e) {
  if (ui.peek && props.mode !== 'peek') return
  if (e.clipboardData?.files?.length) addFiles(e.clipboardData.files)
}
function askAssistant() {
  assistMsg.value = ''; proposal.value = null
  if (!assist.value.trim()) return
  const r = assistantRead(assist.value, o.value)
  if (r.blocked) assistMsg.value = r.blocked
  else proposal.value = r.items
}
function applyProposal() {
  const items = proposal.value
  act('Preenchi o que está marcado com ✦. Confira.', () => items.forEach((c) => addItem(o.value, c, true)))
  proposal.value = null; assist.value = ''
}

watch(() => ui.orderCmd, (c) => {
  if (!c || !o.value) return
  if (ui.peek && props.mode !== 'peek') return
  if (c.k === 'a') edit('item')
  if (c.k === 'c') edit('customer')
  if (c.k === 'v') edit('device')
  if (c.k === 'd') edit('when')
  if (c.k === 'm') ui.send = o.value.id
  if (c.k === 'f') fileInput.value?.click()
  if (c.k === 's') chooseStatus()
  if (c.k === 'r' && rest(o.value) > 0) ui.receive = [o.value.id]
  if (c.k === 'p') ui.print = o.value.id
})
watch(() => props.orderId, () => { editing.value = null; proposal.value = null; assistMsg.value = '' })
onMounted(() => window.addEventListener('paste', onPaste))
onBeforeUnmount(() => window.removeEventListener('paste', onPaste))
</script>

<template>
  <section v-if="o" class="od" :class="'od--' + mode" :aria-label="`OS ${o.number}, ${customer.name}`">
    <div class="od-scroll" tabindex="-1" data-od-focus>
      <div class="od-top">
        <span class="num">OS {{ o.number }}</span>
        <span class="spacer"></span>
        <button v-if="mode !== 'page'" class="icon-btn hide-phone" title="Abrir em página inteira" aria-label="Abrir em página inteira" @click="go('os', { id: o.id, query: { page: 1 } })"><Maximize2 :size="16" /></button>
        <button class="icon-btn" title="Mais ações" aria-label="Mais ações" @click="menu"><MoreHorizontal :size="18" /></button>
        <button v-if="mode === 'page'" class="btn btn--ghost" @click="go('os', { id: o.id })">Voltar à lista</button>
        <button v-else class="icon-btn" title="Fechar" :aria-label="phone ? 'Voltar' : 'Fechar'" @click="mode === 'peek' ? emit('close') : ui.cursorClose?.()"><ChevronLeft v-if="phone" :size="22" /><X v-else :size="18" /></button>
      </div>
      <header class="od-head">
        <Combobox v-if="editing === 'customer'" id="od-cust" ref="custCombo" label="Qual cliente?" placeholder="Qual cliente?" :groups="customerGroups" keep-open @pick="pickCustomer" @cancel="editing = null" />
        <h2 v-else class="od-h"><button class="od-name" title="Trocar cliente (C)" @click="edit('customer')">{{ customer.name }}</button></h2>
        <Combobox v-if="editing === 'device'" id="od-dev" ref="devCombo" :label="labels.deviceQ" :placeholder="labels.deviceQ" :groups="deviceGroups" keep-open @pick="pickDevice" @cancel="editing = null" />
        <button v-else class="od-device" :title="`Trocar ${labels.device.toLowerCase()} (V)`" @click="edit('device')">
          <template v-if="device">{{ device.label }} <span class="num">{{ device.tag }}</span></template>
          <template v-else>Escolher {{ labels.device.toLowerCase() }}</template>
        </button>
        <div class="od-state">
          <StatusLabel :order="o" plain />
          <span class="od-sentence" :class="{ 'od-sentence--late': lateDays(o) }">{{ sentence(o) }}</span>
        </div>
        <div class="od-actions">
          <button v-if="step" class="btn btn--primary" @click="runStep">{{ step.label }}</button>
          <button v-if="step?.key !== 'send'" class="btn" @click="ui.send = o.id"><Send :size="15" aria-hidden="true" />Mandar ao cliente</button>
        </div>
      </header>

      <div class="od-body">
        <div class="od-col">
          <section class="od-sec od-sec--request">
            <h3>O que o cliente pediu <span v-if="saved" class="muted">Salvo</span></h3>
             <textarea class="inline-edit" rows="1" :value="o.request" aria-label="O que o cliente pediu" placeholder="Escreva o que o cliente pediu" @blur="saveRequest"></textarea>
          </section>
          <section class="od-sec od-sec--items">
            <h3>Serviços e peças <button class="link" @click="edit('item')">Adicionar</button></h3>
            <Combobox v-if="editing === 'item'" id="od-item" ref="addCombo" label="O que vai ser feito?" placeholder="O que vai ser feito?" :groups="itemGroups" keep-open @pick="pickItem" @cancel="editing = null" />
            <ul v-if="o.items.length" class="items">
              <li v-for="i in o.items" :key="i.id" class="item">
                <span>
                  <span class="item-name"><span v-if="i.ai" class="ai" title="Preenchido pelo assistente">✦ </span>{{ i.name }}</span>
                  <span v-if="i.qty > 1" class="sub">{{ String(i.qty).replace('.', ',') }} × {{ brl(i.price) }}</span>
                </span>
                <input v-if="priceEdit === i.id" :id="'price-' + i.id" v-model="priceText" v-money class="field price-in" :aria-label="`Valor de ${i.name}`" @keydown.enter.stop="commitPrice(i)" @keydown.esc.stop="priceEdit = null" @blur="commitPrice(i)">
                <button v-else class="price-btn" :aria-label="`Mudar valor de ${i.name}, ${brl(i.qty * i.price)}`" title="Mudar valor" @click="startPrice(i)">{{ brl(i.qty * i.price) }}</button>
                <button class="remove" :aria-label="`Tirar ${i.name}`" title="Tirar da OS" @click="removeItem(i)"><Trash2 :size="14" /></button>
              </li>
            </ul>
            <p v-else class="muted">Nenhum serviço ainda.<template v-if="!touch"> Aperte <kbd>A</kbd> para adicionar.</template></p>
          </section>
          <section class="od-sec od-sec--photos" :class="{}" @dragover.prevent="over = true" @dragleave="over = false" @drop.prevent="over = false; addFiles($event.dataTransfer.files)">
            <h3>Fotos</h3>
            <div class="photos">
              <button v-for="p in o.photos" :key="p.id" class="photo" :aria-label="`Ver foto: ${p.label}`" @click="ui.lightbox = p">
                <img v-if="p.src" :src="p.src" alt=""><ImageIcon v-else :size="22" aria-hidden="true" /><span>{{ p.label }}</span>
              </button>
              <label class="photo photo-add" :class="{ 'is-over': over }">
                <ImagePlus :size="18" aria-hidden="true" />{{ phone ? 'Adicionar foto' : 'Colar ou arrastar' }}
                <input ref="fileInput" class="sr" type="file" accept="image/*" multiple aria-label="Anexar foto" @change="addFiles($event.target.files)">
              </label>
            </div>
          </section>
          <section class="od-sec od-sec--comments">
            <h3>Comentários da equipe</h3>
            <div v-for="c in o.comments" :key="c.id" class="comment"><b>{{ c.author }}</b> <span class="muted small">{{ friendlyDay(c.at) }}</span><br>{{ c.text }}</div>
            <input v-model="comment" class="field" aria-label="Escrever comentário" placeholder="Escrever comentário para a equipe" @keydown.enter="addComment">
          </section>
        </div>
        <div class="od-col">
          <section class="od-sec od-sec--money">
            <dl class="receipt">
              <div v-if="o.discount"><dt>Subtotal</dt><dd>{{ brl(subtotal(o)) }}</dd></div>
              <div v-if="o.discount"><dt>Desconto</dt><dd>−{{ brl(o.discount) }}</dd></div>
              <div class="is-total"><dt>Total</dt><dd>{{ brl(total(o)) }}</dd></div>
              <div v-if="paid(o)"><dt>Recebido</dt><dd>{{ brl(paid(o)) }}</dd></div>
              <div v-if="rest(o)" class="is-rest"><dt>Falta receber</dt><dd>{{ brl(rest(o)) }}</dd></div>
            </dl>
            <form v-if="editing === 'discount'" class="assist-note" @submit.prevent="commitDiscount">
              <label class="field-label" for="od-disc">Desconto em reais</label>
              <input id="od-disc" ref="discInput" v-model="discText" v-money class="field" @keydown.esc.stop="editing = null" @blur="commitDiscount">
            </form>
            <div v-if="o.payments.length" style="margin-top: .4rem">
              <div v-for="p in o.payments" :key="p.id" class="pay-row"><span>{{ methodLabel(p.method) }}, {{ friendlyDay(p.at) }}</span><span class="num">{{ brl(p.amount) }}</span></div>
            </div>
          </section>
          <section v-if="track.length" class="od-sec od-sec--link">
            <h3>Link do cliente</h3>
            <ol class="track">
              <li v-for="t in track" :key="t.id" :class="{ 'is-done': t.at }"><span class="dot" :class="t.at ? 'dot--success' : 'dot--hollow'" aria-hidden="true"></span><span>{{ t.label }}</span><span v-if="t.at" class="muted small">{{ friendlyDay(t.at) }}</span></li>
            </ol>
            <p v-if="staleValue !== null" class="warn" role="status">O valor mudou. O cliente ainda vê {{ brl(staleValue) }} no link.</p>
            <div class="od-link-actions">
              <button v-if="o.copiedOnly" class="btn" @click="act('Marcado como enviado', () => { o.copiedOnly = false })">Já mandei</button>
              <button v-if="staleValue !== null" class="btn" @click="ui.send = o.id">Mandar de novo</button>
            </div>
            <div class="sim-row">
              <button v-if="!o.openedAt" class="proto-sim" @click="simOpen">Simular: cliente abriu</button>
              <button v-if="o.status === 'quote'" class="proto-sim" @click="simApprove">Simular: cliente aprovou</button>
              <button v-if="charge" class="proto-sim" @click="simulatePaid(charge)">Simular: cliente pagou</button>
            </div>
          </section>
          <section class="od-sec od-sec--details">
            <h3>Detalhes</h3>
            <dl class="kv">
              <dt>Responsável</dt>
              <dd>
                <Combobox v-if="editing === 'who'" id="od-who" ref="whoCombo" label="Quem é o responsável?" placeholder="Quem é o responsável?" :groups="whoGroups" keep-open @pick="pickWho" @cancel="editing = null" />
                <button v-else class="link" @click="edit('who')">{{ o.assignee || 'Escolher' }}</button>
              </dd>
              <template v-for="r in dateRows" :key="r.key">
                <dt>{{ r.label }}</dt>
                <dd>
                  <template v-if="editing === r.key">
                    <input id="od-when" v-model="whenText" class="field" :type="touch ? 'datetime-local' : 'text'" :aria-label="r.label" :placeholder="touch ? undefined : 'sex 14, amanhã 9, 12/11 10h'" @keydown.enter.stop="commitWhen" @keydown.esc.stop="editing = null">
                    <span v-if="!touch" class="muted small">{{ whenParsed ? `${longDay(whenParsed)}, ${hhmm(whenParsed)}` : 'Escreva o dia e a hora' }}</span>
                    <span class="od-date-actions"><button class="btn" @click="commitWhen">Salvar</button><button class="btn btn--ghost" @click="editing = null">Cancelar</button></span>
                  </template>
                  <button v-else class="link" @click="edit(r.key)">{{ r.value ? friendlyWhen(r.value) : 'Marcar' }}</button>
                </dd>
              </template>
              <template v-if="o.address"><dt>Endereço</dt><dd>{{ o.address }}</dd></template>
              <template v-if="invoice"><dt>Nota fiscal</dt><dd><button class="link" @click="go('notas')">{{ invoice.number ? `Nº ${invoice.number}` : 'Na prefeitura' }}</button></dd></template>
              <template v-else-if="canInvoice(o)"><dt>Nota fiscal</dt><dd><button class="link" @click="go('notas', { query: { o: o.id } })">Emitir</button></dd></template>
              <template v-if="customer.phone"><dt>Telefone</dt><dd class="num">{{ customer.phone }}</dd></template>
            </dl>
          </section>
        </div>
      </div>
    </div>
    <div class="assist-bar">
      <div v-if="proposal" class="assist-note" role="status">
        <span><span class="ai">✦</span> Posso adicionar à OS?</span>
        <ul><li v-for="c in proposal" :key="c.key">{{ c.name }}, {{ brl(c.price) }}</li></ul>
        <div class="row"><button class="btn" @click="applyProposal">Adicionar</button><button class="btn btn--ghost" @click="proposal = null">Agora não</button></div>
      </div>
      <p v-if="assistMsg" class="assist-note small" role="status">{{ assistMsg }}</p>
      <form @submit.prevent="askAssistant">
        <span class="ai" aria-hidden="true">✦</span>
        <input v-model="assist" class="field" aria-label="Pedir ao assistente" :placeholder="`Peça ao assistente: ${db.catalog[0].name.toLowerCase()}`">
      </form>
    </div>
  </section>
</template>
