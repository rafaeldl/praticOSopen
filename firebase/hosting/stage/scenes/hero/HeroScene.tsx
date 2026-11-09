import { Camera, Check, ChevronRight, Clock, Mic, Square, User, X } from 'lucide-react'
// Import each part from its own file: the kit's index pulls every part's CSS
import { Stage } from '../../kit/stage'
import type { Act } from '../../kit/act'
import { Phone } from '../../kit/phone'
import { Bar } from '../../kit/window'
import { Collapse } from '../../kit/motion/Collapse'
import { Roll } from '../../kit/motion/Roll'
import { States } from '../../kit/motion/States'
import { Stream } from '../../kit/motion/Stream'
import { Toast } from '../../kit/parts/Toast'
import { DeviceIcon } from '../shared/DeviceIcon'
import './hero.css'

// The home hero: you speak, PraticOS writes the work order.
//
// One iPhone with the app's real "Nova OS" sheet, cropped at the top so the
// sheet's cards and the assistant bar at the foot carry the story. Beats:
// 1. The empty sheet (context) and a tap on "Falar".
// 2. The bar turns into "Ouvindo…" with its wave; what was said streams into
//    the opaque card above it, word by word.
// 3. A tap on stop: the customer and the vehicle land in their card, then the
//    two services drop in one by one, each carrying the total down with it,
//    the total rolling a beat after each row lands. Every field the assistant
//    filled carries the app's blue ✦.
// 4. The notice "Preenchido pela IA · Desfazer" rises over the bar and the
//    save check turns blue (payoff). Plays once; the host offers "Ver de novo".
//
// Real strings: the transcript, the customer, the vehicle, the two services
// and their prices, the total, the notice. The photos card is filler.

export type HeroCopy = {
  label: string
  title: string
  client: string
  clientEmpty: string
  vehicle: string
  vehicleEmpty: string
  /** The second row's icon, by trade (shared/DeviceIcon); the car by default. */
  deviceIcon?: string
  work: string
  add: string
  due: string
  request: string
  requestHint: string
  photos: string
  photo: string
  talk: string
  listening: string
  line: string
  items: { name: string; price: string }[]
  totalLabel: string
  /** The total after each item lands, the first being before any item. */
  totals: string[]
  filled: string
  undo: string
}

type Phase = 'idle' | 'listening' | 'done'
type S = { phase: Phase; words: number; heard: boolean; client: boolean; items: number; notice: boolean }

const START: S = { phase: 'idle', words: 0, heard: false, client: false, items: 0, notice: false }

const words = (line: string) => line.split(' ').length

function makeScript(copy: HeroCopy) {
  const n = words(copy.line)
  return async (a: Act<S>) => {
    await a.wait(900)
    a.mark('talk')
    await a.click('talk')
    a.put({ phase: 'listening', heard: true })
    await a.wait(700)
    a.mark('heard')
    for (let i = 1; i <= n; i++) {
      a.put({ words: i })
      // Speech, not a model: a little slower than streaming text
      await a.wait(150)
    }
    await a.wait(800)
    a.mark('stop')
    await a.click('stop')
    a.put({ phase: 'done', heard: false })
    await a.wait(380)
    a.mark('fill')
    a.put({ client: true })
    await a.wait(520)
    for (let i = 1; i <= copy.items.length; i++) {
      a.put({ items: i })
      await a.wait(560)
    }
    await a.wait(300)
    a.mark('notice')
    a.put({ notice: true })
    await a.wait(3200)
  }
}

function Spark() {
  return (
    <span className="ph-spark" aria-hidden>
      ✦
    </span>
  )
}

function Wave() {
  return (
    <span className="ph-wave" aria-hidden>
      {Array.from({ length: 14 }, (_, i) => (
        <i key={i} style={{ animationDelay: `${(i * 97) % 520}ms` }} />
      ))}
    </span>
  )
}

