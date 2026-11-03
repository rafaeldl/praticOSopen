// Joining what the list got from disk, from the server and page by page,
// always by id and in one order (newest first, id as tie-break), so no order is
// shown twice or skipped.
export interface ListRow {
  id: string
  createdAt?: string | null
}

/** Negative when `a` comes first: newer first, then the larger id (same as the query). */
export function compareRows(a: ListRow, b: ListRow): number {
  const byDate = (b.createdAt ?? '').localeCompare(a.createdAt ?? '')
  return byDate !== 0 ? byDate : b.id.localeCompare(a.id)
}

/** Union by id; on the same id the incoming copy wins. */
export function mergeById<T extends ListRow>(current: T[], incoming: T[]): T[] {
  const byId = new Map(current.map((row) => [row.id, row]))
  for (const row of incoming) byId.set(row.id, row)
  return [...byId.values()].sort(compareRows)
}

/**
 * The server's first page replaces what the disk showed for that stretch: rows
 * up to the last one of the page that the server did not send were deleted or
 * moved away. Older rows (from later pages) stay.
 */
export function applyFreshFirstPage<T extends ListRow>(current: T[], fresh: T[], pageSize: number): T[] {
  const sortedFresh = [...fresh].sort(compareRows)
  if (sortedFresh.length < pageSize) return sortedFresh
  const boundary = sortedFresh[sortedFresh.length - 1] as T
  const freshIds = new Set(sortedFresh.map((row) => row.id))
  const older = current.filter((row) => !freshIds.has(row.id) && compareRows(boundary, row) < 0)
  return mergeById(older, sortedFresh)
}
