# Subscription System - PraticOS

**Date:** 2026-04-04
**Status:** Implemented (pending RevenueCat credentials)
**Related Issues:** PRA-11 (IAP), PRA-12 (Plans Screen), PRA-13 (Feature Gates)

---

## Overview

PraticOS uses a subscription model with four plans, managed through RevenueCat for cross-platform in-app purchase handling. Feature gates automatically limit functionality based on the active plan.

---

## Plans & Limits

| Feature | Free | Starter (R$59/mo) | Pro (R$119/mo) | Business (R$249/mo) |
|---------|------|-------------------|----------------|----------------------|
| Photos/month | 30 | 200 | 500 | Unlimited (-1) |
| Form templates | 1 | 3 | 10 | Unlimited (-1) |
| Users | 1 | 3 | 5 | Unlimited (-1) |
| PDF watermark | Yes | No | No | No |

Unlimited is represented as `-1` in the codebase and Firestore.

---

## Architecture

```
RevenueCat SDK (purchases_flutter)
           ↓
   SubscriptionService          lib/services/subscription_service.dart
           ↓
   SubscriptionStore (MobX)     lib/mobx/subscription_store.dart
           ↓
   Company.subscription         lib/models/subscription.dart
   (synced to Firestore)
           ↓
   FeatureGateService           lib/services/feature_gate_service.dart
           ↓
   UI screens + widgets
```

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/subscription.dart` | Data models: `Subscription`, `SubscriptionLimits`, `SubscriptionUsage` |
| `lib/models/subscription.g.dart` | Generated JSON serialization |
| `lib/services/subscription_service.dart` | RevenueCat SDK wrapper (initialize, purchase, restore) |
| `lib/services/feature_gate_service.dart` | Checks limits and returns `FeatureGateResult` |
| `lib/mobx/subscription_store.dart` | Reactive state: current plan, offerings, purchase flow |
| `lib/mobx/subscription_store.g.dart` | Generated MobX code |
| `lib/screens/subscription/plans_screen.dart` | Plan comparison + purchase UI |
| `lib/screens/subscription/subscription_success_screen.dart` | Post-purchase confirmation |
| `lib/exceptions/feature_gate_exception.dart` | Exception thrown when feature gate is blocked |

---

## Firestore Data Model

The `subscription` field is embedded in the `/companies/{companyId}` document:

```json
{
  "subscription": {
    "plan": "starter",
    "status": "active",
    "rcSubscriberId": "usr_xxx",
    "subscribedAt": "2026-04-01T00:00:00Z",
    "expiresAt": "2026-05-01T00:00:00Z",
    "limits": {
      "photosPerMonth": 200,
      "formTemplates": 3,
      "users": 3,
      "pdfWatermark": false
    },
    "usage": {
      "photosThisMonth": 45,
      "formTemplatesActive": 2,
      "usersActive": 2,
      "usageResetAt": "2026-04-01T00:00:00Z"
    }
  }
}
```

### Status Values
- `active` – subscription is paid and current
- `trialing` – in free trial period
- `past_due` – payment failed, grace period
- `cancelled` – cancelled, access until `expiresAt`
- `expired` – access ended

---

## RevenueCat Integration

### SDK Initialization

RevenueCat is initialized in `SubscriptionService.initialize(userId)`, called after successful login. The `userId` should be the company ID to correctly associate subscriptions per company.

API keys are injected at build time via `--dart-define`:

```bash
# Android build
flutter build appbundle --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx

# iOS build
flutter build ios --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
```

### CI/CD Secrets Required

Add these secrets to GitHub Actions (Settings → Secrets → Actions):

| Secret | Platform | Source |
|--------|----------|--------|
| `REVENUECAT_ANDROID_API_KEY` | Android | RevenueCat → Project Settings → API Keys → Public SDK Key (Android) |
| `REVENUECAT_IOS_API_KEY` | iOS | RevenueCat → Project Settings → API Keys → Public SDK Key (iOS) |

Both are already wired in `android_release.yml` and `ios_release.yml`.

### RevenueCat Product IDs

Configure these entitlement identifiers in RevenueCat dashboard to match the app's plans:

| Plan | Entitlement ID |
|------|----------------|
| Starter | `starter` |
| Pro | `pro` |
| Business | `business` |

---

## Feature Gates

`FeatureGateService` provides static check methods that return a `FeatureGateResult`:

```dart
// Check before adding a photo
final result = FeatureGateService.canAddPhoto(Global.companyAggr);
if (!result.isAllowed) {
  // Show upgrade prompt
  showUpgradeModal(context, suggestedPlan: result.suggestedPlan);
  return;
}
if (result.isNearLimit) {
  // Show soft warning (80%+ usage)
  showWarningBanner(context, message: result.message);
}

// Check before creating a form template
final result = FeatureGateService.canCreateFormTemplate(company);

// Check before adding a collaborator
final result = FeatureGateService.canAddUser(company);

// PDF watermark check
final showWatermark = FeatureGateService.shouldShowPdfWatermark(company);
```

### FeatureGateResult Properties

| Property | Type | Description |
|----------|------|-------------|
| `isAllowed` | bool | Whether the action is permitted |
| `currentUsage` | int | Current usage count |
| `limit` | int | Plan limit (-1 = unlimited) |
| `usagePercentage` | double | Usage ratio (0.0–1.0+) |
| `isNearLimit` | bool | True if usage ≥ 80% |
| `isAtLimit` | bool | True if usage ≥ 100% |
| `isUnlimited` | bool | True if limit == -1 |
| `message` | String? | Human-readable message for UI |
| `suggestedPlan` | String? | Plan ID to suggest for upgrade |

---

## Navigation Routes

| Route | Screen |
|-------|--------|
| `/subscription/plans` | `PlansScreen` – plan comparison and purchase |
| `/subscription/success` | `SubscriptionSuccessScreen` – post-purchase confirmation |

---

## Provider Setup

`SubscriptionStore` is registered as a Provider in `main.dart`:

```dart
Provider<SubscriptionStore>(create: (_) => SubscriptionStore()),
```

Access in widgets:
```dart
final subscriptionStore = context.read<SubscriptionStore>();
```

---

## Usage Reset

The `usage.usageResetAt` field tracks when usage counters were last reset. Usage is reset monthly. The reset logic should be implemented via a Firebase Cloud Function or as part of RevenueCat webhook handling.

---

## Testing Without RevenueCat Keys

If `REVENUECAT_ANDROID_API_KEY` / `REVENUECAT_IOS_API_KEY` are not set (e.g., local dev builds), `SubscriptionService` skips initialization gracefully. All users default to the Free plan with Free plan limits applied.

To test paid plan behavior locally, manually update the `subscription` field in the Firestore company document for a test company.
