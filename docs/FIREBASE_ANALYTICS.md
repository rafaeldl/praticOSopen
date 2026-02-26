# FIREBASE_ANALYTICS.md

## Overview

Firebase Analytics custom events for measuring the install → registration → activation funnel and feature adoption. The app previously only had automatic screen tracking via `FirebaseAnalyticsObserver`.

## Architecture

### AnalyticsService (`lib/services/analytics_service.dart`)

Singleton service (same pattern as `FormatService`, `SegmentConfigService`):

```dart
AnalyticsService.instance.logOrderCreated(orderId: '...');
```

Key design decisions:
- **Fire-and-forget**: All methods are void. A `_safe()` wrapper catches errors and sends them to Crashlytics — analytics never blocks the UI.
- **Built-in events**: Uses Firebase's typed methods where available (`logLogin`, `logSignUp`, `logShare`, `logTutorialBegin`, `logTutorialComplete`) for better integration with Google Ads conversions.
- **Custom events**: Uses `logEvent` for domain-specific events (`order_created`, `customer_created`, etc.).
- **User identity**: `identifyUser()` sets `userId`, user properties (`company_id`, `segment`, `user_role`), and default event parameters.

### Helper: `getAuthMethod()`

Detects auth provider from `FirebaseAuth.instance.currentUser.providerData`:
- `google.com` → `'google'`
- `apple.com` → `'apple'`
- `password` → `'email'`

## Events

### P1 — Install → Activation Funnel

| Event | Type | File | Trigger |
|-------|------|------|---------|
| `login` | built-in | `auth_store.dart` | After company loaded (with `has_company` param) |
| `login` | built-in | `auth_store.dart` | After auth without company (goes to onboarding) |
| `sign_up` | built-in | `user_store.dart` | After creating new user document in Firestore |
| `tutorial_begin` | built-in | `welcome_screen.dart` | When user taps "Configure" (`variant: setup`) or "Skip" (`variant: skip`) |
| `company_created` | custom | `confirm_bootstrap_screen.dart` | After `createCompanyForUser()` in the CREATE branch |
| `tutorial_complete` | built-in | `confirm_bootstrap_screen.dart` | Before navigating away from onboarding |

### P2 — Engagement & Activation

| Event | Type | File | Trigger |
|-------|------|------|---------|
| `order_created` | custom | `order_store.dart` | After `repository.createItem()` succeeds (both with/without order number) |
| `customer_created` | custom | `customer_store.dart` | After `repository.createItem()` in `saveCustomer` |
| `share` | built-in | `share_link_service.dart` | After `SharePlus.share()`, `launchUrl()` (WhatsApp), or `Clipboard.setData()` |

### P3 — Feature Adoption

| Event | Type | File | Trigger |
|-------|------|------|---------|
| `photo_uploaded` | custom | `order_store.dart` | After successful upload in `_uploadPhoto` (with `source: camera/gallery`) |
| `payment_added` | custom | `order_store.dart` | After `addPayment()` updates the order |
| `collaborator_invited` | custom | `collaborator_store.dart` | In `addCollaborator()` — both invite and direct paths (with `method: invite/direct`) |
| `invite_accepted` | custom | `invite_store.dart` | After `waitForCompanyClaim()` in `acceptInvite` |

### User Properties

Set via `identifyUser()` on login:

| Property | Source |
|----------|--------|
| `userId` | `FirebaseAuth.uid` |
| `company_id` | `company.id` |
| `segment` | `company.segment` |
| `user_role` | `user.companies[].role.name` |

Cleared via `clearUser()` on sign-out.

## Verification

### Enable Debug Mode

```bash
# Android
adb shell setprop debug.firebase.analytics.app br.com.rafsoft.praticos

# iOS (add to Xcode scheme arguments)
-FIRDebugEnabled
```

### Test Checklist

1. Open Firebase Console → Analytics → DebugView
2. Login → verify `login` event + user properties
3. New user → verify `sign_up`
4. Onboarding flow → `tutorial_begin` → `company_created` → `tutorial_complete`
5. Create order → `order_created` with params
6. Create customer → `customer_created`
7. Upload photo → `photo_uploaded` with `source`
8. Add payment → `payment_added`
9. Share order → `share` with correct `method`
10. Invite collaborator → `collaborator_invited`
11. Accept invite → `invite_accepted`

### Disable Debug Mode

```bash
# Android
adb shell setprop debug.firebase.analytics.app .none.

# iOS: remove -FIRDebugEnabled from scheme
```

## Files Modified

- **NEW**: `lib/services/analytics_service.dart`
- `lib/mobx/auth_store.dart` — login, identifyUser, clearUser
- `lib/mobx/user_store.dart` — sign_up
- `lib/mobx/order_store.dart` — order_created, photo_uploaded, payment_added
- `lib/mobx/customer_store.dart` — customer_created
- `lib/mobx/collaborator_store.dart` — collaborator_invited
- `lib/mobx/invite_store.dart` — invite_accepted
- `lib/services/share_link_service.dart` — share (3 variants)
- `lib/screens/onboarding/welcome_screen.dart` — tutorial_begin
- `lib/screens/onboarding/confirm_bootstrap_screen.dart` — company_created, tutorial_complete