// short: only the customer and the services, on a shorter screen, for the
// hero over the trade photos (no request, photos or due-date cards)
export function HeroScene({ copy, short = false }: { copy: HeroCopy; short?: boolean }) {
  const all = copy.items.length
  const poster: S = { phase: 'done', words: words(copy.line), heard: false, client: true, items: all, notice: true }
  return (
    <Stage<S>
      width={short ? 400 : 560}
      height={short ? 506 : 664}
      compact={short ? undefined : { below: 520, width: 358, height: 608 }}
      initial={START}
      poster={poster}
      script={makeScript(copy)}
      play="once"
      cursor={{ at: { x: 470, y: 700 }, style: 'touch' }}
      className={short ? 'ph-hero ph-hero--short' : 'ph-hero'}
    >
      {(s, _rect, layout) => {
        return (
          <Phone width={short ? 360 : layout === 'compact' ? 330 : 360} className="ph-phone" aria-label={copy.label}>
            <div className="ph-screen">
              <div className="ph-scroll">
              <div className="ph-top">
                <span className="ph-round" aria-hidden>
                  <X size={18} strokeWidth={2.2} />
                </span>
                <div className="ph-title">{copy.title}</div>
                <span className="ph-round ph-save" data-on={s.notice || undefined} aria-hidden>
                  <Check size={18} strokeWidth={2.6} />
                </span>
              </div>

              <div className="ph-card">
                <div className="ph-row">
                  <span className="ph-ico">
                    <User size={18} strokeWidth={2} />
                  </span>
                  <States
                    align="start"
                    value={s.client ? 'on' : 'off'}
                    states={{
                      off: <span className="ph-empty">{copy.clientEmpty}</span>,
                      on: (
                        <span className="ph-val">
                          {copy.client}
                          <Spark />
                        </span>
                      ),
                    }}
                  />
                </div>
                <div className="ph-row">
                  <span className="ph-ico">
                    <DeviceIcon name={copy.deviceIcon} />
                  </span>
                  <States
                    align="start"
                    value={s.client ? 'on' : 'off'}
                    states={{
                      off: <span className="ph-empty">{copy.vehicleEmpty}</span>,
                      on: (
                        <span className="ph-val">
                          {copy.vehicle}
                          <Spark />
                        </span>
                      ),
                    }}
                  />
                </div>
              </div>

              <section className="ph-sec">
              <div className="ph-label">{copy.work}</div>
              <div className="ph-card">
                {copy.items.map((item, i) => (
                  <Collapse key={item.name} open={s.items > i} reveal="drop">
                    <div className="ph-row ph-row--item">
                      <span className="ph-val">
                        {item.name}
                        <Spark />
                      </span>
                      <span className="ph-price">{item.price}</span>
                    </div>
                  </Collapse>
                ))}
                <Collapse open={s.items > 0}>
                  <div className="ph-row ph-row--total">
                    <span>{copy.totalLabel}</span>
                    <span className="ph-price">
                      <Roll delay={260}>{copy.totals[s.items] ?? copy.totals[0]}</Roll>
                    </span>
                  </div>
                </Collapse>
                <div className="ph-row ph-add"><span>{copy.add}</span></div>
              </div>
              </section>

              {!short && (<>
              <section className="ph-sec">
              <div className="ph-label">{copy.request}</div>
              <div className="ph-card"><div className="ph-row ph-request">{copy.requestHint}</div></div>
              </section>

              <section className="ph-sec">
              <div className="ph-label">{copy.photos}</div>
              <div className="ph-card ph-photos">
                {[0, 1, 2].map((i) => (
                  <span key={i} className={`ph-thumb ph-thumb--${i}`} />
                ))}
                <span className="ph-thumb ph-thumb--add">
                  <Bar w={22} h={22} r={11} tone={3} />
                </span>
              </div>

              <div className="ph-card">
                <div className="ph-row">
                  <span className="ph-ico">
                    <Clock size={18} strokeWidth={2} />
                  </span>
                  <span className="ph-grow">{copy.due}</span>
                  <ChevronRight size={18} strokeWidth={2} className="ph-chev" />
                </div>
              </div>
              </section>
              </>)}

              </div>
              {/* Foot: the transcript card, the notice, then the bar */}
              <div className="ph-foot">
                <div className="ph-heard" data-on={s.heard || undefined}>
                  <Stream text={copy.line} count={s.words} />
                </div>
                <Toast show={s.notice} className="ph-notice" icon={<span className="ph-spark">✦</span>} action={<span className="ph-undo">{copy.undo}</span>}>
                  {copy.filled}
                </Toast>
                <div className="ph-bar" data-phase={s.phase}>
                  <span className="ph-pill ph-pill--photo" data-hide={s.phase === 'listening' || undefined}>
                    <Camera size={18} strokeWidth={2} />
                    {copy.photo}
                  </span>
                  <span className="ph-pill ph-pill--talk" data-target="talk" data-listening={s.phase === 'listening' || undefined}>
                    <span className="ph-x" data-show={s.phase === 'listening' || undefined} aria-hidden>
                      <X size={15} strokeWidth={2.4} />
                    </span>
                    <States
                      value={s.phase === 'listening' ? 'listening' : 'talk'}
                      states={{
                        talk: (
                          <span className="ph-talk">
                            <Mic size={18} strokeWidth={2} />
                            {copy.talk}
                          </span>
                        ),
                        listening: (
                          <span className="ph-talk ph-talk--on">
                            <Wave />
                            {copy.listening}
                          </span>
                        ),
                      }}
                    />
                    <span className="ph-stop" data-target="stop" data-show={s.phase === 'listening' || undefined} aria-hidden>
                      <Square size={11} strokeWidth={0} fill="currentColor" />
                    </span>
                  </span>
                </div>
              </div>
            </div>
          </Phone>
        )
      }}
    </Stage>
  )
}
