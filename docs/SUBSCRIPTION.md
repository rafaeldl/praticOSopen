# Subscription System - PraticOS

**Date:** 2026-10-07
**Status:** Paid plans via In-App Purchase (RevenueCat)
**Spec:** `docs/superpowers/specs/2026-10-07-paid-plans-iap-design.md`

---

## Overview

PraticOS is freemium. Registering a company gives the Free plan. Starter, Pro and Business are auto-renewable monthly subscriptions sold **only inside the app**: App Store In-App Purchase on iOS and Google Play Billing on Android, both through RevenueCat. The web sells nothing.

Prices and periods come from the stores and are shown by the RevenueCat paywall. They are never hardcoded in the app, the website or these docs.

---

## Plans & Limits

| Feature | Free | Starter | Pro | Business |
|---------|------|---------|-----|----------|
| Photos/month | 30 | 200 | 500 | Unlimited (-1) |
| Form templates (active) | 1 | 3 | 10 | Unlimited (-1) |
| Users (members + pending invites) | 1 | 3 | 5 | Unlimited (-1) |
| PDF watermark | Yes | No | No | No |

Defaults live in `SubscriptionLimits.defaults` (`lib/models/subscription.dart`) and match the server.

---

## Architecture

```
App (iOS/Android)
  RevenueCat SDK ── purchase / restore ──▶ App Store / Google Play
        │                                        │
        │ appUserID = companyId                  ▼
        │                                   RevenueCat
        │                                        │ webhook (Authorization)
        ▼                                        ▼
  Firestore companies/{id}.subscription ◀── Function revenuecatWebhook
        │   (only the server writes plan/status)
        ▼
  SubscriptionStore (MobX, live listener) → Global.subscription → FeatureGateService → UI
```

### Identity

- The RevenueCat `appUserID` is the **company id**: the subscription belongs to the company.
- `AuthStore` calls `SubscriptionStore.bindCompany(companyId)` after login and on company switch. It starts the Firestore listener and calls `SubscriptionService.initialize(companyId)` (configures the SDK, or `Purchases.logIn` when already configured).
- `AuthStore` calls `SubscriptionStore.unbind()` on logout and account deletion: cancels the listener, clears `Global.subscription` and calls `Purchases.logOut()`.

### Products and entitlements

| Plan | Product (App Store and Play) | Entitlement |
|------|------------------------------|-------------|
| Starter | `praticos_starter_monthly` | `starter` |
| Pro | `praticos_pro_monthly` | `pro` |
| Business | `praticos_business_monthly` | `business` |

App Store subscription group `PraticOS`, ordered Business > Pro > Starter. RevenueCat offering `default` with the three packages. `SubscriptionService.entitlementIds` lists only these three.

---

## Platform switch: `paidPlansEnabled`

`SubscriptionService.paidPlansEnabled` is the single switch for SDK, purchase UI and limits, on iOS and Android alike:

- `true` only when the build has a real store key for the platform: `REVENUECAT_IOS_API_KEY` starting with `appl_` on iOS, `REVENUECAT_ANDROID_API_KEY` starting with `goog_` on Android.
- `SubscriptionService.purchaseUiEnabled` and `FeatureGateService.planLimitsEnforced` follow it.
- Without the key (local builds, CI without secrets, web), the app is unlimited and has no purchase UI. This avoids enforcing limits with no way to buy.
- A Test Store key (`test_`) configures the SDK in debug builds only, and never turns paid plans on.
- Tests use `SubscriptionService.debugPaidPlansEnabledOverride` and `FeatureGateService.debugPlanLimitsEnforcedOverride` (reset to `null` in `tearDown`).

```bash
flutter build ios --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
flutter build appbundle --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
```

GitHub secrets `REVENUECAT_IOS_API_KEY` and `REVENUECAT_ANDROID_API_KEY` are wired in `ios_release.yml` and `android_release.yml`.

---

## Firestore Data Model (server-owned)

`companies/{companyId}.subscription`, written by the RevenueCat webhook:

