import { createRoot } from 'react-dom/client'
import { WebScene, type WebCopy } from './WebScene'

// Mounts the computer section's scene:
//   <div data-stage="web"><script type="application/json">{copy}</script></div>
// The copy comes from homepage.json (webApp.scene), so pt, en and es share it.

for (const host of document.querySelectorAll<HTMLElement>('[data-stage="web"]')) {
  const data = host.querySelector('script[type="application/json"]')
  if (!data?.textContent) continue
  const copy = JSON.parse(data.textContent) as WebCopy
  const root = document.createElement('div')
  host.append(root)
  createRoot(root).render(<WebScene copy={copy} />)
}
