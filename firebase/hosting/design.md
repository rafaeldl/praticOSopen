# Design — PraticOS site

The locked design system for the institutional site (`firebase/hosting/src`).
Every page reads this file before emitting code. Extend or amend it here; never
override it per page.

Out of scope: `src/order/` (customer share view `/q/{token}`) and `src/login.njk`.
They belong to the app and still load the legacy `style.css` — do not touch.

## Idea

The site shows the people it serves. Warm paper, navy ink and navy bands, solid
yellow actions, big type, and photos of people at work. The product moment is a
spoken request turning into a work order, shown as a product scene (below).
No gradients, no orbs, no icon-tile card grids. Device frames and glass only
inside a product scene.

## Genre
modern-minimal (custom theme "Campo")

## Macrostructure family
- **Home**: Product hero — headline beside the app on an iPhone writing a work
  order from speech (Stageshow scene), then feature tabs with app screens drawn
  as stills (Stageshow), the AI list, the moving trades reels and the closing band.
- **Segments and feature pages**: Narrative Workflow — the life of a work order
  in numbered stages. Segments may swap stage content for their trade and add a
  problem → solution split (Split Studio rows).
- **Pricing**: plan sheet (one ruled table, three columns) + tabular spec sheet
  for the comparison + conversational FAQ.
- **Content pages** (docs, FAQ, support, legal): Long Document — single column,
  60–65ch measure, sticky "Nesta página" index on wide screens, no hero art.

## Theme
Brand colors (navy, action yellow, brand blue, status colors) are shared with the web app and the phone app: see `docs/DESIGN_TOKENS.md`. The paper background, Outfit and the rules are site-only.

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
- No scroll reveals. Hover/focus/press, plus one pass of the home hero scene with a manual replay ("Ver de novo"). The scene rests on its payoff, and reduced motion shows only that frame.
- The home trades reels move slowly and continuously. Rows can be dragged with the mouse or swiped, and a click or tap opens the trade's page. They pause on hover and through a visible toggle, keyboard focus stops them, and reduced motion leaves still rows that can be dragged and swiped. Nothing else loops.

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
- No invented numbers (users, ratings, conversion). No fake testimonials: a quote
  goes live only after the named customer approves the exact text, and it never
  sits beside an AI-generated photo. The only exception is the customer's own
  portrait, retouched from a real photo, if they approve the final image.
- Claim only what the app does. Segment fields marked "para evolução futura" in `firebase/scripts/seed_segments.js` are not claims.
- Feature flags in `site.json`: `flags.whatsappBot` (assistant pages/sections,
  currently **off** — bot is shut down), `flags.whatsappContact` (float button),
  `flags.softwareItPage` (the Software e TI page claims the automatic service
  invoice; **off** until it ships), `flags.webApp` (the "Entrar" link to `/web`
  in the bar, menu and footer, the home's "Também no computador" band and the
  help article "Usar no computador"; turn it on together with opening
  `config/webApp` to everyone) and `flags.nfsePage` (the service invoice page
  `funcionalidades/nota-fiscal.html`, its help article, the FAQ section and the
  priced "Quanto custa?"; both pages are not even built while it is off). A
  `segments.json` link, footer/nav link, FAQ group or item with `"flag"` shows
  only when that flag is on (`enabledLinks` / `flagShown` filters); a FAQ entry
  with `"hideWhenFlag"` shows only while it is off.
- The service invoice (NFS-e) is Brazil-only: it lives only in the `pt` blocks
  and pt pages, with a PT-only `langSwitch`. `npm run build` ends with
  `scripts/check-br-only.js`, which fails if "nota fiscal", "NFS-e" or "Emissor
  Nacional" shows up on an `-en`/`-es` page (legal texts excepted).
- pt-BR, en, es always updated together.

## Per-page allowances
- Marketing pages MAY use the sample work-order ticket (Tier-A HTML/CSS), real
  screenshots and photos of people at work. No illustrations.
- The current photos in `src/assets/images/site/` are AI-generated: keep the
  "Imagens ilustrativas" note beside them, never attach a name, company or
  testimonial, and replace them with authorized customer photos as they arrive.
- Every trade in the app's seed has a page and a reel photo.
- App screens appear whole, 820 x 1240, with all four corners rounded: no bleed
  off the panel, no clipped navigation, no row cut through.
- Content pages: typography only; tables and callouts use rules, not cards.

## What pages MUST share
Wordmark, tokens, fonts, CTA voice, section-head rule, nav, footer.

## What pages MAY differ on
Macrostructure within their family, ordering of sections, whether a page shows
the ticket.

## Shared chrome

The header, final band and footer are navy in both themes, as in the prototype.
The bar keeps links, language and theme controls. The final band uses two plain
buttons, not store cards. The WhatsApp float is icon only, so it never covers text.

## Product scenes (Stageshow)

Faux product UI built with the Stageshow skill (`.claude/skills/stageshow`) in
`stage/`, built into `src/assets/stage/` (see `docs/SITE_STAGE_SCENES.md`).
The skill's own rules apply inside a scene (framing, restraint, motion, the
`film.mjs --gate`); this file still governs the page around it.

- The scene draws the app as it is: its screens, its colors
  (`lib/theme/app_colors.dart`), its strings from `lib/l10n`. It only shows what
  the app does.
- The phone comes from the kit, runs off an edge of the stage and is never a
  whole device floating on the band.
- Both widths pass the gate (the shown width and 390) before merging.

## Segment pages

Segment pages use the same language as the home: navy photo hero, yellow words in
the headline, the trade's order card over its photo, tabs and rows. Do not bring
back the printed ticket, highlighter headline, mono labels or numbered stages.
Write copy as sales, not as a system description: what the professional gains.
Avoid "campo", "cadastro" and "configurar".

## Segment page screens

App screens on the site are drawn with the Stageshow kit (`stage/`, see
`docs/SITE_STAGE_SCENES.md`), not screenshots. Each trade page feeds the home's
scenes with its own example (`scene` on each stage in `_data/segments/<slug>.json`):
show only what the trade does, with the customer, device and services its copy
already names.
