import { Camera, Car, Check, ChevronLeft, ChevronRight, Lock, User } from 'lucide-react'
import { Stage } from '../../kit/stage'
import { Phone, Notification } from '../../kit/phone'
import '../hero/hero.css'
import './tabs.css'

// Stills for the home's "Como funciona" tabs, one app screen per tab, each a
// different moment from the hero above them (craft.md, A page of demos):
// talk: a spoken correction changes one price and the total;
// record: the check-in checklist with photos of the damage;
// approve: the customer's phone, the order in the browser, the approve button;
// schedule: the week in Agenda with the reminder banner dropping in;
// receive: Financeiro, who owes what, oldest first, and the button to charge.
//
// Every scene is one iPhone running off the bottom of the panel, at the
// size it is seen. Words only where the tab's story is; the rest is the
// app's own quiet chrome.

type Item = { name: string; price: string; changed?: boolean }

export type TalkCopy = { kind: 'talk'; label: string; title: string; client: string; vehicle: string; work: string; items: Item[]; totalLabel: string; total: string; said: string }
export type RecordCopy = { kind: 'record'; label: string; back: string; title: string; progress: string; items: { q: string; a: string; photos?: number }[]; add: string }
export type ApproveCopy = { kind: 'approve'; label: string; url: string; title: string; client: string; status: string; line: string; items: Item[]; totalLabel: string; total: string; button: string; comment: string }
export type ScheduleCopy = {
  kind: 'schedule'
  label: string
  title: string
  month: string
  days: string[]
  dates: string[]
  pick: number
  dots: number[]
  dayLine: string
  rows: { name: string; time: string; status: string; kind: 'approved' | 'quote'; sub: string }[]
  notifyTitle: string
  notifyBody: string
  now: string
  icon?: string
}
export type ReceiveCopy = { kind: 'receive'; label: string; title: string; next: string; nextSub: string; button: string; section: string; rows: { name: string; amount: string; sub: string }[] }
export type TabCopy = TalkCopy | RecordCopy | ApproveCopy | ScheduleCopy | ReceiveCopy

function Spark() {
  return (
    <span className="ph-spark" aria-hidden>
      ✦
    </span>
  )
}

function Frame({ label, kind, children, top }: { label: string; kind: string; children: React.ReactNode; top?: React.ReactNode }) {
  return (
    <Stage width={420} height={520} compact={{ below: 400, width: 358, height: 460 }} className={`ph-hero ph-tab ph-tab--${kind}`}>
      {(_s, _r, layout) => (
        <>
          <Phone width={layout === 'compact' ? 304 : 360} className="ph-phone" aria-label={label}>
            <div className="ph-screen">{children}</div>
          </Phone>
          {top}
        </>
      )}
    </Stage>
  )
}

function Talk({ c }: { c: TalkCopy }) {
  return (
    <Frame
      label={c.label}
      kind="talk"
      top={<div className="ph-said">{c.said}</div>}
    >
      <div className="ph-top">
        <span className="ph-round" aria-hidden>
          <ChevronLeft size={18} strokeWidth={2.2} />
        </span>
        <div className="ph-title">{c.title}</div>
        <span className="ph-round ph-save" data-on aria-hidden>
          <Check size={18} strokeWidth={2.6} />
        </span>
      </div>
      <div className="ph-card">
        <div className="ph-row">
          <span className="ph-ico">
            <User size={18} strokeWidth={2} />
          </span>
          <span className="ph-val">
            {c.client}
            <Spark />
          </span>
        </div>
        <div className="ph-row">
          <span className="ph-ico">
            <Car size={18} strokeWidth={2} />
          </span>
          <span className="ph-val">
            {c.vehicle}
            <Spark />
          </span>
        </div>
      </div>
      <section className="ph-sec">
        <div className="ph-label">{c.work}</div>
        <div className="ph-card">
          {c.items.map((it) => (
            <div key={it.name} className="ph-row ph-row--item" data-changed={it.changed || undefined}>
              <span className="ph-val">
                {it.name}
                <Spark />
              </span>
              <span className="ph-price">{it.price}</span>
            </div>
          ))}
          <div className="ph-row ph-row--total">
            <span>{c.totalLabel}</span>
            <span className="ph-price">{c.total}</span>
          </div>
        </div>
      </section>
    </Frame>
  )
}

