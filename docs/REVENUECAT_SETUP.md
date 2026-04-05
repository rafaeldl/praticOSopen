# Guia de Configuracao do RevenueCat

**Data:** 2026-04-04
**Autor:** CTO Agent
**Status:** Em execucao
**Relacionado:** PRA-11, PR #224, PR #225

---

## 1. Visao Geral

Este documento descreve os passos para configurar o RevenueCat como provedor de billing para o PraticOS.

### Stack
- **Frontend:** Flutter (`purchases_flutter: ^6.0.0`)
- **Backend:** Firebase Cloud Functions (webhook receiver)
- **Billing Provider:** RevenueCat (gratis ate $2.5k MRR)

### Produtos de Assinatura
| Product ID | Nome | Preco | Entitlement |
|------------|------|-------|-------------|
| `praticos_starter_monthly` | Starter | R$ 59/mes | `starter` |
| `praticos_pro_monthly` | Pro | R$ 119/mes | `pro` |
| `praticos_business_monthly` | Business | R$ 249/mes | `business` |

---

## 2. Passos de Configuracao

### 2.1 Criar Conta RevenueCat

1. Acessar https://app.revenuecat.com/signup
2. Criar conta com email corporativo
3. Criar novo projeto: "PraticOS"
4. Selecionar plataformas: iOS + Android

### 2.2 Configurar App Store Connect

**Pre-requisitos:** Acesso ao App Store Connect com role Admin ou App Manager

1. **Criar Subscriptions:**
   - App Store Connect > App > Subscriptions
   - Criar Subscription Group: "PraticOS Plans"
   - Adicionar produtos:
     - `praticos_starter_monthly` - R$ 59,00/mes
     - `praticos_pro_monthly` - R$ 119,00/mes
     - `praticos_business_monthly` - R$ 249,00/mes
   - Configurar localizacoes (pt-BR obrigatorio)
   - Configurar trial period: 7 dias

2. **Configurar Shared Secret:**
   - App Store Connect > Users and Access > Keys
   - Gerar App-Specific Shared Secret
   - Copiar para RevenueCat

3. **Conectar no RevenueCat:**
   - RevenueCat > Project > iOS App
   - Bundle ID: `br.com.rafsoft.praticos`
   - Colar Shared Secret
   - Habilitar Server Notifications (URL do webhook)

### 2.3 Configurar Google Play Console

**Pre-requisitos:** Acesso ao Google Play Console com role Admin

1. **Criar Subscriptions:**
   - Google Play Console > App > Monetization > Products > Subscriptions
   - Adicionar produtos com MESMOS IDs:
     - `praticos_starter_monthly` - R$ 59,00/mes
     - `praticos_pro_monthly` - R$ 119,00/mes
     - `praticos_business_monthly` - R$ 249,00/mes
   - Configurar base plans (monthly)
   - Configurar trial period: 7 dias

2. **Criar Service Account:**
   - Google Cloud Console > IAM > Service Accounts
   - Criar service account para RevenueCat
   - Gerar JSON key
   - No Play Console: Grant permissions (View financial data, Manage orders)

3. **Conectar no RevenueCat:**
   - RevenueCat > Project > Android App
   - Package Name: `br.com.rafsoft.praticos`
   - Upload JSON key
   - Habilitar Real-Time Developer Notifications

### 2.4 Configurar Entitlements no RevenueCat

1. **Criar Entitlements:**
   - RevenueCat > Project > Entitlements
   - Criar 3 entitlements:
     - `starter` - associar a `praticos_starter_monthly`
     - `pro` - associar a `praticos_pro_monthly`
     - `business` - associar a `praticos_business_monthly`

2. **Criar Offerings:**
   - RevenueCat > Project > Offerings
   - Criar offering "default"
   - Adicionar packages para cada produto

### 2.5 Obter API Keys

1. **Public API Keys:**
   - RevenueCat > Project > API Keys
   - Copiar Public SDK Key (iOS): `appl_xxxxx`
   - Copiar Public SDK Key (Android): `goog_xxxxx`

2. **Webhook Secret:**
   - RevenueCat > Project > Integrations > Webhooks
   - Configurar webhook URL: `https://us-central1-praticos-app.cloudfunctions.net/webhooks-revenuecat`
   - Copiar Authorization Header value

---

## 3. Configurar GitHub Secrets

Adicionar ao GitHub repo (Settings > Secrets > Actions):

```
REVENUECAT_IOS_API_KEY=appl_xxxxx
REVENUECAT_ANDROID_API_KEY=goog_xxxxx
REVENUECAT_WEBHOOK_SECRET=whsec_xxxxx
```

Estes secrets serao usados:
- Build: `--dart-define=REVENUECAT_IOS_API_KEY=${{ secrets.REVENUECAT_IOS_API_KEY }}`
- Cloud Functions: `functions:secrets:set REVENUECAT_WEBHOOK_SECRET`

---

## 4. Testar em Sandbox

### 4.1 iOS Sandbox
1. App Store Connect > Users and Access > Sandbox Testers
2. Criar tester com email de teste
3. No device: Settings > App Store > Sandbox Account
4. Login com sandbox tester
5. Testar compra no app

### 4.2 Android Test Track
1. Google Play Console > App > Testing > Internal testing
2. Adicionar testers (Gmail accounts)
3. Criar release no internal track
4. Testar compra via link de teste

### 4.3 Cenarios de Teste
- [ ] Compra bem-sucedida (starter, pro, business)
- [ ] Cancelamento usuario
- [ ] Restore purchase em novo device
- [ ] Webhook recebido e processado
- [ ] Feature gates aplicados corretamente
- [ ] Trial de 7 dias

---

## 5. Checklist de Deploy

- [ ] Conta RevenueCat criada
- [ ] Produtos iOS criados e conectados
- [ ] Produtos Android criados e conectados
- [ ] Entitlements configurados
- [ ] API Keys obtidas
- [ ] GitHub Secrets adicionados
- [ ] PR #224 merged (CI/CD keys)
- [ ] PR #225 merged (subscription code)
- [ ] Cloud Functions deployed
- [ ] Webhook testado
- [ ] Sandbox testing completo
- [ ] App publicado com billing ativo

---

## 6. Troubleshooting

### Erro: "Product not found"
- Verificar se product_id esta identico nas lojas e no RevenueCat
- Aguardar propagacao (pode levar ate 24h)

### Erro: "Webhook 401"
- Verificar REVENUECAT_WEBHOOK_SECRET
- Verificar URL do webhook no RevenueCat

### Erro: "Entitlement not active"
- Verificar mapeamento produto -> entitlement no RevenueCat
- Verificar se compra foi processada (RevenueCat Dashboard > Customers)

---

**Documento criado por:** CTO Agent
**Proxima revisao:** Apos deploy em producao
