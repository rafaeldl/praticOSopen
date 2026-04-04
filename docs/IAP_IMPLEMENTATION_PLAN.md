# Plano Tecnico: In-App Purchase (PRA-11)

**Data:** 2026-04-03
**Autor:** CTO Agent
**Status:** Em revisao
**Issue:** PRA-11

---

## 1. Visao Geral

Implementar sistema de assinaturas in-app para iOS e Android no PraticOS, permitindo que usuarios assinem os planos Starter (R$59), Pro (R$119) e Business (R$249).

## 2. Arquitetura Proposta

### 2.1 Stack Tecnica

| Componente | Tecnologia | Justificativa |
|------------|------------|---------------|
| Client SDK | `in_app_purchase` (oficial Flutter) | Suporte oficial, mantido pelo time Flutter |
| Backend Sync | Firebase Cloud Functions | Ja usamos Firebase, menor complexidade |
| Subscription Management | RevenueCat | Simplifica gestao cross-platform, webhooks, analytics |
| Database | Firestore | Consistencia com stack existente |

### 2.2 Alternativa: RevenueCat vs Solucao Nativa

**Recomendacao: RevenueCat**

| Criterio | RevenueCat | Nativo |
|----------|------------|--------|
| Tempo de implementacao | 2-3 dias | 7-10 dias |
| Webhooks prontos | Sim | Desenvolver |
| Analytics de assinatura | Incluido | Firebase custom |
| Restore purchase | Automatico | Manual |
| Custo | Gratis ate $2.5k MRR | $0 |
| Suporte cross-platform | Excelente | Manual |

**Decisao:** Usar RevenueCat para MVP. Custo zero ate atingirmos R$12.5k MRR.

## 3. Modelo de Dados

### 3.1 Firestore: Company Document

Adicionar campos ao documento `/companies/{companyId}`:

```typescript
interface CompanySubscription {
  // Plano atual: 'free' | 'starter' | 'pro' | 'business'
  plan: string;

  // Status: 'active' | 'trialing' | 'past_due' | 'cancelled' | 'expired'
  status: string;

  // RevenueCat subscriber ID
  rcSubscriberId?: string;

  // Datas
  subscribedAt?: Timestamp;
  expiresAt?: Timestamp;
  cancelledAt?: Timestamp;

  // Limites atuais (calculados a partir do plano)
  limits: {
    photosPerMonth: number;      // 30 | 200 | 500 | -1 (unlimited)
    formTemplates: number;       // 1 | 3 | 10 | -1
    users: number;               // 1 | 3 | 5 | -1
    pdfWatermark: boolean;       // true (Free) | false (Paid)
  };

  // Uso atual (resetado mensalmente)
  usage: {
    photosThisMonth: number;
    formTemplatesActive: number;
    usersActive: number;
    usageResetAt: Timestamp;
  };
}
```

### 3.2 Flutter: Subscription Model

Novo arquivo: `lib/models/subscription.dart`

```dart
@JsonSerializable()
class Subscription {
  final String plan;              // free, starter, pro, business
  final String status;            // active, trialing, past_due, cancelled, expired
  final String? rcSubscriberId;
  final DateTime? subscribedAt;
  final DateTime? expiresAt;
  final DateTime? cancelledAt;
  final SubscriptionLimits limits;
  final SubscriptionUsage usage;
}

@JsonSerializable()
class SubscriptionLimits {
  final int photosPerMonth;       // -1 = unlimited
  final int formTemplates;
  final int users;
  final bool pdfWatermark;
}

@JsonSerializable()
class SubscriptionUsage {
  final int photosThisMonth;
  final int formTemplatesActive;
  final int usersActive;
  final DateTime usageResetAt;
}
```

## 4. Fluxo de Implementacao

### 4.1 Fase 1: Infraestrutura (3 dias)

#### Dia 1: Setup RevenueCat + Lojas
- [ ] Criar conta RevenueCat
- [ ] Configurar produtos na App Store Connect:
  - `praticos_starter_monthly` - R$59/mes
  - `praticos_pro_monthly` - R$119/mes
  - `praticos_business_monthly` - R$249/mes
- [ ] Configurar produtos no Google Play Console:
  - Mesmos IDs para consistencia
- [ ] Conectar lojas ao RevenueCat

#### Dia 2: Integracao Flutter
- [ ] Adicionar dependencias ao `pubspec.yaml`:
  ```yaml
  purchases_flutter: ^6.0.0  # RevenueCat SDK
  ```
- [ ] Criar `lib/services/subscription_service.dart`
- [ ] Criar `lib/mobx/subscription_store.dart`
- [ ] Inicializar RevenueCat no `main.dart`

#### Dia 3: Backend Sync
- [ ] Criar Cloud Function `onSubscriptionUpdated` (webhook RevenueCat)
- [ ] Atualizar modelo Company no Firestore
- [ ] Criar `lib/models/subscription.dart`
- [ ] Sincronizar status na abertura do app

### 4.2 Fase 2: UI de Assinatura (2 dias)

