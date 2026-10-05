/**
 * Background refresh that never disturbs the page: assigns the fresh value only
 * on success and swallows failures, so a flaky network keeps the last good data
 * (unlike useFetch's refresh, which resets data to null and sets error).
 */
export async function quietRefresh<T>(fetcher: () => Promise<T>, assign: (fresh: T) => void): Promise<void> {
  try {
    assign(await fetcher())
  } catch {
    // keep previous data; the next visibility event retries
  }
}
