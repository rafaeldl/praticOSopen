const money = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' })
const moneyRound = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })

export const brl = (v) => money.format(v || 0)
export const brlShort = (v) => (Number.isInteger(v) ? moneyRound : money).format(v || 0)

// The prototype's clock is frozen on a working day at 10:40, so the example
// data tells the same story at any hour.
function baseToday() {
  const d = new Date()
  if (d.getDay() === 0) d.setDate(d.getDate() + 1)
  d.setHours(10, 40, 0, 0)
  return d
}
export const NOW = baseToday()
export const today = () => { const d = new Date(NOW); d.setHours(0, 0, 0, 0); return d }

export function at(day, hhmm) {
  const [h, m] = hhmm.split(':').map(Number)
  const d = new Date(day); d.setHours(h, m || 0, 0, 0); return d
}
export function addBusinessDays(n) {
  const d = today(); const step = n < 0 ? -1 : 1
  for (let i = 0; i < Math.abs(n);) {
    d.setDate(d.getDate() + step)
    if (d.getDay() !== 0) i++
  }
  return d
}
export const sameDay = (a, b) => new Date(a).toDateString() === new Date(b).toDateString()
export const daysBetween = (a, b) => {
  const x = new Date(a); x.setHours(0, 0, 0, 0)
  const y = new Date(b); y.setHours(0, 0, 0, 0)
  return Math.round((y - x) / 864e5)
}
export const hhmm = (d) => new Date(d).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
export const weekdayShort = (d) => new Date(d).toLocaleDateString('pt-BR', { weekday: 'short' }).replace('.', '')
export const dayMonth = (d) => new Date(d).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
export const longDay = (d) => new Date(d).toLocaleDateString('pt-BR', { weekday: 'long', day: 'numeric', month: 'long' })

export function friendlyDay(d) {
  const diff = daysBetween(today(), d)
  if (diff === 0) return 'hoje'
  if (diff === 1) return 'amanhã'
  if (diff === -1) return 'ontem'
  if (diff > 1 && diff < 7) return weekdayShort(d)
  return dayMonth(d)
}
export const friendlyWhen = (d) => `${friendlyDay(d)}, ${hhmm(d)}`
export const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`

export const modKey = /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl'

export const norm = (s) => (s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

// Every typed word must match the start of some word in the text.
export function matches(text, query) {
  const words = norm(text).split(/[^a-z0-9]+/).filter(Boolean)
  return norm(query).split(/\s+/).filter(Boolean).every((q) => words.some((w) => w.startsWith(q)))
}

const WEEKDAYS = { dom: 0, seg: 1, ter: 2, qua: 3, qui: 4, sex: 5, sab: 6 }

// Reads short text such as "sex 14", "amanhã 9", "hoje 15:30" or "12/11 10h".
export function parseWhen(text) {
  const t = norm(text).trim()
  if (!t) return null
  let day = null
  let rest = t
  const cut = (re) => { const m = rest.match(re); if (m) rest = rest.replace(m[0], ' '); return m }
  if (cut(/\bhoje\b/)) day = today()
  else if (cut(/\bamanha\b/)) { day = today(); day.setDate(day.getDate() + 1) } else {
    const wd = cut(/\b(dom|seg|ter|qua|qui|sex|sab)[a-z-]*\b/)
    const dm = wd ? null : cut(/\b(\d{1,2})\/(\d{1,2})\b/)
    if (wd) {
      day = today()
      const gap = (WEEKDAYS[wd[1]] - day.getDay() + 7) % 7 || 7
      day.setDate(day.getDate() + gap)
    } else if (dm) {
      day = today(); day.setMonth(+dm[2] - 1, +dm[1])
      if (daysBetween(today(), day) < -30) day.setFullYear(day.getFullYear() + 1)
    }
  }
  const tm = rest.match(/\b(\d{1,2})(?::|h)?(\d{2})?\b/)
  if (!day && !tm) return null
  if (!day) day = today()
  const h = tm ? +tm[1] : 9
  if (h > 23) return null
  return at(day, `${h}:${tm?.[2] || '00'}`)
}

/* Money typed by a person: "150", "150,5", "1.500,00" and "1500.50" all mean what they look like. */
export function parseMoney(text) {
  const t = String(text).replace(/[^\d,.]/g, '')
  const dot = /\.\d{1,2}$/.test(t) && !t.includes(',')
  const n = parseFloat(dot ? t : t.replace(/\./g, '').replace(',', '.'))
  return Number.isFinite(n) ? n : null
}
export const moneyText = (n) => new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n)
/* Whole value selected on focus, so typing replaces it instead of landing in the middle. */
export const vMoney = {
  mounted(el) {
    el.inputMode = 'decimal'
    let fresh = false
    el.addEventListener('focus', () => { fresh = true; el.select(); setTimeout(() => { if (document.activeElement === el) el.select() }) })
    el.addEventListener('mouseup', (e) => { if (fresh) { e.preventDefault(); el.select() } fresh = false })
    el.addEventListener('blur', () => { fresh = false })
    el.addEventListener('input', () => { const v = el.value.replace(/[^\d,.]/g, ''); if (v !== el.value) el.value = v })
  },
}
const pad = (n) => String(n).padStart(2, '0')
export const localInput = (v) => { const d = new Date(v); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}` }
