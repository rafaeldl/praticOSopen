# Public Profile UX Spec — `/pro/{slug}`

> **Status:** Active spec for redesign implementation
> **Created:** 2026-03-01
> **Related:** [PUBLIC_PROFILE.md](./PUBLIC_PROFILE.md) (brainstorm), `firebase/web/`

---

## 1. Competitive Research

Patterns extracted from leading US home-services platforms to inform design decisions.

### Platform Analysis

| Platform | Key Pattern | What We Learn |
|----------|------------|---------------|
| **Yelp** | 2-column desktop: content (left) + sticky sidebar CTA (right). Rating inline with name. Photos prominent above fold. | Sidebar CTA keeps conversion visible during scroll. Rating next to name builds instant trust. |
| **Thumbtack** | Clean cards, "Top Pro" badge, "Hired X times on Thumbtack", transparent pricing, response time. | Social proof counters ("200+ hires") convert better than abstract ratings alone. Specificity wins. |
| **Angi** | Layered trust badges (verified, licensed, background-checked), credentials section, "A" rating grade. | Multiple trust signals in hierarchy — each one reduces friction incrementally. |
| **Housecall Pro** | Professional hero section, integrated booking widget, service area map. | Hero quality signals professionalism. Booking embedded, not external. |
| **Square Appointments** | The booking IS the profile. Service list with prices + duration. Zero-friction "Book Now". | When CTA is the primary experience (not secondary), conversion maximizes. |

### Adopted Patterns

| Pattern | Source | Why Adopt |
|---------|--------|-----------|
| **2-column layout (desktop)** | Yelp, Thumbtack | Keeps CTA visible while user browses content |
| **Rating inline with name** | Yelp, Google | Instant credibility above the fold |
| **Stats counters** | Thumbtack ("Hired X times") | Concrete social proof > abstract description |
| **Verified badge** | All platforms | Universal trust signal |
| **Featured review** | Yelp (highlighted review) | Best testimonial gets visual priority |
| **Sticky CTA** | Yelp sidebar, Square | Conversion always one tap/click away |
| **Service cards with photos** | Thumbtack, Housecall Pro | Visual services feel more tangible than text lists |

### Intentionally Skipped

| Pattern | Source | Why Skip (for now) |
|---------|--------|--------------------|
| Integrated booking/calendar | Square, Housecall Pro | Requires calendar infra we don't have yet |
| Service area map | Housecall Pro, Angi | Needs geolocation data we don't collect |
| Response time indicator | Thumbtack | Need to build tracking before displaying |
| License/background check badges | Angi | No verification pipeline exists |
| Price range (min–max) | Thumbtack | API only has single `value`, not range |

---

## 2. Responsive Layout

### Desktop (>= 1024px) — 2 Columns

```
┌──────────────────────────────────────────────────────────────┐
│                        HERO (full width)                     │
│  ┌──────┐                                                    │
│  │ Logo │  Company Name  ✓ Verified                          │
│  └──────┘  Segment • City, State                             │
│                                                              │
│        150+           ★ 4.8          120                      │
│    services       avg rating      reviews                    │
│                                                              │
├────────────────────────────────────┬─────────────────────────┤
│           CONTENT (~60%)           │    SIDEBAR (~40%)       │
│                                    │    ┌─────────────────┐  │
│  ── ABOUT                          │    │  Request Quote  │  │
│  Bio text with expand/collapse...  │    │                 │  │
│                                    │    │ [WhatsApp btn]  │  │
│  ── SERVICES                       │    │ [Call btn]      │  │
│  ┌──────┐ ┌──────┐ ┌──────┐       │    │                 │  │
│  │photo │ │photo │ │photo │       │    │  ★ 4.8 (120)    │  │
│  │name  │ │name  │ │name  │       │    │  150+ services  │  │
│  │price │ │price │ │price │       │    └─────────────────┘  │
│  └──────┘ └──────┘ └──────┘       │    (sticky on scroll)   │
│                                    │                         │
│  ── PORTFOLIO                      │                         │
│  ┌────────────────────────────┐   │                         │
│  │    Featured Photo 16:9     │   │                         │
│  └────────────────────────────┘   │                         │
│  [img] [img] [img] [img] [img]    │                         │
│                                    │                         │
│  ── REVIEWS                        │                         │
│  ┌────────────────────────────┐   │                         │
│  │  ★ Featured Review         │   │                         │
│  │  "Best technician ever..." │   │                         │
│  │  — Maria S. · 2w ago      │   │                         │
│  └────────────────────────────┘   │                         │
│  ┌─────────────┐ ┌─────────────┐  │                         │
│  │ Review card │ │ Review card │  │                         │
│  └─────────────┘ └─────────────┘  │                         │
│                                    │                         │
│          Powered by PraticOS       │                         │
├────────────────────────────────────┴─────────────────────────┤
│                    [Lang Switcher: PT EN ES]                  │
└──────────────────────────────────────────────────────────────┘
```

