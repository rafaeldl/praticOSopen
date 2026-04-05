# Guia de Configuracao do RevenueCat

**Data:** 2026-04-05 (atualizado)
**Autor:** CTO Agent
**Status:** Configuracao de Teste Disponivel
**Relacionado:** PRA-11, PRA-38, PR #224, PR #225

---

## 1. Visao Geral

Este documento descreve os passos para configurar o RevenueCat como provedor de billing para o PraticOS.

### Stack
- **Frontend:** Flutter (`purchases_flutter: ^8.0.0`, `purchases_ui_flutter: ^8.0.0`)
- **Backend:** Firebase Cloud Functions (webhook receiver)
- **Billing Provider:** RevenueCat (gratis ate $2.5k MRR)

### Ambiente de Teste

Para desenvolvimento e testes, use a API Key de teste:
```
test_rHipMRrqwezbhAuzyWKGLEqwfhP
```

Esta key sera usada automaticamente se nenhuma key de producao for configurada.

**Entitlement de teste:** `Rafsoft Pro`

### Produtos de Assinatura (Producao)
| Product ID | Nome | Preco | Entitlement |
|------------|------|-------|-------------|
| `praticos_starter_monthly` | Starter | R$ 59/mes | `starter` |
| `praticos_pro_monthly` | Pro | R$ 119/mes | `pro` |
| `praticos_business_monthly` | Business | R$ 249/mes | `business` |

### Produtos de Assinatura (Teste)
| Product ID | Tipo | Entitlement |
|------------|------|-------------|
| `monthly` | Mensal | `Rafsoft Pro` |
| `yearly` | Anual | `Rafsoft Pro` |
| `lifetime` | Vitalicio | `Rafsoft Pro` |

---

## 2. Inicio Rapido (Desenvolvimento)

### 2.1 Instalar Dependencias

```bash
cd /Users/rafaeldl/Projetos/praticOSopen
flutter pub get
```

### 2.2 Executar o App

Sem configurar nada, o app usara a API key de teste automaticamente:

```bash
flutter run
```

### 2.3 Usar o SubscriptionService

```dart
import 'package:praticos/services/subscription_service.dart';

// Inicializar apos login
await SubscriptionService.instance.initialize(userId);

// Apresentar Paywall nativo do RevenueCat
final result = await SubscriptionService.instance.presentPaywall();
if (result == PaywallResult.purchased) {
  // Usuario comprou!
}

// Ou verificar se precisa mostrar paywall
final result = await SubscriptionService.instance.presentPaywallIfNeeded();

// Verificar entitlement
final info = await SubscriptionService.instance.getCustomerInfo();
if (SubscriptionService.instance.hasProEntitlement(info)) {
  // Usuario tem Rafsoft Pro
}

// Abrir Customer Center para gerenciar assinatura
await SubscriptionService.instance.presentCustomerCenter();
```

---

## 3. Funcionalidades do SDK

### 3.1 Paywall Nativo

O RevenueCat oferece Paywalls nativos configurados no Dashboard. Use:

```dart
// Apresentar paywall incondicional
await SubscriptionService.instance.presentPaywall();

// Apresentar apenas se usuario nao tiver entitlement
await SubscriptionService.instance.presentPaywallIfNeeded(
  requiredEntitlement: 'Rafsoft Pro',
);
```

### 3.2 Customer Center

Para usuarios gerenciarem suas assinaturas:

```dart
await SubscriptionService.instance.presentCustomerCenter();
```

O Customer Center permite:
- Ver detalhes da assinatura
- Cancelar/Alterar plano
- Restaurar compras
- Acessar suporte

### 3.3 Verificacao de Entitlements

```dart
final info = await SubscriptionService.instance.getCustomerInfo();

// Verificar entitlement especifico
if (info.entitlements.active.containsKey('Rafsoft Pro')) {
  // Tem acesso pro
}

// Usar helpers do service
final plan = SubscriptionService.instance.getPlanFromEntitlements(info);
final details = SubscriptionService.instance.getSubscriptionDetails(info);
```

### 3.4 Compra Manual (sem Paywall)

```dart
final offerings = await SubscriptionService.instance.getOfferings();
if (offerings?.current != null) {
  // Pegar pacote mensal
  final monthly = offerings!.current!.monthly;
  if (monthly != null) {
    await SubscriptionService.instance.purchasePackage(monthly);
  }
}
```

### 3.5 Restaurar Compras

```dart
await SubscriptionService.instance.restorePurchases();
```

---

## 4. Passos de Configuracao (Producao)

### 4.1 Criar Conta RevenueCat

1. Acessar https://app.revenuecat.com/signup
2. Criar conta com email corporativo
3. Criar novo projeto: "PraticOS"
4. Selecionar plataformas: iOS + Android

### 4.2 Configurar App Store Connect

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

### 4.3 Configurar Google Play Console

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

### 4.4 Configurar Entitlements no RevenueCat

1. **Criar Entitlements:**
   - RevenueCat > Project > Entitlements
   - Criar entitlements:
     - `Rafsoft Pro` - para ambiente de teste
     - `starter` - associar a `praticos_starter_monthly`
     - `pro` - associar a `praticos_pro_monthly`
     - `business` - associar a `praticos_business_monthly`

