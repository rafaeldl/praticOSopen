import { ChevronLeft } from 'lucide-react'
import { Stage } from '../../kit/stage'
import type { Act } from '../../kit/act'
import type { Point } from '../../kit/measure'
import { Phone } from '../../kit/phone'
import { Window } from '../../kit/window'
import { States } from '../../kit/motion/States'
import { Collapse } from '../../kit/motion/Collapse'
import { Roll } from '../../kit/motion/Roll'
import '../hero/hero.css'
import '../tabs/tabs.css'
import './web.css'

// The home's "Também no computador": a window and a phone telling one event
// (device-pair). The web app's Início, on its board (Quadro), sits top right
// and runs off the bottom; the phone stands over the window's sidebar, the
// filler, never over the board.
// Beats: the cursor drags order 186 from "Em andamento" to "Concluída"; the
// card lands at the top of the column; a beat later the same order on the
// phone turns "Concluída". Plays once and holds the end (the poster).
// Narrow, the sidebar and the first column go: the window runs off the
// right, the phone stands over the board's empty foot.
//
// Real strings: the web app's menu, title, summary, button, view switch and
// column names (firebase/webapp, OrderBoard.vue), the moving card, the
// phone's order. The other cards are filler with plausible names.

type Card = { who: string; num: string; sub: string; money: string }
export type WebCopy = {
  label: string
  url: string
  nav: string[]
  title: string
  summary: string
  newOrder: string
  views: [string, string]
  columns: { name: string; tone: 'accent' | 'warning' | 'success'; cards: Card[] }[]
  phone: { back: string; title: string; client: string; device: string; from: string; to: string; items: { name: string; price: string }[]; totalLabel: string; total: string }
}

// Column 1 is "Em andamento"; its first card is the one that moves to column 2
const FROM = 1
const TO = 2

// One card element moves the whole way (never swapped): it sits over an
// empty slot in "Em andamento", follows the hand, and settles over a slot in
// "Concluída" that opened under it while it hovered; then the old slot closes.
type S = { moved: boolean; lifted: boolean; at: Point | null; over: boolean; phoneDone: boolean }
const START: S = { moved: false, lifted: false, at: null, over: false, phoneDone: false }
const END: S = { moved: true, lifted: false, at: null, over: false, phoneDone: true }

async function script(a: Act<S>) {
  await a.wait(900)
  const card = a.rect('slot-from', { layout: true })
  // The landing slot opens where the column's first card is now
  const to = a.rect('to-first', { layout: true })
  const grab = { x: card.x + card.width * 0.42, y: card.y + 16 }
  const off = { x: grab.x - card.x, y: grab.y - card.y }
  a.mark('grab')
  await a.move(grab)
  await a.drag(
    { x: to.x + off.x, y: to.y + off.y },
    (p) => {
      const at = { x: p.x - off.x, y: p.y - off.y }
      a.put({ lifted: true, at, over: at.x + card.width / 2 > to.x })
    },
    { duration: 1150 },
  )
  a.mark('drop')
  await a.set({ lifted: false, at: null, moved: true, over: false })
  await a.wait(650)
  a.mark('phone')
  a.put({ phoneDone: true })
  await a.wait(500)
  await a.move('rest')
  await a.wait(2600)
}

function CardBody({ c }: { c: Card }) {
  return (
    <>
      <span className="wb-card__top">
        <strong>{c.who}</strong>
        <span className="wb-num">{c.num}</span>
      </span>
      <span className="wb-card__sub">{c.sub}</span>
      <span className="wb-num wb-card__money">{c.money}</span>
    </>
  )
}

