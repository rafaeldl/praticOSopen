import { describe, expect, test, vi } from 'vitest'
import { ApiError, createApi, errorMessageKey } from '../src/lib/api'

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status })

function setup(responses: (Response | Error)[], company: string | null = 'c1') {
  const fetchMock = vi.fn(async () => {
    const next = responses.shift()
    if (next instanceof Error) throw next
    return next as Response
  })
  const getToken = vi.fn(async (force: boolean) => (force ? 'fresh' : 'cached'))
  const api = createApi({
    baseUrl: () => 'https://api.test',
    getToken,
    getCompanyId: () => company,
    fetch: fetchMock as unknown as typeof fetch,
  })
  return { api, fetchMock, getToken }
}

const headersOf = (mock: ReturnType<typeof vi.fn>, call = 0) =>
  (mock.mock.calls[call] as unknown as [string, RequestInit])[1].headers as Record<string, string>

describe('requests', () => {
  test('sends the ID token and the company', async () => {
    const { api, fetchMock } = setup([json(200, { success: true, data: { ok: 1 } })])
    await expect(api.request('/v1/app/x')).resolves.toEqual({ ok: 1 })
    expect(headersOf(fetchMock)).toEqual({ Authorization: 'Bearer cached', 'X-Company-Id': 'c1' })
  })

  test('account routes go without company', async () => {
    const { api, fetchMock } = setup([json(200, {})])
    await api.request('/v1/app/account', { noCompany: true })
    expect(headersOf(fetchMock)['X-Company-Id']).toBeUndefined()
  })

  test('JSON body', async () => {
    const { api, fetchMock } = setup([json(200, {})])
    await api.request('/x', { method: 'POST', body: { a: 1 } })
    const init = (fetchMock.mock.calls[0] as unknown as [string, RequestInit])[1]
    expect(init.body).toBe('{"a":1}')
    expect(init.method).toBe('POST')
  })

  test('401 retries once with a fresh token', async () => {
    const { api, fetchMock } = setup([json(401, {}), json(200, { data: 'ok' })])
    await expect(api.request('/x')).resolves.toBe('ok')
    expect(headersOf(fetchMock, 1).Authorization).toBe('Bearer fresh')
  })

  test('no session never reaches the network', async () => {
    const { fetchMock } = setup([])
    const api = createApi({ baseUrl: () => '', getToken: async () => null, getCompanyId: () => null, fetch: fetchMock as unknown as typeof fetch })
    await expect(api.request('/x')).rejects.toMatchObject({ code: 'NO_SESSION' })
    expect(fetchMock).not.toHaveBeenCalled()
  })
})

describe('errors become i18n keys, never server text', () => {
  test.each([
    ['FORBIDDEN', 403, 'web.error.forbidden'],
    ['INSUFFICIENT_PERMISSIONS', 403, 'web.error.forbidden'],
    ['NOT_FOUND', 404, 'web.error.notFound'],
    ['VALIDATION_ERROR', 400, 'web.error.validation'],
    ['RATE_LIMIT_EXCEEDED', 429, 'web.error.rateLimit'],
    ['INVALID_TRANSITION', 400, 'web.error.conflict'],
    ['INTERNAL_ERROR', 500, 'web.error.generic'],
    ['SOME_NEW_CODE', 409, 'web.error.conflict'],
    ['SOME_NEW_CODE', 503, 'web.error.unavailable'],
  ])('%s %d', async (code, status, key) => {
    const { api } = setup([json(status, { success: false, error: { code, message: 'Stack at /srv/x.js:1' } })])
    const error = (await api.request('/x').catch((e) => e)) as ApiError
    expect(error).toBeInstanceOf(ApiError)
    expect(error.messageKey).toBe(key)
    expect(errorMessageKey(error)).toBe(key)
    expect(error.message).not.toContain('/srv')
  })

  test('401 twice is a finished session', async () => {
    const { api } = setup([json(401, {}), json(401, {})])
    await expect(api.request('/x')).rejects.toMatchObject({ messageKey: 'web.error.sessionExpired' })
  })

  test('a 200 reporting failure is still a failure', async () => {
    const { api } = setup([json(200, { success: false, error: { code: 'NOT_FOUND' } })])
    await expect(api.request('/x')).rejects.toMatchObject({ messageKey: 'web.error.notFound' })
  })

  test('network failure', async () => {
    const { api } = setup([new TypeError('Failed to fetch')])
    await expect(api.request('/x')).rejects.toMatchObject({ messageKey: 'web.error.network' })
  })

  test('HTML error page instead of JSON', async () => {
    const { api } = setup([new Response('<html>502</html>', { status: 502 })])
    await expect(api.request('/x')).rejects.toMatchObject({ messageKey: 'web.error.unavailable' })
  })

  test('anything else shows the generic text', () => {
    expect(errorMessageKey(new Error('secret detail'))).toBe('web.error.generic')
  })
})
