// Text drawn in a PDF made by lib/pdf/order-pdf.ts, for the tests (vitest and
// Playwright). pdf-lib writes Helvetica text as hex WinAnsi strings inside
// Flate-compressed content streams; this inflates them and decodes the strings.
import { inflateSync } from 'node:zlib'

const WINANSI_EXTRA: Record<number, string> = {
  0x80: '€', 0x82: '‚', 0x83: 'ƒ', 0x84: '„', 0x85: '…', 0x86: '†', 0x87: '‡', 0x88: 'ˆ', 0x89: '‰', 0x8a: 'Š', 0x8b: '‹', 0x8c: 'Œ', 0x8e: 'Ž',
  0x91: '‘', 0x92: '’', 0x93: '“', 0x94: '”', 0x95: '•', 0x96: '–', 0x97: '—', 0x98: '˜', 0x99: '™', 0x9a: 'š', 0x9b: '›', 0x9c: 'œ', 0x9e: 'ž', 0x9f: 'Ÿ',
}

/** Every text run of the file, one per line, in drawing order. */
export function pdfText(bytes: Uint8Array): string {
  const buffer = Buffer.from(bytes)
  const raw = buffer.toString('latin1')
  const runs: string[] = []
  let at = 0
  for (;;) {
    const start = raw.indexOf('stream', at)
    if (start < 0) break
    const begin = raw[start + 6] === '\r' ? start + 8 : start + 7
    const end = raw.indexOf('endstream', begin)
    if (end < 0) break
    at = end + 9
    if (raw.slice(Math.max(0, start - 3), start) === 'end') continue
    let content: string
    try {
      content = inflateSync(buffer.subarray(begin, end)).toString('latin1')
    } catch {
      content = raw.slice(begin, end)
    }
    for (const match of content.matchAll(/<([0-9A-Fa-f]*)>\s*Tj/g)) {
      const hex = match[1] ?? ''
      let text = ''
      for (let i = 0; i < hex.length; i += 2) {
        const code = parseInt(hex.slice(i, i + 2), 16)
        text += WINANSI_EXTRA[code] ?? String.fromCharCode(code)
      }
      runs.push(text)
    }
  }
  // Money comes with a no-break space (Intl); tests compare with a plain one.
  return runs.join('\n').replace(/\u00a0/g, ' ')
}

/** Pages in the file (the /Type /Page objects). */
export function pdfPageCount(bytes: Uint8Array): number {
  return (Buffer.from(bytes).toString('latin1').match(/\/Type\s*\/Page(?!s)/g) ?? []).length
}
