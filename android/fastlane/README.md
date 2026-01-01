fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android test

```sh
[bundle exec] fastlane android test
```

Runs all the tests

### android build_flutter

```sh
[bundle exec] fastlane android build_flutter
```

Build the Android App Bundle (AAB) using Flutter

### android internal

```sh
[bundle exec] fastlane android internal
```

Deploy a new version to the Google Play Internal Track

### android promote_to_production

```sh
[bundle exec] fastlane android promote_to_production
```

Promote Internal to Production

### android screenshots

```sh
[bundle exec] fastlane android screenshots
```

Capture screenshots automatically using Flutter integration tests

### android screenshots_all

```sh
[bundle exec] fastlane android screenshots_all
```

Capture screenshots for Phone, 7-inch Tablet, and 10-inch Tablet

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
