import { reactive, computed, nextTick, ref, watch, onBeforeUnmount } from 'vue'
import { makeDatabases } from './seed.js'
import { brl, norm, NOW, sameDay, daysBetween, friendlyWhen, friendlyDay, hhmm, plural } from './format.js'

const STORE_KEY = 'praticos-proto-prefs-3'
function loadPrefs() {
  try { return JSON.parse(localStorage.getItem(STORE_KEY)) || {} } catch { return {} }
}
export function savePrefs() {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(prefs)) } catch { /* private window */ }
}

const hostTheme = document.documentElement.getAttribute('data-theme')
export const prefs = reactive({ theme: hostTheme || 'system', action: 'yellow', density: 'comfy', font: 'sober', seg: 'auto', empty: false, ...loadPrefs() })
prefs.empty = false

const dbs = reactive(makeDatabases())
export const db = computed(() => dbs[prefs.seg + (prefs.empty ? '_empty' : '')])

export function resetData() {
  Object.assign(dbs, makeDatabases())
  ui.selected = []
  ui.toast = null
  go('inicio')
}

const phoneQuery = window.matchMedia('(max-width: 40rem)')
export const phone = ref(phoneQuery.matches)
phoneQuery.addEventListener('change', (e) => { phone.value = e.matches })
const touchQuery = window.matchMedia('(pointer: coarse)')
export const touch = ref(touchQuery.matches)
touchQuery.addEventListener('change', (e) => { touch.value = e.matches })
export const filterHint = computed(() => (phone.value || touch.value ? 'Filtrar' : 'Filtrar (aperte /)'))

export const route = reactive({ name: 'inicio', id: null, query: {} })
const ROUTES = ['inicio', 'os', 'quadro', 'agenda', 'receber', 'financeiro', 'clientes', 'notas', 'catalogo', 'importar', 'entrada']
export function go(name, opts = {}) {
  route.name = name
  route.id = opts.id ?? null
  route.query = opts.query ?? {}
  const hash = '#' + name + (route.id ? `/${route.id}` : '') + (route.query.page ? '/pagina' : '')
  try { if (location.hash !== hash) history.pushState(null, '', hash) } catch { /* locked frame */ }
  ui.peek = null
  nextTick(() => document.querySelector('[data-page-title]')?.focus({ preventScroll: true }))
}
export function routeFromHash() {
  const [name, id, page] = location.hash.replace('#', '').split('/')
  if (!ROUTES.includes(name)) return
  route.name = name
  route.id = id ? (/^\d+$/.test(id) ? Number(id) : id) : null
  route.query = page ? { page: 1 } : {}
}

export const ui = reactive({
  layers: 0, newOrder: false, newOrderSeed: null, palette: false, shortcuts: false, proto: false,
  receive: null, send: null, assist: null, confirm: null, picker: null, lightbox: null, peek: null,
  toast: null, more: false, selected: [], orderCmd: null, live: '', print: null, panel: null, dirty: false, closeNewOrder: null,
})

/* Back button: each screen and each open layer is one history entry, so Back closes what is on top. */
const LAYERS = ['panel', 'peek', 'newOrder', 'send', 'print', 'receive', 'palette', 'more']
let stack = []
let skipPop = 0
const mark = (layer) => { try { history.pushState({ layer }, '', location.hash) } catch { /* locked frame */ } }
watch(() => LAYERS.filter((k) => ui[k]).join(), () => {
  const open = LAYERS.filter((k) => ui[k])
  if (stack.some((k) => !open.includes(k) && history.state?.layer === k)) { skipPop++; history.back() }
  open.filter((k) => !stack.includes(k)).forEach(mark)
  stack = open
}, { flush: 'post' })
window.addEventListener('popstate', (e) => {
  if (skipPop) { skipPop--; return }
  if (e.state?.layer && !stack.includes(e.state.layer)) { history.back(); return }
  const top = stack[stack.length - 1]
  const asked = ui.confirm || ui.picker
  ui.confirm = null; ui.picker = null
  if (asked && top) { mark(top); return }
  if (top && e.state?.layer !== top) {
    if (top === 'newOrder') {
      ui.closeNewOrder()
      if (ui.newOrder) mark(top)
    } else ui[top] = ['palette', 'more'].includes(top) ? false : null
    return
  }
  routeFromHash()
})
window.addEventListener('beforeunload', (e) => { if (ui.dirty) { e.preventDefault(); e.returnValue = '' } })
/* On the phone a list's detail fills the screen, so it counts as a layer. */
export function phonePanel(idRef) {
  watch(idRef, (id) => { ui.panel = phone.value ? id : null }, { immediate: true })
  watch(() => ui.panel, (p) => { if (!p && phone.value) idRef.value = null })
  onBeforeUnmount(() => { ui.panel = null })
}

