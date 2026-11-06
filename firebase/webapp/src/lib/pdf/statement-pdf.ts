// PDF of "Mandar extrato" (pay.customer.statement), drawn like the app's
// (lib/services/pdf/customer_statement_pdf.dart): teal band with the company,
// "OS em aberto de João em 06/11/2026.", one block per order (title, device,
// services and parts with quantity and value, discount, total · pago · falta)
// and the total owed. Pure: texts come resolved, so vitest covers it.
import { PDFDocument, StandardFonts, rgb, type PDFFont, type PDFImage, type PDFPage, type RGB } from 'pdf-lib'
import { pdfSafe, wrap, type PdfCompany } from './order-pdf'
import { statementTotal, type StatementOrder } from '@/lib/receive/statement'

export interface StatementPdfTexts {
  title: string
  /** Today, under the title. */
  date: string
  /** "OS em aberto de João em 06/11/2026." */
  sentence: string
  itemColumn: string
  quantityColumn: string
  valueColumn: string
  orderNumber: (number: string) => string
  completed: string
  inProgress: string
  discount: string
  totals: (total: string, paid: string, open: string) => string
  totalOpen: string
  money: (value: number) => string
  day: (iso: string) => string
}

const W = 595.28
const H = 841.89
const PAD = 32
const BODY_W = W - PAD * 2
const BOTTOM = 40
const HEAD = 72

function hex(value: number): RGB {
  return rgb(((value >> 16) & 255) / 255, ((value >> 8) & 255) / 255, (value & 255) / 255)
}
const C = {
  header: hex(0x0d3b4f),
  text: hex(0x1a2b3c),
  secondary: hex(0x5a7184),
  bgLighter: hex(0xf0f7fa),
  border: hex(0xe2e8f0),
  white: rgb(1, 1, 1),
  soft: rgb(0.87, 0.92, 0.94),
}

/** Header, block titles and rows of the extrato, built for `orders` (checked, oldest first). */
export async function buildStatementPdf(orders: readonly StatementOrder[], company: PdfCompany, texts: StatementPdfTexts): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const font = await doc.embedFont(StandardFonts.Helvetica)
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const logo: PDFImage | null = company.logo
    ? await (company.logo.kind === 'png' ? doc.embedPng(company.logo.bytes) : doc.embedJpg(company.logo.bytes)).catch(() => null)
    : null

  let page!: PDFPage
  let y = 0
  const text = (value: string, x: number, size: number, options: { bold?: boolean; color?: RGB; right?: number } = {}) => {
    const face: PDFFont = options.bold ? bold : font
    const safe = pdfSafe(value)
    const width = face.widthOfTextAtSize(safe, size)
    page.drawText(safe, { x: options.right !== undefined ? options.right - width : x, y: H - y - size * 0.8, size, font: face, color: options.color ?? C.text })
  }
  const header = () => {
    page.drawRectangle({ x: 0, y: H - HEAD, width: W, height: HEAD, color: C.header })
    let left = PAD
    if (logo) {
      page.drawRectangle({ x: PAD, y: H - 56, width: 40, height: 40, color: C.white })
      const scale = Math.min(32 / logo.width, 32 / logo.height)
      page.drawImage(logo, { x: PAD + 4 + (32 - logo.width * scale) / 2, y: H - 52 + (32 - logo.height * scale) / 2, width: logo.width * scale, height: logo.height * scale })
      left += 52
    }
    y = 16
    text(company.name, left, 10, { bold: true, color: C.white })
    y += 14
    for (const info of [company.address, company.phone, company.email]) {
      if (!info) continue
      text(info, left, 8, { color: C.soft })
      y += 10
    }
    y = 16
    text(texts.title.toUpperCase(), 0, 22, { bold: true, color: C.white, right: W - PAD })
    y = 42
    text(texts.date, 0, 9, { color: C.soft, right: W - PAD })
    y = HEAD + 20
  }
  const newPage = () => {
    page = doc.addPage([W, H])
    header()
  }
  const need = (height: number) => {
    if (y + height > H - BOTTOM) newPage()
  }

  newPage()
  for (const line of wrap(texts.sentence, font, 13, BODY_W)) {
    text(line, PAD, 13)
    y += 18
  }
  y += 8

  const colQty = PAD + BODY_W * 0.72
  const colValue = W - PAD - 6
  const row = (cells: [string, string, string], strong = false, fill?: RGB) => {
    const lines = wrap(cells[0], strong ? bold : font, 9, BODY_W * 0.62)
    const height = lines.length * 11 + 8
    need(height)
    if (fill) page.drawRectangle({ x: PAD, y: H - y - height, width: BODY_W, height, color: fill })
    const top = y
    y += 4
    for (const part of lines) {
      text(part, PAD + 6, 9, { bold: strong })
      y += 11
    }
    y = top + 4
    text(cells[1], 0, 9, { bold: strong, right: colQty + 30 })
    text(cells[2], 0, 9, { bold: strong, right: colValue })
    y = top + height
    page.drawLine({ start: { x: PAD, y: H - y }, end: { x: W - PAD, y: H - y }, thickness: 0.5, color: C.border })
  }

  for (const order of orders) {
    need(60)
    const title = [
      texts.orderNumber(order.number === null ? '-' : String(order.number)),
      order.date ? texts.day(order.date) : '',
      order.completed === null ? '' : order.completed ? texts.completed : texts.inProgress,
    ].filter(Boolean)
    text(title.join(' · '), PAD, 11, { bold: true })
    y += 15
    // Without a device, `device` is the first service, already in the table.
    if (order.device && order.device !== order.items[0]?.name) {
      for (const line of wrap(order.device, font, 9, BODY_W)) {
        text(line, PAD, 9, { color: C.secondary })
        y += 12
      }
    }
    y += 4
    if (order.items.length) {
      row([texts.itemColumn, texts.quantityColumn, texts.valueColumn], true, C.bgLighter)
      for (const item of order.items) row([item.name, String(item.quantity), texts.money(item.value)])
    }
    y += 4
    if (order.discount > 0) {
      need(14)
      text(`${texts.discount}  - ${texts.money(order.discount)}`, 0, 9, { right: W - PAD })
      y += 14
    }
    need(14)
    text(texts.totals(texts.money(order.total), texts.money(order.paid), texts.money(order.open)), 0, 9, { bold: true, right: W - PAD })
    y += 30
  }

  need(20)
  const total = texts.money(statementTotal(orders))
  const totalWidth = bold.widthOfTextAtSize(pdfSafe(total), 13)
  text(total, 0, 13, { bold: true, right: W - PAD })
  y += 2
  text(`${texts.totalOpen}  `, 0, 11, { right: W - PAD - totalWidth })
  return doc.save({ useObjectStreams: false })
}
