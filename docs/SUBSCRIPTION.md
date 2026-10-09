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
- The CI secrets are the launch switch: a release build with a real `goog_`/`appl_` key turns paid plans on for every user of that platform. Keep a placeholder (e.g. `DISABLED`) in `REVENUECAT_ANDROID_API_KEY`/`REVENUECAT_IOS_API_KEY` until the server (webhook, rules) is deployed and the grace-period script has run.
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

**Known limitation:** app versions <= 1.55 cannot parse the statuses `cancelled` and `past_due`; those clients fail to read the subscription of such companies until updated.

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

The "Current plan" row shows `Subscription.periodState`: "Renews on {date}" for an active store subscription, "Valid until {date}" once auto-renew is off, "Courtesy until {date}" during the launch grace period and "Payment issue" when the store reports a billing problem; nothing on Free. "View plans" reads "Change plan" while a store subscription is in force (`hasStoreSubscription`). In TestFlight and sandbox a monthly subscription renews daily, so the date is one day ahead.

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
on an undefined secret). Each secret also needs the same IAM bindings as
`ASAAS_CREDENTIALS_KEY`: `roles/secretmanager.secretAccessor` for
`940190275097-compute@developer.gserviceaccount.com` and `roles/secretmanager.viewer` for
`github-actions-deployer@praticos.iam.gserviceaccount.com` (without the viewer binding the CI
deploy fails with 403 on `secretmanager.secrets.get`). For the emulator, put both in `firebase/functions/.secret.local`
(gitignored).

---

## Testing

- `fvm flutter test test/models/subscription_test.dart` — server and legacy formats, effective plan, usage paths.
- `fvm flutter test test/services/subscription_service_test.dart test/services/feature_gate_service_test.dart` — `paidPlansEnabled` on/off, limits.
- `fvm flutter test test/mobx/subscription_store_test.dart` — listener, company switch, unbind.
- `fvm flutter test test/services/paywall_launcher_test.dart test/widgets/photo_limit_dialog_test.dart` — buy button by role.
- Manual (sandbox iOS and Play license tester): buy, cancel, restore on another device, change plan; check `companies/{id}.subscription` in Firestore after each event.
