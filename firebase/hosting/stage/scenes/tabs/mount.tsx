import { createRoot } from 'react-dom/client'
import { TabScene, type TabCopy } from './TabScenes'

// Mounts every tab still on the page:
//   <div data-stage="tab"><script type="application/json">{copy}</script></div>
// A panel hidden by the tabs still mounts; the Stage measures on show.

export function mountTabs(root: ParentNode = document) {
  for (const host of root.querySelectorAll<HTMLElement>('[data-stage="tab"]')) {
    const data = host.querySelector('script[type="application/json"]')
    if (!data?.textContent || host.dataset.mounted) continue
    host.dataset.mounted = '1'
    const copy = JSON.parse(data.textContent) as TabCopy
    if (copy.kind === 'schedule' && host.dataset.icon) copy.icon = host.dataset.icon
    const el = document.createElement('div')
    host.append(el)
    createRoot(el).render(<TabScene copy={copy} />)
  }
}

mountTabs()