```json
{
  "plan": "pro",
  "status": "active",
  "source": "store",
  "store": "app_store",
  "expiresAt": "2026-11-07T12:00:00.000Z",
  "limits": { "photosPerMonth": 500, "formTemplates": 10, "users": 5, "pdfWatermark": false },
  "usage": {
    "photosThisMonth": 45,
    "formTemplatesActive": 2,
    "usersActive": 2,
    "usageResetAt": "2026-10-01T00:00:00.000Z"
  },
  "rcSubscriberId": "<companyId>",
  "updatedAt": "2026-10-07T12:00:00.000Z"
}
```

| `status` | Meaning |
|----------|---------|
| `active` | Paid and renewing |
| `cancelled` | Renewal off; access kept until `expiresAt` |
| `past_due` | Billing retry or grace period; access kept |
| `expired` | No active entitlement; `plan` is `free` |

`source` is `store` (paid through a store) or `grace` (60 days of Pro granted to existing companies at launch).

### Client rules

- `Subscription.fromJson` reads the server schema. Unknown `status` becomes `active`, unknown `plan` becomes `free`. Legacy client keys are read as fallback: `usage.formTemplates` → `formTemplatesActive`, `usage.collaborators` → `usersActive`, `limits.collaborators` → `users`.
- **Effective plan:** `Subscription.effectivePlan(now)` is `plan` while `expiresAt` is null or in the future, `free` afterwards. `effectiveLimits(now)` follows it. The app does not wait for the server's daily expiration job.
- The app **never writes** `plan`, `status`, `limits` or dates. `Company.subscription` is `@JsonKey(includeToJson: false)`, so saving a company never sends it back.
- The app only writes the usage counters, through `SubscriptionUsagePaths` (collection `companies`):
  - `subscription.usage.photosThisMonth` (`FieldValue.increment(1)`, `PhotoService`)
  - `subscription.usage.formTemplatesActive` (`FormTemplateStore`)
  - `subscription.usage.usersActive` (`CollaboratorStore`, members + pending invites)

---

## Usage Reset (server)

`usage.usageResetAt` marks the last reset of the usage counters. The monthly Function `scheduledResetMonthlyUsage` (`firebase/functions`) zeroes `photosThisMonth`. Webhook, expiration job and reset details are documented with the server changes.

---

## Feature Gates

`FeatureGateService` returns a `FeatureGateResult` from the **effective** plan of `Global.subscription` (null = Free):

```dart
final result = FeatureGateService.canAddPhoto(Global.subscription);
if (!result.isAllowed) {
  showFeatureLimitDialog(context, result); // lib/widgets/photo_limit_dialog.dart
  return;
}

FeatureGateService.canAddPhotos(Global.subscription, count);
FeatureGateService.canCreateFormTemplate(Global.subscription);
FeatureGateService.canAddCollaborator(Global.subscription);
FeatureGateService.shouldShowPdfWatermark(Global.subscription);
```

Stores throw `FeatureGateLimitException` (`lib/services/feature_gate_service.dart`); screens catch it and call `showFeatureLimitDialog`.

| Property | Type | Description |
|----------|------|-------------|
| `isAllowed` | bool | Whether the action is permitted |
| `currentUsage` | int | Current usage count |
| `limit` | int | Plan limit (-1 = unlimited) |
| `usagePercentage` | double | Usage ratio (0.0–1.0+) |
| `isNearLimit` | bool | True if usage ≥ 80% |
| `isAtLimit` | bool | True if usage ≥ 100% |
| `isUnlimited` | bool | True if limit == -1 |
| `currentPlan` | SubscriptionPlan | Effective plan |
| `suggestedUpgrade` | SubscriptionPlan? | Next plan with a higher limit |

---

## Purchase UI: `PaywallLauncher`

`lib/services/paywall_launcher.dart` is the only entry point for buying:

