import { getProfileBySlug } from '~/server/utils/profile-service'

export default defineEventHandler(async (event) => {
  const slug = getRouterParam(event, 'slug')

  if (!slug || !/^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$/.test(slug)) {
    throw createError({
      statusCode: 400,
      message: 'Invalid slug format',
    })
  }

  try {
    const profile = await getProfileBySlug(slug)

    if (!profile) {
      throw createError({
        statusCode: 404,
        message: 'Profile not found',
      })
    }

    // Cache: CDN caches for 1h, serves stale for 24h while revalidating
    setResponseHeaders(event, {
      'Cache-Control': 's-maxage=3600, stale-while-revalidate=86400',
    })

    return { data: profile }
  } catch (error: any) {
    if (error.statusCode) throw error
    console.error('[profile-api] Error fetching profile:', slug, error)
    throw createError({
      statusCode: 500,
      message: 'Failed to load profile',
    })
  }
})
