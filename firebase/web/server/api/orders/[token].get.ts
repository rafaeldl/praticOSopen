export default defineEventHandler(async (event) => {
  const token = getRouterParam(event, 'token')
  const config = useRuntimeConfig()

  if (!token) {
    throw createError({ statusCode: 400, message: 'Token is required' })
  }

  try {
    // Every /q/ visitor reaches the api from this server's IP; the secret gets
    // these loads a per-link rate limit there instead of one shared IP bucket.
    const headers: Record<string, string> = config.ssrApiSecret
      ? { 'X-Praticos-SSR-Secret': config.ssrApiSecret }
      : {}
    const data = await $fetch(`${config.apiBaseUrl}/public/orders/${token}`, { headers })
    return data
  } catch (error: any) {
    const statusCode = error?.response?.status || error?.statusCode || 500
    throw createError({
      statusCode,
      message: error?.data?.error?.message || 'Failed to load order',
    })
  }
})
