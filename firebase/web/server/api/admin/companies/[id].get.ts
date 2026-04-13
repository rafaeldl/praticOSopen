import { getAdminDb } from '~/server/utils/firebase'
import { verifyAdminToken } from '~/server/utils/admin-auth'
import { parseFirestoreDate } from '~/server/utils/parse-date'

export default defineEventHandler(async (event) => {
  await verifyAdminToken(event)

  const id = getRouterParam(event, 'id')
  if (!id) throw createError({ statusCode: 400, message: 'Company ID required' })

  const db = getAdminDb()

  const [companySnap, ordersSnap] = await Promise.all([
    db.collection('companies').doc(id).get(),
    db.collection('companies').doc(id).collection('orders').orderBy('createdAt', 'desc').limit(1000).get(),
  ])

  if (!companySnap.exists) {
    throw createError({ statusCode: 404, message: 'Company not found' })
  }

  const companyData = companySnap.data()!
  const now = new Date()

  const orders = ordersSnap.docs.map((doc) => {
    const d = doc.data()
    return {
      id: doc.id,
      number: d.number,
      status: d.status,
      total: (d.total as number) || 0,
      payment: d.payment,
      createdAt: (parseFirestoreDate(d.createdAt) || parseFirestoreDate(d.updatedAt))?.toISOString() || null,
      customerName: d.customer?.name || null,
      hasPhotos: Array.isArray(d.photos) && d.photos.length > 0,
      hasShareLink: !!d.shareLink?.token,
      hasDocuments: Array.isArray(d.documents) && d.documents.length > 0,
      hasDevices: Array.isArray(d.devices) && d.devices.length > 0,
      isContract: !!d.isContract,
      hasRating: !!d.rating?.score,
    }
  })

  // Stats
  const activeStatuses = ['quote', 'approved', 'progress']
  const activeOrders = orders.filter((o) => activeStatuses.includes(o.status))
  const billableOrders = orders.filter((o) => o.status !== 'canceled' && o.total > 0)
  const revenue = billableOrders.reduce((sum, o) => sum + o.total, 0)
  const avgTicket = billableOrders.length > 0 ? revenue / billableOrders.length : 0

  // Status distribution
  const statusDistribution: Record<string, number> = {}
  for (const o of orders) {
    if (o.status) statusDistribution[o.status] = (statusDistribution[o.status] || 0) + 1
  }

  // Orders by month (last 12 months)
  const ordersByMonth: { month: string; count: number }[] = []
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const monthEnd = new Date(d.getFullYear(), d.getMonth() + 1, 0)
    const label = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    const count = orders.filter((o) => {
      if (!o.createdAt) return false
      const dt = new Date(o.createdAt)
      return dt >= d && dt <= monthEnd
    }).length
    ordersByMonth.push({ month: label, count })
  }

  // Feature usage
  const totalCount = orders.length || 1
  const featureUsage = {
    photos: Math.round((orders.filter((o) => o.hasPhotos).length / totalCount) * 100),
    shareLinks: Math.round((orders.filter((o) => o.hasShareLink).length / totalCount) * 100),
    documents: Math.round((orders.filter((o) => o.hasDocuments).length / totalCount) * 100),
    devices: Math.round((orders.filter((o) => o.hasDevices).length / totalCount) * 100),
    contracts: Math.round((orders.filter((o) => o.isContract).length / totalCount) * 100),
    ratings: Math.round((orders.filter((o) => o.hasRating).length / totalCount) * 100),
  }

  // Company info
  const company = {
    id: companySnap.id,
    name: companyData.name,
    segment: companyData.segment,
    country: companyData.country,
    email: companyData.email,
    phone: companyData.phone,
    ownerName: companyData.owner?.name,
    ownerEmail: companyData.owner?.email,
    membersCount: Array.isArray(companyData.users) ? companyData.users.length : 0,
    members: Array.isArray(companyData.users)
      ? companyData.users.map((u: any) => ({ name: u.name, email: u.email, role: u.role }))
      : [],
    createdAt: parseFirestoreDate(companyData.createdAt)?.toISOString() || null,
    subscription: companyData.subscription?.plan || null,
    features: {
      fieldService: !!companyData.fieldService,
      scheduling: !!companyData.useScheduling,
      deviceManagement: !!companyData.useDeviceManagement,
      contracts: !!companyData.useContracts,
    },
  }

  return {
    data: {
      company,
      stats: {
        totalOrders: orders.length,
        activeOrders: activeOrders.length,
        revenue: Math.round(revenue * 100) / 100,
        avgTicket: Math.round(avgTicket * 100) / 100,
      },
      statusDistribution,
      ordersByMonth,
      featureUsage,
      recentOrders: orders.slice(0, 20),
    },
  }
})
