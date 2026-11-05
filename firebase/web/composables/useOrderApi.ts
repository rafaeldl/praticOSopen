/** Thrown instead of calling the api when the page is a preview ("Ver como o cliente vê"). */
export class PreviewBlockedError extends Error {
  constructor() {
    super('preview')
    this.name = 'PreviewBlockedError'
  }
}

/**
 * Preview mode of the magic link page (`?preview=1`). Shared state so every
 * component's write goes through the same guard; `blockedAt` changes on each
 * blocked try so the page can show its notice.
 */
export function useOrderPreview() {
  const preview = useState('orderPreview', () => false)
  const blockedAt = useState('orderPreviewBlockedAt', () => 0)
  return { preview, blockedAt }
}

export function useOrderApi() {
  const config = useRuntimeConfig()
  const apiBase = config.public.apiBaseUrl
  const { preview, blockedAt } = useOrderPreview()

  /** In preview no customer action reaches the api: nothing is approved, rated, commented or notified. */
  function guard() {
    if (!preview.value) return
    blockedAt.value = Date.now()
    throw new PreviewBlockedError()
  }

  async function getOrder(token: string) {
    const { data, error } = await useFetch(`/api/orders/${token}`)
    if (error.value) throw error.value
    return data.value
  }

  async function approveQuote(token: string) {
    guard()
    const res = await $fetch(`${apiBase}/public/orders/${token}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    })
    return res
  }

  async function rejectQuote(token: string, reason?: string) {
    guard()
    const res = await $fetch(`${apiBase}/public/orders/${token}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: { reason },
    })
    return res
  }

  async function addComment(token: string, text: string) {
    guard()
    const res = await $fetch(`${apiBase}/public/orders/${token}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: { text },
    })
    return res
  }

  async function getComments(token: string) {
    const res = await $fetch(`${apiBase}/public/orders/${token}/comments`)
    return res
  }

  async function submitRating(token: string, score: number, comment?: string) {
    guard()
    const res = await $fetch(`${apiBase}/public/orders/${token}/rating`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: { score, comment: comment || undefined },
    })
    return res
  }

  return { getOrder, approveQuote, rejectQuote, addComment, getComments, submitRating }
}
