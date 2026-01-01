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

### Layout & Structure
*   **Grouping:** Use `CupertinoListSection.insetGrouped` for the main form container.
    *   This provides the standard iOS grouped table view look with rounded corners.
    *   **Background:** The page scaffold should use `CupertinoColors.systemGroupedBackground`.
*   **Structure:**
    1.  **Header/Photo:** If the entity has an image (Product, Service, etc.), place the photo picker at the very top, centered, outside the grouped section.
    2.  **Fields:** Group related fields inside `CupertinoListSection.insetGrouped`.
*   **Navigation Bar:**
    *   **Middle:** "Novo [Entidade]" or "Editar [Entidade]".
    *   **Trailing:** "Salvar" button (Text only, bold). Show a `CupertinoActivityIndicator` in place of the text while saving.

### Photo Input (Entity Avatar)
*   **Placement:** Top center of the scroll view.
*   **Widget:** Circular avatar (ClipOval) approx 100x100 size.
*   **Placeholder:** If no image exists, use a `Container` with a specific background color (`systemGrey5`) and a central icon (`CupertinoIcons`) representing the entity type.
*   **Edit Action:**
    *   Overlay a small camera icon (`CupertinoIcons.camera_fill`) in a blue circle (`activeBlue`) at the bottom-right of the avatar.
    *   **Interaction:** Tapping the avatar opens a `CupertinoActionSheet` with options: "Tirar Foto", "Escolher da Galeria", "Cancelar".
*   **Loading State:** Overlay a black transparent background with `CupertinoActivityIndicator` (white) when uploading.

### Input Fields (`CupertinoTextFormFieldRow`)
*   **Widget:** Use `CupertinoTextFormFieldRow` inside the list section.
*   **Label:** Use the `prefix` parameter for the field label (Text style fontSize: 16).
*   **Alignment:**
    *   **Text:** `textAlign: TextAlign.right` for the input value.
    *   **Placeholder:** standard placeholder on the right.
*   **Capitalization:** Use `TextCapitalization.sentences` for names and descriptions.
*   **Validation:** Return "Obrigatório" string for empty required fields.

### Currency Formatting
*   **Formatter:** Use `CurrencyTextInputFormatter`.
    *   **Configuration:** `locale: 'pt_BR'`, `symbol: 'R$'` (Note: **No space** after the symbol).
    *   **Controller:** Always use a `TextEditingController`. Initialize its text in `didChangeDependencies` using a helper method that matches the formatter's symbol.
    *   **Symbol Handling:** Ensure the symbol (`R$`) is consistent between the initial text generation and the formatter configuration to avoid input masking conflicts.
*   **Keyboard:** `TextInputType.number`.

### Inputs
*   **Search:** Use `CupertinoSearchTextField`.
*   **Text Fields:** Use `CupertinoTextField` with `BoxDecoration` removed (borderless) inside list items, or standard rounded style for search.

## 6. Typography & Colors

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

## 7. Dark Mode & Dynamic Colors

### CupertinoTheme Configuration
When using `MaterialApp` with Cupertino widgets, wrap the app content with `CupertinoTheme` to ensure dynamic colors resolve correctly:

```dart
MaterialApp(
  // ... other properties
  builder: (context, child) {
    final brightness = Theme.of(context).brightness;
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: brightness,
        primaryColor: CupertinoColors.activeBlue,
      ),
      child: child!,
    );
  },
)
```

### Dynamic Color Resolution
**Critical:** Most `CupertinoColors` are dynamic and require `.resolveFrom(context)` to adapt to light/dark mode.

#### Colors That Require `.resolveFrom(context)`
| Color | Light Mode | Dark Mode | Usage |
|-------|------------|-----------|-------|
| `CupertinoColors.label` | Black | White | Primary text |
| `CupertinoColors.secondaryLabel` | Gray | Light Gray | Secondary text, subtitles |
| `CupertinoColors.systemBackground` | White | Black | List backgrounds, cards |
| `CupertinoColors.systemGroupedBackground` | Light Gray | Black | Scaffold background |
| `CupertinoColors.secondarySystemGroupedBackground` | White | Dark Gray | Grouped section backgrounds |
| `CupertinoColors.systemGrey` | Gray | Gray | Icons, placeholders |
| `CupertinoColors.systemGrey5` | Very Light Gray | Very Dark Gray | Avatar placeholders |
| `CupertinoColors.separator` | Light Gray | Dark Gray | Dividers |

#### Colors That Do NOT Require Resolution (Static)
*   `CupertinoColors.white`
*   `CupertinoColors.black`
*   `CupertinoColors.activeBlue`
*   `CupertinoColors.systemRed`
*   `CupertinoColors.systemGreen`

### Implementation Pattern

```dart
// ✅ CORRECT - Dynamic color with resolution
Text(
  'Title',
  style: TextStyle(
    color: CupertinoColors.label.resolveFrom(context),
  ),
)

// ❌ WRONG - Dynamic color without resolution (won't adapt to dark mode)
Text(
  'Title',
  style: TextStyle(
    color: CupertinoColors.label, // Always resolves to light mode value
  ),
)
```

### Avoiding `const` with Dynamic Colors
Dynamic colors cannot be used inside `const` widgets because `.resolveFrom(context)` is a method call.

```dart
// ❌ WRONG - Will cause compilation error
const Icon(
  CupertinoIcons.person,
  color: CupertinoColors.systemGrey.resolveFrom(context), // ERROR!
)

// ✅ CORRECT - Remove const when using dynamic colors
Icon(
  CupertinoIcons.person,
  color: CupertinoColors.systemGrey.resolveFrom(context),
)

// ✅ ALSO CORRECT - Use Builder to get context
Builder(
  builder: (context) => Icon(
    CupertinoIcons.person,
    color: CupertinoColors.systemGrey.resolveFrom(context),
  ),
)
```

### Background Color Choices

| Context | Color to Use | Result |
|---------|--------------|--------|
| Page scaffold | `systemGroupedBackground` | Gray (light) / Black (dark) |
| List container | `systemBackground` | White (light) / Black (dark) |
| Grouped sections | `secondarySystemGroupedBackground` | White (light) / Dark Gray (dark) |
| Cards on gray background | `systemBackground` | White (light) / Black (dark) |

### Form Field Styling for Dark Mode
When using `CupertinoTextFormFieldRow` or custom form fields:

```dart
CupertinoTextFormFieldRow(
  // ... other properties
  style: TextStyle(
    color: CupertinoColors.label.resolveFrom(context),
  ),
)
```

### Avatar/Placeholder Icons

```dart
Container(
  decoration: BoxDecoration(
    color: CupertinoColors.systemGrey5.resolveFrom(context),
    shape: BoxShape.circle,
  ),
  child: Icon(
    CupertinoIcons.person,
    color: CupertinoColors.systemGrey.resolveFrom(context),
  ),
)
```

## 8. Implementation Example (Order List Item)

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
