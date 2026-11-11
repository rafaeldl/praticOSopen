import { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { HeroScene, type HeroCopy } from './HeroScene'

// Mounts the hero scene on the Eleventy page:
//   <div data-stage-wrap>
//     <div data-stage="hero"><script type="application/json">{copy}</script></div>
//     <button data-stage-replay hidden>Ver de novo</button>
//   </div>
// data-short draws the shorter screen (customer and services only).
// The page can hold more than one (the hero test variant and the Falar tab);
// each replay button sits next to its scene.
// The copy comes from homepage.json, so pt, en and es share one scene. The
// scene plays once; the replay button remounts it (kit.md, Explicit replay).

function Hero({ copy, replay, short }: { copy: HeroCopy; replay: HTMLButtonElement | null; short: boolean }) {
  const [run, setRun] = useState(0)
  useEffect(() => {
    if (!replay) return
    const again = () => setRun((n) => n + 1)
    replay.hidden = false
    replay.addEventListener('click', again)
    return () => replay.removeEventListener('click', again)
  }, [replay])
  return <HeroScene key={run} copy={copy} short={short} />
}

export function mountHero(host: HTMLElement) {
  const data = host.querySelector('script[type="application/json"]')
  if (!data?.textContent) return
  const copy = JSON.parse(data.textContent) as HeroCopy
  const replay = host.closest('[data-stage-wrap]')?.querySelector<HTMLButtonElement>('[data-stage-replay]') ?? null
  const root = document.createElement('div')
  host.append(root)
  createRoot(root).render(<Hero copy={copy} replay={replay} short={host.dataset.short !== undefined} />)
}

for (const host of document.querySelectorAll<HTMLElement>('[data-stage="hero"]')) mountHero(host)
