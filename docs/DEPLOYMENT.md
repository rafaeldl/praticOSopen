# Guia de Deploy e Publicação - PraticOS

Este documento detalha o processo de build, testes e deploy automatizado para Android (Google Play) e iOS (App Store) utilizando Fastlane e GitHub Actions.

## 📱 Visão Geral

O projeto utiliza **Fastlane** para automação local e **GitHub Actions** para CI/CD.
O fluxo suporta:
- Build de Release (AAB/IPA).
- Assinatura digital automática (Android) e manual via Match/Secrets (iOS).
- Geração automática de Screenshots (Phone e Tablets).
- Upload de Metadados (Textos, Imagens, Changelog).
- Publicação em trilhas de teste (Internal/TestFlight) e Produção.

---

## 🤖 Android

### Pré-requisitos
- Chave de Upload (`rafsoft.keystore`) configurada.
- Credenciais da Google Play API (`play_store_credentials.json`).
- `local.properties` configurado (se rodar local).

### Comandos Fastlane (Local)

Execute dentro da pasta `android/`:

| Comando | Descrição |
|---------|-----------|
| `bundle exec fastlane internal` | Builda e envia para **Internal Track** (sem metadados/prints). |
| `bundle exec fastlane deploy_with_metadata` | Builda e envia para **Internal** (padrão) **COM** metadados e prints. |
| `bundle exec fastlane promote_to_production` | Promove a versão de Internal para **Production**. |
| `bundle exec fastlane screenshots_all` | Gera prints para Celular, Tablet 7" e Tablet 10". |

### Geração de Screenshots (Android)
Para gerar os prints corretos para a Play Store, você deve ter 3 emuladores rodando simultaneamente:
1. **Phone** (Ex: Pixel 6)
2. **Tablet 7"** (Ex: Nexus 7)
3. **Tablet 10"** (Ex: Pixel Tablet)

Execute:
```bash
cd android
bundle exec fastlane screenshots_all
# Se os IDs forem diferentes do padrão (5554, 5556, 5558):
# bundle exec fastlane screenshots_all phone_device:emulator-5554 tablet7_device:emulator-9999 ...
```

### GitHub Actions (CI/CD)
O workflow `.github/workflows/android_release.yml` é acionado em:
- **Push na branch `feature/android-deployment` ou `master`**: Roda a lane `internal` (Upload para trilha interna).
- **Criação de Tag `v*`**: Roda a lane `deploy_with_metadata track:production` (Upload direto para Produção com metadados).

---

## 🍎 iOS

### Pré-requisitos
- Certificados e Provisioning Profiles (gerenciados via Secrets no CI).
- Conta na App Store Connect.

### Comandos Fastlane (Local)

Execute dentro da pasta `ios/`:

| Comando | Descrição |
|---------|-----------|
| `bundle exec fastlane beta` | Builda e envia para **TestFlight**. |
| `bundle exec fastlane release_store` | Builda e envia para **App Store** (com metadados/prints). |
| `bundle exec fastlane screenshots_all` | Gera prints para iPhone 16e e iPhone 17. |

### Geração de Screenshots (iOS)
Requer macOS e Xcode. Certifique-se de que os simuladores **iPhone 16e** e **iPhone 17** existam.

Execute:
```bash
cd ios
bundle exec fastlane screenshots_all
```

### GitHub Actions (CI/CD)
O workflow `.github/workflows/ios_release.yml` é acionado em:
- **Push na branch `master`**: Envia para TestFlight.
- **Criação de Tag `v*`**: Envia para App Store (Release).

---

## 📸 Estrutura de Screenshots Automatizados

O sistema utiliza `integration_test` do Flutter para navegar no app e tirar fotos.
Arquivo principal: `integration_test/screenshot_test.dart`

**Cenários cobertos (7 telas):**
1. **Home** - Lista de OS (`01_home`)
2. **Detalhes da OS** (`02_order_detail`)
3. **Seleção de Segmento** - Onboarding (`03_segments`)
4. **Dashboard** - Gráficos (`04_dashboard`)
5. **Pagamentos** (`05_payments`)
6. **Formulários/Checklists** (`06_forms`)
7. **Login** (`07_login`)

### Nomenclatura Padronizada

**Android:** `{number}_{name}.png`
- Exemplo: `01_home.png`, `02_order_detail.png`

**iOS:** `{device}-{number}_{name}.png`
- Exemplo: `iPhone 16e-01_home.png`, `iPhone 17-02_order_detail.png`

### Variáveis de Ambiente

- `TEST_LOCALE`: Define o idioma do app (`pt-BR`, `en-US`, `es-ES`). O locale é forçado via `--dart-define` diretamente no app.
- `FORCE_LOGOUT`: Força logout antes de começar (padrão: `true`)

### Exemplos de uso via Fastlane:

**iOS:**
```bash
cd ios
bundle exec fastlane screenshots locale:pt-BR device:"iPhone 16e"
bundle exec fastlane screenshots locale:en-US device:"iPhone 16e"
bundle exec fastlane screenshots locale:es-ES device:"iPhone 16e"

# Todos os locales e devices
bundle exec fastlane screenshots_all
```

**Android:**
```bash
cd android
bundle exec fastlane screenshots locale:pt-BR avd:Pixel_7
bundle exec fastlane screenshots locale:en-US avd:Pixel_7
bundle exec fastlane screenshots locale:es-ES avd:Pixel_7

# Todos os locales e devices
bundle exec fastlane screenshots_all
```

**Manual via Flutter Drive:**
```bash
fvm flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d <DEVICE_ID> \
  --dart-define=TEST_LOCALE=pt-BR \
  --dart-define=FORCE_LOGOUT=true
```

**Total:** 21 screenshots por plataforma (3 idiomas × 7 telas)

---

## 🔐 Segredos e Variáveis (GitHub Secrets)

Para que o CI funcione, as seguintes secrets devem estar configuradas no repositório:

### Android
- `ANDROID_KEYSTORE_BASE64`: Arquivo `.keystore` em base64.
- `ANDROID_KEY_PROPERTIES`: Conteúdo do `key.properties`.
- `ANDROID_PLAY_STORE_CREDENTIALS_BASE64`: JSON da conta de serviço Google Play Console.
- `ANDROID_GOOGLE_SERVICES_JSON_BASE64`: Arquivo `google-services.json`.

### iOS
- `IOS_DIST_CERTIFICATE_BASE64`: Certificado `.p12` de distribuição.
- `IOS_DIST_CERTIFICATE_PASSWORD`: Senha do certificado.
- `IOS_PROVISIONING_PROFILE_BASE64`: Arquivo `.mobileprovision`.
- `APP_STORE_CONNECT_API_KEY_ID`: Key ID da App Store Connect API.
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`: Issuer ID.
- `APP_STORE_CONNECT_API_KEY_PRIVATE_KEY`: Conteúdo da chave `.p8`.
