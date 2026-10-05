# Web UX Guidelines — PraticOS site

The full, locked design system lives in [`firebase/hosting/design.md`](../firebase/hosting/design.md).
This page is the short version for anyone editing the institutional site.

## Visual language

The site looks like the thing it sells: a **work order**.

- Light paper background by default; dark mode follows the OS or the theme toggle.
- Graphite ink for text, hairline rules and a 2px ink rule on top of every section head.
- Brand blue (`--color-accent`) for links, focus and the active state only.
- Logo yellow (`--color-marker`) as a highlighter on one phrase per page.
- Numbers, prices, OS numbers and form labels in IBM Plex Mono.

Never: gradients, glassmorphism, glow shadows, floating orbs, icon-tile card grids,
emoji in headings, italic headings, eyebrow labels above every heading.

## Typography

| Role | Face | Notes |
|------|------|-------|
| Display / headings | Archivo 800 | roman, tracking −0.025em, `text-wrap: balance` |
| Body | IBM Plex Sans 400/600 | 17px base, 1.6 line-height, ≤ 65ch |
| Mono | IBM Plex Mono 400/500 | figures, labels (13px uppercase, 0.06em) |

## Tokens

All values come from `src/css/tokens.css` (`--color-*`, `--font-*`, `--space-*`,
`--text-*`, `--ease-*`, `--dur-*`, `--radius-*`). Do not write raw hex/oklch/rgb in
page CSS — add a token instead.

## Components (`src/css/site.css`)

- `.btn--primary` (ink fill), `.btn--secondary` (outline), `.btn--text`, `.btn--whatsapp`
- `.section`, `.section--alt`, `.section-head`, `.wrap`
- `.shot` — real app screenshots with a hairline border; no fake phone frames
- `.cta-final` — closing band with App Store / Google Play
- Nav (`partials/navbar.njk`) and footer (`partials/footer.njk`)

## Copy

- Talk about the job: orçamento, OS, foto, cliente, aprovação, pagamento.
- No "poderoso", "intuitivo", "eficiente", "solução completa", exclamation marks.
- Never invent metrics, ratings, testimonials or logos.
- pt-BR, en and es are always updated together.

## Accessibility

- One `h1` per page, no skipped heading levels, skip link to `#conteudo`.
- `:focus-visible` ring always visible; Escape closes menus.
- Contrast ≥ 4.5:1 for body text in both themes.
- No horizontal scroll at 320, 375, 414 and 768 px.
