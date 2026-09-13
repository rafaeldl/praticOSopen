# Order card design system

## 1. Intent and reference
Implement the approved September 13 concept: order/status header, square cover beside device and customer, item rows, tonal total, green Share action, secondary Open in PraticOS/complete actions. The concept is an image direction; responsive dimensions adapt to the host iframe. Never embed the mockup as UI or use its illustrative vehicle photo as customer data. The host owns the PraticOS heading outside the card.

## 2. Surface and colors
Host variables override defaults. Light Canvas/CanvasText surface, dark equivalent from color-scheme. Secondary surface light #f3f4f7 / dark #282c34; secondary text #596273 / #b6bfcc. Thin neutral border; 20px outer radius, 10px buttons, 12px summary and photo. Primary action #087f4f with white text; hover #06643e. Status colors have separate light/dark high contrast values. Subtle outer shadow only.

## 3. Typography
System font inherited from host. Body 14px, labels 12px, vehicle 17px, order and total 22px. Weights 400/500/600/700; tabular prices. Translated PT/EN/ES based on host locale, then browser language, then PT. Currency remains BRL, the existing order contract, with locale-aware Intl formatting (Flutter FormatService cannot run in this React widget).

## 4. Layout tokens
4px spacing base; steps 4/8/12/16/24. Maximum width 600px, padding 24px (16px in narrow frames), photo 140px (96px narrow), gap 20px (12px narrow). Full-width main action, auto-fitting secondary actions. Long content wraps; amounts do not shrink. No fixed viewport height. No photo or failed photo removes its column.

## 5. Primitives and states
Card shell; header/status badge; cover/identity; item group/price row; total band; icon button (primary and secondary); live feedback; inline confirmation. SVG icons are decorative with accessible button text. Buttons have 44px minimum targets, focus ring, hover and pressed feedback, disabled state. Loading uses explicit text. Confirmation retains copy/share and allows cancel. Error displays feedback without mutating order. Photo failure collapses the image column.

## 6. Motion
Only button transform on press, 120ms ease; no decorative movement. Reduced motion disables transitions.

## 7. Accessibility and personas
Busy shop owner scans identity/total, shares a draft and selects the destination app and recipient; technician confirms completion; keyboard user sees focus and live status. Text survives long names, multiple devices/items and narrow frames. Status includes text, not color alone. Preserve all existing allowed actions. Sharing never sends automatically or exposes customer phone.

## 8. Validation and boundaries
Exercise live bundled iframe handshake, theme changes, copy denial, native share, cancellation, fallback copy, order open-link success/refusal, confirmation/cancel/success/failure, incoming order update, and PT/EN/ES at 375/768/1280. Documentation in docs/MCP_INTEGRATION.md and hosting/src language docs. Local host harness proves protocol wiring; actual ChatGPT/native share handoff requires deployment and host session. No production deployment in this task.

Open in PraticOS opens the existing public web order URL. Native order deep links are not available in this app. Share fallback never forces WhatsApp.
