# WEB_PORTAL.md - PraticOS Web Portal

## Overview

PraticOS Web Portal enables the existing Flutter app to run in a browser with an adaptive layout that switches between mobile and desktop experiences based on screen width.

## Architecture

### Adaptive Layout System

The responsive infrastructure lives in `lib/responsive/`:

```
lib/responsive/
├── breakpoints.dart          # Breakpoint constants + ScreenSize enum
├── responsive_builder.dart   # Builder widget that passes ScreenSize
├── responsive_layout.dart    # Mobile/tablet/desktop widget switcher
├── adaptive_scaffold.dart    # Drop-in adaptive layout (tabs vs sidebar)
├── adaptive_widgets.dart     # Platform detection helpers
└── desktop_sidebar.dart      # Desktop navigation sidebar
```

### Breakpoints

| Screen Size | Width | Layout |
|-------------|-------|--------|
| Mobile | < 768px | CupertinoTabBar (bottom tabs) |
| Tablet | 768 - 1024px | Desktop sidebar |
| Desktop | > 1024px | Desktop sidebar |

### AdaptiveScaffold

`AdaptiveScaffold` is a drop-in replacement for `CupertinoTabScaffold` that:

- **Mobile (< 768px)**: Renders the standard `CupertinoTabScaffold` with `CupertinoTabBar` — zero change to current mobile behavior.
- **Desktop (>= 768px)**: Renders a `Row` with `DesktopSidebar` + content area. Each tab has its own `Navigator` with `appRoutes` to preserve per-tab navigation stacks.

### Desktop Sidebar

`DesktopSidebar` features:
- PraticOS branding at the top
- Vertical navigation items with icons + labels
- Active item highlighting with blue accent
- Collapsible mode (icon-only) via toggle button
- Animated width transitions
- Dark mode support with dynamic Cupertino colors

### Data Flow

```
NavigationController
    ├── Builds SidebarDestinations (icon, activeIcon, label)
    ├── Builds BottomNavigationBarItems (same data, for mobile)
    ├── Builds page widgets (Home, Customers, Agenda, Financial, Settings)
    └── Passes all to AdaptiveScaffold
            ├── Mobile → CupertinoTabScaffold + CupertinoTabBar
            └── Desktop → Row(DesktopSidebar, IndexedStack(Navigators))
```

## How to Run on Web

### Development

```bash
# Build and run in Chrome
fvm flutter run -d chrome

# Build only
fvm flutter build web
```

### Firebase Configuration

The web build uses `lib/firebase_options.dart` for Firebase configuration. This file is generated/maintained manually with the web project config. iOS/Android continue to use their native config files (GoogleService-Info.plist, google-services.json).

### Platform Guards

Files that use `dart:io` (Platform checks, File I/O) have `kIsWeb` guards to prevent runtime errors on web:

- `Platform.isIOS` / `Platform.isAndroid` calls are wrapped with `if (!kIsWeb)` checks
- `NotificationStore.initialize()` is skipped on web (FCM is mobile-only)
- `FirebaseCrashlytics` is skipped on web (not supported)
- File operations in photo/image services use `dart:io` stubs (available in Flutter Web JS target)

## Known Limitations

### Phase 0 Scope

1. **No URL-based deep linking** — The app uses `Navigator.push()` with named routes, not `go_router`. Deep linking (e.g., `/orders/123`) will be added in a future phase.
2. **Photo operations** — Camera and file-based photo operations won't work on web. A web-specific file upload (drag-and-drop, file picker) will be needed.
3. **Push notifications** — FCM is mobile-only. Web notifications will require a separate implementation.
4. **Bundle size** — First load may be large. Code splitting and deferred loading are future optimizations.

### Browser Support

- Chrome (recommended)
- Firefox
- Safari
- Edge

## Responsive Utilities

### Using ResponsiveBuilder

```dart
import 'package:praticos/responsive/responsive_builder.dart';

ResponsiveBuilder(
  builder: (context, screenSize) {
    if (screenSize == ScreenSize.desktop) {
      return WideLayout();
    }
    return NarrowLayout();
  },
)
```

### Using ResponsiveLayout

```dart
import 'package:praticos/responsive/responsive_layout.dart';

ResponsiveLayout(
  mobile: MobileView(),
  tablet: TabletView(), // optional, falls back to mobile
  desktop: DesktopView(), // optional, falls back to tablet then mobile
)
```

### Checking Platform

```dart
import 'package:praticos/responsive/adaptive_widgets.dart';

if (isDesktopLayout(context)) {
  // Screen width >= 768px
}

if (isWebPlatform()) {
  // Running on Flutter Web
}
```

## Phase 1 Roadmap

Future web portal phases will include:

- **Phase 1**: Adapt key screens (Orders, Customers) for wide layouts
- **Phase 2**: Web-specific features (drag-and-drop, keyboard shortcuts)
- **Phase 3**: go_router migration for URL-based deep linking
- **Phase 4**: Performance optimization (code splitting, lazy loading)