2. **Criar Offerings:**
   - RevenueCat > Project > Offerings
   - Criar offering "default"
   - Adicionar packages para cada produto

### 4.5 Configurar Paywalls no RevenueCat

1. **Criar Paywall:**
   - RevenueCat > Project > Paywalls
   - Escolher template
   - Customizar cores, textos, imagens
   - Associar ao offering "default"

2. **Configurar Customer Center:**
   - RevenueCat > Project > Customer Center
   - Habilitar funcionalidades desejadas
   - Customizar textos

### 4.6 Obter API Keys

1. **Public API Keys:**
   - RevenueCat > Project > API Keys
   - Copiar Public SDK Key (iOS): `appl_xxxxx`
   - Copiar Public SDK Key (Android): `goog_xxxxx`

2. **Webhook Secret:**
   - RevenueCat > Project > Integrations > Webhooks
   - Configurar webhook URL: `https://us-central1-praticos-app.cloudfunctions.net/webhooks-revenuecat`
   - Copiar Authorization Header value

---

## 5. Configurar API Keys no Build

### 5.1 Via Linha de Comando

```bash
flutter run \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxxxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxxxx
```

### 5.2 Via GitHub Secrets (CI/CD)

Adicionar ao GitHub repo (Settings > Secrets > Actions):

```
REVENUECAT_IOS_API_KEY=appl_xxxxx
REVENUECAT_ANDROID_API_KEY=goog_xxxxx
REVENUECAT_WEBHOOK_SECRET=whsec_xxxxx
```

### 5.3 Via VS Code launch.json

```json
{
  "configurations": [
    {
      "name": "Flutter (production)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=REVENUECAT_IOS_API_KEY=appl_xxxxx",
        "--dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxxxx"
      ]
    }
  ]
}
```

---

## 6. Testar em Sandbox

### 6.1 iOS Sandbox
1. App Store Connect > Users and Access > Sandbox Testers
2. Criar tester com email de teste
3. No device: Settings > App Store > Sandbox Account
4. Login com sandbox tester
5. Testar compra no app

### 6.2 Android Test Track
1. Google Play Console > App > Testing > Internal testing
2. Adicionar testers (Gmail accounts)
3. Criar release no internal track
4. Testar compra via link de teste

### 6.3 Cenarios de Teste
- [ ] Paywall apresentado corretamente
- [ ] Compra bem-sucedida (monthly, yearly, lifetime)
- [ ] Cancelamento usuario
- [ ] Restore purchase em novo device
- [ ] Customer Center funcional
- [ ] Webhook recebido e processado
- [ ] Feature gates aplicados corretamente
- [ ] Trial de 7 dias

---

## 7. Checklist de Deploy

### Configuracao RevenueCat
- [ ] Conta RevenueCat criada
- [ ] Produtos iOS criados e conectados
- [ ] Produtos Android criados e conectados
- [ ] Entitlements configurados
- [ ] Paywalls configurados
- [ ] Customer Center configurado
- [ ] API Keys obtidas

### Configuracao CI/CD
- [ ] GitHub Secrets adicionados
- [ ] PR merged (subscription code)
- [ ] Cloud Functions deployed
- [ ] Webhook testado

### Testes
- [ ] Sandbox testing iOS completo
- [ ] Sandbox testing Android completo
- [ ] Paywall testado
- [ ] Customer Center testado
- [ ] App publicado com billing ativo

---

## 8. Troubleshooting

### Erro: "Product not found"
- Verificar se product_id esta identico nas lojas e no RevenueCat
- Aguardar propagacao (pode levar ate 24h)

### Erro: "Webhook 401"
- Verificar REVENUECAT_WEBHOOK_SECRET
- Verificar URL do webhook no RevenueCat

### Erro: "Entitlement not active"
- Verificar mapeamento produto -> entitlement no RevenueCat
- Verificar se compra foi processada (RevenueCat Dashboard > Customers)

### Erro: "Paywall not configured"
- Verificar se Paywall foi criado no RevenueCat Dashboard
- Verificar se esta associado ao offering correto

### Erro: "Customer Center not available"
- Verificar se Customer Center foi habilitado no RevenueCat Dashboard
- Verificar versao do SDK (`purchases_ui_flutter: ^8.0.0`)

### Debug: Ver logs do SDK
O SubscriptionService loga todas operacoes com prefixo `SubscriptionService:`.
Use `flutter run` e observe os logs no console.

---

## 9. Referencias

- [RevenueCat Flutter SDK](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [RevenueCat Paywalls](https://www.revenuecat.com/docs/tools/paywalls)
- [RevenueCat Customer Center](https://www.revenuecat.com/docs/tools/customer-center)
- [App Store Connect Subscriptions](https://developer.apple.com/documentation/storekit/in-app_purchase/subscriptions_and_offers)
- [Google Play Billing](https://developer.android.com/google/play/billing)

---

**Documento criado por:** CTO Agent
**Ultima atualizacao:** 2026-04-05
**Proxima revisao:** Apos deploy em producao
