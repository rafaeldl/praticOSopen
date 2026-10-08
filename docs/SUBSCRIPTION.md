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

The `subscription` field is embedded in the `/companies/{companyId}` document. The
server schema (`firebase/functions/src/models/types.ts`) is canonical: plan fields are
written only by Cloud Functions; clients may change only `usage` (see "Firestore rules").

```json
{
  "subscription": {
    "plan": "pro",
    "status": "active",
    "source": "store",
    "store": "app_store",
    "rcSubscriberId": "<companyId>",
    "expiresAt": "2026-11-07T12:00:00Z",
    "updatedAt": "2026-10-07T12:00:00.000Z",
    "limits": {
      "photosPerMonth": 500,
      "formTemplates": 10,
      "users": 5,
      "pdfWatermark": false
    },
    "usage": {
      "photosThisMonth": 45,
      "formTemplatesActive": 2,
      "usersActive": 2,
      "usageResetAt": "2026-11-01T00:00:00.000Z"
    }
  }
}
```

| Field | Values | Notes |
|-------|--------|-------|
| `source` | `store` \| `grace` | `store` = state read from RevenueCat; `grace` = launch grace period (60 days of Pro) |
| `store` | `app_store` \| `play_store` \| `null` | Store of the active subscription |
| `expiresAt` | ISO string \| `null` | End of the paid period or of the grace period; `null` = no expiry |

### Status Values

| RevenueCat state | `status` | Access |
|------------------|----------|--------|
| Active entitlement, auto-renew on | `active` | Paid plan |
| Active entitlement, auto-renew off | `cancelled` | Paid plan until `expiresAt` |
| Active entitlement with billing issue / store grace period | `past_due` | Paid plan |
| No active entitlement | `expired` (`plan` = `free`) | Free |

Effective plan on the client: `plan` while `expiresAt` is null or in the future, otherwise Free.

**Known limitation:** app versions <= 1.55 cannot parse the statuses `cancelled` and
`past_due`; those clients fail to read the subscription of such companies until updated.

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

## iOS: No Paid Features (App Review 3.1.1)

The iOS app has **no paid features and no purchase UI**. Apple rejected versions
1.51.0, 1.52.0 and 1.52.2 under guideline 3.1.1 (Payments - In-App Purchase):
first for selling subscriptions outside IAP, then for accessing paid content that
is not sold through IAP. Since the app has no IAP, iOS must not gate anything.

Two platform switches implement this:

| Switch | File | Effect on iOS |
|--------|------|---------------|
| `SubscriptionService.purchaseUiEnabled` | `lib/services/subscription_service.dart` | Hides the Subscription section in Settings, the plans and manage screens, upgrade CTAs and the `upgrade` / `plans` / `restore` / `subscription` deep links |
| `FeatureGateService.planLimitsEnforced` | `lib/services/feature_gate_service.dart` | Every limit becomes `-1` (unlimited): photos, form templates, collaborators. No PDF watermark |

Rules:

- Android and web keep plans, limits and purchase UI unchanged.
- Usage counters (`subscription.usage.*`) are still incremented on iOS, so limits
  keep working for the same company on other platforms.
- The App Review notes sent by fastlane (`ios/fastlane/Deliverfile` and
  `ios/fastlane/metadata/review_information/notes.txt`) state this behaviour.
  Keep them true: if limits return to iOS, or if any plan starts being sold on
  any platform, update the notes.
- 1.53.0 was rejected again under 3.1.1, now for "account registration for
  businesses", because the old notes said paid plans existed on the website.
  No plan is sold anywhere (RevenueCat is disabled), so the notes now say that
  registration is free, nothing is purchasable on any platform, and future paid
  plans will use In-App Purchase on iOS. Never describe paid plans as available
  outside the app in the notes.
- **The website must not show prices while iOS has no In-App Purchase.**
  The 1.53.0 rejection also came from `praticos.web.app` (the app's marketing
  URL) showing a Free/Starter/Pro price table, plan limits and "upgrade" CTAs,
  which contradicted the notes. The pricing page, the plans section on the home
  and segment pages, the "Planos" menu item and every plan/price mention in the
  FAQ, support, terms and segment pages were removed; `/pricing*.html` now
  301-redirects to the home page (`firebase/firebase.json`). Do not bring back
  prices, plan names, plan limits or "upgrade" language on the site until paid
  plans are sold on iOS through In-App Purchase.
- To restore limits on iOS: ship In-App Purchase first (see
  `docs/IAP_IMPLEMENTATION_PLAN.md`), then remove both platform checks.

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

## Server (Cloud Functions)

Code: `firebase/functions/src/routes/webhooks/revenuecat.routes.ts`,
`src/services/subscription.service.ts`, `src/services/subscription-plans.ts` (pure rules)
and `src/services/revenuecat.client.ts`.

