import { getAdminDb } from './firebase'

export interface PublicProfileData {
  company: {
    id: string
    name: string
    segment?: string
    city?: string
    state?: string
    country?: string
    logo?: string
    phone?: string
    whatsapp?: string
    bio?: string
    showPrices: boolean
    showPhone: boolean
    showWhatsapp: boolean
    showAddress: boolean
    verified: boolean
    slug: string
    tags?: string[]
  }
  services: Array<{
    id: string
    name: string
    value?: number
    photo?: string
  }>
  reviews: Array<{
    id: string
    score: number
    comment?: string
    customerName: string
    createdAt: string
  }>
  portfolio: Array<{
    url: string
    description?: string
  }>
  certifications: Array<{
    id: string
    name: string
    issuer?: string
    verifiedAt?: string
  }>
  stats: {
    completedOrders: number
    avgRating: number
    reviewCount: number
  }
}

function maskCustomerName(name?: string): string {
  if (!name) return ''
  const parts = name.trim().split(/\s+/)
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase() + '.'
  return parts[0] + ' ' + parts[parts.length - 1].charAt(0).toUpperCase() + '.'
}

export async function getProfileBySlug(slug: string): Promise<PublicProfileData | null> {
  const db = getAdminDb()

  // 1. Lookup slug → companyId
  const slugDoc = await db.collection('profileSlugs').doc(slug).get()
  if (!slugDoc.exists) return null

  const { companyId } = slugDoc.data() as { companyId: string }
  if (!companyId) return null

  // 2. Fetch company + profile config in parallel
  const [companySnap, profileSnap] = await Promise.all([
    db.collection('companies').doc(companyId).get(),
    db.collection('companies').doc(companyId).collection('publicProfile').doc('config').get(),
  ])

  if (!companySnap.exists) return null

  const companyData = companySnap.data() as Record<string, any>
  const profileConfig = profileSnap.exists
    ? (profileSnap.data() as Record<string, any>)
    : {}

  // Check if profile is active
  if (profileConfig.active === false) return null

  // 3. Fetch services + completed orders (for ratings & stats) in parallel
  // Services: uses existing index (company.id, name). Filter inactive client-side
  // to avoid needing a composite index on (active, name) for != queries.
  // Orders: uses existing index (status, createdAt DESC).
  const [servicesSnap, ordersSnap] = await Promise.all([
    db.collection('companies').doc(companyId).collection('services')
      .orderBy('name')
      .limit(100)
      .get(),
    db.collection('companies').doc(companyId).collection('orders')
      .where('status', '==', 'done')
      .orderBy('createdAt', 'desc')
      .limit(200)
      .get(),
  ])

  // Build services list (filter out inactive client-side)
  const services = servicesSnap.docs
    .filter(doc => doc.data().active !== false)
    .slice(0, 50)
    .map(doc => {
      const d = doc.data()
      return {
        id: doc.id,
        name: d.name || '',
        value: d.value,
        photo: d.photo,
      }
    })

  // Extract reviews and stats from completed orders
  const hiddenReviews = new Set(profileConfig.hiddenReviews || [])
  const reviews: PublicProfileData['reviews'] = []
  let totalRating = 0
  let ratingCount = 0

  for (const doc of ordersSnap.docs) {
    const order = doc.data()
    if (order.rating?.score) {
      ratingCount++
      totalRating += order.rating.score

      if (!hiddenReviews.has(doc.id) && order.rating.comment) {
        reviews.push({
          id: doc.id,
          score: order.rating.score,
          comment: order.rating.comment,
          customerName: maskCustomerName(
            order.rating.customerName || order.customer?.name
          ),
          createdAt: order.rating.createdAt?.toDate?.()
            ? order.rating.createdAt.toDate().toISOString()
            : order.createdAt?.toDate?.()
              ? order.createdAt.toDate().toISOString()
              : new Date().toISOString(),
        })
      }
    }
  }

  // Sort reviews by date descending, limit to 20
  reviews.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
  const limitedReviews = reviews.slice(0, 20)

  // Build portfolio
  const portfolio: PublicProfileData['portfolio'] = (profileConfig.portfolioPhotos || []).map(
    (p: any) => ({
      url: p.url || p,
      description: p.description || '',
    })
  )

  // Build company info with privacy filtering
  const showPhone = profileConfig.showPhone !== false
  const showWhatsapp = profileConfig.showWhatsapp !== false
  const showAddress = profileConfig.showAddress !== false
  const showPrices = profileConfig.showPrices !== false

  const address = companyData.address || {}

  return {
    company: {
      id: companyId,
      name: companyData.name || '',
      segment: companyData.segment?.id || companyData.segment,
      city: showAddress ? (address.city || companyData.city) : undefined,
      state: showAddress ? (address.state || companyData.state) : undefined,
      country: companyData.country || address.country || 'BR',
      logo: companyData.logo,
      phone: showPhone ? companyData.phone : undefined,
      whatsapp: showWhatsapp ? (companyData.whatsapp || companyData.phone) : undefined,
      bio: profileConfig.bio || companyData.description || '',
      showPrices,
      showPhone,
      showWhatsapp,
      showAddress,
      verified: profileConfig.verified === true,
      slug,
      tags: Array.isArray(profileConfig.tags) ? profileConfig.tags : [],
    },
    services,
    reviews: limitedReviews,
    portfolio,
    certifications: Array.isArray(profileConfig.certifications)
      ? profileConfig.certifications.map((c: any, i: number) => ({
          id: c.id || String(i),
          name: c.name || '',
          issuer: c.issuer,
          verifiedAt: c.verifiedAt,
        }))
      : [],
    stats: {
      completedOrders: ordersSnap.size,
      avgRating: ratingCount > 0 ? Math.round((totalRating / ratingCount) * 10) / 10 : 0,
      reviewCount: ratingCount,
    },
  }
}
