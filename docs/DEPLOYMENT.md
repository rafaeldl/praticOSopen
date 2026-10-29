# Guia de Deploy e Publicação - PraticOS

Este documento detalha o processo de build, testes e deploy automatizado para Android (Google Play) e iOS (App Store) utilizando Fastlane e GitHub Actions, e o deploy do Firebase (Functions, regras, índices e site).

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

## 🔥 Firebase (Functions, regras, índices e site)

Todos usam o secret `FIREBASE_SERVICE_ACCOUNT_PRATICOS` e publicam no projeto `praticos` em push na `master`.

| O que muda | Workflow | Comando |
|------------|----------|---------|
| `firebase/functions/**` | `firebase-functions-deploy.yml` | `firebase deploy --only functions` |
| `firebase/hosting/**`, `firebase/firebase.json` | `firebase-hosting-deploy.yml` | action `FirebaseExtended/action-hosting-deploy` |
| `firebase/firestore.rules`, `firebase/firestore.indexes.json`, `firebase/storage.rules` | `firebase-rules-deploy.yml` | `firebase deploy --only firestore:rules,firestore:indexes,storage --non-interactive` |

### Regras e índices

Até 29/10/2026 as regras eram publicadas à mão e ficaram de 08/10 a 29/10 sem deploy, o que quebrou "Receber de cliente" e a NFS-e em produção. Agora o `firebase-rules-deploy.yml`:

1. Roda os testes de regras (`npm run test:rules` e `npm run test:rbac` em `firebase/functions`). Se falharem, nada é publicado.
2. Publica regras do Firestore, índices e regras do Storage.
3. Confere que produção ficou igual ao repositório (`.github/scripts/check-rules-drift.sh`).

Também roda manualmente (Actions → "Deploy Firestore/Storage Rules" → Run workflow). Um deploy de regras por vez (`concurrency`); não divide grupo com o de Functions porque mexem em coisas diferentes e o GitHub cancela execuções pendentes do mesmo grupo.

**Índices nunca são apagados pelo CI.** Sem `--force` e com `--non-interactive`, o firebase-tools só cria o que falta: índice que existe em produção e não está no `firestore.indexes.json` aparece no log ("there are N indexes defined in your project that are not present...") e continua lá. Não colocar `--force` no workflow. Para apagar um índice, fazer à mão no console ou com `firebase deploy --only firestore:indexes --force` depois de conferir a lista. Para trazer um índice criado no console para o arquivo: `firebase firestore:indexes --project praticos > firebase/firestore.indexes.json`.

### Conferência diária (drift)

`firebase-rules-drift.yml` roda todo dia às 08:17 (Brasília) e manualmente. Compara o ruleset publicado (`projects/praticos/releases/cloud.firestore` e `firebase.storage/<bucket>` na API `firebaserules`) com `firebase/firestore.rules` e `firebase/storage.rules` da `master`. Se diferirem, o job falha com o diff e o GitHub manda e-mail. Causas comuns: deploy à mão de outro branch, ou o deploy de regras falhou.

Rodar local (com `gcloud auth login`):

```bash
RULES_QUOTA_PROJECT=praticos .github/scripts/check-rules-drift.sh
```

Em repositório público, o GitHub desliga workflows agendados depois de 60 dias sem commits. Se isso acontecer, reativar em Actions → "Firestore/Storage Rules Drift" → Enable workflow.

### Permissões da conta de serviço

A conta do secret `FIREBASE_SERVICE_ACCOUNT_PRATICOS` precisa, no projeto `praticos`:

| Papel | Para quê |
|-------|----------|
| Firebase Rules Admin (`roles/firebaserules.admin`) | Criar rulesets e trocar os releases do Firestore e do Storage; ler para o drift |
| Cloud Datastore Index Admin (`roles/datastore.indexAdmin`) | Listar e criar índices e field overrides do Firestore |
| Service Usage Consumer (`roles/serviceusage.serviceUsageConsumer`) | O firebase-tools confere se as APIs do Firestore e do Rules estão ligadas |
| Firebase Viewer (`roles/firebase.viewer`) | Achar o bucket padrão do Storage |

O Service Usage Consumer costuma já existir por causa do deploy de Functions. Para conferir:

```bash
gcloud projects get-iam-policy praticos --flatten="bindings[].members" --filter="bindings.members:serviceAccount:<EMAIL_DA_CONTA>" --format="table(bindings.role)"
```

O e-mail da conta é o `client_email` do JSON do secret. Se algum papel faltar (ou se a conta já tiver `roles/firebase.admin` ou `roles/editor`, que cobrem tudo isso):

```bash
gcloud projects add-iam-policy-binding praticos --member="serviceAccount:<EMAIL_DA_CONTA>" --role="roles/firebaserules.admin"
```

Repetir com `roles/datastore.indexAdmin` e os demais que faltarem.

---

## 🔐 Segredos e Variáveis (GitHub Secrets)

Para que o CI funcione, as seguintes secrets devem estar configuradas no repositório:

### Android
- `ANDROID_KEYSTORE_BASE64`: Arquivo `.keystore` em base64.
- `ANDROID_KEY_PROPERTIES`: Conteúdo do `key.properties`.
- `ANDROID_PLAY_STORE_CREDENTIALS_BASE64`: JSON da conta de serviço Google Play Console.
- `ANDROID_GOOGLE_SERVICES_JSON_BASE64`: Arquivo `google-services.json`.

### iOS
A assinatura usa **fastlane match** — ver `docs/IOS_CODE_SIGNING.md`. Os secrets do match são criados por `ios/scripts/bootstrap_match.sh`.
- `MATCH_PASSWORD`: Passphrase que descriptografa o repo de certificados.
- `MATCH_GIT_PRIVATE_KEY`: Deploy key SSH somente leitura do `rafaeldl/praticos-certificates`.
- `APP_STORE_CONNECT_API_KEY_ID`: Key ID da App Store Connect API.
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID`: Issuer ID.
- `APP_STORE_CONNECT_API_KEY_PRIVATE_KEY`: Conteúdo da chave `.p8`.
