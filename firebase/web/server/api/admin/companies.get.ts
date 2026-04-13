import { getAdminDb } from '~/server/utils/firebase'
import { verifyAdminToken } from '~/server/utils/admin-auth'
import { getCached, setCache, getTtlForPeriod } from '~/server/utils/admin-cache'
import { parseFirestoreDate } from '~/server/utils/parse-date'

const CACHE_KEY = 'admin:companies'

export default defineEventHandler(async (event) => {
  await verifyAdminToken(event)

  const CACHE_TTL = 5 * 60_000 // 5 min cache
  let allData = getCached<any>(CACHE_KEY, CACHE_TTL)

  if (!allData) {
    const db = getAdminDb()
    const now = new Date()
    const activeWindowStart = new Date(now.getTime() - 7 * 86400000) // active = OS in last 7 days

    const [ordersSnap, companiesSnap] = await Promise.all([
      db.collectionGroup('orders').orderBy('createdAt', 'desc').limit(10000).get(),
      db.collection('companies').get(),
    ])

    // Build per-company order stats
    const companyOrderStats = new Map<string, { totalOrders: number; lastOrderDate: string | null; revenue: number }>()
    for (const doc of ordersSnap.docs) {
      const d = doc.data()
      const companyId = d.company?.id as string
      if (!companyId) continue

      const createdAt = parseFirestoreDate(d.createdAt) || parseFirestoreDate(d.updatedAt)
      const existing = companyOrderStats.get(companyId)
      if (existing) {
        existing.totalOrders++
        existing.revenue += d.status !== 'canceled' ? ((d.total as number) || 0) : 0
        if (createdAt && (!existing.lastOrderDate || createdAt.toISOString() > existing.lastOrderDate)) {
          existing.lastOrderDate = createdAt.toISOString()
        }
      } else {
        companyOrderStats.set(companyId, {
          totalOrders: 1,
          revenue: d.status !== 'canceled' ? ((d.total as number) || 0) : 0,
          lastOrderDate: createdAt?.toISOString() || null,
        })
      }
    }

    allData = companiesSnap.docs.map((doc) => {
      const d = doc.data()
      const stats = companyOrderStats.get(doc.id)
      // Prefer lastOrderDate from company doc (set by trigger), fallback to orders scan
      const lastOrderDate = parseFirestoreDate(d.lastOrderDate)?.toISOString() || stats?.lastOrderDate || null
      const isActive = lastOrderDate ? new Date(lastOrderDate) >= activeWindowStart : false

      return {
        id: doc.id,
        name: (d.name as string) || '',
        segment: (d.segment as string) || '',
        country: (d.country as string) || '',
        membersCount: Array.isArray(d.users) ? d.users.length : 0,
        totalOrders: (d.nextOrderNumber ? d.nextOrderNumber - 1 : 0) || stats?.totalOrders || 0,
        revenue: Math.round((stats?.revenue || 0) * 100) / 100,
        lastOrderDate,
        active: isActive,
        createdAt: parseFirestoreDate(d.createdAt)?.toISOString() || null,
        subscription: d.subscription?.plan || null,
        ownerName: d.owner?.name || null,
        ownerEmail: d.owner?.email || null,
      }
    })

    // Extract unique segments and countries for filter options
    const segments = [...new Set(allData.map((c: any) => c.segment).filter(Boolean))].sort()
    const countries = [...new Set(allData.map((c: any) => c.country).filter(Boolean))].sort()

    allData = { companies: allData, filters: { segments, countries } }
    setCache(CACHE_KEY, allData)
  }

  return { data: allData.companies, filters: allData.filters }
})
