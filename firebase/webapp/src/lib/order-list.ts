// Joining what the list got from disk, from the server and page by page,
// always by id and in the query's order (newest first by default, id as
// tie-break), so no order is shown twice or skipped.
export interface ListRow {
  id: string
  createdAt?: string | null
}

export type RowCompare<T extends ListRow = ListRow> = (a: T, b: T) => number

/** Negative when `a` comes first: newer first, then the larger id (same as the query). */
export function compareRows(a: ListRow, b: ListRow): number {
  const byDate = (b.createdAt ?? '').localeCompare(a.createdAt ?? '')
  return byDate !== 0 ? byDate : b.id.localeCompare(a.id)
}

/**
 * The order of a query sorted by another field ("dueDate", "onHold.since"),
 * read from the row the screen holds, id as tie-break in the same direction.
 */
export function compareBy<T extends ListRow>(field: string, dir: 'asc' | 'desc'): RowCompare<T> {
  const sign = dir === 'asc' ? 1 : -1
  const read = (row: T) => {
    const value = field
      .split('.')
      .reduce<unknown>((current, key) => (current && typeof current === 'object' ? (current as Record<string, unknown>)[key] : undefined), row)
    return typeof value === 'string' ? value : ''
  }
  return (a, b) => (read(a).localeCompare(read(b)) || a.id.localeCompare(b.id)) * sign
}

/** Union by id; on the same id the incoming copy wins. */
export function mergeById<T extends ListRow>(current: T[], incoming: T[], compare: RowCompare<T> = compareRows): T[] {
  const byId = new Map(current.map((row) => [row.id, row]))
  for (const row of incoming) byId.set(row.id, row)
  return [...byId.values()].sort(compare)
}

/**
 * The server's first page replaces what the disk showed for that stretch: rows
 * up to the last one of the page that the server did not send were deleted or
 * moved away. Later rows (from later pages) stay.
 */
export function applyFreshFirstPage<T extends ListRow>(current: T[], fresh: T[], pageSize: number, compare: RowCompare<T> = compareRows): T[] {
  const sortedFresh = [...fresh].sort(compare)
  if (sortedFresh.length < pageSize) return sortedFresh
  const boundary = sortedFresh[sortedFresh.length - 1] as T
  const freshIds = new Set(sortedFresh.map((row) => row.id))
  const later = current.filter((row) => !freshIds.has(row.id) && compare(boundary, row) < 0)
  return mergeById(later, sortedFresh, compare)
}
