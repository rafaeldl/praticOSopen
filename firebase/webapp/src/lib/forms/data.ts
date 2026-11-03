// Checklists in Firestore and Storage, in the app's shapes (lib/forms/model.ts).
// Templates: /companies/{cid}/forms (rules: owner, admin, supervisor write).
// Answers: /companies/{cid}/orders/{oid}/forms (any member, like the app).
// Photos: tenants/{cid}/orders/{oid}/forms/{fid}/{itemId}_{ms}.{ext}, the
// path the app uploads to and storage.rules allows (one level under the form).
import { firestoreClient, firestoreLite, storageClient } from '@/lib/firebase'
import { session } from '@/lib/session'
import {
  acceptsAnswer,
  applyChange,
  isAnswered,
  itemDoc,
  missingCount,
  normalizeOrderForm,
  normalizeResponses,
  normalizeTemplate,
  orderFormDoc,
  responseOf,
  statusAfter,
  type AnswerChange,
  type FormItem,
  type FormStatus,
  type OrderForm,
  type Template,
} from './model'

const companyId = () => session.companyId as string
const author = () => ({ id: session.uid, name: session.name ?? session.email ?? '' })
const companyAggr = () => ({ id: companyId(), name: session.company?.name ?? '' })
const nowIso = () => new Date().toISOString()

/** How long a write may wait for the server: offline, the answer is kept on screen and marked not saved. */
export const WRITE_TIMEOUT_MS = 10_000

function withTimeout<T>(work: Promise<T>): Promise<T> {
  return Promise.race([work, new Promise<T>((_, reject) => setTimeout(() => reject(Object.assign(new Error('timeout'), { code: 'deadline-exceeded' })), WRITE_TIMEOUT_MS))])
}

/**
 * Every write goes in a transaction that reads first: without connection it
 * fails and the screen says so. A plain write would wait in the browser's
 * queue, show as done, and land later or never (the web has no offline mode).
 */
async function online(run: (transaction: import('firebase/firestore').Transaction, firestore: typeof import('firebase/firestore'), db: import('firebase/firestore').Firestore) => Promise<void>): Promise<void> {
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  await withTimeout(firestore.runTransaction(db, (transaction) => run(transaction, firestore, db)))
}

/** The checklist was completed (here or in the app): no answer until it is reopened. */
export class FormCompleted extends Error {
  constructor() {
    super('FORM_COMPLETED')
  }
}

/** Someone saved the template since it was opened: nothing is written over it. */
export class TemplateChanged extends Error {
  constructor() {
    super('TEMPLATE_CHANGED')
  }
}

// ── Templates ──

