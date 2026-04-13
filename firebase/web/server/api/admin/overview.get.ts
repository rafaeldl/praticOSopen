import { getAdminDb } from '~/server/utils/firebase'
import { verifyAdminToken } from '~/server/utils/admin-auth'
import { getCached, setCache, getTtlForPeriod } from '~/server/utils/admin-cache'
import { parseFirestoreDate } from '~/server/utils/parse-date'

export default defineEventHandler(async (event) => {
  await verifyAdminToken(event)

  const query = getQuery(event)
  const period = (query.period as string) || '30d'

  const cacheKey = `admin:overview:${period}`
  const ttl = getTtlForPeriod(period)
  const cached = getCached(cacheKey, ttl)
  if (cached) return { data: cached }

  const db = getAdminDb()

  const now = new Date()
  const periodDays = parsePeriodDays(period)
  const periodStart = new Date(now.getTime() - periodDays * 86400000)

  const [ordersSnap, companiesSnap] = await Promise.all([
    db.collectionGroup('orders').orderBy('createdAt', 'desc').limit(10000).get(),
    db.collection('companies').get(),
  ])

  // Parse all orders
  const allOrders = ordersSnap.docs.map((doc) => {
    const d = doc.data()
    const createdAt = parseFirestoreDate(d.createdAt)
    const updatedAt = parseFirestoreDate(d.updatedAt)
    return {
      id: doc.id,
      status: d.status as string | undefined,
      total: (d.total as number) || 0,
      companyId: d.company?.id as string | undefined,
      companyName: d.company?.name as string | undefined,
      companyCountry: d.company?.country as string | undefined,
      effectiveDate: createdAt || updatedAt,
      hasPhotos: Array.isArray(d.photos) && d.photos.length > 0,
      hasShareLink: !!d.shareLink?.token,
      hasDocuments: Array.isArray(d.documents) && d.documents.length > 0,
      hasDevices: Array.isArray(d.devices) && d.devices.length > 0,
      isContract: !!d.isContract,
      hasRating: !!d.rating?.score,
    }
  })

  // Parse companies
  const companies = companiesSnap.docs.map((doc) => {
    const d = doc.data()
    return {
      id: doc.id,
      name: d.name as string,
      segment: d.segment as string | undefined,
      country: d.country as string | undefined,
      membersCount: Array.isArray(d.users) ? d.users.length : 0,
      createdAt: parseFirestoreDate(d.createdAt),
      lastOrderDate: parseFirestoreDate(d.lastOrderDate),
      nextOrderNumber: (d.nextOrderNumber as number) || 0,
    }
  })

  // Totals from nextOrderNumber (source of truth, not period-dependent)
  const realTotalOrders = companies.reduce((sum, c) => sum + Math.max(0, c.nextOrderNumber - 1), 0)

  // Debug: date parsing stats
  const ordersWithDate = allOrders.filter((o) => o.effectiveDate !== null).length

  // --- PERIOD-FILTERED orders (everything below uses this) ---
  const periodOrders = allOrders.filter((o) => o.effectiveDate && o.effectiveDate >= periodStart)

  // Active companies = had at least 1 OS in the last 7 days (using lastOrderDate from company doc)
  const ACTIVE_WINDOW_DAYS = 7
  const activeWindowStart = new Date(now.getTime() - ACTIVE_WINDOW_DAYS * 86400000)
  const activeCompanyIds = new Set(
    companies
      .filter((c) => c.lastOrderDate && c.lastOrderDate >= activeWindowStart)
      .map((c) => c.id),
  )

  // Retention: of companies registered in the selected period, how many are still active?
  // "Active" = created at least 1 OS in the last 7 days (lastOrderDate >= 7 days ago)
  const companiesInPeriod = companies.filter((c) => c.createdAt && c.createdAt >= periodStart)
  const retainedCount = companiesInPeriod.filter((c) => activeCompanyIds.has(c.id)).length
  const retentionRate = companiesInPeriod.length > 0
    ? Math.round((retainedCount / companiesInPeriod.length) * 100)
    : 0

  // Orders by status (period-filtered)
  const ordersByStatus: Record<string, number> = {}
  for (const o of periodOrders) {
    if (o.status) ordersByStatus[o.status] = (ordersByStatus[o.status] || 0) + 1
  }

  // Financial (all non-canceled orders with value in period)
  const periodBillable = periodOrders.filter((o) => o.status !== 'canceled' && o.total > 0)
  const periodRevenue = periodBillable.reduce((sum, o) => sum + o.total, 0)
  const periodAvgTicket = periodBillable.length > 0 ? periodRevenue / periodBillable.length : 0

  // Orders over time chart (period-filtered, max 90 days of granularity)
  const chartDays = Math.min(periodDays, 90)
  const ordersOverTime: { date: string; count: number }[] = []
  for (let i = chartDays - 1; i >= 0; i--) {
    const d = new Date(now.getTime() - i * 86400000)
    const dateStr = d.toISOString().slice(0, 10)
    const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    const dayEnd = new Date(dayStart.getTime() + 86400000)
    const count = allOrders.filter(
      (o) => o.effectiveDate && o.effectiveDate >= dayStart && o.effectiveDate < dayEnd,
    ).length
    ordersOverTime.push({ date: dateStr, count })
  }

  // New companies in period
  const newCompaniesInPeriod = companies.filter(
    (c) => c.createdAt && c.createdAt >= periodStart,
  ).length

  // New companies per month (scoped to period, max 12 months)
  const monthsToShow = Math.min(Math.ceil(periodDays / 30), 12)
  const newCompaniesPerMonth: { month: string; count: number }[] = []
  for (let i = monthsToShow - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const monthEnd = new Date(d.getFullYear(), d.getMonth() + 1, 0)
    const label = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    const count = companies.filter(
      (c) => c.createdAt && c.createdAt >= d && c.createdAt <= monthEnd,
    ).length
    newCompaniesPerMonth.push({ month: label, count })
  }

  // Top 10 companies (period-filtered)
  const companyMap = new Map(companies.map((c) => [c.id, c]))
  const periodCompanyStats = new Map<string, { name: string; segment: string; country: string; orders: number; revenue: number; lastActivity: string | null }>()
  for (const o of periodOrders) {
    if (!o.companyId) continue
    const dateStr = o.effectiveDate?.toISOString() || null
    const existing = periodCompanyStats.get(o.companyId)
    if (existing) {
      existing.orders++
      existing.revenue += o.status !== 'canceled' ? o.total : 0
      if (dateStr && (!existing.lastActivity || dateStr > existing.lastActivity)) {
        existing.lastActivity = dateStr
      }
    } else {
      const comp = companyMap.get(o.companyId)
      periodCompanyStats.set(o.companyId, {
        name: o.companyName || 'Unknown',
        segment: comp?.segment || '',
        country: o.companyCountry || '',
        orders: 1,
        revenue: o.status !== 'canceled' ? o.total : 0,
        lastActivity: dateStr,
      })
    }
  }
  const topCompanies = Array.from(periodCompanyStats.entries())
    .map(([id, stats]) => {
      const comp = companyMap.get(id)
      const realOrders = comp?.nextOrderNumber ? comp.nextOrderNumber - 1 : stats.orders
      return { id, ...stats, realOrders }
    })
    .sort((a, b) => b.orders - a.orders)
    .slice(0, 10)

  // Churn risk: companies that had orders before the period but none in the period
  // Build all-time stats to know who existed before
  const allTimeCompanyStats = new Map<string, { name: string; segment: string; lastActivity: string | null }>()
  for (const o of allOrders) {
    if (!o.companyId) continue
    const dateStr = o.effectiveDate?.toISOString() || null
    const existing = allTimeCompanyStats.get(o.companyId)
    if (existing) {
      if (dateStr && (!existing.lastActivity || dateStr > existing.lastActivity)) {
        existing.lastActivity = dateStr
      }
    } else {
      const comp = companyMap.get(o.companyId)
      allTimeCompanyStats.set(o.companyId, {
        name: o.companyName || 'Unknown',
        segment: comp?.segment || '',
        lastActivity: dateStr,
      })
    }
  }
  const churnRisk = Array.from(allTimeCompanyStats.entries())
    .filter(([id]) => !activeCompanyIds.has(id))
    .map(([id, stats]) => ({
      id,
      name: stats.name,
      segment: stats.segment,
      lastActivity: stats.lastActivity,
      daysSinceLastOrder: stats.lastActivity
        ? Math.floor((now.getTime() - new Date(stats.lastActivity).getTime()) / 86400000)
        : null,
    }))
    .sort((a, b) => (a.daysSinceLastOrder || 999) - (b.daysSinceLastOrder || 999))
    .slice(0, 20)

  const result = {
    period,
    periodDays,
    totalCompanies: companies.length,
    activeCompanies: activeCompanyIds.size,
    ordersPeriod: periodOrders.length,
    revenuePeriod: Math.round(periodRevenue * 100) / 100,
    averageTicket: Math.round(periodAvgTicket * 100) / 100,
    retentionRate,
    realTotalOrders,
    newCompaniesInPeriod,
    ordersByStatus,
    ordersOverTime,
    newCompaniesPerMonth,
    topCompanies,
    churnRisk,
    _debug: {
      ordersLoaded: allOrders.length,
      ordersWithDate,
      ordersWithoutDate: allOrders.length - ordersWithDate,
      oldestDate: allOrders.filter((o) => o.effectiveDate).sort((a, b) => a.effectiveDate!.getTime() - b.effectiveDate!.getTime())[0]?.effectiveDate?.toISOString() || null,
      newestDate: allOrders.filter((o) => o.effectiveDate).sort((a, b) => b.effectiveDate!.getTime() - a.effectiveDate!.getTime())[0]?.effectiveDate?.toISOString() || null,
    },
  }

  setCache(cacheKey, result)
  return { data: result }
})

function parsePeriodDays(period: string): number {
  switch (period) {
    case 'today': return 1
    case '7d': return 7
    case '30d': return 30
    case '90d': return 90
    case '6m': return 180
    case '1y': return 365
    case 'all': return 3650
    default: return 30
  }
}