**Key desktop decisions:**
- Hero spans full width (above the 2-column split)
- Content column: `max-w-[640px]`
- Sidebar: `w-[320px]`, `sticky top-8`, starts at same level as "About"
- Outer container: `max-w-[1024px] mx-auto`
- Gap between columns: `gap-8` (32px)

### Tablet (768px – 1023px) — Single Column, Wider

```
┌────────────────────────────────────────┐
│              HERO (full width)          │
│   Logo  Company Name  ✓ Verified       │
│         Segment • City, State          │
│   150+ services  ★ 4.8  120 reviews   │
├────────────────────────────────────────┤
│           max-w-2xl mx-auto            │
│                                        │
│  ── ABOUT                              │
│  ── SERVICES (3 cols grid)             │
│  ── PORTFOLIO                          │
│  ── REVIEWS                            │
│  Powered by PraticOS                   │
│                                        │
├────────────────────────────────────────┤
│  [Lang] ←── fixed bottom-right        │
├────────────────────────────────────────┤
│  ┌──────────────┬──────────────┐       │
│  │  WhatsApp    │    Call      │  fixed │
│  └──────────────┴──────────────┘ bottom │
└────────────────────────────────────────┘
```

### Mobile (< 768px) — Single Column + Sticky Bottom Bar

```
┌──────────────────────────┐
│       HERO (full width)   │
│  ┌────┐                   │
│  │Logo│  Company Name     │
│  └────┘  ✓ Verified       │
│  Segment • City           │
│                           │
│  150+    ★ 4.8    120     │
│  serv.   rating   rev.    │
├──────────────────────────┤
│      px-5 content         │
│                           │
│  ── ABOUT                 │
│  Bio (line-clamp-4)       │
│  [Read more]              │
│                           │
│  ── SERVICES (2 cols)     │
│  ┌─────┐ ┌─────┐         │
│  │ svc │ │ svc │         │
│  └─────┘ └─────┘         │
│                           │
│  ── PORTFOLIO             │
│  [Featured 16:9]          │
│  [img][img][img]          │
│                           │
│  ── REVIEWS               │
│  [Featured review]        │
│  [compact][compact]       │
│  [Show more]              │
│                           │
│  Powered by PraticOS      │
│                           │
│                           │
│  ← extra padding for bar →│
├──────────────────────────┤
│ [PT EN ES] ← lang fixed  │
├──────────────────────────┤
│ [WhatsApp]  [Ligar]      │
│ ← sticky bottom bar →    │
└──────────────────────────┘
```

**Key mobile decisions:**
- `pb-28` on `<main>` to clear the sticky CTA bar
- Stats use horizontal flex layout (no dividers if space is tight)
- Services grid: `grid-cols-2`
- Portfolio remaining grid: `grid-cols-3`
- Reviews: single column, no grid

---

## 3. Section Hierarchy

Ordered by conversion impact, justified by competitive research:

