// Everything the order PDF needs, read when someone asks for it: the orders
// (Firestore for who sees values, the API projection otherwise), the company,
// the customers' records, the checklists and the photos. Then order-pdf.ts
// draws it. Values only with viewPrices ("Valores e cobrança" on): who does not
// see them never receives them (the API drops them) and the PDF has none.
import { locale, t } from '@/i18n'
import { firestoreLite } from '@/lib/firebase'
import { formatDate, formatMoney } from '@/lib/format'
import { normalizeOrderForm, optionText, labelOf, titleOf, type OrderForm } from '@/lib/forms/model'
import { loadCustomer } from '@/lib/customers/data'
import { normalizeOrder, type OrderStatus } from '@/lib/orders/model'
import { formatPhone } from '@/lib/phone'
import { country, orderName, statusText } from '@/lib/orders/text'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { api, can, effectiveUseFinancial, session } from '@/lib/session'
import { buildOrdersPdf, pdfFileName, type PdfCompany, type PdfImage, type PdfOrderPart, type PdfTexts } from './order-pdf'

/** The app's limits (OsPdfOptions): 30 photos of the order, 8 per checklist question. */
const MAX_ORDER_PHOTOS = 30
const MAX_ITEM_PHOTOS = 8
/** Photos bigger than this are scaled down, so a batch stays a file people can send. */
const MAX_SIDE = 1600
const CONCURRENCY = 5

/** Who gets the PDF at all (canShareOrderPdf): who sees prices, or everyone when values are off. */
export const canOrderPdf = (): boolean => can('viewPrices') || !effectiveUseFinancial()
/** Who gets prices in it (orderPdfShowsValues with viewPrices). */
export const pdfShowsValues = (): boolean => can('viewPrices') && effectiveUseFinancial()

/** The app's fallback font (assets/fonts/Roboto-Regular.ttf, Apache 2.0) and fontkit, downloaded only for a PDF that needs them. */
async function robotoFallback() {
  const [fontkit, font] = await Promise.all([import('@pdf-lib/fontkit'), import('../../../../../assets/fonts/Roboto-Regular.ttf?url')])
  const response = await fetch(font.default)
  if (!response.ok) throw new Error(`pdf: font ${response.status}`)
  return { fontkit: fontkit.default, bytes: new Uint8Array(await response.arrayBuffer()) }
}

const tr = (key: Parameters<typeof t>[0]) => t(key)

export function pdfTexts(): PdfTexts {
  const where = country()
  return {
    serviceOrder: orderName(),
    customer: resolveLabel('customer._entity', segmentLabels(), tr),
    newOrder: t('newOrder'),
    notInformed: t('notInformed'),
    generatedBy: t('generatedByPraticos'),
    site: 'praticos.app',
    description: t('descriptionColumn'),
    quantity: t('quantityShort'),
    unitValue: t('pdfUnitValue'),
    total: t('total'),
    services: t('services'),
    products: t('products'),
    discount: t('discount'),
    paid: t('pdfPaid'),
    summary: t('pdfSummary'),
    general: t('pdfGeneral'),
    equipment: t('pdfEquipment'),
    serviceType: t('pdfServiceType'),
    productType: t('pdfProductType'),
    itemType: t('pdfItemType'),
    technician: t('pdfTechnician'),
    created: t('pdfCreatedDate'),
    completed: t('pdfCompletedDate'),
    serviceLocation: t('serviceLocation'),
    trackOnline: t('pdfTrackOnline'),
    trackOnlineDescription: t('pdfTrackOnlineDescription'),
    terms: t('pdfTermsAndConditions'),
    clientSignature: t('pdfClientSignature'),
    companySignature: t('pdfCompanySignature'),
    photosDigital: t('photosAvailableDigitally'),
    yes: t('yes'),
    no: t('no'),
    formCompleted: t('statusCompleted'),
    formInProgress: t('statusInProgress'),
    formPending: t('statusPending'),
    notAnswered: t('notAnswered'),
    notSelected: t('notSelected'),
    status: (status: OrderStatus) => statusText(status),
    money: (value: number) => formatMoney(value, where),
    date: (iso: string) => formatDate(iso, where),
    pageOf: (current: number, total: number) => t('pageOf', { current, total }),
    attachedPhotos: (count: number) => t('attachedPhotosCount', { count }),
    formLabel: (title: string) => t('formLabelWithTitle', { title }),
    formTitle: (form: OrderForm) => titleOf(form, locale.value),
    itemLabel: (item) => labelOf(item, locale.value),
    optionText: (item, value) => optionText(item, value, locale.value),
  }
}

type Raw = Record<string, unknown>

async function readDoc(path: string[]): Promise<Raw | null> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDoc(doc(db, path[0] as string, ...path.slice(1)))
  return snap.exists() ? (snap.data() as Raw) : null
}

async function readForms(orderId: string): Promise<OrderForm[]> {
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', orderId, 'forms'))
  // Oldest first, the order they were added in (startedAt).
  return snap.docs.map((d) => normalizeOrderForm(d.id, d.data())).sort((a, b) => String(a.startedAt ?? '').localeCompare(String(b.startedAt ?? '')))
}

