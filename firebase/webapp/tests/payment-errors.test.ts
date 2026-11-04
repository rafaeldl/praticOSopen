// pay.errors.text: every Asaas and nota code the app turns into a sentence
// (lib/screens/payments/asaas_error_text.dart) has a sentence on the web too,
// never the generic "algo deu errado".
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, test } from 'vitest'
import { ApiError, codeMessageKey } from '../src/lib/api'
import { chargeErrorKey } from '../src/lib/receive/data'

const dart = readFileSync(resolve(__dirname, '../../../lib/screens/payments/asaas_error_text.dart'), 'utf8')
const codes = [...dart.matchAll(/case '([A-Z_]+)':/g)].map((match) => match[1] as string)
// The web's own words for the same thing: the request never answered (NETWORK) is its own state.
const WEB_ONLY = new Set(['NETWORK_ERROR'])

describe('erros do Asaas e da nota (pay.errors.text)', () => {
  test('lê os códigos do app', () => {
    expect(codes.length).toBeGreaterThanOrEqual(35)
  })
  test.each(codes.filter((code) => !WEB_ONLY.has(code)))('%s tem frase própria', (code) => {
    const key = codeMessageKey(code) ?? chargeErrorKey(new ApiError(code, 400, 'web.error.validation'))
    expect(key).not.toBe('web.error.generic')
    expect(key).not.toBe('web.error.validation')
  })
})
