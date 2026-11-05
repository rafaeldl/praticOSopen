/**
 * "Ver como o cliente vê": the team opens the customer's own link with
 * `?preview=1`. The page then shows a banner, blocks approve/reject/rate/comment
 * before any request, and asks the api not to count the visit (the api skips
 * viewCount/lastViewedAt for `preview=1`). It is only a display mode: the token
 * still decides what can be read, so the flag grants nothing.
 */
export function isPreview(query: Record<string, unknown> | null | undefined): boolean {
  const value = query?.preview
  return (Array.isArray(value) ? value[0] : value) === '1'
}

/** Path of the order data, carrying the preview flag to the api. */
export function orderDataPath(token: string, preview: boolean): string {
  const path = `/api/orders/${encodeURIComponent(token)}`
  return preview ? `${path}?preview=1` : path
}
