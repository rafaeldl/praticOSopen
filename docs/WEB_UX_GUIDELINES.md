# PráticOS Web UX/UI Guidelines

This document outlines the design principles and coding standards for the PráticOS website, focusing on a **Premium Dark Theme** aesthetic that mirrors the modern, clean feel of the mobile application.

## 1. Core Philosophy

*   **Dark Premium:** The website uses a dark theme by default (`--bg-primary`: #0A0E17) to convey a modern, premium software feel.
*   **Gradient Centric:** Use gradients sparingly but effectively for calls-to-action (CTAs) and text emphasis to create visual interest without clutter.
*   **Glassmorphism:** Utilize transparency and blur effects (`backdrop-filter`) for floating elements like the navigation bar.
*   **Responsive & Fluid:** Typography and layouts should scale fluidly across devices using `clamp()` and responsive grid systems.

## 2. Design Tokens (CSS Variables)

All design values are defined in `:root` in `style.css`. Do not hardcode hex values or pixel sizes in component styles.

### Colors
*   **Primary Brand:**
    *   `--color-primary`: `#4A9BD9` (Blue)
    *   `--color-yellow`: `#FFE600` (Accent)
    *   `--gradient-primary`: Linear gradient from Primary to Yellow. Used for primary buttons and text emphasis.
*   **Backgrounds:**
    *   `--bg-primary`: `#0A0E17` (Main background - Deep Blue/Black)
    *   `--bg-secondary`: `#0F1520` (Alternating section background)
    *   `--bg-card`: `#1A2235` (Card background)
*   **Text:**
    *   `--text-primary`: `#FFFFFF` (Headings, Body)
    *   `--text-secondary`: `#A0AEC0` (Subtitles, Descriptions)
    *   `--text-tertiary`: `#718096` (Meta data, Footer links)

### Typography
*   **Headings:** `Outfit`, sans-serif. Bold weights (700, 800).
*   **Body:** `DM Sans`, sans-serif. Clean, highly readable.
*   **Scaling:** Use `clamp()` for fluid font sizing.
    *   H1: `clamp(2.5rem, 5vw, 4rem)`
    *   H2: `clamp(2rem, 4vw, 3rem)`

### Spacing & Radius
*   **Container:** `1200px` max-width with `24px` padding.
*   **Section Padding:** `120px` (Desktop), `80px` (Tablet), `60px` (Mobile).
*   **Border Radius:**
    *   Buttons: `--radius-full` (9999px)
    *   Cards: `--radius-lg` (20px) or `--radius-xl` (28px)

## 3. Layout & Structure

### Navigation Bar
*   **Sticky:** Fixed position (`top: 0`).
*   **Scroll Effect:** Adds `.scrolled` class on scroll > 50px.
    *   Background: `rgba(10, 14, 23, 0.95)`
    *   Blur: `backdrop-filter: blur(20px)`
*   **Mobile:** Collapses into a full-screen overlay menu triggered by a hamburger icon (`.nav-toggle`).

### Sections
*   **Alternating Backgrounds:** Use `--bg-primary` for Hero and Feature highlights, and `--bg-secondary` for Features list, Pricing, and Contact to create visual rhythm.
*   **Headers:** Centered section headers with a "pill" tag (`.section-tag`) above the title.
    *   Tag style: Outline or subtle background, rounded caps.
    *   Title style: H2 with key phrases in `.gradient-text`.

### Footer
*   **Grid Layout:** 4 columns on desktop (Brand + 3 Link lists), collapsing to 2 columns on tablet and 1 on mobile.
*   **Style:** Minimalist, no heavy background differentiation, just a top border.

## 4. Components

### Buttons (`.btn`)
*   **Shape:** Pill-shaped (`border-radius: 50px`).
*   **Primary (`.btn-primary`):** Gradient background, white text, subtle shadow glow (`--shadow-glow`).
    *   Hover: Lift (`translateY(-2px)`) and increased shadow.
*   **Secondary (`.btn-secondary`):** Card background color, solid border.
*   **Outline (`.btn-outline`):** Transparent background, border only. Used for secondary actions in dark areas.

### Cards (`.feature-card`, `.pricing-card`)
*   **Appearance:** Dark card background (`--bg-card`) with a subtle gradient (`--gradient-card`).
*   **Border:** Thin, semi-transparent border (`--border-color`).
*   **Hover:**
    *   Border lightens (`--border-color-hover`).
    *   Card lifts (`translateY(-4px)`).
    *   Shadow increases (`--shadow-md`).
*   **Icons:** Use SVG icons wrapped in a container (`.feature-icon`) with a subtle background color matching the icon color (15% opacity).

### Phone Mockups
*   **Container:** `.phone-frame` or `.phone-mockup`.
*   **Style:** Dark background, rounded corners (approx 32px-40px), thin border.
*   **Shadow:** Deep drop shadow (`--shadow-lg`) to simulate depth.

## 5. Visual Effects & Animation

### Entrance Animations
*   **Fade In Up:** Use for text and cards. Elements slide up 30px and fade in.
*   **Fade In Right:** Use for side images (like phone mockups in Hero).
*   **Staggering:** Use `transition-delay` on grid items (e.g., cards 1, 2, 3 appear sequentially) to create a cascading effect.

### Background Orbs
*   **Usage:** Large, blurred colored circles (`.gradient-orb`) floating in the background of the Hero section.
*   **Animation:** Slow floating movement (`@keyframes float`) to add life to the static dark background.
*   **Colors:** Primary Blue, Yellow, and Orange.

## 6. Responsiveness

### Breakpoints
*   **Desktop (> 1024px):** Standard 3-column grids, full navbar.
*   **Tablet (768px - 1024px):**
    *   Grids collapse to 2 columns.
    *   Hero becomes centered (text top, image bottom).
*   **Mobile (< 768px):**
    *   Navbar collapses to Hamburger menu.
    *   Grids become 1 column.
    *   Hero phone images stack or hide secondary ones.
    *   Horizontal scroll for screenshots (`.screenshots-showcase`).

### Mobile Menu
*   **Behavior:** Full screen take-over.
*   **Transition:** Fade in + visibility toggle.
*   **Content:** Large text links, centered.

## 7. Implementation Checklist

When adding new pages or sections, ensure:
1.  [ ] **Semantic HTML:** Use `<section>`, `<header>`, `<main>`, `<footer>`, `<nav>`.
2.  [ ] **Accessibility:** All images have `alt` text. Interactive elements have focus states. Colors meet contrast ratios (light text on dark bg).
3.  [ ] **Performance:** Images are `loading="lazy"` (except Hero LCP image).
4.  [ ] **Consistency:** Use defined CSS variables for *all* colors and spacings. Do not use magic numbers.
5.  [ ] **Dark Mode Integrity:** Ensure no white backgrounds are introduced; strictly adhere to the dark theme palette.
