// PDF of the order, drawn like the app's (lib/services/pdf/, docs/PDF_GENERATION.md):
// teal header on every page, status bar, customer and summary, one block per
// device with its items, QR of the link, attached photos, terms, signatures and
// one page per checklist. Several orders go in one file, each starting on its
// own page and numbered on its own ("Página 1 de 2").
//
// Pure: texts come resolved (load.ts) and images as bytes, so vitest covers it
// without a browser. pdf-lib is loaded with this module, never before someone
// asks for a PDF. Helvetica draws only WinAnsi; what is outside it is simplified
// goes out in Roboto (assets/fonts, as the app), loaded only when needed.
import { PDFDocument, StandardFonts, degrees, rgb, type PDFFont, type PDFImage, type PDFPage, type RGB } from 'pdf-lib'
import qrcode from 'qrcode-generator'
import type { OrderForm } from '@/lib/forms/model'
import type { Order, OrderLine, OrderStatus } from '@/lib/orders/model'

export interface PdfImage {
  bytes: Uint8Array
  kind: 'jpg' | 'png'
}

export interface PdfTexts {
  serviceOrder: string
  customer: string
  newOrder: string
  notInformed: string
  generatedBy: string
  site: string
  description: string
  quantity: string
  unitValue: string
  total: string
  services: string
  products: string
  discount: string
  paid: string
  summary: string
  general: string
  equipment: string
  serviceType: string
  productType: string
  itemType: string
  technician: string
  created: string
  completed: string
  serviceLocation: string
  trackOnline: string
  trackOnlineDescription: string
  terms: string
  clientSignature: string
  companySignature: string
  photosDigital: string
  yes: string
  no: string
  formCompleted: string
  formInProgress: string
  formPending: string
  notAnswered: string
  notSelected: string
  status: (status: OrderStatus) => string
  money: (value: number) => string
  date: (iso: string) => string
  pageOf: (current: number, total: number) => string
  attachedPhotos: (count: number) => string
  formLabel: (title: string) => string
  formTitle: (form: OrderForm) => string
  itemLabel: (item: OrderForm['items'][number]) => string
  optionText: (item: OrderForm['items'][number], value: string) => string
  /** The note of a question in lines (question, marked options, photos). Optional: older callers have none. */
  noteLines?: (form: OrderForm, item: OrderForm['items'][number]) => string[]
}

export interface PdfCompany {
  name: string
  address?: string | null
  phone?: string | null
  email?: string | null
  terms?: string | null
  logo?: PdfImage | null
}

export interface PdfOrderPart {
  order: Order
  /** The customer's record (phone and e-mail), or the copy in the order. */
  customer: { name?: string; phone?: string | null; email?: string | null } | null
  /** payment == 'paid' on the order (the app shows "Pago" with the total). */
  paid: boolean
  shareUrl: string | null
  /** Photos that downloaded, in the order's order; failures are left out (as the app). */
  photos: PdfImage[]
  /** Photos attached but not downloaded: the section says they are in the system. */
  missingPhotos: number
  forms: { form: OrderForm; photos: Record<string, PdfImage[]> }[]
}

export interface PdfOptions {
  /** viewPrices with "Valores e cobrança" on: prices, totals and payments. */
  showValues: boolean
  /** Loads fontkit and Roboto (assets/fonts, the app's fallback); called only when some text needs it. */
  fallbackFont?: () => Promise<{ fontkit: unknown; bytes: Uint8Array }>
  /**
   * The "PraticOS" mark across the order's pages (#724), exactly when the app
   * draws it: FeatureGateService.shouldShowPdfWatermark, on the web
   * shouldShowPdfWatermark of lib/plan-limits.ts (off while the plan switch is off).
   */
  watermark?: boolean
}

// PdfStyles of the app.
const C = {
  primary: hex(0x1b5e7b),
  headerStart: hex(0x0d3b4f),
  statusBar: hex(0xf0f7fa),
  text: hex(0x1a2b3c),
  secondary: hex(0x5a7184),
  muted: hex(0x8fa3b8),
  bgLight: hex(0xf8fafb),
  bgLighter: hex(0xf0f7fa),
  border: hex(0xe2e8f0),
  divider: hex(0xedf2f7),
  footer: hex(0xa0aec0),
  equipmentBg: hex(0xfafcfd),
  equipmentBorder: hex(0xcbd9df),
  product: hex(0xe67e22),
  paid: hex(0x16a34a),
  danger: hex(0xdc2626),
  white: rgb(1, 1, 1),
  grey: hex(0xd1d5db),
}
const STATUS_COLOR: Record<OrderStatus, RGB> = {
  quote: hex(0xff9800),
  approved: hex(0x1b5e7b),
  progress: hex(0x9c27b0),
  done: hex(0x4caf50),
  canceled: hex(0xf44336),
}
const FORM_COLOR = { completed: hex(0x4caf50), in_progress: hex(0xff9800), pending: hex(0x8fa3b8) }

const W = 595.28
const H = 841.89
const PAD = 32
const FOOTER = 26
const BODY_W = W - PAD * 2
const PHOTO = 75
const GAP = 5

