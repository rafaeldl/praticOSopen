fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_check

```sh
[bundle exec] fastlane ios build_check
```

Build check para CI (simulador, sem assinatura)

### ios get_next_build_number

```sh
[bundle exec] fastlane ios get_next_build_number
```

Retorna o próximo build number (último do TestFlight + 1)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + upload para TestFlight (sem match)

### ios upload_last

```sh
[bundle exec] fastlane ios upload_last
```

Só envia o último .ipa do diretório padrão do Fastlane

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload do IPA gerado pelo Flutter build

### ios release_store

```sh
[bundle exec] fastlane ios release_store
```

Build + Upload para App Store (com metadados e screenshots)

### ios fix_screenshots_alpha

```sh
[bundle exec] fastlane ios fix_screenshots_alpha
```

Remove alpha channel from all screenshots (required by App Store)

### ios promote

```sh
[bundle exec] fastlane ios promote
```

Promote TestFlight build to App Store (no re-upload)

### ios clear_screenshots

```sh
[bundle exec] fastlane ios clear_screenshots
```

Clear all screenshots from App Store Connect (useful before fresh upload)

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Gera screenshots automaticamente usando Flutter integration tests

### ios screenshots_all

```sh
[bundle exec] fastlane ios screenshots_all
```

Gera screenshots para todos dispositivos e idiomas

### ios screenshots_pt_br

```sh
[bundle exec] fastlane ios screenshots_pt_br
```

Gera screenshots apenas para pt-BR (backwards compatibility)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
