export default defineEventHandler(async (event) => {
  const token = getRouterParam(event, 'token')
  const config = useRuntimeConfig()

  if (!token) {
    throw createError({ statusCode: 400, message: 'Token is required' })
  }

  try {
    const data = await $fetch(`${config.apiBaseUrl}/public/orders/${token}`)
    return data
  } catch (error: any) {
    const statusCode = error?.response?.status || error?.statusCode || 500
    throw createError({
      statusCode,
      message: error?.data?.error?.message || 'Failed to load order',
    })
  }
})