/** The company's templates, live (the app saves elsewhere too). */
export async function watchTemplates(onList: (list: Template[]) => void, onError: (error: unknown) => void): Promise<() => void> {
  const [db, { collection, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return onSnapshot(
    collection(db, 'companies', companyId(), 'forms'),
    (snapshot) => {
      // A first answer from an empty cache is not "no checklists": wait for the server.
      if (snapshot.empty && snapshot.metadata.fromCache) return
      onList(snapshot.docs.map((doc) => normalizeTemplate(doc.id, doc.data())))
    },
    onError,
  )
}

/** The segment's ready-made checklists (`segments/{id}/forms`), read once. */
export async function loadReadyTemplates(): Promise<Template[]> {
  const segment = session.company?.segment
  if (!segment) return []
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDocs(collection(db, 'segments', segment, 'forms'))
  return snapshot.docs.map((doc) => normalizeTemplate(doc.id, doc.data() as Record<string, unknown>))
}

/** The company's plan (`subscription`), for the active checklists limit. */
export async function loadSubscription(): Promise<unknown> {
  const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDoc(doc(db, 'companies', companyId()))
  return (snapshot.data() as Record<string, unknown> | undefined)?.subscription ?? null
}

export interface TemplateInput {
  title: string
  description: string | null
  items: FormItem[]
  /** Kept when the title did not change (the app's translations). */
  titleI18n?: Record<string, string> | null
  descriptionI18n?: Record<string, string> | null
}

/**
 * New template: FormDefinition.toJson, with every key the app writes. `id` is
 * new unless given (a ready-made one copied keeps nothing of the segment's id).
 */
export async function createTemplate(input: TemplateInput & { isActive?: boolean }): Promise<string> {
  const [db, { collection, doc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const ref = doc(collection(db, 'companies', companyId(), 'forms'))
  const now = nowIso()
  await online(async (transaction) => {
    await transaction.get(ref)
    transaction.set(ref, {
      id: ref.id,
      createdAt: now,
      createdBy: author(),
      updatedAt: now,
      updatedBy: author(),
      company: companyAggr(),
      title: input.title,
      description: input.description,
      isActive: input.isActive ?? true,
      items: input.items.map(itemDoc),
      titleI18n: input.titleI18n ?? null,
      descriptionI18n: input.descriptionI18n ?? null,
    })
  })
  return ref.id
}

/**
 * Saves an edited template only if nobody saved it since `seen` (its updatedAt
 * when opened). The app overwrites; the web never does: it says so and reads again.
 */
export async function updateTemplate(id: string, seen: string | null, fields: Partial<TemplateInput> & { isActive?: boolean }): Promise<void> {
  const [db, { doc, runTransaction }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const ref = doc(db, 'companies', companyId(), 'forms', id)
  await withTimeout(
    runTransaction(db, async (transaction) => {
      const snapshot = await transaction.get(ref)
      if (!snapshot.exists()) throw new TemplateChanged()
      const current = normalizeTemplate(id, snapshot.data())
      if ((current.updatedAt ?? null) !== seen) throw new TemplateChanged()
      const data: Record<string, unknown> = { updatedAt: nowIso(), updatedBy: author() }
      if (fields.title !== undefined) data.title = fields.title
      if (fields.description !== undefined) data.description = fields.description
      if (fields.items !== undefined) data.items = fields.items.map(itemDoc)
      if (fields.titleI18n !== undefined) data.titleI18n = fields.titleI18n
      if (fields.descriptionI18n !== undefined) data.descriptionI18n = fields.descriptionI18n
      if (fields.isActive !== undefined) data.isActive = fields.isActive
      transaction.update(ref, data)
    }),
  )
}

/**
 * "Parar de usar" / "Voltar a usar": only `isActive`, right away (outside
 * "Salvar checklist"), and like it only over the version read: otherwise the
 * next save would take the web's own version and write over the app (M1 of #524).
 * Resolves with the new version.
 */
export async function setTemplateActive(id: string, seen: string | null, isActive: boolean): Promise<string> {
  const now = nowIso()
  await online(async (transaction, { doc }, db) => {
    const ref = doc(db, 'companies', companyId(), 'forms', id)
    const snapshot = await transaction.get(ref)
    if (!snapshot.exists() || (normalizeTemplate(id, snapshot.data()).updatedAt ?? null) !== seen) throw new TemplateChanged()
    transaction.update(ref, { isActive, updatedAt: now, updatedBy: author() })
  })
  return now
}

export async function deleteTemplate(id: string): Promise<void> {
  await online(async (transaction, { doc }, db) => {
    const ref = doc(db, 'companies', companyId(), 'forms', id)
    await transaction.get(ref)
    transaction.delete(ref)
  })
}

/** "Usar" a ready-made one: title, description, questions and its isActive, with a new id (like the app). */
export function importReady(ready: Template): Promise<string> {
  return createTemplate({ title: ready.title, description: ready.description, items: ready.items, isActive: ready.isActive })
}

// ── Checklists of an order ──

const formsOf = async (orderId: string) => {
  const [db, firestore] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  return { db, firestore, collection: firestore.collection(db, 'companies', companyId(), 'orders', orderId, 'forms') }
}

/** The order's checklists, live, newest first (FormsService.getOrderForms). */
export async function watchOrderForms(orderId: string, onList: (list: OrderForm[]) => void, onError: (error: unknown) => void): Promise<() => void> {
  const { firestore, collection } = await formsOf(orderId)
  return firestore.onSnapshot(
    firestore.query(collection, firestore.orderBy('startedAt', 'desc')),
    (snapshot) => onList(snapshot.docs.map((doc) => normalizeOrderForm(doc.id, doc.data()))),
    onError,
  )
}

/** Puts a copy of the template in the order (FormsService.addFormToOrder). */
export async function addOrderForm(orderId: string, template: Template, deviceId: string | null): Promise<OrderForm> {
  const { firestore, collection } = await formsOf(orderId)
  const data = orderFormDoc(template, deviceId, nowIso())
  const ref = firestore.doc(collection)
  await online(async (transaction) => {
    await transaction.get(ref)
    transaction.set(ref, data)
  })
  return normalizeOrderForm(ref.id, data as unknown as Record<string, unknown>)
}

export async function deleteOrderForm(orderId: string, formId: string): Promise<void> {
  const { firestore, collection } = await formsOf(orderId)
  const ref = firestore.doc(collection, formId)
  await online(async (transaction) => {
    await transaction.get(ref)
    transaction.delete(ref)
  })
}

/**
 * Saves one answer. A transaction reads the checklist again and changes only
 * that question (lib/forms/model.ts applyChange), so what the app or another
 * tab saved meanwhile stays. With `complete`, the checklist is completed in the
 * same write when nothing is left (the app does it after the last question).
 * Resolves with the checklist as saved.
 */
export async function saveAnswer(orderId: string, formId: string, change: AnswerChange, complete = false): Promise<OrderForm> {
  const { db, firestore, collection } = await formsOf(orderId)
  const ref = firestore.doc(collection, formId)
  return withTimeout(
    firestore.runTransaction(db, async (transaction) => {
      const snapshot = await transaction.get(ref)
      if (!snapshot.exists()) throw Object.assign(new Error('form removed'), { code: 'not-found' })
      const form = normalizeOrderForm(formId, snapshot.data())
      if (!acceptsAnswer(form.status)) throw new FormCompleted()
      const responses = applyChange(normalizeResponses(snapshot.data().responses), change)
      let status: FormStatus = statusAfter(form.status, responses)
      const next: OrderForm = { ...form, responses, status }
      const now = nowIso()
      const data: Record<string, unknown> = { responses: responses.map((r) => ({ itemId: r.itemId, value: r.value ?? null, photoUrls: r.photoUrls })), updatedAt: now }
      if (complete && status !== 'completed' && missingCount(next) === 0) {
        status = 'completed'
        data.completedAt = now
      }
      data.status = status
      transaction.update(ref, data)
      return { ...next, status }
    }),
  )
}

/** Concluir / Reabrir (FormsService.updateStatus). */
export async function setFormStatus(orderId: string, formId: string, status: FormStatus): Promise<void> {
  const { firestore, collection } = await formsOf(orderId)
  const ref = firestore.doc(collection, formId)
  const now = nowIso()
  await online(async (transaction) => {
    if (!(await transaction.get(ref)).exists()) throw Object.assign(new Error('form removed'), { code: 'not-found' })
    transaction.update(ref, { status, updatedAt: now, ...(status === 'completed' ? { completedAt: now } : {}) })
  })
}


/**
 * Sends photos of a question, then adds them in one transaction. Returns how
 * many failed (each one is told; the app swallows partial failures).
 */
export async function addPhotos(orderId: string, formId: string, itemId: string, files: File[]): Promise<{ failed: number }> {
  const [storage, { ref, uploadBytes, getDownloadURL }] = await Promise.all([storageClient(), import('firebase/storage')])
  const urls: string[] = []
  let failed = 0
  for (const [index, file] of files.entries()) {
    try {
      const extension = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '') || 'jpg'
      const target = ref(storage, `tenants/${companyId()}/orders/${orderId}/forms/${formId}/${itemId}_${Date.now()}_${index}.${extension}`)
      await uploadBytes(target, file, { contentType: file.type })
      urls.push(await getDownloadURL(target))
    } catch (error) {
      console.warn('forms: photo not sent', error)
      failed++
    }
  }
  if (urls.length) await saveAnswer(orderId, formId, { kind: 'addPhotos', itemId, urls })
  return { failed }
}

/** Takes the photo out of the answer, then erases the file (the app leaves it in Storage). */
export async function removePhoto(orderId: string, formId: string, itemId: string, url: string): Promise<void> {
  await saveAnswer(orderId, formId, { kind: 'removePhoto', itemId, url })
  try {
    const [storage, { ref, deleteObject }] = await Promise.all([storageClient(), import('firebase/storage')])
    await deleteObject(ref(storage, url))
  } catch (error) {
    // The answer no longer shows it; a file left behind is not worth an error.
    console.warn('forms: photo file not erased', error)
  }
}

export { isAnswered, responseOf }
