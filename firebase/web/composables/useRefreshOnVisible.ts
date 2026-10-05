import { createVisibilityRefresher } from '~/utils/visibility-refresher'

interface RefreshOnVisibleOptions {
  when?: () => boolean
  minIntervalMs?: number
}

/**
 * Re-runs `refresh` when the tab becomes visible again, e.g. after the customer
 * pays the Asaas invoice in another tab and comes back to the order link.
 */
export function useRefreshOnVisible(refresh: () => unknown, options: RefreshOnVisibleOptions = {}) {
  const handle = createVisibilityRefresher({ refresh, ...options })
  const listener = () => handle(document.visibilityState)

  onMounted(() => {
    document.addEventListener('visibilitychange', listener)
    window.addEventListener('focus', listener)
  })
  onBeforeUnmount(() => {
    document.removeEventListener('visibilitychange', listener)
    window.removeEventListener('focus', listener)
  })
}
