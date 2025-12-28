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

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Gera screenshots automaticamente

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