function hex(value: number): RGB {
  return rgb(((value >> 16) & 255) / 255, ((value >> 8) & 255) / 255, (value & 255) / 255)
}

// ---------------------------------------------------------------------------
// Text that Helvetica can draw (WinAnsi)
// ---------------------------------------------------------------------------

const CP1252_EXTRA = new Set('€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ')

function drawable(char: string): boolean {
  const code = char.codePointAt(0) ?? 0
  return (code >= 0x20 && code <= 0x7e) || (code >= 0xa0 && code <= 0xff) || CP1252_EXTRA.has(char)
}

/** Has a character Helvetica cannot draw (the app falls back to Roboto for it). */
export function needsFallback(text: string): boolean {
  return [...text].some((char) => !/[\t\r\n]/.test(char) && !drawable(char))
}

/** One line of text Helvetica draws: accents it lacks are dropped, the rest becomes "?". */
export function pdfSafe(text: string): string {
  let out = ''
  for (const char of text.replace(/[\t\r\n]+/g, ' ')) {
    if (drawable(char)) out += char
    else {
      const plain = char.normalize('NFKD').replace(/\p{M}/gu, '')
      out += plain && [...plain].every(drawable) ? plain : '?'
    }
  }
  return out
}

/** Lines of `text` that fit `width` (paragraphs kept, long words broken). */
export function wrap(text: string, base: PDFFont, size: number, width: number, fallback: PDFFont | null = null): string[] {
  const lines: string[] = []
  for (const paragraph of text.split(/\r?\n/)) {
    const odd = !!fallback && needsFallback(paragraph)
    const font = odd ? (fallback as PDFFont) : base
    const words = (odd ? paragraph.replace(/\t/g, ' ') : pdfSafe(paragraph)).split(' ').filter(Boolean)
    let line = ''
    for (const word of words) {
      const next = line ? `${line} ${word}` : word
      if (font.widthOfTextAtSize(next, size) <= width) {
        line = next
        continue
      }
      if (line) lines.push(line)
      line = ''
      let rest = word
      while (font.widthOfTextAtSize(rest, size) > width && rest.length > 1) {
        let cut = rest.length - 1
        while (cut > 1 && font.widthOfTextAtSize(rest.slice(0, cut), size) > width) cut--
        lines.push(rest.slice(0, cut))
        rest = rest.slice(cut)
      }
      line = rest
    }
    lines.push(line)
  }
  return lines.length ? lines : ['']
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

interface Ctx {
  doc: PDFDocument
  font: PDFFont
  bold: PDFFont
  texts: PdfTexts
  show: boolean
  company: PdfCompany
  logo: PDFImage | null
  images: Map<PdfImage, PDFImage | null>
  /** Roboto, only when some text needs it (B4). */
  fallback: PDFFont | null
  watermark: boolean
}

/** The font and text to draw: Helvetica as the app, Roboto for what Helvetica lacks. */
function face(ctx: Pick<Ctx, 'font' | 'bold' | 'fallback'>, value: string, bold = false): { font: PDFFont; text: string } {
  if (ctx.fallback && needsFallback(value)) return { font: ctx.fallback, text: value.replace(/[\t\r\n]+/g, ' ') }
  return { font: bold ? ctx.bold : ctx.font, text: pdfSafe(value) }
}

/** Pages of one order, with a cursor that goes down from the top. */
class Flow {
  pages: PDFPage[] = []
  page!: PDFPage
  /** Distance from the top of the page. */
  y = 0
  constructor(
    private ctx: Ctx,
    private top: () => number,
  ) {
    this.newPage()
  }
  newPage() {
    this.page = this.ctx.doc.addPage([W, H])
    this.pages.push(this.page)
    this.y = this.top()
  }
  /** Room for `height` below, or a new page. */
  need(height: number) {
    if (this.y + height > H - FOOTER - 12) this.newPage()
  }
  text(value: string, x: number, size: number, options: { bold?: boolean; color?: RGB; right?: number; opacity?: number; baseline?: number } = {}) {
    const { font, text: safe } = face(this.ctx, value, options.bold)
    const width = font.widthOfTextAtSize(safe, size)
    const left = options.right !== undefined ? options.right - width : x
    this.page.drawText(safe, { x: left, y: H - (options.baseline ?? this.y) - size * 0.8, size, font, color: options.color ?? C.text, opacity: options.opacity })
    return width
  }
  rect(x: number, top: number, width: number, height: number, options: { fill?: RGB; border?: RGB }) {
    this.page.drawRectangle({
      x,
      y: H - top - height,
      width,
      height,
      color: options.fill,
      borderColor: options.border,
      borderWidth: options.border ? 0.5 : 0,
    })
  }
  line(x1: number, x2: number, top: number, color: RGB = C.border) {
    this.page.drawLine({ start: { x: x1, y: H - top }, end: { x: x2, y: H - top }, thickness: 0.5, color })
  }
}

const lineName = (line: OrderLine) => {
  const name = line.name || ''
  const description = line.description?.trim()
  return description && description !== name ? (name ? `${name} - ${description}` : description) : name
}

function drawHeader(ctx: Ctx, page: PDFPage, number: string): number {
  const { company, texts } = ctx
  const info = [company.address, company.phone, company.email].filter((item): item is string => !!item?.trim())
  const height = Math.max(72, 32 + 13 + info.length * 10)
  // The app's teal gradient, in stripes.
  const STRIPES = 40
  for (let i = 0; i < STRIPES; i++) {
    const k = i / (STRIPES - 1)
    const mix = (a: number, b: number) => a + (b - a) * k
    page.drawRectangle({
      x: (W / STRIPES) * i,
      y: H - height,
      width: W / STRIPES + 1.5,
      height,
      color: rgb(mix(C.headerStart.red, C.primary.red), mix(C.headerStart.green, C.primary.green), mix(C.headerStart.blue, C.primary.blue)),
    })
  }
  let x = PAD
  if (ctx.logo) {
    page.drawRectangle({ x, y: H - 16 - 40, width: 40, height: 40, color: C.white })
    const scale = Math.min(32 / ctx.logo.width, 32 / ctx.logo.height)
    const w = ctx.logo.width * scale
    const h = ctx.logo.height * scale
    page.drawImage(ctx.logo, { x: x + 4 + (32 - w) / 2, y: H - 16 - 4 - 32 + (32 - h) / 2, width: w, height: h })
    x += 52
  }
  const draw = (value: string, size: number, top: number, bold: boolean, opacity = 1, right?: number) => {
    const { font, text: safe } = face(ctx, value, bold)
    const left = right !== undefined ? right - font.widthOfTextAtSize(safe, size) : x
    page.drawText(safe, { x: left, y: H - top - size * 0.8, size, font, color: C.white, opacity })
  }
  draw(company.name, 10, 16, true)
  info.forEach((item, i) => draw(item, 8, 30 + i * 10, false, 0.73))
  draw(texts.serviceOrder.toLocaleUpperCase(), 9, 16, false, 0.6, W - PAD)
  draw(`#${number}`, 22, 28, true, 1, W - PAD)
  return height
}

function drawFooter(ctx: Ctx, page: PDFPage, left: string, right: string) {
  page.drawRectangle({ x: 0, y: 0, width: W, height: FOOTER, color: C.bgLight })
  page.drawLine({ start: { x: 0, y: FOOTER }, end: { x: W, y: FOOTER }, thickness: 0.5, color: C.border })
  const size = 7
  const l = face(ctx, left)
  page.drawText(l.text, { x: PAD, y: 10, size, font: l.font, color: C.footer })
  const r = face(ctx, right)
  page.drawText(r.text, { x: W - PAD - r.font.widthOfTextAtSize(r.text, size), y: 10, size, font: r.font, color: C.footer })
}

function sectionTitle(flow: Flow, title: string, x = PAD) {
  flow.text(title.toLocaleUpperCase(), x, 7.5, { bold: true, color: C.primary })
}

function drawStatusBar(ctx: Ctx, flow: Flow, order: Order) {
  const top = flow.y
  flow.rect(0, top, W, 20, { fill: C.statusBar })
  const color = STATUS_COLOR[order.status]
  flow.page.drawCircle({ x: PAD + 3, y: H - top - 10, size: 3, color })
  flow.y = top + 6.5
  let x = PAD + 10
  x += flow.text(ctx.texts.status(order.status).toLocaleUpperCase(), x, 8, { bold: true, color })
  const tech = order.assignedTo?.name
  if (tech) {
    x += flow.text('  ·  ', x, 8, { color: C.muted })
    flow.text(`${ctx.texts.technician}: ${tech}`, x, 8, { color: C.secondary })
  }
  const dates = [order.createdAt ? `${ctx.texts.created}: ${ctx.texts.date(order.createdAt)}` : null]
  if (order.status === 'done' && order.updatedAt) dates.push(`${ctx.texts.completed}: ${ctx.texts.date(order.updatedAt)}`)
  flow.text(dates.filter(Boolean).join('  ·  '), 0, 7.5, { color: C.muted, right: W - PAD })
  flow.y = top + 20 + 16
}

function customerCard(ctx: Ctx, part: PdfOrderPart, width: number) {
  const name = part.customer?.name || part.order.customer?.name || ctx.texts.notInformed
  const contact = [part.customer?.phone, part.customer?.email].filter((item): item is string => !!item?.trim()).join(' · ')
  const inner = width - 20
  const nameLines = wrap(name, ctx.bold, 10, inner, ctx.fallback)
  const contactLines = contact ? wrap(contact, ctx.font, 8, inner, ctx.fallback).slice(0, 2) : []
  const address = part.order.address?.trim() ? wrap(part.order.address, ctx.font, 8.5, inner, ctx.fallback) : []
  const height = 16 + nameLines.length * 12 + (contactLines.length ? 3 + contactLines.length * 10 : 0) + (address.length ? 18 + address.length * 11 : 0)
  const draw = (flow: Flow, x: number, top: number, boxHeight: number) => {
    flow.rect(x, top, width, boxHeight, { border: C.border })
    let y = top + 8
    for (const line of nameLines) {
      flow.text(line, x + 10, 10, { bold: true, baseline: y })
      y += 12
    }
    if (contactLines.length) y += 3
    for (const line of contactLines) {
      flow.text(line, x + 10, 8, { color: C.secondary, baseline: y })
      y += 10
    }
    if (address.length) {
      y += 6
      flow.text(ctx.texts.serviceLocation.toLocaleUpperCase(), x + 10, 7, { bold: true, color: C.muted, baseline: y })
      y += 12
      for (const line of address) {
        flow.text(line, x + 10, 8.5, { baseline: y })
        y += 11
      }
    }
  }
  return { height, draw }
}

function summaryCard(ctx: Ctx, part: PdfOrderPart) {
  const { order } = part
  const services = order.lines.filter((l) => l.kind === 'service').reduce((sum, l) => sum + (l.value ?? 0), 0)
  const products = order.lines.filter((l) => l.kind === 'product').reduce((sum, l) => sum + (l.total ?? 0), 0)
  const discount = order.discount ?? 0
  const total = order.total ?? 0
  const paidAmount = order.paidAmount ?? 0
  const rows: { label: string; value: string; color?: RGB }[] = []
  if (services > 0) rows.push({ label: ctx.texts.services, value: ctx.texts.money(services) })
  if (products > 0) rows.push({ label: ctx.texts.products, value: ctx.texts.money(products) })
  if (discount > 0) rows.push({ label: ctx.texts.discount, value: `- ${ctx.texts.money(discount)}`, color: C.danger })
  const paid = part.paid || paidAmount > 0
  const height = 20 + rows.length * 13 + 12 + 16 + (paid ? 17 : 0)
  const draw = (flow: Flow, x: number, top: number, width: number, boxHeight: number) => {
    flow.rect(x, top, width, boxHeight, { border: C.border })
    const right = x + width - 12
    let y = top + 10
    for (const row of rows) {
      flow.text(row.label, x + 12, 8.5, { color: row.color ?? C.secondary, baseline: y })
      flow.text(row.value, 0, 8.5, { color: row.color ?? C.text, right, baseline: y })
      y += 13
    }
    flow.line(x + 12, right, y + 4, C.border)
    y += 12
    flow.text(ctx.texts.total.toLocaleUpperCase(), x + 12, 10, { bold: true, color: C.primary, baseline: y + 1 })
    flow.text(ctx.texts.money(total), 0, 12, { bold: true, color: C.primary, right, baseline: y })
    y += 16
    if (paid) {
      y += 4
      flow.text(ctx.texts.paid, x + 12, 8.5, { color: C.paid, baseline: y })
      flow.text(ctx.texts.money(paidAmount > 0 ? paidAmount : total), 0, 8.5, { color: C.paid, right, baseline: y })
    }
  }
  return { height, draw }
}

function drawCustomerAndSummary(ctx: Ctx, flow: Flow, part: PdfOrderPart) {
  const SUMMARY = 260
  const cardWidth = ctx.show ? BODY_W - SUMMARY - 12 : BODY_W
  const card = customerCard(ctx, part, cardWidth)
  const summary = ctx.show ? summaryCard(ctx, part) : null
  const height = Math.max(card.height, summary?.height ?? 0)
  flow.need(16 + height)
  sectionTitle(flow, ctx.texts.customer)
  if (summary) sectionTitle(flow, ctx.texts.summary, PAD + cardWidth + 12)
  flow.y += 14
  card.draw(flow, PAD, flow.y, height)
  summary?.draw(flow, PAD + cardWidth + 12, flow.y, SUMMARY, height)
  flow.y += height + 14
}

interface Block {
  name: string
  meta: string
  badge: number | null
  lines: OrderLine[]
}

/** Same grouping as buildEquipmentBlocks: one block, or one per device plus "Geral". */
function blocksOf(ctx: Ctx, order: Order): Block[] {
  const meta = (d: Order['devices'][number]) => [d.serial, (d as { manufacturer?: string }).manufacturer].filter(Boolean).join(' · ')
  if (!order.devices.length) return order.lines.length ? [{ name: ctx.texts.equipment, meta: '', badge: null, lines: order.lines }] : []
  if (order.devices.length === 1) {
    const device = order.devices[0]!
    return [{ name: device.name || ctx.texts.equipment, meta: meta(device), badge: null, lines: order.lines }]
  }
  const blocks: Block[] = order.devices.map((device, i) => ({
    name: device.name || ctx.texts.equipment,
    meta: meta(device),
    badge: i + 1,
    lines: order.lines.filter((line) => line.deviceId && line.deviceId === device.id),
  }))
  const general = order.lines.filter((line) => !line.deviceId)
  if (general.length) blocks.push({ name: ctx.texts.general, meta: '', badge: null, lines: general })
  return blocks
}

function drawBlocks(ctx: Ctx, flow: Flow, order: Order) {
  const { texts, show } = ctx
  const cols = show ? [45, BODY_W - 45 - 28 - 140, 28, 70, 70] : [45, BODY_W - 45 - 28, 28]
  const xs = cols.map((_, i) => PAD + cols.slice(0, i).reduce((a, b) => a + b, 0))
  const headerRow = () => {
    flow.rect(PAD, flow.y, BODY_W, 20, { fill: C.bgLighter, border: C.equipmentBorder })
    const top = flow.y + 6
    flow.text(texts.itemType, xs[0]! + 6, 7.5, { bold: true, color: C.primary, baseline: top })
    flow.text(texts.description, xs[1]! + 6, 7.5, { bold: true, color: C.primary, baseline: top })
    flow.text(texts.quantity, 0, 7.5, { bold: true, color: C.primary, right: xs[2]! + cols[2]! / 2 + ctx.bold.widthOfTextAtSize(texts.quantity, 7.5) / 2, baseline: top })
    if (show) {
      flow.text(texts.unitValue, 0, 7.5, { bold: true, color: C.primary, right: xs[3]! + cols[3]! - 6, baseline: top })
      flow.text(texts.total, 0, 7.5, { bold: true, color: C.primary, right: xs[4]! + cols[4]! - 6, baseline: top })
    }
    flow.y += 20
  }
  for (const [index, block] of blocksOf(ctx, order).entries()) {
    if (index) flow.y += 10
    flow.need(30 + (block.lines.length ? 40 : 0))
    const top = flow.y
    flow.rect(PAD, top, BODY_W, 28, { fill: C.equipmentBg, border: C.equipmentBorder })
    let x = PAD + 10
    if (block.badge !== null) {
      flow.page.drawCircle({ x: x + 9, y: H - top - 14, size: 9, color: C.primary })
      flow.text(String(block.badge), 0, 9, { bold: true, color: C.white, right: x + 9 + ctx.bold.widthOfTextAtSize(String(block.badge), 9) / 2, baseline: top + 10 })
      x += 26
    }
    flow.y = top + 9
    x += flow.text(block.name, x, 10, { bold: true }) + 8
    if (block.meta) flow.text(block.meta, x, 8, { color: C.secondary, baseline: top + 10.5 })
    if (block.lines.length && show) {
      const subtotal = block.lines.reduce((sum, line) => sum + ((line.kind === 'product' ? line.total : line.value) ?? 0), 0)
      flow.text(texts.money(subtotal), 0, 10, { bold: true, color: C.primary, right: W - PAD - 10 })
    }
    flow.y = top + 28
    if (!block.lines.length) continue
    headerRow()
    for (const line of block.lines) {
      const descLines = wrap(lineName(line), ctx.font, 8.5, cols[1]! - 12, ctx.fallback)
      const height = 10 + descLines.length * 11
      if (flow.y + height > H - FOOTER - 12) {
        flow.newPage()
        headerRow()
      }
      const rowTop = flow.y
      flow.rect(PAD, rowTop, BODY_W, height, { border: C.divider })
      const product = line.kind === 'product'
      flow.text(product ? texts.productType : texts.serviceType, xs[0]! + 4, 7, { bold: true, color: product ? C.product : C.primary, baseline: rowTop + 6 })
      descLines.forEach((text, i) => flow.text(text, xs[1]! + 6, 8.5, { baseline: rowTop + 5 + i * 11 }))
      const quantity = String(product ? (line.quantity ?? 1) : 1)
      flow.text(quantity, 0, 8.5, { color: C.secondary, right: xs[2]! + cols[2]! / 2 + ctx.font.widthOfTextAtSize(quantity, 8.5) / 2, baseline: rowTop + 5 })
      if (show) {
        flow.text(texts.money(line.value ?? 0), 0, 8.5, { color: C.secondary, right: xs[3]! + cols[3]! - 6, baseline: rowTop + 5 })
        flow.text(texts.money((product ? line.total : line.value) ?? 0), 0, 8.5, { bold: true, right: xs[4]! + cols[4]! - 6, baseline: rowTop + 5 })
      }
      flow.y = rowTop + height
    }
  }
  flow.y += 14
}

function drawQr(ctx: Ctx, flow: Flow, url: string) {
  const qr = qrcode(0, 'M')
  qr.addData(url)
  qr.make()
  const count = qr.getModuleCount()
  const lines = wrap(ctx.texts.trackOnlineDescription, ctx.font, 8, BODY_W - 100, ctx.fallback)
  const height = Math.max(84, 20 + 13 + lines.length * 10 + 14)
  flow.need(height)
  const top = flow.y
  flow.rect(PAD, top, BODY_W, height, { border: C.border })
  const cell = 64 / count
  for (let r = 0; r < count; r++) {
    for (let c = 0; c < count; c++) {
      if (qr.isDark(r, c)) flow.page.drawRectangle({ x: PAD + 12 + c * cell, y: H - top - 10 - (r + 1) * cell, width: cell + 0.05, height: cell + 0.05, color: C.text })
    }
  }
  let y = top + 12
  flow.text(ctx.texts.trackOnline, PAD + 88, 10, { bold: true, color: C.primary, baseline: y })
  y += 15
  for (const line of lines) {
    flow.text(line, PAD + 88, 8, { color: C.secondary, baseline: y })
    y += 10
  }
  flow.text(url, PAD + 88, 7.5, { color: C.primary, baseline: y + 4 })
  flow.y = top + height + 14
}

function imageOf(ctx: Ctx, image: PdfImage): PDFImage | null {
  return ctx.images.get(image) ?? null
}

function drawPhotoGrid(ctx: Ctx, flow: Flow, photos: PdfImage[], left = PAD, width = BODY_W) {
  const perRow = Math.max(1, Math.floor((width + GAP) / (PHOTO + GAP)))
  for (let i = 0; i < photos.length; i += perRow) {
    flow.need(PHOTO + GAP)
    photos.slice(i, i + perRow).forEach((photo, j) => {
      const x = left + j * (PHOTO + GAP)
      flow.rect(x, flow.y, PHOTO, PHOTO, { border: C.grey })
      const image = imageOf(ctx, photo)
      if (!image) return
      const scale = Math.min((PHOTO - 1) / image.width, (PHOTO - 1) / image.height)
      const w = image.width * scale
      const h = image.height * scale
      flow.page.drawImage(image, { x: x + (PHOTO - w) / 2, y: H - flow.y - PHOTO + (PHOTO - h) / 2, width: w, height: h })
    })
    flow.y += PHOTO + GAP
  }
}

function drawPhotos(ctx: Ctx, flow: Flow, part: PdfOrderPart) {
  const shown = part.photos.filter((photo) => imageOf(ctx, photo))
  if (shown.length) {
    flow.need(16 + PHOTO)
    sectionTitle(flow, ctx.texts.attachedPhotos(shown.length))
    flow.y += 14
    drawPhotoGrid(ctx, flow, shown)
    flow.y += 9
  }
  if (part.missingPhotos > 0) {
    flow.need(14)
    flow.text(ctx.texts.photosDigital, PAD, 8, { color: C.secondary })
    flow.y += 18
  }
}

function drawTermsAndSignatures(ctx: Ctx, flow: Flow, part: PdfOrderPart) {
  const terms = ctx.company.terms?.trim()
  if (terms) {
    const lines = wrap(terms, ctx.font, 7.5, BODY_W - 20, ctx.fallback)
    flow.need(16 + 12 + Math.min(lines.length, 3) * 10.5)
    sectionTitle(flow, ctx.texts.terms)
    flow.y += 14
    let start = flow.y
    let drawn = 0
    const box = () => flow.rect(PAD, start, BODY_W, 12 + drawn * 10.5, { fill: C.bgLight, border: C.border })
    // Long terms run over pages; each page gets its own box.
    const pending: string[] = []
    const flush = () => {
      if (!pending.length) return
      drawn = pending.length
      box()
      pending.forEach((line, i) => flow.text(line, PAD + 10, 7.5, { color: C.secondary, baseline: start + 6 + i * 10.5 }))
      pending.length = 0
    }
    for (const line of lines) {
      if (start + 12 + (pending.length + 1) * 10.5 > H - FOOTER - 12) {
        flush()
        flow.newPage()
        start = flow.y
      }
      pending.push(line)
    }
    flush()
    flow.y = start + 12 + drawn * 10.5
  }
  flow.need(64)
  flow.y += 32
  const blockW = 200
  const left = (W - blockW * 2 - 32) / 2
  const sign = (x: number, label: string, name?: string) => {
    flow.line(x, x + blockW, flow.y, C.muted)
    const center = (text: string, size: number, bold: boolean) => (blockW - ((f) => f.font.widthOfTextAtSize(f.text, size))(face(ctx, text, bold))) / 2
    flow.text(label, x + center(label, 8.5, true), 8.5, { bold: true, baseline: flow.y + 6 })
    if (name) flow.text(name, x + center(name, 7.5, false), 7.5, { color: C.secondary, baseline: flow.y + 18 })
  }
  sign(left, ctx.texts.clientSignature, part.customer?.name || part.order.customer?.name)
  sign(left + blockW + 32, ctx.texts.companySignature, ctx.company.name)
  flow.y += 32
}

function formAnswer(ctx: Ctx, form: OrderForm, item: OrderForm['items'][number]): { text: string; color?: RGB; checks?: { label: string; on: boolean }[] } | null {
  const response = form.responses.find((r) => r.itemId === item.id)
  const value = response?.value
  if (item.type === 'photo_only') return null
  if (value === undefined || value === null || value === '' || (Array.isArray(value) && !value.length && item.type !== 'checklist')) {
    if (!response) return { text: ctx.texts.notAnswered, color: C.muted }
  }
  switch (item.type) {
    case 'boolean':
      if (typeof value !== 'boolean') return { text: ctx.texts.notAnswered, color: C.muted }
      return { text: `X ${(value ? ctx.texts.yes : ctx.texts.no).toLocaleUpperCase()}`, color: value ? C.paid : C.danger }
    case 'checklist': {
      const picked = Array.isArray(value) ? value.map(String) : []
      return { text: '', checks: (item.options ?? []).map((option) => ({ label: ctx.texts.optionText(item, option), on: picked.includes(option) })) }
    }
    case 'select':
      return { text: typeof value === 'string' && value ? ctx.texts.optionText(item, value) : ctx.texts.notSelected }
    default: {
      const text = value === undefined || value === null ? '' : String(value)
      return text ? { text } : { text: ctx.texts.notInformed, color: C.muted }
    }
  }
}

function drawForm(ctx: Ctx, part: PdfOrderPart, entry: PdfOrderPart['forms'][number]): PDFPage[] {
  const { form, photos } = entry
  const number = part.order.number !== undefined ? String(part.order.number) : ctx.texts.newOrder
  const flow = new Flow(ctx, () => PAD)
  // Form header: title and company on the left, order and status on the right.
  const top = flow.y
  const statusColor = FORM_COLOR[form.status]
  const statusText = form.status === 'completed' ? ctx.texts.formCompleted : form.status === 'in_progress' ? ctx.texts.formInProgress : ctx.texts.formPending
  const title = wrap(ctx.texts.formTitle(form).toLocaleUpperCase(), ctx.bold, 13, BODY_W - 160, ctx.fallback)
  title.forEach((line, i) => flow.text(line, PAD, 13, { bold: true, color: C.primary, baseline: top + i * 16 }))
  flow.text(ctx.company.name, PAD, 8.5, { color: C.secondary, baseline: top + title.length * 16 + 2 })
  flow.text(`${ctx.texts.serviceOrder.toLocaleUpperCase()} Nº`, 0, 7.5, { color: C.muted, right: W - PAD, baseline: top })
  flow.text(number, 0, 14, { bold: true, right: W - PAD, baseline: top + 10 })
  const when = form.updatedAt ?? form.startedAt
  if (when) flow.text(ctx.texts.date(when), 0, 8, { color: C.secondary, right: W - PAD, baseline: top + 28 })
  flow.text(statusText.toLocaleUpperCase(), 0, 7.5, { bold: true, color: statusColor, right: W - PAD, baseline: top + 40 })
  flow.y = Math.max(top + title.length * 16 + 16, top + 50) + 6
  flow.line(PAD, W - PAD, flow.y, C.border)
  flow.y += 12
  for (const item of form.items) {
    const label = wrap(ctx.texts.itemLabel(item), ctx.bold, 9, BODY_W - 20, ctx.fallback)
    const answer = formAnswer(ctx, form, item)
    const answerLines = answer && !answer.checks ? wrap(answer.text, ctx.font, 8.5, BODY_W - 20, ctx.fallback) : []
    const checks = answer?.checks ?? []
    const noteLines = (ctx.texts.noteLines?.(form, item) ?? []).flatMap((line) => wrap(line, ctx.font, 8.5, BODY_W - 20, ctx.fallback))
    const itemPhotos = (photos[item.id] ?? []).filter((photo) => imageOf(ctx, photo))
    const height = 10 + label.length * 11 + 4 + answerLines.length * 11 + checks.length * 11 + (noteLines.length ? 3 + noteLines.length * 11 : 0) + 6
    flow.need(height + (itemPhotos.length ? PHOTO + GAP : 0))
    const cardTop = flow.y
    flow.rect(PAD, cardTop, BODY_W, height, { border: C.border })
    let y = cardTop + 8
    for (const line of label) {
      flow.text(line, PAD + 10, 9, { bold: true, baseline: y })
      y += 11
    }
    y += 4
    for (const line of answerLines) {
      flow.text(line, PAD + 10, 8.5, { color: answer?.color ?? C.text, bold: item.type === 'boolean', baseline: y })
      y += 11
    }
    for (const check of checks) {
      flow.text(`[${check.on ? 'X' : ' '}] ${check.label}`, PAD + 10, 8.5, { color: check.on ? C.text : C.muted, baseline: y })
      y += 11
    }
    if (noteLines.length) y += 3
    for (const line of noteLines) {
      flow.text(line, PAD + 10, 8.5, { color: C.secondary, baseline: y })
      y += 11
    }
    flow.y = cardTop + height + 4
    if (itemPhotos.length) {
      drawPhotoGrid(ctx, flow, itemPhotos, PAD + 10, BODY_W - 20)
    }
    flow.y += 6
  }
  flow.pages.forEach((page, i) => drawFooter(ctx, page, ctx.texts.formLabel(ctx.texts.formTitle(form)), ctx.texts.pageOf(i + 1, flow.pages.length)))
  return flow.pages
}

/** The app's PdfMainOsBuilder.buildWatermark: "PraticOS" bold 72, grey at 6%, turned 45° down, centred on the page. */
export const WATERMARK = { text: 'PraticOS', size: 72, opacity: 0.06, angle: -45 }

function drawWatermark(ctx: Ctx, page: PDFPage) {
  const width = ctx.bold.widthOfTextAtSize(WATERMARK.text, WATERMARK.size)
  const height = ctx.bold.heightAtSize(WATERMARK.size, { descender: false })
  const rad = (WATERMARK.angle * Math.PI) / 180
  // The text turns around its start: move the start so its middle lands on the page's middle.
  const [cx, cy] = [width / 2, height / 2]
  const x = W / 2 - (cx * Math.cos(rad) - cy * Math.sin(rad))
  const y = H / 2 - (cx * Math.sin(rad) + cy * Math.cos(rad))
  page.drawText(WATERMARK.text, { x, y, size: WATERMARK.size, font: ctx.bold, color: hex(0x9e9e9e), opacity: WATERMARK.opacity, rotate: degrees(WATERMARK.angle) })
}

function drawOrder(ctx: Ctx, part: PdfOrderPart) {
  const number = part.order.number !== undefined ? String(part.order.number) : ctx.texts.newOrder
  const pages: PDFPage[] = []
  let headerHeight = 0
  const flow = new Flow(ctx, () => {
    headerHeight = drawHeader(ctx, ctx.doc.getPage(ctx.doc.getPageCount() - 1), number)
    return headerHeight
  })
  drawStatusBar(ctx, flow, part.order)
  drawCustomerAndSummary(ctx, flow, part)
  drawBlocks(ctx, flow, part.order)
  if (part.shareUrl) drawQr(ctx, flow, part.shareUrl)
  drawPhotos(ctx, flow, part)
  drawTermsAndSignatures(ctx, flow, part)
  pages.push(...flow.pages)
  flow.pages.forEach((page, i) => drawFooter(ctx, page, `${ctx.texts.generatedBy} · ${ctx.texts.site}`, ctx.texts.pageOf(i + 1, flow.pages.length)))
  // Over the content, on the order's pages only (the app's buildForeground of the main MultiPage).
  if (ctx.watermark) flow.pages.forEach((page) => drawWatermark(ctx, page))
  for (const entry of part.forms) drawForm(ctx, part, entry)
}

async function embed(doc: PDFDocument, image: PdfImage): Promise<PDFImage | null> {
  try {
    return image.kind === 'png' ? await doc.embedPng(image.bytes) : await doc.embedJpg(image.bytes)
  } catch (error) {
    // A broken file is left out, like a failed download (the app's rule).
    console.warn('pdf: image not embedded', error)
    return null
  }
}

/** Roboto embedded (subset) only when the data has a character Helvetica cannot draw. */
async function fallbackFor(doc: PDFDocument, parts: PdfOrderPart[], company: PdfCompany, options: PdfOptions): Promise<PDFFont | null> {
  if (!options.fallbackFont) return null
  const data = JSON.stringify([company.name, company.address, company.phone, company.email, company.terms, parts.map((p) => [p.order, p.customer, p.shareUrl, p.forms.map((f) => f.form)])])
  if (!needsFallback(data)) return null
  try {
    const { fontkit, bytes } = await options.fallbackFont()
    doc.registerFontkit(fontkit as Parameters<PDFDocument['registerFontkit']>[0])
    return await doc.embedFont(bytes, { subset: true })
  } catch (error) {
    // Like the app: without the fallback the PDF still comes out (simplified text).
    console.warn('pdf: fallback font not loaded', error)
    return null
  }
}

/** One PDF with every order in `parts`, in that order. */
export async function buildOrdersPdf(parts: PdfOrderPart[], company: PdfCompany, texts: PdfTexts, options: PdfOptions): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  doc.setTitle(pdfSafe(parts.length === 1 ? `${texts.serviceOrder} ${parts[0]!.order.number ?? ''}` : `${texts.serviceOrder} (${parts.length})`))
  doc.setProducer('PraticOS')
  doc.setCreator('PraticOS')
  const [font, bold] = await Promise.all([doc.embedFont(StandardFonts.Helvetica), doc.embedFont(StandardFonts.HelveticaBold)])
  const images = new Map<PdfImage, PDFImage | null>()
  const all = parts.flatMap((part) => [...part.photos, ...part.forms.flatMap((entry) => Object.values(entry.photos).flat())])
  for (const image of all) if (!images.has(image)) images.set(image, await embed(doc, image))
  const logo = company.logo ? await embed(doc, company.logo) : null
  const fallback = await fallbackFor(doc, parts, company, options)
  const ctx: Ctx = { doc, font, bold, texts, show: options.showValues, company, logo, images, fallback, watermark: options.watermark === true }
  for (const part of parts) drawOrder(ctx, part)
  // Plain objects (no object streams): simpler files that any reader opens.
  return doc.save({ useObjectStreams: false })
}

/** "OS-186.pdf" like the app; several orders: "OS-186-190.pdf". */
export function pdfFileName(serviceOrder: string, numbers: (number | undefined)[]): string {
  const clean = (serviceOrder || 'OS').replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, '') || 'OS'
  const known = numbers.filter((n): n is number => typeof n === 'number')
  if (numbers.length === 1) return `${clean}-${known[0] ?? 'NOVA'}.pdf`
  return known.length ? `${clean}-${Math.min(...known)}-${Math.max(...known)}.pdf` : `${clean}.pdf`
}
