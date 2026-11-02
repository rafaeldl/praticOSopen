# Design — PraticOS site

The locked design system for the institutional site (`firebase/hosting/src`).
Every page reads this file before emitting code. Extend or amend it here; never
override it per page.

Out of scope: `src/order/` (customer share view `/q/{token}`) and `src/login.njk`.
They belong to the app and still load the legacy `style.css` — do not touch.

## Idea

The site shows the people it serves. Warm paper, navy ink and navy bands, solid
yellow actions, big type, and photos of people at work. The product moment is a
spoken request turning into a work order. No gradients, no orbs, no glass, no
icon-tile card grids, no fake device frames.

## Genre
modern-minimal (custom theme "Campo")

## Macrostructure family
- **Home**: Photographic — headline beside trade photos with the spoken-order
  card over them, then feature tabs with real screens, the AI list, the moving
  trades reels and the closing band.
- **Segments and feature pages**: Narrative Workflow — the life of a work order
  in numbered stages. Segments may swap stage content for their trade and add a
  problem → solution split (Split Studio rows).
- **Pricing**: plan sheet (one ruled table, three columns) + tabular spec sheet
  for the comparison + conversational FAQ.
- **Content pages** (docs, FAQ, support, legal): Long Document — single column,
  60–65ch measure, sticky "Nesta página" index on wide screens, no hero art.

## Theme
Tokens live in `src/css/tokens.css`. Light is the default; dark follows the OS
or the saved toggle (`html[data-theme="dark"]`).

- `--color-paper`    oklch(96% 0.01 85)
- `--color-paper-2`  oklch(92% 0.015 85)
- `--color-ink`      oklch(28% 0.08 255) — navy
- `--color-muted`    oklch(42% 0.025 245)
- `--color-rule`     oklch(85% 0.017 85)
- `--color-navy`     oklch(28% 0.08 255) — bands; stays navy in dark mode
- `--color-accent`   oklch(52% 0.16 255) — brand blue, text-safe
- `--color-marker`   oklch(86% 0.17 88) — logo yellow, primary actions and tags
- `--color-focus`    oklch(55% 0.18 250)

## Typography
- Display: **Outfit** 800 (700/900 available), roman only
- Body: **DM Sans** 400 / 500 / 700
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
- `.btn` + `--primary` (yellow fill, navy text) · `--secondary` (outline) ·
  `--whatsapp` · `--text` · `--sm`; `.btn-row`
- `.shot` — real app screenshot, hairline border, no fake device chrome;
  light/dark pairs via `.theme-light` / `.theme-dark`
- `.mark` — yellow highlighter on **one** phrase per page; the home uses a yellow phrase in the headline instead
- `.label`, `.mono`, `.lede`, `.prose`, `a.link`
- `.cta-final` — the closing navy band with store buttons (`components/download.njk`)
- Nav N1b (`partials/navbar.njk`), footer Ft4 (`partials/footer.njk`)

## Motion
- Easings `--ease-out` / `--ease-in` / `--ease-in-out`; 160–240 ms.
- No scroll reveals. Hover/focus/press, plus one pass of the home demo card with a manual replay. The card rests complete, and reduced motion skips the pass.
- The home trades reels move slowly and continuously. They pause on hover and through a visible toggle, keyboard focus stops them, and reduced motion leaves plain hand-scrolled rows. Nothing else loops.

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
- Claim only what the app does. Segment fields marked "para evolução futura" in `firebase/scripts/seed_segments.js` are not claims.
- Feature flags in `site.json`: `flags.whatsappBot` (assistant pages/sections,
  currently **off** — bot is shut down), `flags.whatsappContact` (float button).
- pt-BR, en, es always updated together.

## Per-page allowances
- Marketing pages MAY use the sample work-order ticket (Tier-A HTML/CSS), real
  screenshots and photos of people at work. No illustrations.
- The current photos in `src/assets/images/site/` are AI-generated: keep the
  "Imagens ilustrativas" note beside them, never attach a name, company or
  testimonial, and replace them with authorized customer photos as they arrive.
- Every trade in the app's seed has a page and a reel photo.
- Content pages: typography only; tables and callouts use rules, not cards.

## What pages MUST share
Wordmark, tokens, fonts, CTA voice, section-head rule, nav, footer.

## What pages MAY differ on
Macrostructure within their family, ordering of sections, whether a page shows
the ticket.

## Segment page screens

The app screenshots in `assets/screenshots/` come from a car-repair demo account
(Onix, oil change, vehicle check-in). Only the `automotivo` page may show them,
plus the neutral `financial.png`, which is the one screen other trades share.
Stages without `image` render as text. Add a screen to another trade only when
it was captured with that trade's data.
