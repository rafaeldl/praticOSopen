# Checkout Go-Live - Guia Operacional

**PRA-45 | Atualizado: 2026-04-05**

Este documento lista **exatamente o que precisa ser feito** para colocar o checkout (billing) no ar.
Itens marcados com `[CLI]` podem ser automatizados. Itens marcados com `[MANUAL]` exigem acesso ao browser.

---

## Estado Atual

| Item | Status |
|------|--------|
| Codigo Flutter (SDK, telas, feature gates) | Mergeado em master (#225, #231) |
| Cloud Functions (webhook, reset mensal) | Mergeado em master (#225) |
| CI/CD pipeline RevenueCat keys | PR #224 aberto, CI verde |
| Bloqueio de bots (security) | PR #226 aberto |
| GitHub Secrets de build (iOS/Android) | Configurados |
| GitHub Secrets RevenueCat | **PENDENTE** |
| Conta RevenueCat | **PENDENTE** |
| Produtos nas lojas | **PENDENTE** |

---

## Fase 1: Merge dos PRs Pendentes [CLI]

Estes PRs estao com CI verde e prontos. Executar na ordem:

```bash
# PR #224 - Injecao de API keys RevenueCat no CI/CD
gh pr merge 224 --squash --delete-branch

# PR #226 - Bloqueio de signups fraudulentos (opcional, recomendado)
gh pr merge 226 --squash --delete-branch

# PR #230 - Git Workflow docs (opcional)
gh pr merge 230 --squash --delete-branch
```

---

## Fase 2: Criar Conta RevenueCat [MANUAL]

1. Acessar https://app.revenuecat.com/signup
2. Criar conta com email corporativo (ex: `billing@rafsoft.com.br`)
3. Criar projeto: **PraticOS**
4. Adicionar plataformas: **iOS** + **Android**

### Conectar iOS
- Em "iOS App", informar:
  - Bundle ID: `br.com.rafsoft.praticos`
  - Colar App-Specific Shared Secret (obtido no App Store Connect, passo abaixo)

### Conectar Android
- Em "Android App", informar:
  - Package Name: `br.com.rafsoft.praticos`
  - Upload do JSON key da Service Account Google (obtido no Google Play Console, passo abaixo)

---

## Fase 3: Criar Produtos nas Lojas [MANUAL]

### 3A. App Store Connect

**Acesso necessario:** Admin ou App Manager

1. Ir em **App > Subscriptions**
2. Criar Subscription Group: `PraticOS Plans`
3. Criar 3 produtos:

| Product ID | Nome Exibicao | Preco | Trial |
|------------|---------------|-------|-------|
| `praticos_starter_monthly` | Starter | R$ 59,00/mes | 7 dias |
| `praticos_pro_monthly` | Pro | R$ 119,00/mes | 7 dias |
| `praticos_business_monthly` | Business | R$ 249,00/mes | 7 dias |

4. Adicionar localizacao pt-BR para cada produto:
   - Nome de exibicao e descricao
5. Gerar **App-Specific Shared Secret**:
   - Users and Access > Integrations > Shared Secret > Generate
   - Copiar e colar no RevenueCat (Fase 2)

### 3B. Google Play Console

**Acesso necessario:** Admin

1. Ir em **Monetization > Products > Subscriptions**
2. Criar 3 produtos com os **mesmos IDs**:

| Product ID | Nome Exibicao | Preco | Trial |
|------------|---------------|-------|-------|
| `praticos_starter_monthly` | Starter | R$ 59,00/mes | 7 dias |
| `praticos_pro_monthly` | Pro | R$ 119,00/mes | 7 dias |
| `praticos_business_monthly` | Business | R$ 249,00/mes | 7 dias |

3. Criar **Service Account** para RevenueCat:
   - Google Cloud Console > IAM > Service Accounts
   - Criar conta de servico
   - Gerar JSON key
   - No Play Console: conceder permissoes "View financial data" e "Manage orders"
   - Upload do JSON no RevenueCat (Fase 2)

---

## Fase 4: Configurar Entitlements e Offerings no RevenueCat [MANUAL]

### 4A. Entitlements

No RevenueCat Dashboard > Entitlements, criar:

| Entitlement | Produtos Associados |
|-------------|---------------------|
| `starter` | `praticos_starter_monthly` (iOS + Android) |
| `pro` | `praticos_pro_monthly` (iOS + Android) |
| `business` | `praticos_business_monthly` (iOS + Android) |

### 4B. Offerings

1. Criar Offering: `default`
2. Adicionar packages:
   - Monthly Starter -> `praticos_starter_monthly`
   - Monthly Pro -> `praticos_pro_monthly`
   - Monthly Business -> `praticos_business_monthly`

### 4C. Paywall (opcional mas recomendado)

1. RevenueCat > Paywalls > Criar novo
2. Escolher template, customizar cores e textos
3. Associar ao offering `default`

### 4D. Customer Center (opcional)

1. RevenueCat > Customer Center > Habilitar
2. Customizar textos em portugues

---

## Fase 5: Obter API Keys do RevenueCat [MANUAL]

No RevenueCat Dashboard > Project > API Keys, copiar:

| Chave | Formato | Exemplo |
|-------|---------|---------|
| Public SDK Key (iOS) | `appl_xxxxxxxx` | `appl_AbCdEfGhIjKl` |
| Public SDK Key (Android) | `goog_xxxxxxxx` | `goog_AbCdEfGhIjKl` |

No RevenueCat Dashboard > Integrations > Webhooks:
- Configurar URL: `https://us-central1-praticos.cloudfunctions.net/api/webhooks/revenuecat`
- Anotar o **Webhook Signing Secret**

---

## Fase 6: Configurar GitHub Secrets [CLI]

Depois de obter as chaves da Fase 5, executar:

```bash
# RevenueCat API Keys
gh secret set REVENUECAT_IOS_API_KEY --body "appl_VALOR_AQUI"
gh secret set REVENUECAT_ANDROID_API_KEY --body "goog_VALOR_AQUI"

# RevenueCat Webhook Secret (para Cloud Functions)
gh secret set REVENUECAT_WEBHOOK_SECRET --body "whsec_VALOR_AQUI"
```

### Verificar secrets configurados

```bash
gh secret list
```

**Secrets esperados (total 15):**
| Secret | Status |
|--------|--------|
| `ANDROID_GOOGLE_SERVICES_JSON_BASE64` | Ja existe |
| `ANDROID_KEYSTORE_BASE64` | Ja existe |
| `ANDROID_PLAY_STORE_CREDENTIALS_BASE64` | Ja existe |
| `APP_STORE_CONNECT_API_KEY_ID` | Ja existe |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Ja existe |
| `APP_STORE_CONNECT_API_KEY_PRIVATE_KEY` | Ja existe |
| `FIREBASE_SERVICE_ACCOUNT_PRATICOS` | Ja existe |
| `IOS_DIST_CERTIFICATE_BASE64` | Ja existe |
| `IOS_DIST_CERTIFICATE_PASSWORD` | Ja existe |
| `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64` | Ja existe |
| `IOS_PROVISIONING_PROFILE_BASE64` | Ja existe |
| `PAT_TOKEN` | Ja existe |
| `REVENUECAT_IOS_API_KEY` | **NOVO** |
| `REVENUECAT_ANDROID_API_KEY` | **NOVO** |
| `REVENUECAT_WEBHOOK_SECRET` | **NOVO** |

---

## Fase 7: Deploy Cloud Functions [CLI]

O webhook do RevenueCat precisa estar rodando. Verificar e fazer deploy:

```bash
cd firebase
npm run build
firebase deploy --only functions
```

### Configurar Webhook Secret no Firebase

```bash
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
# Colar o valor do webhook signing secret quando solicitado
```

---

## Fase 8: Criar RC e Testar [CLI + MANUAL]

### 8A. Criar Release Candidate

```bash
# Incrementar versao e criar tag RC
cd /Users/rafaeldl/Projetos/praticOSopen
git tag v1.47.0-rc
git push origin v1.47.0-rc
```

Isso dispara automaticamente:
- `ios_release.yml` -> Build iOS + Upload TestFlight
- `android_release.yml` -> Build Android + Upload Internal Track

### 8B. Testes em Sandbox [MANUAL]

**iOS:**
1. App Store Connect > Users and Access > Sandbox Testers
2. Criar tester: `testebilling@rafsoft.com.br`
3. No iPhone: Ajustes > App Store > Conta Sandbox
4. Abrir app via TestFlight
5. Testar compra de plano Starter

**Android:**
1. Google Play Console > Testing > Internal Testing
2. Adicionar testers (contas Gmail)
3. Instalar via link de teste
4. Testar compra de plano Starter

### 8C. Checklist de Testes

- [ ] Paywall aparece ao atingir limite de fotos
- [ ] Compra de plano Starter funciona (iOS)
- [ ] Compra de plano Starter funciona (Android)
- [ ] Webhook recebido no Firebase (verificar logs)
- [ ] Feature gates atualizam apos compra
- [ ] Restore purchase funciona
- [ ] Customer Center abre e mostra plano
- [ ] PDF sem marca dagua apos upgrade
- [ ] Cancelamento reverte para plano Free

---

## Fase 9: Go Live [CLI + MANUAL]

### 9A. Promover para Producao

**iOS:**
1. App Store Connect > TestFlight > selecionar build RC
2. Submit for Review
3. Aguardar aprovacao (1-3 dias)

**Android:**
1. Google Play Console > Production > Create release
2. Usar AAB do Internal Track
3. Roll out (pode ser staged: 10% -> 50% -> 100%)

### 9B. Monitoramento Pos-Deploy

```bash
# Logs do webhook RevenueCat
firebase functions:log --only api

# Dashboard RevenueCat
# https://app.revenuecat.com/overview
```

---

## Resumo: Ordem de Execucao

| # | Acao | Tipo | Dependencia |
|---|------|------|-------------|
| 1 | Merge PRs #224, #226, #230 | CLI | Nenhuma |
| 2 | Criar conta RevenueCat | MANUAL | Nenhuma |
| 3 | Criar produtos App Store Connect | MANUAL | Conta Apple Developer |
| 4 | Criar produtos Google Play Console | MANUAL | Conta Google Play |
| 5 | Configurar entitlements/offerings RC | MANUAL | Etapas 2, 3, 4 |
| 6 | Obter API keys do RevenueCat | MANUAL | Etapa 5 |
| 7 | `gh secret set` das 3 chaves RC | CLI | Etapa 6 |
| 8 | Deploy Cloud Functions | CLI | Etapa 6 |
| 9 | Tag RC e aguardar CI | CLI | Etapas 1, 7 |
| 10 | Testes sandbox (iOS + Android) | MANUAL | Etapa 9 |
| 11 | Submit para producao | MANUAL | Etapa 10 |

**Estimativa de esforco manual:** Etapas 2-6 (criacao de contas e produtos nas lojas).
**Automatizavel via CLI:** Etapas 1, 7, 8, 9 (merge, secrets, deploy, tag).

---

**Autor:** CTO Agent | **PRA-45**