| # | Section | Rationale | Visible When |
|---|---------|-----------|--------------|
| 1 | **Hero** (logo, name, verified, segment, location) | First impression — establishes identity and trust. All competitors lead with this. | Always |
| 2 | **Stats** (completedOrders, avgRating, reviewCount) | Concrete social proof above the fold. Thumbtack pattern: numbers > words. | Any stat > 0 |
| 3 | **About** (bio) | Personal touch, explains expertise. Yelp/Thumbtack both feature this prominently. | `company.bio` exists |
| 4 | **Services** (grid with photos + prices) | Core value proposition — what the professional does and costs. Square/Thumbtack emphasize this. | `services.length > 0` |
| 5 | **Portfolio** (featured photo + grid) | Visual proof of work quality. Behance-inspired "show don't tell". | `portfolio.length > 0` |
| 6 | **Reviews** (featured + compact list) | Social proof from customers. Yelp's featured review pattern. | `reviews.length > 0` |
| 7 | **CTA** (WhatsApp + Call) | Conversion point. Yelp sidebar / Square "Book Now" pattern. | `company.whatsapp \|\| company.phone` |
| 8 | **Footer** (Powered by PraticOS) | Branding + viral loop (other pros see it). | Always |

---

## 4. Component Specifications

### 4.1 ProfileHeader

**File:** `firebase/web/components/profile/ProfileHeader.vue`

```
┌──────────────────────────────────────────────┐
│  ○ ○ ○ (floating orbs, decorative bg)        │
│                                              │
│            ┌──────────┐                      │
│            │   LOGO   │  96px mobile         │
│            │  or "J"  │  100px sm            │
│            └──────────┘  120px lg            │
│                                              │
│          Company Name                        │
│   ✓ Verified  · Segment · City, State        │
│                                              │
│     150+        ★ 4.8        120             │
│   services    avg rating   reviews           │
│                                              │
└──────────────────────────────────────────────┘
```

**API data consumed:**
- `company.logo` — Image URL or fallback to first letter of `company.name`
- `company.name` — h1 heading
- `company.verified` — Green badge with shield icon
- `company.segment` → `getSegmentLabel(segment)` — Localized segment name
- `company.city`, `company.state` — Location text (joined with comma)
- `stats.completedOrders` — Rounded to nearest 50 with "+" for >= 100
- `stats.avgRating` — Star icon + number
- `stats.reviewCount` — Count

**Breakpoint behavior:**
- Logo: `h-24 w-24` → `sm:h-[100px]` → `lg:h-[120px]`
- Name: `text-2xl` → `sm:text-3xl` → `lg:text-4xl`
- Stats numbers: `text-3xl` → `sm:text-4xl`
- Stats separated by `h-10 w-px` vertical dividers

**Interactions:**
- None (static display)

**Visual details:**
- Background: `hero-bg` gradient with 3 floating orbs (brand-primary, brand-yellow, brand-orange)
- Orb opacity: theme-aware via `--hero-orb-opacity` (0.08 dark, 0.18 light)
- Logo ring: `logo-glow-ring` — subtle blue glow shadow
- Verified badge: green bg (`rgba(52,199,89,0.15)`), shield+checkmark icon

---

### 4.2 ProfileAbout

**File:** `firebase/web/components/profile/ProfileAbout.vue`

```
──  (accent line 48px gradient)
ABOUT  (section label, 11px uppercase tracking-widest)

❝  Bio text goes here. Can be multiple lines.
   Supports pre-line whitespace. Truncated to
   4 lines initially with line-clamp.
   [Read more]
```

**API data consumed:**
- `company.bio` — Text content (whitespace-pre-line preserved)

**Breakpoint behavior:**
- Text size: `text-base` → `sm:text-lg`
- No layout changes across breakpoints (single column content)

**Interactions:**
- **Expand/collapse:** If bio > 200 chars OR > 4 lines, shows "Read more" / "Read less" toggle
- `line-clamp-4` when collapsed, full text when expanded

**Visual details:**
- Decorative opening quote mark: `text-5xl text-brand-primary opacity-20`
- Left padding `pl-6` with quote positioned `absolute left-0 top-0`
- Section header: gradient accent line + uppercase label

---

### 4.3 ProfileServicesList

**File:** `firebase/web/components/profile/ProfileServicesList.vue`