function Record({ c }: { c: RecordCopy }) {
  return (
    <Frame label={c.label} kind="record">
      <div className="ph-nav">
        <span className="ph-back">
          <ChevronLeft size={16} strokeWidth={2.6} />
          {c.back}
        </span>
      </div>
      <div className="ph-large">{c.title}</div>
      <div className="ph-subtitle">{c.progress}</div>
      <div className="ph-card">
        {c.items.map((it, i) => (
          <div key={it.q} className="ph-row ph-row--check" data-photos={it.photos || undefined}>
            <span className="ph-check__q">{it.q}</span>
            <span className="ph-check__a" data-flag={i === 0 || undefined}>
              {it.a}
            </span>
            {it.photos ? (
              <span className="ph-check__photos">
                {Array.from({ length: it.photos }, (_, k) => (
                  <span key={k} className={`ph-shot ph-shot--${k}`} />
                ))}
                <span className="ph-shot ph-shot--add" aria-hidden>
                  <Camera size={18} strokeWidth={2} />
                </span>
              </span>
            ) : null}
          </div>
        ))}
      </div>
    </Frame>
  )
}

function Approve({ c }: { c: ApproveCopy }) {
  return (
    <Frame label={c.label} kind="approve">
      <div className="ph-url">
        <Lock size={12} strokeWidth={2.4} />
        {c.url}
      </div>
      <div className="ph-page">
        <div className="ph-page__title">{c.title}</div>
        <div className="ph-page__client">{c.client}</div>
        <div className="ph-status">
          <span className="ph-dot" />
          {c.status} · {c.line}
        </div>
        <span className="ph-primary">{c.button}</span>
        <div className="ph-card ph-card--flat">
          {c.items.map((it) => (
            <div key={it.name} className="ph-row ph-row--item">
              <span>{it.name}</span>
              <span className="ph-price">{it.price}</span>
            </div>
          ))}
          <div className="ph-row ph-row--total">
            <span>{c.totalLabel}</span>
            <span className="ph-price">{c.total}</span>
          </div>
        </div>
        <span className="ph-link">{c.comment}</span>
      </div>
    </Frame>
  )
}

function Schedule({ c }: { c: ScheduleCopy }) {
  return (
    <Frame label={c.label} kind="schedule">
      <Notification
        banner
        className="ph-banner"
        icon={c.icon ? <img src={c.icon} alt="" width={38} height={38} /> : undefined}
        title={c.notifyTitle}
        body={c.notifyBody}
        time={c.now}
      />
      <div className="ph-large ph-large--top">{c.title}</div>
      <div className="ph-month">
        <ChevronLeft size={18} strokeWidth={2.2} />
        <span>{c.month}</span>
        <ChevronRight size={18} strokeWidth={2.2} />
      </div>
      <div className="ph-week">
        {c.days.map((d, i) => (
          <span key={i} className="ph-day" data-pick={i === c.pick || undefined}>
            <span className="ph-day__w">{d}</span>
            <span className="ph-day__n">{c.dates[i]}</span>
            <span className="ph-day__dot" data-on={c.dots.includes(i) || undefined} />
          </span>
        ))}
      </div>
      <div className="ph-dayline">{c.dayLine}</div>
      <div className="ph-list">
        {c.rows.map((r) => (
          <div key={r.name} className="ph-agenda">
            <div className="ph-agenda__head">
              <span className="ph-agenda__name">{r.name}</span>
              <span className="ph-agenda__time">{r.time}</span>
            </div>
            <div className="ph-agenda__status" data-kind={r.kind}>
              <span className="ph-dot" />
              {r.status}
            </div>
            <div className="ph-agenda__sub">{r.sub}</div>
          </div>
        ))}
      </div>
    </Frame>
  )
}

function Receive({ c }: { c: ReceiveCopy }) {
  return (
    <Frame label={c.label} kind="receive">
      <div className="ph-large ph-large--top">{c.title}</div>
      <div className="ph-next">
        <div className="ph-next__line">{c.next}</div>
        <div className="ph-next__sub">{c.nextSub}</div>
        <span className="ph-primary">{c.button}</span>
      </div>
      <div className="ph-label">{c.section}</div>
      <div className="ph-list">
        {c.rows.map((r) => (
          <div key={r.name} className="ph-money">
            <div className="ph-money__head">
              <span>{r.name}</span>
              <span className="ph-price">{r.amount}</span>
            </div>
            <div className="ph-money__sub">{r.sub}</div>
          </div>
        ))}
      </div>
    </Frame>
  )
}

export function TabScene({ copy }: { copy: TabCopy }) {
  switch (copy.kind) {
    case 'talk':
      return <Talk c={copy} />
    case 'record':
      return <Record c={copy} />
    case 'approve':
      return <Approve c={copy} />
    case 'schedule':
      return <Schedule c={copy} />
    case 'receive':
      return <Receive c={copy} />
  }
}
