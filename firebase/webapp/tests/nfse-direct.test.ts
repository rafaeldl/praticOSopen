import { describe, expect, test } from 'vitest'
import { codeMessageKey } from '../src/lib/api'
import { certificateFileProblem, certificateState, daysLeft, defaultEmitterId, emitterOf, fileToBase64, settingsOf, stylePreview } from '../src/lib/nfse/direct'
import { nfseApiBaseUrl } from '../src/lib/session'

const now = new Date('2026-11-05T12:00:00Z')
const emitter = (id: string, certificate: Record<string, unknown> | null = { notAfter: '2027-03-12T00:00:00Z', status: 'active' }) =>
  emitterOf(id, { legalName: id.toUpperCase(), taxId: '00000000000191', regime: 'mei', certificate })

describe('NFS-e direta: emitentes (nfse.direct.*)', () => {
  test('lê o emitente com o que falta como vazio', () => {
    const e = emitterOf('e1', { legalName: 'OFICINA', regime: 'simples', certificate: { notAfter: '2027-03-12T00:00:00Z', status: 'active', uploadedBy: { name: 'Rafael' } } })
    expect(e.regime).toBe('simples')
    expect(e.service).toBeNull()
    expect(e.descriptionStyle).toEqual({ uppercase: false, separator: ', ' })
    expect(e.certificate?.uploadedBy).toBe('Rafael')
  })

  test('situação do certificado: vale, vence em menos de 30 dias, vencido, sem', () => {
    expect(certificateState(emitter('a'), now)).toBe('valid')
    const soon = emitter('b', { notAfter: '2026-11-12T12:00:00Z', status: 'active' })
    expect(certificateState(soon, now)).toBe('expiring')
    expect(daysLeft(soon, now)).toBe(7)
    expect(certificateState(emitter('c', { notAfter: '2026-11-01T00:00:00Z', status: 'active' }), now)).toBe('expired')
    expect(certificateState(emitter('d', { notAfter: '2027-03-12T00:00:00Z', status: 'deleted' }), now)).toBe('missing')
    expect(certificateState(emitter('e', null), now)).toBe('missing')
  })

  test('padrão: o da configuração, senão o único', () => {
    expect(defaultEmitterId([emitter('a'), emitter('b')], settingsOf({ defaultEmitterId: 'b' }))).toBe('b')
    expect(defaultEmitterId([emitter('a'), emitter('b')], settingsOf({ defaultEmitterId: 'x' }))).toBeNull()
    expect(defaultEmitterId([emitter('a')], settingsOf(undefined))).toBe('a')
  })

  test('emissão automática do Asaas lê como "Nunca"', () => {
    expect(settingsOf({ autoIssue: 'paid' }).autoIssue).toBe('never')
    expect(settingsOf({ autoIssue: 'allOrders' }).autoIssue).toBe('allOrders')
  })

  test('estilo da descrição', () => {
    expect(stylePreview({ uppercase: true, separator: ' - ' }, ['Troca de óleo', 'Alinhamento'])).toBe('TROCA DE ÓLEO - ALINHAMENTO')
  })

  test('arquivo do certificado: só .pfx/.p12 e pequeno', () => {
    expect(certificateFileProblem({ name: 'oficina.pfx', size: 3000 })).toBeNull()
    expect(certificateFileProblem({ name: 'OFICINA.P12', size: 3000 })).toBeNull()
    expect(certificateFileProblem({ name: 'foto.png', size: 3000 })).toBe('type')
    expect(certificateFileProblem({ name: 'grande.pfx', size: 200_000 })).toBe('size')
  })

  test('arquivo vira base64 sem passar por texto', async () => {
    expect(await fileToBase64(new Blob([new Uint8Array([1, 2, 255])]))).toBe('AQL/')
  })

  test('recusas do certificado têm frase própria', () => {
    expect(codeMessageKey('CERT_WRONG_PASSWORD')).toBe('nfseDirectErrorWrongPassword')
    expect(codeMessageKey('EMITTER_ALREADY_EXISTS')).toBe('nfseDirectErrorAlreadyExists')
  })

  test('a nfseApi fica ao lado da api', () => {
    expect(nfseApiBaseUrl('https://southamerica-east1-praticos.cloudfunctions.net/api')).toBe('https://southamerica-east1-praticos.cloudfunctions.net/nfseApi')
  })
})