export function WebScene({ copy }: { copy: WebCopy }) {
  const mover = copy.columns[FROM].cards[0]
  return (
    <Stage<S>
      width={680}
      height={460}
      compact={{ below: 560, width: 358, height: 600 }}
      initial={START}
      poster={END}
      script={script}
      play="once"
      cursor={{ at: 'rest' }}
      className="ph-hero ph-tab wb"
    >
      {(s, rect, layout) => {
        const narrow = layout === 'compact'
        return (
          <>
            <Window url={copy.url} className="wb-window" aria-label={copy.label}>
              <div className="wb-app">
                {!narrow && (
                  <aside className="wb-side">
                    <span className="wb-logo">PraticOS</span>
                    {copy.nav.map((n, i) => (
                      <span key={n} className="wb-nav" data-on={i === 0 || undefined}>
                        {n}
                      </span>
                    ))}
                  </aside>
                )}
                <div className="wb-main">
                  <div className="wb-head">
                    <div>
                      <div className="wb-title">{copy.title}</div>
                      <div className="wb-summary">{copy.summary}</div>
                    </div>
                    <span className="wb-new">{copy.newOrder}</span>
                  </div>
                  <div className="wb-views">
                    <span>{copy.views[0]}</span>
                    <span data-on>{copy.views[1]}</span>
                  </div>
                  <div className="wb-board">
                    {copy.columns.map((col, ci) => {
                      if (narrow && ci === 0) return null
                      const rest = ci === FROM ? col.cards.slice(1) : col.cards
                      const count = rest.length + ((ci === FROM && !s.moved) || (ci === TO && s.moved) ? 1 : 0)
                      return (
                        <section key={col.name} className="wb-col" data-over={(ci === TO && s.over) || undefined}>
                          <div className="wb-col__head">
                            <span className={`wb-dot wb-dot--${col.tone}`} />
                            {col.name}
                            <span className="wb-num wb-col__count">
                              <Roll>{String(count)}</Roll>
                            </span>
                          </div>
                          <div className="wb-list">
                            {ci === FROM && (
                              <Collapse open={!s.moved}>
                                <div className="wb-slot" data-target="slot-from" data-empty={(s.at && !s.moved) || undefined} />
                              </Collapse>
                            )}
                            {ci === TO && (
                              <Collapse open={s.over || s.moved}>
                                <div className="wb-slot" data-target="slot-to" data-empty={!s.moved || undefined} />
                              </Collapse>
                            )}
                            {rest.map((c, i) => (
                              <div key={c.num} className="wb-card" data-target={ci === TO && i === 0 ? 'to-first' : undefined}>
                                <CardBody c={c} />
                              </div>
                            ))}
                          </div>
                        </section>
                      )
                    })}
                  </div>
                </div>
              </div>
            </Window>

            {(() => {
              const home = rect(s.moved ? 'slot-to' : 'slot-from')
              const at = s.at ?? home
              return (
                <div
                  className="wb-card wb-mover"
                  data-lifted={s.lifted || undefined}
                  data-landed={(s.moved && !s.at) || undefined}
                  style={{ translate: `${at.x}px ${at.y}px`, width: home.width || undefined, visibility: home.width ? undefined : 'hidden' }}
                >
                  <CardBody c={mover} />
                </div>
              )
            })()}

            <Phone width={narrow ? 240 : 222} className="ph-phone wb-phone" aria-hidden>
              <div className="ph-screen">
                <div className="ph-nav">
                  <span className="ph-back">
                    <ChevronLeft size={16} strokeWidth={2.6} />
                    {copy.phone.back}
                  </span>
                </div>
                <div className="ph-large">{copy.phone.title}</div>
                <div className="ph-head">
                  <div className="ph-head__client">{copy.phone.client}</div>
                  <div className="wb-device">{copy.phone.device}</div>
                  <div className="wb-status" data-done={s.phoneDone || undefined}>
                    <span className="ph-dot" />
                    <States
                      align="start"
                      value={s.phoneDone ? 'to' : 'from'}
                      states={{ from: <span>{copy.phone.from}</span>, to: <span>{copy.phone.to}</span> }}
                    />
                  </div>
                </div>
                <div className="ph-card wb-items">
                  {copy.phone.items.map((it) => (
                    <div key={it.name} className="ph-row">
                      <span>{it.name}</span>
                      <span className="ph-price">{it.price}</span>
                    </div>
                  ))}
                  <div className="ph-row ph-row--total">
                    <span>{copy.phone.totalLabel}</span>
                    <span className="ph-price">{copy.phone.total}</span>
                  </div>
                </div>
              </div>
            </Phone>

            <span data-target="rest" className="wb-rest" style={narrow ? { left: 320, top: 250 } : { left: 640, top: 420 }} />
          </>
        )
      }}
    </Stage>
  )
}
