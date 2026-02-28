export function useOrderApi() {
  const config = useRuntimeConfig()
  const apiBase = config.public.apiBaseUrl

  async function getOrder(token: string) {
    const { data, error } = await useFetch(`/api/orders/${token}`)
    if (error.value) throw error.value
    return data.value
  }

  async function approveQuote(token: string) {
    const res = await $fetch(`${apiBase}/public/orders/${token}/approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    })
    return res
  }

  async function rejectQuote(token: string, reason?: string) {
    const res = await $fetch(`${apiBase}/public/orders/${token}/reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: { reason },
    })
    return res
  }

  async function addComment(token: string, text: string) {
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
    const res = await $fetch(`${apiBase}/public/orders/${token}/rating`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: { score, comment: comment || undefined },
    })
    return res
  }

  return { getOrder, approveQuote, rejectQuote, addComment, getComments, submitRating }
}