```
──  (accent line)
SERVICES

┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ [photo]  │ │ [photo]  │ │          │ │          │
│ 4:3      │ │ 4:3      │ │ No photo │ │ No photo │
│──────────│ │──────────│ │          │ │          │
│ Name     │ │ Name     │ │ Name     │ │ Name     │
│ From $XX │ │ From $XX │ │ From $XX │ │          │
└──────────┘ └──────────┘ └──────────┘ └──────────┘
```

**API data consumed:**
- `services[].name` — Service name
- `services[].value` — Price (formatted via `formatCurrency(value, country)`)
- `services[].photo` — Optional photo URL
- `company.showPrices` — Whether to display prices
- `company.country` — Currency formatting (BR → R$, US → $)

**Breakpoint behavior:**
- Grid: `grid-cols-2` → `sm:grid-cols-3` → `lg:grid-cols-4`
- Card: rounded-xl border, `card-hover-lift` on hover

**Interactions:**
- **Hover:** Card lifts 2px with increased shadow (`card-hover-lift`)
- **Photo hover:** Image scales 105% with `transition-transform duration-300`

**Visual details:**
- Photo aspect ratio: `aspect-[4/3]`
- Card: `bg-[var(--bg-card)]`, `border border-[var(--border-color)]`
- Price label: `text-xs text-brand-primary`, prefixed with "Starting at" / "A partir de"

---

### 4.4 ProfilePortfolioGrid

**File:** `firebase/web/components/profile/ProfilePortfolioGrid.vue`

```
──  (accent line)
PORTFOLIO

┌────────────────────────────────────────────────┐
│                                                │
│           Featured Photo (16:9)                │
│    hover: gradient overlay + description       │
│                                                │
└────────────────────────────────────────────────┘

┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│  1:1   │ │  1:1   │ │  1:1   │ │  1:1   │ │  1:1   │
│ square │ │ square │ │ square │ │ square │ │ square │
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

**API data consumed:**
- `portfolio[0]` — Featured photo (first in array, displayed large)
- `portfolio[1..n]` — Remaining photos in grid
- `portfolio[].url` — Image URL
- `portfolio[].description` — Optional caption (shown on hover for featured)

**Breakpoint behavior:**
- Featured photo: always `aspect-[16/9]`, full width of content column
- Remaining grid: `grid-cols-3` → `sm:grid-cols-4` → `lg:grid-cols-5`
- Each grid photo: `aspect-square`

**Interactions:**
- **Click (any photo):** Opens lightbox (`$emit('openLightbox', index)`)
- **Hover (featured):** Gradient overlay from-black/70 fades in, shows description
- **Hover (grid):** Black overlay 30%, image scales 105%

**Visual details:**
- Featured: `rounded-2xl`, larger rounded corners
- Grid items: `rounded-xl`
- Gap: `gap-2` for grid, `mb-3` between featured and grid
- Lightbox: Reuses `OrderPhotoLightbox` component from share link feature

---

### 4.5 ProfileReviewsSection

**File:** `firebase/web/components/profile/ProfileReviewsSection.vue`

```
──  (accent line)
REVIEWS  ★★★★★ 4.8 (15)

┌─────────────────────────────────────────────────┐
│  ★ FEATURED                                     │
│  ★★★★★                                         │
│                                                 │
│  "Best technician I've ever hired. Arrived      │
│   on time, explained everything, and the        │
│   price was fair."                              │
│                                                 │
│  [MS] Maria S.                                  │
│       2 weeks ago                               │
└─────────────────────────────────────────────────┘

┌──────────────────────┐  ┌──────────────────────┐
│ [CR] Carlos R. ★★★★★│  │ [JL] João L.   ★★★★☆│
│ "Excelente serviço"  │  │ "Muito bom"         │
│ 1 month ago          │  │ 3 months ago         │
└──────────────────────┘  └──────────────────────┘

         [ Show more reviews ]