export const STATUS = {
  quote: { label: 'Orçamento', dot: 'neutral' },
  approved: { label: 'Aprovada', dot: 'accent' },
  progress: { label: 'Em andamento', dot: 'warning' },
  done: { label: 'Concluída', dot: 'success' },
  canceled: { label: 'Cancelada', dot: 'hollow' },
}
export const METHODS = [['pix', 'Pix'], ['cash', 'Dinheiro'], ['card', 'Cartão'], ['transfer', 'Transferência']]
export const methodLabel = (m) => (m === 'link' ? 'Pago pelo link' : METHODS.find((x) => x[0] === m)?.[1] || m)
export const HOLD_REASONS = ['Esperando peça', 'Esperando o cliente aprovar', 'Esperando pagamento', 'Outro motivo']

export const customerOf = (o) => db.value.customers.find((c) => c.id === o.customerId) || { name: 'Sem cliente', devices: [], phone: '' }
export const deviceOf = (o) => customerOf(o).devices.find((d) => d.id === o.deviceId) || null
export const orderById = (id) => db.value.orders.find((o) => o.id === id)
export const isOpen = (o) => ['quote', 'approved', 'progress'].includes(o.status)

export const subtotal = (o) => o.items.reduce((s, i) => s + i.qty * i.price, 0)
export const total = (o) => Math.max(0, subtotal(o) - o.discount)
export const paid = (o) => o.payments.reduce((s, p) => s + p.amount, 0)
export const rest = (o) => (o.status === 'canceled' ? 0 : Math.max(0, total(o) - paid(o)))

export function lateDays(o) {
  if (!['approved', 'progress'].includes(o.status) || !o.dueAt) return 0
  if (new Date(o.dueAt) >= NOW) return 0
  return Math.max(1, daysBetween(o.dueAt, NOW))
}
export const isToday = (o) => (o.dueAt && sameDay(o.dueAt, NOW)) || (o.scheduledAt && sameDay(o.scheduledAt, NOW))
export const isHeld = (o) => !!o.hold && ['approved', 'progress'].includes(o.status)
export const quoteAge = (o) => (o.sentAt ? daysBetween(o.sentAt, NOW) : daysBetween(o.createdAt, NOW))
export const doneAge = (o) => daysBetween(o.sentAt || o.createdAt, NOW)

// The sentence under the status: one plain answer to "how is this one going?".
export function sentence(o) {
  if (o.status === 'canceled') return 'Cancelada'
  const late = lateDays(o)
  if (isHeld(o)) {
    const held = `${o.hold.reason.toLowerCase()}, há ${plural(Math.max(1, daysBetween(o.hold.since, NOW)), 'dia', 'dias')}`
    return late ? `Atrasada ${plural(late, 'dia', 'dias')}, ${held}` : held[0].toUpperCase() + held.slice(1)
  }
  if (late) return `Atrasada ${plural(late, 'dia', 'dias')}`
  if (o.status === 'quote') {
    if (o.sentAt) return `Cliente ainda não respondeu, há ${plural(Math.max(1, quoteAge(o)), 'dia', 'dias')}`
    return 'Ainda não foi mandado ao cliente'
  }
  if (o.status === 'done') {
    const r = rest(o)
    return r > 0 ? `Falta receber ${brl(r)}` : 'Tudo recebido'
  }
  if (o.dueAt) return `Prometida para ${friendlyWhen(o.dueAt)}`
  if (o.scheduledAt) return `Marcada para ${friendlyWhen(o.scheduledAt)}`
  return 'Sem data marcada'
}

export function nextStep(o) {
  if (o.status === 'canceled') return null
  if (o.status === 'quote') return o.sentAt ? { key: 'approve', label: 'Cliente aprovou' } : { key: 'send', label: 'Mandar orçamento ao cliente' }
  if (o.status === 'approved') return { key: 'start', label: 'Começar o serviço' }
  if (o.status === 'progress') return isHeld(o) ? { key: 'resume', label: 'Voltar ao serviço' } : { key: 'finish', label: 'Marcar como pronta' }
  if (rest(o) > 0) return { key: 'receive', label: `Receber ${brl(rest(o))}` }
  return null
}

export function whenLabel(o) {
  if (o.status === 'done') return o.scheduledAt ? friendlyDay(o.scheduledAt) : ''
  if (o.dueAt) return friendlyWhen(o.dueAt)
  if (o.scheduledAt) return friendlyWhen(o.scheduledAt)
  return ''
}

