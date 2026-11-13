import { describe, expect, test } from 'vitest'
import { cookiesPolicyUrl, legalUrl } from '../src/lib/legal-links'

describe('Termos e Política no idioma da tela', () => {
  test('português sem sufixo, inglês e espanhol com', () => {
    expect(legalUrl('terms', 'pt')).toBe('/terms.html')
    expect(legalUrl('privacy', 'en')).toBe('/privacy-en.html')
    expect(legalUrl('terms', 'es')).toBe('/terms-es.html')
  })

  test('o aviso de estatísticas abre a parte de cookies da política', () => {
    expect(cookiesPolicyUrl('pt')).toBe('/privacy.html#cookies-e-estatisticas-de-uso')
    expect(cookiesPolicyUrl('en')).toBe('/privacy-en.html#cookies-and-usage-statistics')
    expect(cookiesPolicyUrl('es')).toBe('/privacy-es.html#cookies-y-estadisticas-de-uso')
  })
})
