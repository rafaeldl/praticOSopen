// A tab opened before a deploy asks for chunks that no longer exist (404).
// Reload once to get the new build; if it fails again right away, let the error
// show instead of looping.
const KEY = 'praticos.reloadedForAssets'
const WINDOW_MS = 60_000

interface StorageLike {
  getItem(key: string): string | null
  setItem(key: string, value: string): void
}

/** True when it reloaded. */
export function reloadForNewBuild(
  storage: StorageLike | undefined,
  reload: () => void,
  now = Date.now(),
): boolean {
  try {
    const last = Number(storage?.getItem(KEY) ?? 0)
    if (last > 0 && last <= now && now - last < WINDOW_MS) return false
    storage?.setItem(KEY, String(now))
  } catch {
    // No session storage: still reload once (this page instance).
  }
  reload()
  return true
}

const CHUNK_ERROR = /Failed to fetch dynamically imported module|Importing a module script failed|error loading dynamically imported module/i

export function isChunkLoadError(error: unknown): boolean {
  return CHUNK_ERROR.test(String((error as { message?: string })?.message ?? error))
}

export function watchForStaleBuild(onError: (handler: (error: unknown) => void) => void): void {
  const storage = (() => {
    try {
      return sessionStorage
    } catch {
      return undefined
    }
  })()
  window.addEventListener('vite:preloadError', (event) => {
    if (reloadForNewBuild(storage, () => location.reload())) event.preventDefault()
  })
  onError((error) => {
    if (isChunkLoadError(error)) reloadForNewBuild(storage, () => location.reload())
  })
}