// Undo keeps one snapshot of the working data, which is enough for a prototype.
function snapshot() {
  const { orders, customers, catalog, charges, invoices } = db.value
  return JSON.stringify({ orders, customers, catalog, charges, invoices })
}
let toastTimer
export function toast(text, undoSnap) {
  clearTimeout(toastTimer)
  ui.toast = { text, undo: undoSnap || null }
  ui.live = text
  if (!undoSnap) toastTimer = setTimeout(() => { ui.toast = null }, 7000)
}
export function undo() {
  if (!ui.toast?.undo) return
  const s = JSON.parse(ui.toast.undo)
  Object.assign(db.value, s)
  ui.toast = null
  toast('Desfeito')
}
export function act(text, fn) {
  const snap = snapshot()
  const r = fn()
  toast(text, snap)
  return r
}

export function setStatus(o, st) {
  if (o.status === st) return
  act(`OS ${o.number}: ${STATUS[st].label}`, () => {
    o.status = st
    if (!['approved', 'progress'].includes(st)) o.hold = null
  })
}
export function setHold(o, reason) {
  act(reason ? `OS ${o.number} parada: ${reason}` : `OS ${o.number} voltou ao serviço`, () => {
    o.hold = reason ? { reason, since: NOW.toISOString() } : null
  })
}
export function addItem(o, it, ai = false) {
  o.items.push({ id: 'n' + Math.random().toString(36).slice(2), kind: it.kind, name: it.name, qty: it.qty || 1, price: it.price, ai })
}
export function pay(o, amount, method) {
  o.payments.push({ id: 'n' + Math.random().toString(36).slice(2), amount, method, at: NOW.toISOString() })
}
export function receiveMany(list, method, amountOverride) {
  const totalValue = amountOverride ?? list.reduce((s, o) => s + rest(o), 0)
  const people = new Set(list.map((o) => o.customerId)).size
  act(`Recebido ${brl(totalValue)} de ${plural(people, 'cliente', 'clientes')}`, () => {
    list.forEach((o) => {
      const value = amountOverride ?? rest(o)
      if (value > 0) pay(o, value, method)
      if (rest(o) === 0) closeCharge(o)
    })
  })
  ui.selected = []
}
export function createCustomer(name) {
  const c = { id: 'c' + Date.now(), name, phone: '', email: '', address: '', zip: '', devices: [], kind: 'person' }
  db.value.customers.unshift(c)
  return c
}
export const phoneDigits = (p) => (p || '').replace(/\D/g, '').replace(/^55(?=\d{10})/, '')
export const samePhone = (phone, except) => {
  const d = phoneDigits(phone)
  return d.length >= 10 ? db.value.customers.find((c) => c !== except && phoneDigits(c.phone) === d) || null : null
}

/* Link to the customer and payment link. In the product the customer picks Pix, boleto or card on the link page. */
export const greeting = (c) => (c.kind === 'company' ? c.name : c.name.split(' ')[0])
export const clientLink = (o) => `praticos.web.app/q/exemplo-${o.number}`
export const chargeOf = (o) => db.value.charges.find((ch) => ch.status === 'open' && ch.orderIds.includes(o.id)) || null
export function closeCharge(o) { const ch = chargeOf(o); if (ch) ch.status = 'closed' }
export function createCharge(orders) {
  orders.forEach(closeCharge)
  const ch = {
    id: 'ch' + Date.now() + Math.random().toString(36).slice(2, 6), customerId: orders[0].customerId, orderIds: orders.map((o) => o.id),
    value: orders.reduce((s, o) => s + rest(o), 0), status: 'open', createdAt: NOW.toISOString(), openedAt: null,
  }
  db.value.charges.unshift(ch)
  orders.forEach((o) => { o.chargedAt = NOW.toISOString() })
  return ch
}
export function chargeLabel(o) {
  const ch = chargeOf(o)
  if (!ch) return ''
  return `Cobrança enviada ${friendlyDay(ch.createdAt)}, ${ch.openedAt ? `cliente abriu ${friendlyDay(ch.openedAt)}` : 'ainda não abriu'}`
}
export function simulatePaid(ch) {
  const list = ch.orderIds.map(orderById).filter(Boolean)
  act(`${customerOf(list[0]).name} pagou ${brl(ch.value)} pelo link`, () => {
    list.forEach((o) => { if (rest(o) > 0) pay(o, rest(o), 'link') })
    ch.status = 'paid'
  })
}