/** An image the PDF can embed: JPEG or PNG as is when small, anything else redrawn as JPEG. */
async function imageOf(url: string): Promise<PdfImage | null> {
  try {
    const response = await fetch(url)
    if (!response.ok) return null
    const blob = await response.blob()
    const type = blob.type || ''
    const head = new Uint8Array(await blob.slice(0, 4).arrayBuffer())
    const jpg = head[0] === 0xff && head[1] === 0xd8
    const png = head[0] === 0x89 && head[1] === 0x50
    if ((jpg || png) && blob.size < 1_500_000) return { bytes: new Uint8Array(await blob.arrayBuffer()), kind: jpg ? 'jpg' : 'png' }
    if (!type.startsWith('image/') && !jpg && !png) return null
    const bitmap = await createImageBitmap(blob)
    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(bitmap.width * scale))
    canvas.height = Math.max(1, Math.round(bitmap.height * scale))
    const context = canvas.getContext('2d')
    if (!context) return null
    context.fillStyle = '#fff'
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    bitmap.close()
    const out = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.82))
    return out ? { bytes: new Uint8Array(await out.arrayBuffer()), kind: 'jpg' } : null
  } catch (error) {
    // Optional: a photo that does not download never stops the PDF (the app's rule).
    console.warn('pdf: image not loaded', error)
    return null
  }
}

/** Downloads in parallel, a few at a time, once per URL, keeping the order. */
function imageLoader() {
  const cache = new Map<string, Promise<PdfImage | null>>()
  let running = 0
  const queue: (() => void)[] = []
  const slot = () =>
    new Promise<void>((resolve) => {
      if (running < CONCURRENCY) {
        running++
        resolve()
      } else queue.push(() => (running++, resolve()))
    })
  const release = () => {
    running--
    queue.shift()?.()
  }
  return (url: string) => {
    let found = cache.get(url)
    if (!found) {
      found = slot().then(() => imageOf(url).finally(release))
      cache.set(url, found)
    }
    return found
  }
}

const present = <T>(list: (T | null)[]): T[] => list.filter((item): item is T => item !== null)

async function partOf(id: string, show: boolean, load: (url: string) => Promise<PdfImage | null>): Promise<PdfOrderPart | null> {
  // Who sees values reads the document; the others the API's projection, without any value.
  const raw = show ? await readDoc(['companies', session.companyId as string, 'orders', id]) : await api<Raw>(`/v1/app/orders/${encodeURIComponent(id)}`)
  if (!raw) return null
  const order = normalizeOrder(id, raw, show)
  const aggr = (raw.customer ?? null) as { id?: string; name?: string; phone?: string; email?: string } | null
  const [record, forms] = await Promise.all([
    aggr?.id ? loadCustomer(aggr.id).then((d) => d.customer).catch(() => null) : Promise.resolve(null),
    readForms(id).catch((error) => (console.warn('pdf: checklists not read', error), [] as OrderForm[])),
  ])
  const photoUrls = order.photos.map((photo) => photo.url).filter(Boolean).slice(0, MAX_ORDER_PHOTOS)
  const photos = present(await Promise.all(photoUrls.map(load)))
  const formParts = await Promise.all(
    forms.map(async (form) => {
      const entries = await Promise.all(
        form.responses.map(async (response) => [response.itemId, present(await Promise.all(response.photoUrls.slice(0, MAX_ITEM_PHOTOS).map(load)))] as const),
      )
      return { form, photos: Object.fromEntries(entries.filter(([, list]) => list.length)) }
    }),
  )
  const token = (raw.shareLink as { token?: string } | undefined)?.token
  return {
    order,
    customer: record ?? aggr ? { name: (record ?? aggr)?.name, phone: formatPhone((record ?? aggr)?.phone, country()) || null, email: (record ?? aggr)?.email ?? null } : null,
    paid: show && raw.payment === 'paid',
    shareUrl: typeof token === 'string' && token ? `https://praticos.app/q/${encodeURIComponent(token)}` : null,
    photos,
    missingPhotos: order.photos.length - photos.length,
    forms: formParts,
  }
}

export interface OrdersPdf {
  blob: Blob
  fileName: string
  /** Orders that could not be read (deleted, no access): left out and said. */
  missing: number
}

/** The PDF of these orders, in this order. */
export async function ordersPdf(ids: readonly string[]): Promise<OrdersPdf> {
  const show = pdfShowsValues()
  const load = imageLoader()
  const companyRaw = (await readDoc(['companies', session.companyId as string]).catch(() => null)) ?? {}
  const text = (value: unknown) => (typeof value === 'string' ? value : null)
  const logoUrl = text(companyRaw.logo)
  const [logo, ...parts] = await Promise.all([
    logoUrl ? load(logoUrl) : Promise.resolve(null),
    ...ids.map((id) => partOf(id, show, load).catch((error) => (console.warn('pdf: order not read', id, error), null))),
  ])
  const found = present(parts as (PdfOrderPart | null)[])
  if (!found.length) throw new Error('pdf: no order')
  const company: PdfCompany = {
    name: text(companyRaw.name) ?? session.company?.name ?? '',
    address: text(companyRaw.address),
    phone: text(companyRaw.phone),
    email: text(companyRaw.email),
    terms: text(companyRaw.termsOfService),
    logo: logo as PdfImage | null,
  }
  const texts = pdfTexts()
  const bytes = await buildOrdersPdf(found, company, texts, { showValues: show, fallbackFont: robotoFallback })
  return {
    blob: new Blob([bytes as BlobPart], { type: 'application/pdf' }),
    fileName: pdfFileName(texts.serviceOrder, found.map((part) => part.order.number)),
    missing: ids.length - found.length,
  }
}
