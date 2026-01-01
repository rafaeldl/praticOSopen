# Android Fastlane Setup

This project uses [Fastlane](https://fastlane.tools) to automate building and deploying the Android application.

## Prerequisites

Before running Fastlane, ensure you have the following files in place (these are git-ignored for security):

1.  **Signing Keystore**:
    *   Place your release keystore file at: `android/app/rafsoft.keystore`
    *   Ensure the passwords in `android/app/build.gradle` match your keystore (currently hardcoded as `rafsoft`).

2.  **Google Play Credentials**:
    *   Obtain a Service Account JSON key from the Google Play Console (API Access).
    *   Save it to: `android/fastlane/play_store_credentials.json`
    *   Ensure this service account has permission to manage your app in the Play Store.

## Available Lanes

Run these commands from the `android` directory (or root using `bundle exec fastlane android ...`):

### `fastlane android test`
Runs the unit tests.

### `fastlane android internal`
1.  Builds the App Bundle (`.aab`).
2.  Uploads it to the **Internal** track on Google Play Console.
3.  **Note**: This lane skips uploading metadata, images, and screenshots by default to speed up the process.

### `fastlane android promote_to_production`
Promotes the latest release from the **Internal** track to the **Production** track.

## Troubleshooting

- **Missing Keystore**: If the build fails finding `rafsoft.keystore`, ensure the file exists in `android/app/`.
- **Authentication Error**: If upload fails, check that `android/fastlane/play_store_credentials.json` is valid and has the correct permissions in Google Play Console.
