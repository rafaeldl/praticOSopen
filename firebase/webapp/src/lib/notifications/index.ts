// Avisos (the bell on Início): companies/{cid}/notifications written by the
// server (notification.service.ts) for each recipient. Same reads and texts as
// lib/repositories/tenant/notification_repository.dart and
// lib/screens/notifications/notification_list_tile.dart. The rules let each
// person read and mark as read only their own.
import { t } from '@/i18n'
import { firestoreLite } from '../firebase'
import { formatDate } from '../format'
import { session } from '../session'

export interface Notice {
  id: string
  type: string | null
  title: string
  body: string
  orderId: string | null
  orderNumber: string | number | null
  read: boolean
  createdAt: Date | null
}

/** Shown as a number up to this; above it, "99+". */
export const BADGE_MAX = 99

const EMOJI = '[\\p{Extended_Pictographic}\\p{Emoji_Presentation}\\u200d\\ufe0f\\u20e3]'

/** The app shows status with words, not pictograms: emoji off both ends of a title. */
export function stripEmoji(text: string): string {
  return text.replace(new RegExp(`^(?:${EMOJI}|\\s)+`, 'u'), '').replace(new RegExp(`(?:${EMOJI}|\\s)+$`, 'u'), '')
}

/** The sentence of a row, in everyday words (noticeText). */
export function noticeText(notice: Pick<Notice, 'type' | 'title' | 'body'>): string {
  const title = stripEmoji(notice.title.trim())
  const body = notice.body.trim()
  if (!body) return title
  switch (notice.type) {
    case 'new_comment': {
      const split = body.indexOf(': ')
      return split > 0 ? t('noticeCommented', { name: body.slice(0, split), text: body.slice(split + 2) }) : body
    }
    case 'payment_received': {
      const amount = /[–-]\s*(.+)$/.exec(body)?.[1]
      return amount ? t('noticePaymentReceived', { amount: amount.trim() }) : title
    }
    case 'maintenance_due':
      return `${title}: ${body}`
  }
  const withoutOrder = body
    .replace(/\s+(?:da|na|a|de)\s+OS\s*#\d+/g, '')
    .replace(/\s*OS\s*#\d+/g, '')
    .trim()
  return withoutOrder || title
}

/** "há 5 minutos", "há 2 dias"; older than a month, the date (relativeTime). */
export function relativeTime(time: Date | null, now: Date, country?: string | null): string {
  if (!time) return ''
  const minutes = Math.floor((now.getTime() - time.getTime()) / 60000)
  if (minutes < 1) return t('timeAgoNow')
  if (minutes < 60) return t('timeAgoMinutes', { count: minutes })
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return t('timeAgoHours', { count: hours })
  const days = Math.floor(hours / 24)
  if (days < 30) return t('timeAgoDays', { count: days })
  return formatDate(time, country)
}

function toDate(value: unknown): Date | null {
  if (!value) return null
  if (typeof value === 'string') {
    const date = new Date(value)
    return Number.isNaN(date.getTime()) ? null : date
  }
  const timestamp = value as { toDate?: () => Date }
  return typeof timestamp.toDate === 'function' ? timestamp.toDate() : null
}

export function toNotice(id: string, data: Record<string, unknown>): Notice {
  const text = (value: unknown) => (typeof value === 'string' ? value : '')
  return {
    id,
    type: typeof data.type === 'string' ? data.type : null,
    title: text(data.title),
    body: text(data.body),
    orderId: typeof data.orderId === 'string' && data.orderId ? data.orderId : null,
    orderNumber: typeof data.orderNumber === 'string' || typeof data.orderNumber === 'number' ? data.orderNumber : null,
    read: data.read === true,
    createdAt: toDate(data.createdAt),
  }
}

const lite = () => Promise.all([firestoreLite(), import('firebase/firestore/lite')])

/** This person's notifications in the current company; the rules allow no other query. */
async function mine() {
  const uid = session.uid
  const companyId = session.companyId
  if (!uid || !companyId) return null
  const [db, fs] = await lite()
  return { db, fs, uid, companyId, ref: fs.collection(db, 'companies', companyId, 'notifications') }
}

/**
 * New ones, counted on the server. The app counts at most 50 (its stream's
 * limit), so its "99+" never shows; here the count goes up to 500.
 */
export async function unreadCount(): Promise<number> {
  const at = await mine()
  if (!at) return 0
  const { fs, ref, uid } = at
  const snapshot = await fs.getCount(fs.query(ref, fs.where('recipientId', '==', uid), fs.where('read', '==', false), fs.orderBy('createdAt', 'desc'), fs.limit(500)))
  return snapshot.data().count
}

/** The 50 most recent, new and read (streamNotifications). */
export async function listNotices(): Promise<Notice[]> {
  const at = await mine()
  if (!at) return []
  const { fs, ref, uid } = at
  const snapshot = await fs.getDocs(fs.query(ref, fs.where('recipientId', '==', uid), fs.orderBy('createdAt', 'desc'), fs.limit(50)))
  return snapshot.docs.map((doc) => toNotice(doc.id, doc.data()))
}

export async function markRead(id: string): Promise<void> {
  const at = await mine()
  if (!at) return
  const { db, fs, companyId } = at
  await fs.updateDoc(fs.doc(db, 'companies', companyId, 'notifications', id), { read: true, readAt: fs.serverTimestamp() })
}

/** Every new one of this person, also the ones beyond the 50 shown (markAllAsRead). */
export async function markAllRead(): Promise<void> {
  const at = await mine()
  if (!at) return
  const { db, fs, ref, uid } = at
  const unread = await fs.getDocs(fs.query(ref, fs.where('recipientId', '==', uid), fs.where('read', '==', false), fs.limit(500)))
  if (unread.empty) return
  const batch = fs.writeBatch(db)
  for (const doc of unread.docs) batch.update(doc.ref, { read: true, readAt: fs.serverTimestamp() })
  await batch.commit()
}
