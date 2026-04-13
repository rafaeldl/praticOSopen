export function useAdminPolling<T>(
  fetcher: () => Promise<T>,
  intervalMs: number = 30_000,
) {
  const data = ref<T | null>(null) as Ref<T | null>
  const loading = ref(true)
  const error = ref<string | null>(null)
  const lastUpdated = ref<Date | null>(null)

  let intervalId: ReturnType<typeof setInterval> | null = null
  let paused = false

  async function refresh() {
    try {
      data.value = await fetcher()
      error.value = null
      lastUpdated.value = new Date()
    } catch (e: any) {
      error.value = e.message || 'Failed to fetch data'
    } finally {
      loading.value = false
    }
  }

  function start() {
    refresh()
    intervalId = setInterval(() => {
      if (!paused) refresh()
    }, intervalMs)
  }

  function handleVisibility() {
    paused = document.visibilityState === 'hidden'
    if (!paused) refresh()
  }

  if (import.meta.client) {
    const { token, loading: authLoading } = useAdminAuth()

    onMounted(() => {
      // Wait for auth token before starting polling
      if (token.value) {
        start()
      } else {
        const unwatch = watch(
          () => authLoading.value,
          (isLoading) => {
            if (!isLoading && token.value) {
              unwatch()
              start()
            }
          },
          { immediate: true },
        )
      }
      document.addEventListener('visibilitychange', handleVisibility)
    })

    onUnmounted(() => {
      if (intervalId) clearInterval(intervalId)
      document.removeEventListener('visibilitychange', handleVisibility)
    })
  }

  return { data, loading, error, lastUpdated, refresh }
}
