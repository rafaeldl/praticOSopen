// Avaliações (ratings.*): the orders a customer rated through the order link,
// newest rating first, and their average. Same rules as the app's
// RatingsScreen and OrderRating.hasRating (score from 1 to 5).
import { firestoreLite } from '@/lib/firebase'
import { session } from '@/lib/session'

export interface RatedOrder {
  id: string
  number: number | null
  score: number
  comment: string
  /** The name the customer typed, then the order's customer. */
  customerName: string | null
  ratedAt: number
}

interface OrderDoc {
  number?: number
  customer?: { name?: string }
  rating?: { score?: unknown; comment?: unknown; customerName?: unknown; createdAt?: unknown }
}

function millis(value: unknown): number {
  if (!value) return 0
  if (typeof value === 'string') return Date.parse(value) || 0
  const stamp = value as { toMillis?: () => number; seconds?: number }
  if (typeof stamp.toMillis === 'function') return stamp.toMillis()
  return typeof stamp.seconds === 'number' ? stamp.seconds * 1000 : 0
}

/** Only real ratings (1 to 5), newest first. */
export function ratedOrders(docs: { id: string; data: OrderDoc }[]): RatedOrder[] {
  return docs
    .flatMap(({ id, data }) => {
      const score = data.rating?.score
      if (typeof score !== 'number' || !Number.isInteger(score) || score < 1 || score > 5) return []
      const typed = typeof data.rating?.customerName === 'string' ? data.rating.customerName.trim() : ''
      return [
        {
          id,
          number: typeof data.number === 'number' ? data.number : null,
          score,
          comment: typeof data.rating?.comment === 'string' ? data.rating.comment.trim() : '',
          customerName: typed || data.customer?.name?.trim() || null,
          ratedAt: millis(data.rating?.createdAt),
        },
      ]
    })
    .sort((a, b) => b.ratedAt - a.ratedAt)
}

/** "4,5 de 5": one decimal, as the app rounds. */
export function averageScore(orders: RatedOrder[]): number {
  if (!orders.length) return 0
  const total = orders.reduce((sum, order) => sum + order.score, 0)
  return Math.round((total / orders.length) * 10) / 10
}

/**
 * The company's rated orders. Owner and admin only (manageCompany), who read
 * every order; the filter on rating.score keeps the rest of the orders out of
 * the browser (the app reads every done order and filters on the phone).
 */
export async function loadRatings(): Promise<RatedOrder[]> {
  const companyId = session.companyId
  if (!companyId) throw new Error('ratings: no company')
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const snapshot = await getDocs(query(collection(db, 'companies', companyId, 'orders'), where('rating.score', '>=', 1)))
  return ratedOrders(snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() as OrderDoc })))
}
