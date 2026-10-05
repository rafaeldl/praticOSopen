# Design — PraticOS site

The locked design system for the institutional site (`firebase/hosting/src`).
Every page reads this file before emitting code. Extend or amend it here; never
override it per page.

Out of scope: `src/order/` (customer share view `/q/{token}`) and `src/login.njk`.
They belong to the app and still load the legacy `style.css` — do not touch.

## Idea

The site looks like the thing it sells: a **work order**. Light paper, graphite
ink, form rules, mono figures. The brand blue is a signal, the logo yellow is a
highlighter. No gradients, no orbs, no glass, no icon-tile card grids.

## Genre
modern-minimal (custom theme "Ordem de Serviço")

## Macrostructure family
- **Marketing pages** (home, segments, feature pages): Narrative Workflow —
  the life of a work order in numbered stages. Segments may swap stage content
  for their trade and add a problem → solution split (Split Studio rows).
- **Pricing**: plan sheet (one ruled table, three columns) + tabular spec sheet
  for the comparison + conversational FAQ.
- **Content pages** (docs, FAQ, support, legal): Long Document — single column,
  60–65ch measure, sticky "Nesta página" index on wide screens, no hero art.

## Theme
Tokens live in `src/css/tokens.css`. Light is the default; dark follows the OS
or the saved toggle (`html[data-theme="dark"]`).

- `--color-paper`   oklch(97.5% 0.006 85)
- `--color-paper-2` oklch(95% 0.008 85)
- `--color-ink`     oklch(21% 0.016 255)
- `--color-muted`   oklch(40% 0.014 255)
- `--color-rule`    oklch(86% 0.010 85)
- `--color-accent`  oklch(52% 0.14 250) — brand blue, text-safe
- `--color-marker`  oklch(92% 0.17 102) — logo yellow, highlighter only
- `--color-focus`   oklch(55% 0.18 250)

## Typography
- Display: **Archivo** 800 (700/900 available), roman only, tracking −0.025em
- Body: **IBM Plex Sans** 400 / 600
- Mono: **IBM Plex Mono** 400/500 — numbers, prices, OS numbers, labels
- `--text-display` = clamp(2.6rem, 1.6rem + 4.4vw, 4.75rem); hero ≤ 50 chars
- Labels: mono, 13px, uppercase, 0.06em tracking. No eyebrows over every
  heading — labels are for form fields, tables and ordinal stages only.

## Spacing
4-point named scale in `tokens.css` (`--space-3xs` … `--space-3xl`). Pages use
tokens, never raw values. Page width `--page-max` 74rem, gutter `--page-gutter`.

## Shared building blocks (`src/css/site.css`)
- `.wrap`, `.section`, `.section--alt`, `.section-head` (2px ink rule on top,
  h2 left + lede right on wide screens)
- `.btn` + `--primary` (ink fill → blue on hover) · `--secondary` (outline) ·
  `--whatsapp` · `--text` · `--sm`; `.btn-row`
- `.shot` — real app screenshot, hairline border, no fake device chrome;
  light/dark pairs via `.theme-light` / `.theme-dark`
- `.mark` — highlighter on **one** phrase per page
- `.label`, `.mono`, `.lede`, `.prose`, `a.link`
- `.cta-final` — the closing ink band with store buttons (`components/download.njk`)
- Nav N1b (`partials/navbar.njk`), footer Ft4 (`partials/footer.njk`)

## Motion
- Easings `--ease-out` / `--ease-in` / `--ease-in-out`; 160–240 ms.
- No scroll reveals. Hover/focus/press only. Reduced motion collapses all.

## Microinteractions stance
- Silent success; no toasts, no confetti.
- `:focus-visible` ring always instant.
- Dropdowns open on hover, focus and click; Escape closes.

## CTA voice
- Primary: "Baixar grátis" / "Download free" / "Descargar gratis" → `#baixar`
  (home) — subscriptions happen inside the app.
- Secondary: outline, verb + object ("Ver como funciona", "Comparar planos").
- Rectangular, 6px radius. Never pill-shaped except the WhatsApp float.

## Copy rules
- Speak to the technician/shop owner: concrete jobs (orçamento, foto, link,
  pagamento), no "poderoso", "intuitivo", "eficiente", "solução completa".
- No invented numbers (users, ratings, conversion). No fake testimonials.
- Feature flags in `site.json`: `flags.whatsappBot` (assistant pages/sections,
  currently **off** — bot is shut down), `flags.whatsappContact` (float button).
- pt-BR, en, es always updated together.

## Per-page allowances
- Marketing pages MAY use the sample work-order ticket (Tier-A HTML/CSS) and
  real screenshots. No stock photos, no illustrations.
- Content pages: typography only; tables and callouts use rules, not cards.

## What pages MUST share
Wordmark, tokens, fonts, CTA voice, section-head rule, nav, footer.

## What pages MAY differ on
Macrostructure within their family, ordering of sections, whether a page shows
the ticket.