```

**API data consumed:**
- `reviews[]` — Full review array
- `reviews[].score` — 1-5 star rating
- `reviews[].comment` — Optional review text
- `reviews[].customerName` — Masked name (e.g., "Maria S.")
- `reviews[].createdAt` — ISO date → relative date via `formatRelativeDate()`

**Computed values:**
- `avgRating` — Calculated from reviews array (mean of scores)
- `featuredReview` — Highest score + longest comment (min 30 chars)
- `remainingReviews` — All reviews excluding featured
- `visibleReviews` — First 5 of remaining (expandable)

**Breakpoint behavior:**
- Featured review: single card, full width on all breakpoints
- Remaining reviews: `grid-cols-1` → `lg:grid-cols-2`
- "Show more" button: full width

**Interactions:**
- **Show more / Show less:** Toggles between first 5 and all remaining reviews
- Only visible when `remainingReviews.length > 5`

**Visual details:**
- Featured review: `border border-brand-primary/20 bg-brand-primary/5`, rounded-2xl
- Featured badge: `bg-brand-primary/15 text-brand-primary`, uppercase 10px
- Regular reviews: `bg-[var(--bg-tertiary)]`, rounded-xl
- Avatar circles: colored background (hash-based from name), white text initials
- Star colors: filled = `text-brand-yellow`, empty = `text-[var(--text-tertiary)] opacity-30`

---

### 4.6 ProfileCTAFooter

**File:** `firebase/web/components/profile/ProfileCTAFooter.vue`

```
Mobile/Tablet — Fixed bottom bar:

┌──────────────────────────────────────────────┐
│           REQUEST QUOTE (label)               │
│  ┌───────────────────┐ ┌──────────────────┐  │
│  │ 💬 WhatsApp       │ │ 📞 Call          │  │
│  │ (green, pulsing)  │ │ (blue)           │  │
│  └───────────────────┘ └──────────────────┘  │
└──────────────────────────────────────────────┘
```

**API data consumed:**
- `company.whatsapp` — Phone number → `wa.me/{number}` link
- `company.phone` — Phone number → `tel:{number}` link

**Breakpoint behavior:**
- **Mobile/Tablet:** Fixed bottom bar with backdrop-blur, `z-[900]`
- **Desktop (>= 1024px):** Hidden (`lg:hidden`) — replaced by `ProfileSidebarCTA`

**Interactions:**
- **WhatsApp button:** Opens `wa.me/{phone}` in new tab
- **Call button:** Opens native dialer via `tel:` link
- WhatsApp button has `animate-pulse-glow` — subtle green glow animation

**Visual details:**
- Bar: `bg-[var(--bg-card)]/90 backdrop-blur-xl`, border-top
- WhatsApp: `bg-[#25D366]`, white text, green shadow
- Call: `bg-brand-primary`, white text, blue shadow
- Both: `rounded-xl`, `py-3.5`, `font-bold`
- Safe area support: `padding-bottom: env(safe-area-inset-bottom)` for iPhone notch

---

### 4.7 ProfileLangSwitcher

**File:** `firebase/web/components/profile/ProfileLangSwitcher.vue`

```
Fixed position, bottom-right, above CTA bar:

  ┌────────────────┐
  │ [PT] [EN] [ES] │
  └────────────────┘
```

**API data consumed:** None (uses `useProfileI18n()` composable)

**Breakpoint behavior:**
- Fixed position: `bottom-[88px] right-6` (above CTA bar)
- Adjusts with `env(safe-area-inset-bottom)` on iOS

**Interactions:**
- Click: Sets `?lang=XX` query param and reloads page
- Active language: `bg-brand-primary text-white`
- Inactive: `bg-transparent text-[var(--text-secondary)]`

**Visual details:**
- Container: rounded-full pill, `border border-[var(--border-color)]`, `bg-[var(--bg-card)]`
- Buttons: `h-9 w-9` circular, `text-xs font-semibold`
- `z-[1000]` (above CTA bar at z-900)

---

### 4.8 ProfileStatsBar (unused — stats embedded in Header)

**File:** `firebase/web/components/profile/ProfileStatsBar.vue`

> **Note:** This component exists but is **not currently used** in `[slug].vue`. Stats are rendered inline inside `ProfileHeader`. This component could be repurposed for the desktop sidebar CTA card.

---

## 5. Conversion Patterns

### Strategy: Always-Visible CTA

**Principle:** The user should never need to scroll to find the contact action.

| Breakpoint | CTA Location | Behavior |
|-----------|-------------|----------|
| Desktop (>= 1024px) | Sidebar card, `position: sticky; top: 2rem` | Visible alongside content during entire scroll |
| Tablet (768-1023px) | Fixed bottom bar | Always visible at bottom of screen |
| Mobile (< 768px) | Fixed bottom bar | Always visible, with safe-area padding |

### Trust Signal Hierarchy (above the fold)

These elements appear before any scrolling, building trust fast:

1. **Logo** — Professional visual identity
2. **Verified badge** — Platform endorsement (green shield)
3. **Stats counters** — Quantified social proof ("150+ services", "4.8 rating", "120 reviews")
4. **Segment + Location** — Contextual relevance ("HVAC • Campinas, SP")

### Social Proof Reinforcement (during scroll)

As the user scrolls content sections, these build confidence:

1. **Service photos** — Visual proof of work type
2. **Transparent pricing** — Reduces uncertainty (when `showPrices` enabled)
3. **Portfolio photos** — Quality of past work
4. **Featured review** — Best testimonial highlighted
5. **Review volume** — Multiple reviews = proven track record

### CTA Button Hierarchy

| Button | Priority | Color | Animation | Purpose |
|--------|----------|-------|-----------|---------|
| WhatsApp | Primary | `#25D366` (green) | `pulse-glow` | Lowest friction contact method |
| Call | Secondary | `#4A9BD9` (brand blue) | None | Direct voice contact |

**WhatsApp is primary because:**
- Async (user doesn't need to be available right now)
- Can send photos of the problem
- Creates a conversation thread for follow-up
- Most natural for the Brazilian market

---

## 6. Data Mapping

### API Response Shape (`PublicProfileData`)

Source: `firebase/web/server/utils/profile-service.ts`

```typescript
interface PublicProfileData {
  company: {
    id: string
    name: string
    segment?: string        // e.g. "hvac", "automotive"
    city?: string           // Only if showAddress=true
    state?: string          // Only if showAddress=true
    country?: string        // Default "BR"
    logo?: string           // Firebase Storage URL
    phone?: string          // Only if showPhone=true
    whatsapp?: string       // Only if showWhatsapp=true
    bio?: string            // From profileConfig or company.description
    showPrices: boolean
    showPhone: boolean
    showWhatsapp: boolean
    showAddress: boolean
    verified: boolean
    slug: string
  }
  services: Array<{
    id: string
    name: string
    value?: number          // Price in local currency
    photo?: string          // Service photo URL
  }>
  reviews: Array<{
    id: string
    score: number           // 1-5
    comment?: string        // Only reviews with comments included
    customerName: string    // Masked: "Maria S."
    createdAt: string       // ISO 8601
  }>
  portfolio: Array<{
    url: string             // Photo URL
    description?: string
  }>
  stats: {
    completedOrders: number // Total done orders (up to 200 limit)
    avgRating: number       // Rounded to 1 decimal
    reviewCount: number     // Total rated orders (not just commented ones)
  }
}
```

### Field → Component Mapping

| API Field | Component | Element |
|-----------|-----------|---------|
| `company.logo` | ProfileHeader | Logo image or initial letter fallback |
| `company.name` | ProfileHeader | `<h1>` heading |
| `company.verified` | ProfileHeader | Green verified badge |
| `company.segment` | ProfileHeader | Localized via `getSegmentLabel()` |
| `company.city` + `company.state` | ProfileHeader | Location text with map pin icon |
| `company.bio` | ProfileAbout | Quote-style bio text |
| `company.whatsapp` | ProfileCTAFooter | WhatsApp button → `wa.me/{phone}` |
| `company.phone` | ProfileCTAFooter | Call button → `tel:{phone}` |
| `company.showPrices` | ProfileServicesList | Controls price visibility per service |
| `company.country` | ProfileServicesList | Currency formatting (BR→R$, US→$) |
| `company.name` | `[slug].vue` | SEO meta title, OG tags, Schema.org |
| `services[]` | ProfileServicesList | Grid of service cards |
| `reviews[]` | ProfileReviewsSection | Featured review + compact list |
| `portfolio[]` | ProfilePortfolioGrid | Featured photo + thumbnail grid |
| `stats.completedOrders` | ProfileHeader | Counter (rounded to 50s for >= 100) |
| `stats.avgRating` | ProfileHeader | Star icon + number |
| `stats.reviewCount` | ProfileHeader | Counter |

### SEO Data Usage (`[slug].vue`)

| Meta Tag | Source |
|----------|--------|
| `<title>` | `{name} - Perfil Profissional \| PraticOS` |
| `meta[description]` | `{name} - {segment} em {city}. Veja serviços, avaliações e portfólio.` |
| `og:title` | Same as title |
| `og:description` | Same as description |
| `og:image` | `company.logo` |
| `robots` | `index, follow` |
| Schema.org `LocalBusiness` | name, image, telephone, address, aggregateRating, hasOfferCatalog |

---

## 7. Design Tokens & Theme

### CSS Custom Properties

Source: `firebase/web/assets/css/main.css`

**Brand Colors (static):**
| Token | Value | Usage |
|-------|-------|-------|
| `--color-primary` | `#4A9BD9` | Primary brand blue |
| `--color-primary-light` | `#6BB3E9` | Hover states |
| `--color-primary-dark` | `#3A7BB9` | Active states |
| `--gradient-primary` | `135deg, #4A9BD9 → #FFE600` | Accent lines, text-gradient |

**Dark Theme (default):**
| Token | Value | Usage |
|-------|-------|-------|
| `--bg-primary` | `#0A0E17` | Page background |
| `--bg-secondary` | `#0F1520` | Secondary surfaces |
| `--bg-tertiary` | `#151C2A` | Cards, inputs |
| `--bg-card` | `#1A2235` | Card backgrounds |
| `--bg-card-hover` | `#1F2940` | Card hover state |
| `--text-primary` | `#FFFFFF` | Headings, body |
| `--text-secondary` | `#A0AEC0` | Descriptions, bio |
| `--text-tertiary` | `#718096` | Labels, dates, captions |
| `--border-color` | `rgba(255,255,255,0.08)` | Card borders, dividers |
| `--shadow-md` | `0 4px 20px rgba(0,0,0,0.4)` | Card hover shadows |
| `--hero-bg` | `180deg, #0F1520 → #0A0E17` | Hero gradient |
| `--hero-orb-opacity` | `0.08` | Floating orb visibility |

**Light Theme:**
| Token | Value | Usage |
|-------|-------|-------|
| `--bg-primary` | `#F5F5F7` | Page background |
| `--bg-card` | `#FFFFFF` | Card backgrounds |
| `--text-primary` | `#1A1A2E` | Headings, body |
| `--text-secondary` | `#4A5568` | Descriptions |
| `--hero-bg` | `180deg, #E8F0FE → #F5F5F7` | Hero gradient |
| `--hero-orb-opacity` | `0.18` | Floating orb visibility |

**Status Colors (static):**
| Token | Value | Usage |
|-------|-------|-------|
| `--status-approved` | `#34C759` | Verified badge text |
| `--status-approved-bg` | `rgba(52,199,89,0.15)` | Verified badge bg |

### Tailwind Extended Colors

Source: `firebase/web/tailwind.config.ts`

```
brand-primary:       #4A9BD9
brand-primary-light: #6BB3E9
brand-primary-dark:  #3A7BB9
brand-yellow:        #FFE600    (stars, accents)
brand-orange:        #F5A623    (decorative orbs)
```

### Typography

| Role | Font | Tailwind Class |
|------|------|---------------|
| Headings, numbers | Outfit | `font-heading` |
| Body text, UI | DM Sans | `font-body` |

### Animations

| Name | Duration | Usage |
|------|----------|-------|
| `fade-in-up` | 0.5s ease | Section entrance (0→20px translateY) |
| `stagger-1..5` | +0.1s each | Cascading entrance per section |
| `float` | 8s infinite | Hero background orbs |
| `float-delayed` | 8s infinite | Second orb (offset timing) |
| `float-slow` | 12s infinite | Third orb (slowest) |
| `pulse-glow` | 2.5s infinite | WhatsApp button green glow |

### Utility Classes

| Class | Effect |
|-------|--------|
| `.hero-bg` | Background gradient from `--hero-bg` |
| `.logo-glow-ring` | Blue glow box-shadow around logo |
| `.card-hover-lift` | translateY(-2px) + shadow-md on hover |
| `.section-accent-line` | 48px gradient line (section divider) |
| `.text-gradient` | Gradient text (primary→yellow) |
| `.safe-area-bottom` | Safe area padding for iPhone |
| `.btn` | Pill button base (rounded-full, centered) |

---

## 8. i18n

Source: `firebase/web/composables/useProfileI18n.ts`

**Languages supported:** `pt` (default), `en`, `es`

**Detection order:**
1. `?lang=XX` query param (explicit)
2. `navigator.language` (browser)
3. Fallback: `pt`

**Key strings per section:**

| Key | PT | EN | ES |
|-----|----|----|-----|
| `verified` | Verificado | Verified | Verificado |
| `completedOrders` | serviços realizados | services completed | servicios realizados |
| `avgRating` | nota média | average rating | nota promedio |
| `about` | Sobre | About | Acerca de |
| `servicesTitle` | Serviços | Services | Servicios |
| `portfolioTitle` | Portfólio | Portfolio | Portafolio |
| `reviewsTitle` | Avaliações | Reviews | Calificaciones |
| `requestQuote` | Solicitar Orçamento | Request a Quote | Solicitar Presupuesto |
| `whatsapp` | WhatsApp | WhatsApp | WhatsApp |
| `call` | Ligar | Call | Llamar |
| `startingAt` | A partir de | Starting at | Desde |
| `featuredReview` | Destaque | Featured | Destacada |
| `readMore` | Ler mais | Read more | Leer más |
| `showMore` | Ver mais avaliações | Show more reviews | Ver más calificaciones |
| `poweredBy` | Powered by | Powered by | Powered by |

**Segment labels:** 28 segments translated across all 3 languages (hvac, automotive, electronics, etc.)

**Relative dates:** Localized format ("há 2 semanas" / "2w ago" / "hace 2 semanas")

---

## 9. Implementation Checklist

### Current State (single column)

- [x] ProfileHeader with stats inline
- [x] ProfileAbout with expand/collapse
- [x] ProfileServicesList with photo grid
- [x] ProfilePortfolioGrid with featured + grid + lightbox
- [x] ProfileReviewsSection with featured + compact + show more
- [x] ProfileCTAFooter sticky bottom bar
- [x] ProfileLangSwitcher fixed bottom-right
- [x] SEO meta tags + Schema.org LocalBusiness
- [x] Dark/light theme support
- [x] 3-language i18n (pt/en/es)

### Redesign Tasks (2-column desktop)

- [x] Add 2-column layout wrapper in `[slug].vue` for `lg:` breakpoint
- [x] Create desktop sidebar CTA card (`ProfileSidebarCTA.vue`)
- [x] Make sidebar sticky (`position: sticky; top: 2rem`)
- [x] Hide `ProfileCTAFooter` bottom bar on desktop (`lg:hidden`)
- [x] Adjust content column max-width for 2-column context (`lg:max-w-5xl`)
- [x] Adjust `ProfileLangSwitcher` position on desktop (`lg:bottom-6`)
- [x] Remove bottom padding on desktop (`lg:pb-0`)
- [ ] Test all breakpoint transitions (mobile → tablet → desktop)
- [ ] Verify safe-area behavior on iOS Safari
- [ ] Verify lightbox works correctly in 2-column layout