| Method | What it does |
|--------|--------------|
| `showPaywall(context)` | RevenueCat paywall (offering `default`): store price and period, auto-renewal text, Terms of Use, Privacy Policy, Restore |
| `showCustomerCenter(context)` | RevenueCat Customer Center: manage, cancel, change plan |
| `restore(context)` | `Purchases.restorePurchases()` and the real result (success, nothing found, error) |
| `canPurchase(role)` | `owner` or `admin` |

Only `owner`/`admin` can buy, manage or restore. Other members see "Ask your company admin to change the plan." (`askAdminToChangePlan`).

Entry points:

| Where | File |
|-------|------|
| More > Subscription (current plan, View plans, Manage subscription, Restore purchases) | `lib/screens/menu_navigation/settings.dart` |
| Photo limit dialog | `lib/widgets/photo_limit_dialog.dart` (`showPhotoLimitDialog`) |
| Form template and user limits | `showFeatureLimitDialog` in form template and collaborator screens |
| Deep links `upgrade`/`plans` (paywall), `subscription` (Customer Center), `restore` | `DeepLinkService.subscriptionLinkForPath` / `openSubscriptionLink` |

The paywall and Customer Center are configured in pt, en and es in the RevenueCat dashboard. There are no plan screens or routes in the app (`PlansScreen`, `SubscriptionSuccessScreen`, `ManageSubscriptionScreen` were removed).

Deleting the account warns that the store subscription must be cancelled in the store settings and links to it (`lib/utils/store_subscription.dart`).

---

## Paid plans via IAP (App Review 3.1.1)

Apple rejected 1.51.0, 1.52.0, 1.52.2 and 1.53.0 under guideline 3.1.1: first for selling subscriptions outside IAP, then for accessing paid content not sold through IAP, and finally for "account registration for businesses" counting as an external purchase mechanism. The fix is to sell every paid plan inside the app through In-App Purchase.

Rules:

- Every paid plan is sold through In-App Purchase on iOS and Google Play Billing on Android. Never add another way to pay for a plan (website, link, email, WhatsApp).
- Registration is free and gives the Free plan. The Free limits are lifted only by the IAP subscription.
- The App Review notes (`ios/fastlane/Deliverfile` and `ios/fastlane/metadata/review_information/notes.txt`) say the app is freemium, plans are sold through IAP, and the paywall is at More > Subscription > View plans with the demo account. Keep both files identical and true. The demo account must be owner/admin of its company.
- Resolution Center reply for the IAP submission: `ios/fastlane/app_review_reply_iap.txt`.
- **The website shows no prices.** It says "Start free. Paid plans available in the app." (pt/en/es) and never shows prices, plan limits or upgrade CTAs. `/pricing*.html` keeps redirecting to the home page (`firebase/firebase.json`).
- Before each submission: the three subscriptions are attached to the version, each with its review screenshot.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/models/subscription.dart` | `Subscription`, `SubscriptionLimits`, `SubscriptionUsage`, enums, `SubscriptionUsagePaths` |
| `lib/services/subscription_service.dart` | RevenueCat wrapper, `paidPlansEnabled` |
| `lib/mobx/subscription_store.dart` | `bindCompany`/`unbind`, live listener, `Global.subscription` |
| `lib/services/feature_gate_service.dart` | Limits from the effective plan |
| `lib/services/paywall_launcher.dart` | Paywall, Customer Center, restore, owner/admin rule |
| `lib/widgets/photo_limit_dialog.dart` | Limit dialog for photos, forms and users |
| `lib/utils/store_subscription.dart` | Delete-account warning and store subscription URL |

---

## Testing

- `fvm flutter test test/models/subscription_test.dart` — server and legacy formats, effective plan, usage paths.
- `fvm flutter test test/services/subscription_service_test.dart test/services/feature_gate_service_test.dart` — `paidPlansEnabled` on/off, limits.
- `fvm flutter test test/mobx/subscription_store_test.dart` — listener, company switch, unbind.
- `fvm flutter test test/services/paywall_launcher_test.dart test/widgets/photo_limit_dialog_test.dart` — buy button by role.
- Manual (sandbox iOS and Play license tester): buy, cancel, restore on another device, change plan; check `companies/{id}.subscription` in Firestore after each event.
