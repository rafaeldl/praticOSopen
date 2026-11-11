// Prints one sheet in a hidden iframe of its own (docs/WORK_STAGES.md,
// Imprimir). Safari printed the board's stage sheet blank when it had to lay
// out the whole app in print media; a document holding only the sheet prints
// the same on every browser and never depends on the app's theme.

const SHEET_CSS = `
  @page { margin: 12mm; }
  html, body { margin: 0; background: #fff; color: #000; }
  body { font: 12pt/1.35 -apple-system, "Helvetica Neue", Arial, sans-serif; }
  .print-sheet { display: block; color: #000; }
  .print-sheet h1 { font-size: 18pt; margin: 0.25rem 0; }
  .print-sheet p { margin: 0; }
  .print-sheet table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
  .print-sheet th, .print-sheet td { border-bottom: 1px solid #999; padding: 0.3rem; text-align: left; vertical-align: top; }
  .print-sheet tr { break-inside: avoid; }
  .stage-box { display: inline-block; width: 1.1rem; height: 1.1rem; border: 1.5px solid #000; }
`

/** The HTML document the iframe prints: the sheet alone with its own print styles. */
export function sheetDocument(sheetHtml: string, lang: string): string {
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><title></title><style>${SHEET_CSS}</style></head><body>${sheetHtml}</body></html>`
}

/** Prints `sheet` alone. Falls back to the page's own print when no iframe can be made. */
export function printSheet(sheet: Element): void {
  // The last sheet's frame stays (hidden) until the next print: removing it
  // right after print() cut the job short on Safari.
  document.querySelectorAll('[data-testid="print-frame"]').forEach((old) => old.remove())
  const frame = document.createElement('iframe')
  frame.setAttribute('aria-hidden', 'true')
  frame.setAttribute('data-testid', 'print-frame')
  frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden'
  document.body.appendChild(frame)
  const win = frame.contentWindow
  const doc = frame.contentDocument
  if (!win || !doc) {
    frame.remove()
    window.print()
    return
  }
  doc.open()
  doc.write(sheetDocument(sheet.outerHTML, document.documentElement.lang || 'pt-BR'))
  doc.close()
  // Safari needs the frame laid out and focused before print() goes to it.
  setTimeout(() => {
    win.focus()
    win.print()
  }, 50)
}