#### Dia 4: Tela de Planos
- [ ] Criar `lib/screens/subscription/plans_screen.dart`
- [ ] Mostrar comparativo de features
- [ ] Botoes de assinar para cada plano
- [ ] Indicador de plano atual

#### Dia 5: UX de Upgrade
- [ ] Deep link `praticos://upgrade`
- [ ] Modal de upgrade contextual
- [ ] Feedback durante pagamento
- [ ] Tela de sucesso/erro

### 4.3 Fase 3: Restore & Management (1 dia)

#### Dia 6: Finalizacao
- [ ] Restore purchase
- [ ] Tela de gerenciamento de assinatura
- [ ] Cancelamento (redireciona para loja)
- [ ] Testes end-to-end

## 5. Codigo de Referencia

### 5.1 SubscriptionService

```dart
// lib/services/subscription_service.dart

import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  Future<void> initialize(String userId) async {
    await Purchases.configure(
      PurchasesConfiguration(_apiKey)..appUserID = userId,
    );
  }

  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  Future<Offerings?> getOfferings() async {
    return await Purchases.getOfferings();
  }

  Future<CustomerInfo> purchasePackage(Package package) async {
    return await Purchases.purchasePackage(package);
  }

  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }

  String getPlanFromEntitlements(CustomerInfo info) {
    if (info.entitlements.active.containsKey('business')) return 'business';
    if (info.entitlements.active.containsKey('pro')) return 'pro';
    if (info.entitlements.active.containsKey('starter')) return 'starter';
    return 'free';
  }
}
```

### 5.2 Cloud Function (Webhook)

```typescript
// firebase/functions/src/subscriptions/onWebhook.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onRevenueCatWebhook = functions.https.onRequest(async (req, res) => {
  const event = req.body;
  const appUserId = event.app_user_id; // Company ID

  const planMap: Record<string, string> = {
    'praticos_starter_monthly': 'starter',
    'praticos_pro_monthly': 'pro',
    'praticos_business_monthly': 'business',
  };

  const limitsMap: Record<string, any> = {
    'free': { photosPerMonth: 30, formTemplates: 1, users: 1, pdfWatermark: true },
    'starter': { photosPerMonth: 200, formTemplates: 3, users: 3, pdfWatermark: false },
    'pro': { photosPerMonth: 500, formTemplates: 10, users: 5, pdfWatermark: false },
    'business': { photosPerMonth: -1, formTemplates: -1, users: -1, pdfWatermark: false },
  };

  const productId = event.product_id;
  const plan = planMap[productId] || 'free';

  await admin.firestore().doc(`companies/${appUserId}`).update({
    'subscription.plan': plan,
    'subscription.status': event.type === 'CANCELLATION' ? 'cancelled' : 'active',
    'subscription.limits': limitsMap[plan],
    'subscription.expiresAt': admin.firestore.Timestamp.fromDate(
      new Date(event.expiration_at_ms)
    ),
  });

  res.sendStatus(200);
});
```

## 6. Testes

### 6.1 Sandbox Testing

- iOS: Criar Sandbox Tester no App Store Connect
- Android: Usar conta de teste no License Testing

### 6.2 Cenarios de Teste

| Cenario | Esperado |
|---------|----------|
| Compra bem-sucedida | Status = active, limites atualizados |
| Compra cancelada pelo usuario | Retorna para tela de planos |
| Erro de pagamento | Mensagem de erro, retry |
| Restore purchase | Restaura plano se existir |
| Expiracao | Status = expired, downgrade para Free |
| Cancelamento | Status = cancelled, mantem ate expirar |

## 7. Riscos e Mitigacoes

| Risco | Probabilidade | Mitigacao |
|-------|---------------|-----------|
| Rejeicao App Store | Media | Review guidelines, trial obrigatorio |
| Falha sync Firebase | Baixa | Retry com exponential backoff |
| Webhook nao recebido | Baixa | Sync manual na abertura do app |
| RevenueCat fora do ar | Muito baixa | Fallback para ultimo estado local |

## 8. Metricas de Sucesso

- Usuarios conseguem assinar sem erro
- Status sincronizado em < 5 segundos
- Taxa de erro de compra < 1%
- Restore funciona em 100% dos casos

## 9. Timeline

| Dia | Entregavel | Owner |
|-----|------------|-------|
| D1 | Setup lojas + RevenueCat | CTO |
| D2 | SDK Flutter integrado | Flutter Engineer |
| D3 | Backend sync funcionando | CTO |
| D4 | Tela de planos | Flutter Engineer |
| D5 | UX de upgrade | Flutter Engineer |
| D6 | Testes + polish | QA + Dev |

**Total estimado: 6 dias de trabalho**

## 10. Proximos Passos

1. [x] Aprovacao deste plano pelo Board
2. [ ] Criar conta RevenueCat
3. [ ] Configurar produtos nas lojas
4. [ ] Iniciar implementacao Flutter
5. [ ] Deploy Cloud Function
6. [ ] Testes em sandbox
7. [ ] Release para producao

---

**Documento criado por:** CTO Agent
**Revisao:** Board
**Aprovado em:** Pendente
