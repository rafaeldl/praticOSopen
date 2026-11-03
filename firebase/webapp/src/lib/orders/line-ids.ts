// Item ids for lines read straight from Firestore. The app never stores an id
// on a line, so the server derives one from what the line is and its position
// among equal lines (functions/src/services/order-items.ts locateLines). Same
// recipe here, so a write to /v1/app/orders/:id/items/:itemId finds the line
// without asking the server first.
type RawLine = Record<string, unknown>

async function sha256Hex20(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 20)
}

function signature(kind: 'service' | 'product', line: RawLine): unknown[] {
  const catalog = (kind === 'service' ? line.service : line.product) as { id?: string } | undefined
  return [
    kind,
    catalog?.id ?? null,
    line.description ?? null,
    line.value ?? null,
    kind === 'product' ? (line.quantity ?? null) : null,
    kind === 'product' ? (line.total ?? null) : null,
    line.deviceId ?? null,
  ]
}

/** Ids in screen order: services first, then products, like the server. */
export async function lineIds(services: RawLine[] = [], products: RawLine[] = []): Promise<string[]> {
  const seen = new Map<string, number>()
  const ids: string[] = []
  for (const [kind, lines] of [
    ['service', services],
    ['product', products],
  ] as const) {
    for (const line of lines) {
      const hash = await sha256Hex20(JSON.stringify(signature(kind, line)))
      const occurrence = seen.get(hash) ?? 0
      seen.set(hash, occurrence + 1)
      ids.push(typeof line.id === 'string' && line.id ? line.id : `legacy_${hash}_${occurrence}`)
    }
  }
  return ids
}
