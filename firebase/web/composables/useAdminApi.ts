export function useAdminApi() {
  const { token } = useAdminAuth()

  async function fetchAdmin<T>(url: string, opts?: Record<string, any>): Promise<T> {
    return $fetch(url, {
      ...opts,
      headers: {
        ...opts?.headers,
        Authorization: `Bearer ${token.value}`,
      },
    })
  }

  return { fetchAdmin }
}
