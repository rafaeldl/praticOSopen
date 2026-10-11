# PraticOS UX/UI Guidelines

This document outlines the design principles and coding standards for the PraticOS application, focusing on a strict adoption of Apple's **Human Interface Guidelines (HIG)** to ensure a native, high-quality iOS experience.

> **Colors, typography, screen structure, list components and status colors live in [`APP_DESIGN_SYSTEM.md`](APP_DESIGN_SYSTEM.md).** When this document and the design system differ, the design system wins. This document covers widget choice and interaction patterns.

## 1. Core Philosophy

*   **Native First:** Prioritize `Cupertino` widgets over Material Design widgets. The app should feel indistinguishable from a native iOS app.
*   **Content Centric:** Reduce visual clutter. Use whitespace, typography, and color sparingly to highlight content.
*   **Direct Manipulation:** Use gestures (swipes, taps, long presses) for common actions.

## 2. Navigation & Structure

### Scaffold & Bars
*   **Scaffold:** Always use `CupertinoPageScaffold`.
*   **Navigation Bar:** Use `CupertinoSliverNavigationBar` with `largeTitle` for main screens (Home, Lists) to enable the collapsing title effect. Use `CupertinoNavigationBar` for modal or detail screens.
*   **Tab Bar:** Use `CupertinoTabScaffold` with the `GlassTabBar` (tab order and visibility: `visibleAppTabs()`, see `APP_DESIGN_SYSTEM.md`).
    *   **Icons:** Use `CupertinoIcons` (SF Symbols style).
    *   **Behavior:** Each tab maintains its own navigation stack (`CupertinoTabView`).

### Modal Interactions
*   **Actions:** Use `CupertinoActionSheet` for menus, options, and filtering. Avoid floating dialogs or bottom sheets that don't match iOS style.
*   **Pickers:** Use `CupertinoDatePicker` or `CupertinoPicker` presented in a bottom modal popup.
*   **Alerts:** Use `CupertinoAlertDialog` for destructive confirmations or critical errors.

## 3. Lists & Data Presentation

### List Style
*   **Components:** Use `AppListRow`, `SectionLabel`, `EmptyState`, `ErrorState` and `LoadingState` (`lib/screens/widgets/`). Layout, colors and status dots: see "Componentes de lista" and "Cores" in `APP_DESIGN_SYSTEM.md`.
*   **Status Indicators:** A colored dot plus status text in `textSecondary`. Never a colored badge.

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
    *   **Background:** The page scaffold uses `AppColors.background.resolveFrom(context)`.
*   **Structure:**
    1.  **Header/Photo:** If the entity has an image (Product, Service, etc.), place the photo picker at the very top, centered, outside the grouped section.
    2.  **Fields:** Group related fields inside `CupertinoListSection.insetGrouped`.
*   **Presentation:** Creating something new ("Novo cliente", "Novo serviço") opens as a large sheet with "Cancelar" on the left and the full-width primary button at the bottom as confirmation. Editing something that already exists opens pushed, with "Voltar". See rule 9 in `APP_DESIGN_SYSTEM.md`.

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

## 6. Typography, Colors & Dark Mode

See [`APP_DESIGN_SYSTEM.md`](APP_DESIGN_SYSTEM.md): `AppColors` roles resolved with `.resolveFrom(context)` (light, dark and Increase Contrast), `AppTypography` with Dynamic Type, and `AppSpacing`/`AppSizes`/`AppRadii`. Raw `CupertinoColors` and `lib/theme/app_theme.dart` are the old pattern, kept only on screens not yet redesigned.
