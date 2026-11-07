import { describe, expect, test } from 'vitest'
import { sheetDocument } from '@/lib/print-frame'

describe('sheetDocument', () => {
  test('holds only the sheet, with black ink on white paper', () => {
    const html = sheetDocument('<article class="print-sheet">Pintura</article>', 'pt-BR')
    expect(html).toContain('<html lang="pt-BR">')
    expect(html).toContain('<body><article class="print-sheet">Pintura</article></body>')
    expect(html).toMatch(/\.print-sheet \{ display: block; color: #000; \}/)
    expect(html).not.toContain('var(--')
  })
})
