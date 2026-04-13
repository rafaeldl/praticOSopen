import { getAdminDb } from '~/server/utils/firebase'
import { verifyAdminToken } from '~/server/utils/admin-auth'
import { getCached, setCache } from '~/server/utils/admin-cache'
import { parseFirestoreDate } from '~/server/utils/parse-date'

const CACHE_KEY = 'admin:companies'

export default defineEventHandler(async (event) => {
  await verifyAdminToken(event)

  const query = getQuery(event)
  const search = ((query.search as string) || '').toLowerCase()
  const segmentFilter = (query.segment as string) || ''
  const countryFilter = (query.country as string) || ''
  const statusFilter = (query.status as string) || '' // 'active' | 'inactive' | ''

  let allData = getCached<any[]>(CACHE_KEY)

  if (!allData) {
    const db = getAdminDb()
    const now = new Date()
    const monthAgo = new Date(now.getTime() - 30 * 86400000)

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
      const lastOrderDate = stats?.lastOrderDate || null
      const isActive = lastOrderDate ? new Date(lastOrderDate) >= monthAgo : false

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

    setCache(CACHE_KEY, allData)
  }

  // Apply filters
  let result = allData
  if (search) {
    result = result.filter((c: any) => c.name.toLowerCase().includes(search))
  }
  if (segmentFilter) {
    result = result.filter((c: any) => c.segment === segmentFilter)
  }
  if (countryFilter) {
    result = result.filter((c: any) => c.country === countryFilter)
  }
  if (statusFilter === 'active') {
    result = result.filter((c: any) => c.active)
  } else if (statusFilter === 'inactive') {
    result = result.filter((c: any) => !c.active)
  }

  // Sort by totalOrders desc
  result.sort((a: any, b: any) => b.totalOrders - a.totalOrders)

  // Extract unique segments and countries for filter options
  const segments = [...new Set(allData.map((c: any) => c.segment).filter(Boolean))].sort()
  const countries = [...new Set(allData.map((c: any) => c.country).filter(Boolean))].sort()

  return { data: result, filters: { segments, countries } }
})
