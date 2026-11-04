import { describe, expect, test } from 'vitest'
import { attachmentProblem, attachmentsOf, fileSizeParts, isPaymentProof, normalizeOrder } from '../src/lib/orders/model'

describe('documentos da OS (order.document.open)', () => {
  test('lista só os documentos, nunca o comprovante ligado a um pagamento, e só link http(s)', () => {
    const list = attachmentsOf([
      { id: 'a', url: 'https://x/a.pdf', type: 'invoice', fileName: 'nota.pdf', fileSize: 2048 },
      { id: 'b', url: 'https://x/b.pdf', type: 'receipt', linkedTransactionId: 'tx1' },
      { id: 'c', url: 'javascript:alert(1)', type: 'other' },
      { id: 'd', url: 'https://x/d.png', type: 'estranho' },
      null,
    ])
    expect(list.map((d) => [d.id, d.type])).toEqual([
      ['a', 'invoice'],
      ['d', 'other'],
    ])
  })

  test('vale para quem não vê valores (a OS da API traz só os documentos)', () => {
    const order = normalizeOrder('o', { documents: [{ id: 'a', url: 'https://x/a.pdf', type: 'warranty' }] }, false)
    expect(order.attachments.map((d) => d.id)).toEqual(['a'])
    expect(order.documents).toBeUndefined()
  })

  test('aceita imagem, PDF e Word abaixo de 10 MB, como o Storage', () => {
    expect(attachmentProblem({ type: 'application/pdf', size: 1000 })).toBeNull()
    expect(attachmentProblem({ type: 'image/png', size: 1000 })).toBeNull()
    expect(attachmentProblem({ type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', size: 1000 })).toBeNull()
    expect(attachmentProblem({ type: 'application/zip', size: 1000 })).toBe('type')
    expect(attachmentProblem({ type: 'application/pdf', size: 10 * 1024 * 1024 })).toBe('size')
  })

  test('tamanho em B, KB e MB', () => {
    expect(fileSizeParts(500)).toEqual({ value: 500, unit: 'B' })
    expect(fileSizeParts(2048)).toEqual({ value: 2, unit: 'KB' })
    expect(fileSizeParts(1.45 * 1024 * 1024)).toEqual({ value: 1.5, unit: 'MB' })
    expect(fileSizeParts(undefined)).toBeNull()
  })
})

describe('uma regra só para "é comprovante" (B2)', () => {
  test('comprovante = tipo receipt ou ligado a pagamento: some para quem não vê valores, como no servidor', () => {
    const docs = [
      { id: 'nf', url: 'https://x/nf.pdf', type: 'invoice' },
      { id: 'cp', url: 'https://x/cp.pdf', type: 'receipt' },
      { id: 'pr', url: 'https://x/pr.pdf', type: 'other', linkedTransactionId: 'tx1' },
    ]
    expect(attachmentsOf(docs, false).map((d) => d.id)).toEqual(['nf'])
    // Who sees values also sees a "Comprovante" attached by hand; a proof of a payment stays in "Já recebido".
    expect(attachmentsOf(docs, true).map((d) => d.id)).toEqual(['nf', 'cp'])
    expect(isPaymentProof({ type: 'receipt' })).toBe(true)
    expect(isPaymentProof({ linkedTransactionId: 'x' })).toBe(true)
    expect(isPaymentProof({ type: 'warranty' })).toBe(false)
  })
})