### Webhook `POST /webhooks/revenuecat`

- URL: `https://southamerica-east1-praticos.cloudfunctions.net/api/webhooks/revenuecat`.
- **Auth:** RevenueCat sends the `Authorization` header value configured on the webhook.
  It must be exactly equal to the `REVENUECAT_WEBHOOK_AUTH` secret (constant-time compare).
  There is no signature header.
- **Authoritative state:** the event only tells which company changed (`app_user_id` =
  `companyId`; `TRANSFER` also syncs the origin and destination ids). For each company the
  function calls `GET https://api.revenuecat.com/v1/subscribers/{companyId}` with
  `REVENUECAT_SECRET_API_KEY` and writes the current state. Repeated or out-of-order
  events are harmless.
- **Effective plan:** highest active entitlement (`business` > `pro` > `starter`); none: `free`.
- **Writes** only `plan`, `status`, `limits`, `expiresAt`, `store`, `source` (`store`),
  `rcSubscriberId` and `updatedAt`, by dotted path. Never touches `usage`.
- **Grace kept:** with `source == 'grace'`, `expiresAt` in the future and no active
  entitlement in RevenueCat, nothing is written.
- **Responses:** `500` when a secret is missing (nothing processed), `401` bad
  `Authorization`, `400` no event, `200` processed or ignored (anonymous ids, unknown
  company), `500` on processing errors so RevenueCat retries.

### Daily expiry `scheduledExpireSubscriptions`

Daily at 04:30 America/Sao_Paulo (timeout 540s, concurrency 5). Companies with
`subscription.plan` in starter/pro/business and `expiresAt` in the past are re-synced from
RevenueCat: renewed ones get the new `expiresAt`, the rest drop to Free (`expired`).
Covers the end of the grace period and missed webhooks. A grace company that never
opened the paywall has no RevenueCat customer yet; `GET /v1/subscribers/{companyId}`
creates one (empty, no entitlements) and the company drops to Free. Harmless: it is the
same id the app logs in with later.

### Monthly usage reset `scheduledResetMonthlyUsage`

1st of each month, 03:00 America/Sao_Paulo. Sets `usage.photosThisMonth = 0` and
`usage.usageResetAt` (next 1st, 00:00 UTC) for every company with
`subscription.usage.photosThisMonth > 0` (single-field query, automatic index). This
includes a `subscription` map without `plan` (only `usage`, created by the app's dotted
usage updates; treated as Free everywhere). Companies already at 0 are not written.

### Launch grace period

`firebase/functions/scripts/grant-grace-period.ts`, run once before paid plans ship.
Gives 60 days of Pro (`source: 'grace'`) to every company without an active paid store
subscription, keeps `usage`, and skips companies already in grace (re-running does not
extend it). Dry-run by default; prints only totals.

```bash
cd firebase/functions
npm run subscriptions:grace -- --project=praticos            # dry-run
npm run subscriptions:grace -- --project=praticos --apply    # write
# optional: --days=N overrides the 60-day length
```

### Firestore rules

In both `match /companies/...` blocks, an update by owner/admin may change only `usage`
inside `subscription`, plus the legacy keys the app up to 1.55 writes back when saving the
company (`id`, `currentPeriodStart`, `currentPeriodEnd`, `revenueCatCustomerId`; ignored by
the server). On create, `subscription` must be absent, `null` or Free without server fields.
Accepted limitation: a member with write access can lower its own usage counter.
Rules are not published by CI: `firebase deploy --only firestore:rules --project praticos`.
Rules tests (`npm run test:rules` in `firebase/functions`) need JDK 21+ for the emulator.

### Secrets

| Secret (Secret Manager) | Bound to | Value |
|-------------------------|----------|-------|
| `REVENUECAT_WEBHOOK_AUTH` | `api` | Exact `Authorization` header value set in RevenueCat > Integrations > Webhooks |
| `REVENUECAT_SECRET_API_KEY` | `api`, `scheduledExpireSubscriptions` | RevenueCat secret API key (`sk_...`, API v1) |

```bash
openssl rand -hex 32   # value for the webhook Authorization header
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project praticos
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY --project praticos
```

Both must exist before Functions are deployed (CI deploys on push to `master` and fails
on an undefined secret). For the emulator, put both in `firebase/functions/.secret.local`
(gitignored).

---

## Testing Without RevenueCat Keys

If `REVENUECAT_ANDROID_API_KEY` / `REVENUECAT_IOS_API_KEY` are not set (e.g., local dev builds), `SubscriptionService` skips initialization gracefully. All users default to the Free plan with Free plan limits applied.

To test paid plan behavior locally, manually update the `subscription` field in the Firestore company document for a test company.
