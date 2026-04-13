export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server) return

  const token = useCookie('admin-token')

  // If cookie exists, allow through (token will be verified server-side)
  if (token.value) return

  // No cookie — wait briefly for Firebase Auth to restore session
  const { token: authToken, loading } = useAdminAuth()

  if (loading.value) {
    // Wait for auth to initialize (max 3s)
    await new Promise<void>((resolve) => {
      const unwatch = watch(
        () => loading.value,
        (isLoading) => {
          if (!isLoading) {
            unwatch()
            resolve()
          }
        },
        { immediate: true },
      )
      setTimeout(() => {
        unwatch()
        resolve()
      }, 3000)
    })
  }

  if (!authToken.value) {
    return navigateTo('/admin/login')
  }
})