/* Service invoice: same rules as the app. Parts stay out and the discount is split between services and parts. */
const sumKind = (o, kind) => o.items.filter((i) => i.kind === kind).reduce((s, i) => s + i.qty * i.price, 0)
export const servicesOf = (o) => sumKind(o, 'service')
export const partsOf = (o) => sumKind(o, 'part')
export function invoiceValue(o) {
  const s = servicesOf(o); const p = partsOf(o)
  return s ? Math.max(0, Math.round((s - o.discount * s / (s + p)) * 100) / 100) : 0
}
export const INVOICE_STATUS = {
  sent: { label: 'Na prefeitura', dot: 'warning' }, issued: { label: 'Emitida', dot: 'success' },
  error: { label: 'Recusada', dot: 'danger' }, canceled: { label: 'Cancelada', dot: 'hollow' },
}
export const invoiceOf = (o) => db.value.invoices.find((n) => ['sent', 'issued'].includes(n.status) && n.orderIds.includes(o.id)) || null
export const canInvoice = (o) => o.status === 'done' && servicesOf(o) > 0 && !invoiceOf(o)
export function invoiceNeeds(c) {
  return [!c.email && 'e-mail', !c.address && 'endereço', !c.zip && 'CEP'].filter(Boolean)
}
export function issueInvoices(groups) {
  const made = groups.map((orders) => {
    db.value.invoices = db.value.invoices.filter((n) => !(n.status === 'error' && n.orderIds.some((id) => orders.some((o) => o.id === id))))
    const n = { id: 'nf' + Date.now() + Math.random().toString(36).slice(2, 6), number: null, orderIds: orders.map((o) => o.id), customerId: orders[0].customerId, value: orders.reduce((s, o) => s + invoiceValue(o), 0), status: 'sent', at: NOW.toISOString(), error: null }
    db.value.invoices.unshift(n)
    return n
  })
  const list = () => db.value.invoices
  setTimeout(() => {
    made.forEach((m) => {
      const n = list().find((x) => x.id === m.id)
      if (n?.status === 'sent') { n.status = 'issued'; n.number = 2100 + list().filter((x) => x.number).length }
    })
    toast(made.length === 1 ? 'A prefeitura emitiu a nota' : `A prefeitura emitiu ${made.length} notas`)
  }, 1200)
  return made
}
export function createDevice(customer, label) {
  const d = { id: 'd' + Date.now(), label, tag: '' }
  customer.devices.push(d)
  return d
}
export function createOrder(draft) {
  const number = db.value.nextNumber++
  const o = {
    id: number, number, status: 'quote', customerId: draft.customerId, deviceId: draft.deviceId || null,
    request: draft.request || '', items: draft.items.map((i) => ({ ...i, id: 'n' + Math.random().toString(36).slice(2) })),
    discount: 0, payments: [], photos: [], comments: [], assignee: draft.assignee || null,
    scheduledAt: draft.scheduledAt || null, duration: 60, dueAt: null, hold: null, sentAt: null, chargedAt: null,
    createdAt: NOW.toISOString(), address: null,
  }
  db.value.orders.unshift(o)
  return o
}
export function moveOrderTo(o, date, who) {
  o.scheduledAt = date.toISOString()
  if (who !== undefined) o.assignee = who
}
export function agendaConflict(o) {
  if (!o.assignee || !o.scheduledAt) return null
  const a0 = +new Date(o.scheduledAt); const a1 = a0 + o.duration * 6e4
  return db.value.orders.find((x) => x !== o && x.assignee === o.assignee && x.scheduledAt && isOpen(x) && (() => {
    const b0 = +new Date(x.scheduledAt); const b1 = b0 + x.duration * 6e4
    return a0 < b1 && b0 < a1
  })()) || null
}
export const scheduledLabel = (o) => (o.scheduledAt ? `${friendlyDay(o.scheduledAt)}, ${hhmm(o.scheduledAt)}` : '')

// The prototype's assistant reads a few keywords. It only proposes; the person applies.
export function assistantRead(text, order) {
  const t = text.toLowerCase()
  if (/receb|cancel|apag|exclu|pagou/.test(t)) {
    return { blocked: 'Receber, cancelar e apagar ficam com você. Use os botões da OS.' }
  }
  const generic = ['troca', 'revisao', 'carga', 'manutencao', 'visita', 'teste', 'servico', 'tecnica']
  const wordsOf = (c) => norm(c.name).split(/[^a-z0-9]+/).filter((w) => w.length > 3 && !generic.includes(w))
  const hit = (c) => wordsOf(c).some((w) => norm(text).includes(w))
  const services = db.value.catalog.filter((c) => c.kind === 'service' && hit(c))
  const found = (services.length ? services : db.value.catalog.filter(hit)).slice(0, 4)
  if (!found.length) return { blocked: order ? 'Não achei esse serviço no catálogo. Escreva como ele está cadastrado.' : 'Não entendi. Escreva o serviço como ele está no catálogo.' }
  return { items: found }
}
