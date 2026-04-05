# Android GitHub Secrets Setup

To enable the Android Release workflow, you must add the following secrets to your GitHub repository settings (Settings > Secrets and variables > Actions).

## Required Secrets

All files must be encoded in Base64 before adding them as secrets.

### 1. `ANDROID_KEYSTORE_BASE64`
*   **Source File:** `android/app/rafsoft.keystore`
*   **Command to Generate:**
    ```bash
    base64 -i android/app/rafsoft.keystore | pbcopy
    ```
    *(Use `base64 -w 0` on Linux if needed)*

### 2. `ANDROID_PLAY_STORE_CREDENTIALS_BASE64`
*   **Source File:** `android/fastlane/play_store_credentials.json`
*   **Command to Generate:**
    ```bash
    base64 -i android/fastlane/play_store_credentials.json | pbcopy
    ```

### 3. `ANDROID_GOOGLE_SERVICES_JSON_BASE64`
*   **Source File:** `android/app/google-services.json`
*   **Command to Generate:**
    ```bash
    base64 -i android/app/google-services.json | pbcopy
    ```

### 4. `REVENUECAT_ANDROID_API_KEY`
*   **Source:** RevenueCat dashboard → Project Settings → API Keys → Public SDK Key (Android)
*   **Format:** Plain text (e.g., `goog_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
*   **Used for:** Subscription management via RevenueCat SDK (`purchases_flutter`)
*   **Note:** If not set, RevenueCat will not initialize and all users will be on the Free plan.

### 5. `REVENUECAT_IOS_API_KEY` *(iOS workflow)*
*   **Source:** RevenueCat dashboard → Project Settings → API Keys → Public SDK Key (iOS)
*   **Format:** Plain text (e.g., `appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
*   **Used for:** Subscription management via RevenueCat SDK on iOS builds
*   **Note:** Add this secret to the iOS workflow (`ios_release.yml`) as well.

## Workflow Behavior

*   **Push to `master`:** Triggers `fastlane internal` (Builds AAB & uploads to Internal Test Track).
*   **Tag `v*` (e.g., `v1.0.0`):** Triggers `fastlane promote_to_production` (Promotes Internal build to Production).
