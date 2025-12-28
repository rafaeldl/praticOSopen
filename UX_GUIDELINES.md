# PraticOS UX/UI Guidelines

This document outlines the design principles and coding standards for the PraticOS application, focusing on a strict adoption of Apple's **Human Interface Guidelines (HIG)** to ensure a native, high-quality iOS experience.

## 1. Core Philosophy

*   **Native First:** Prioritize `Cupertino` widgets over Material Design widgets. The app should feel indistinguishable from a native iOS app.
*   **Content Centric:** Reduce visual clutter. Use whitespace, typography, and color sparingly to highlight content.
*   **Direct Manipulation:** Use gestures (swipes, taps, long presses) for common actions.

## 2. Navigation & Structure

### Scaffold & Bars
*   **Scaffold:** Always use `CupertinoPageScaffold`.
*   **Navigation Bar:** Use `CupertinoSliverNavigationBar` with `largeTitle` for main screens (Home, Lists) to enable the collapsing title effect. Use `CupertinoNavigationBar` for modal or detail screens.
*   **Tab Bar:** Use `CupertinoTabScaffold` with `CupertinoTabBar`.
    *   **Icons:** Use `CupertinoIcons` (SF Symbols style).
    *   **Behavior:** Each tab maintains its own navigation stack (`CupertinoTabView`).

### Modal Interactions
*   **Actions:** Use `CupertinoActionSheet` for menus, options, and filtering. Avoid floating dialogs or bottom sheets that don't match iOS style.
*   **Pickers:** Use `CupertinoDatePicker` or `CupertinoPicker` presented in a bottom modal popup.
*   **Alerts:** Use `CupertinoAlertDialog` for destructive confirmations or critical errors.

## 3. Lists & Data Presentation

### List Style
*   **Appearance:** Use a flat list design on `CupertinoColors.systemBackground`.
*   **Separators:** Use `Divider` with an indentation (`indent`) matching the text alignment (e.g., `indent: 76` if there is a leading icon/thumbnail).
*   **Selection:** Use `InkWell` (wrapped in `Material` with `type: MaterialType.transparency`) or `GestureDetector` to provide touch feedback.

### Row Layout (Mail Style)
*   **Compactness:** Prefer 2-line layouts for density.
    *   **Line 1:** Primary Info (Bold) ---------- Secondary Info/Value (Regular/Gray).
    *   **Line 2:** Status Indicator + Details (Gray).
*   **Status Indicators:**
    *   Avoid heavy colored badges/labels.
    *   Use **Status Dots** (small colored circles, e.g., `CupertinoIcons.circle_fill`, size 8-10) to indicate state (Blue=New/Approved, Green=Done, Red=Issue).
    *   Status text should be secondary (gray).

### Swipe Actions
*   **Pattern:** Use `Dismissible` or similar swipe widgets.
*   **Right Swipe (StartToEnd):** **Edit/Action** (Background: System Blue).
*   **Left Swipe (EndToStart):** **Delete/Destructive** (Background: System Red).

## 4. Selection Lists (Pickers)

Screens used to select an entity (e.g., Selecting a Customer for an Order) should follow this pattern:

*   **Mode Detection:** The screen should detect if it's in "Selection Mode" (usually via route arguments).
*   **Navigation Bar:**
    *   **Title:** Entity Name (e.g., "Clientes").
    *   **Trailing:** "Add" button (`CupertinoIcons.add`) to create a new entity inline.
*   **Interaction:**
    *   **Tap:**
        *   *Selection Mode:* Returns the selected object (`Navigator.pop(context, result)`).
        *   *Standard Mode:* Navigates to detail/edit screen.
    *   **Visual Cue:** Use a standard chevron (`chevron_right`) for all items. Do not use different icons for selection to keep the UI clean.
*   **Creation Flow:** If a new entity is created via the trailing "Add" button, it should ideally return the new entity to the selection screen, which can then immediately return it to the caller (auto-selection) or let the user select it.

## 5. Forms & Input

### Layout
*   **Grouping:** Use `CupertinoListSection.insetGrouped` or visually similar styling for forms.
    *   Rounded corners (radius ~10-12).
    *   Background: `CupertinoColors.secondarySystemGroupedBackground` (White in light mode).
    *   Canvas Background: `CupertinoColors.systemGroupedBackground` (Light Gray).
*   **Labels:** Labels should be on the left, values on the right (or placeholders).

### Inputs
*   **Search:** Use `CupertinoSearchTextField`.
*   **Text Fields:** Use `CupertinoTextField` with `BoxDecoration` removed (borderless) inside list items, or standard rounded style for search.

## 5. Typography & Colors

### Fonts
*   Use the system font stack (San Francisco).
*   **Hierarchy:**
    *   **Large Title:** 34pt, Bold.
    *   **Headline:** 17pt, Semibold (List Titles).
    *   **Body:** 17pt, Regular.
    *   **Subhead/Caption:** 15pt, Regular, Gray (`secondaryLabel`).

### Colors
*   **System Colors:** Always use `CupertinoColors` constants (e.g., `systemBlue`, `systemRed`, `label`, `secondaryLabel`, `systemGroupedBackground`).
*   **Dark Mode:** Rely on system colors which adapt automatically to dark mode.

## 6. Implementation Example (Order List Item)

```dart
// Example of a compliant list item
Container(
  color: CupertinoColors.systemBackground,
  child: Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: () { ... },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildThumbnail(order), // Left
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      // Top: Customer --- Value
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(customerName, style: ...fontWeight: FontWeight.w600...),
                          Text(value, style: ...color: CupertinoColors.secondaryLabel...),
                        ],
                      ),
                      // Bottom: Dot + Status + Details
                      Row(
                        children: [
                          Icon(CupertinoIcons.circle_fill, size: 8, color: statusColor),
                          Text("Status • Details", style: ...color: CupertinoColors.secondaryLabel...),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(indent: 76, height: 1, color: CupertinoColors.separator),
        ],
      ),
    ),
  ),
)
```
