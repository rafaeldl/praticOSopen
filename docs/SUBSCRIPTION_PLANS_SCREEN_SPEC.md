# Especificacao Tecnica: Tela de Planos de Assinatura (PRA-12)

**Data:** 2026-04-03
**Autor:** CTO Agent
**Status:** Em implementacao
**Issue:** PRA-12 (subtarefa: PRA-18)

---

## 1. Visao Geral

Implementar tela de comparacao de planos e fluxo completo de upgrade no PraticOS, seguindo os padroes de UX_GUIDELINES.md (estilo iOS/Cupertino nativo).

## 2. Escopo de Telas

### 2.1 PlansScreen (`plans_screen.dart`)
Tela principal de comparacao e selecao de planos.

### 2.2 SubscriptionSuccessScreen (`subscription_success_screen.dart`)
Tela de confirmacao apos compra bem-sucedida.

### 2.3 ManageSubscriptionScreen (`manage_subscription_screen.dart`)
Tela de gerenciamento da assinatura atual.

### 2.4 UpgradePromptModal (Widget reutilizavel)
Modal contextual que aparece quando usuario atinge limite.

---

## 3. Estrutura de Arquivos

```
lib/screens/subscription/
├── plans_screen.dart
├── subscription_success_screen.dart
├── manage_subscription_screen.dart
└── widgets/
    ├── plan_card.dart
    ├── feature_row.dart
    └── upgrade_prompt_modal.dart
```

---

## 4. Especificacao: PlansScreen

### 4.1 Layout Geral

```
┌─────────────────────────────────────┐
│ ← Planos         [Restaurar compra] │  <- CupertinoNavigationBar
├─────────────────────────────────────┤
│                                     │
│  [Icone Coroa]                      │  <- Icone decorativo
│  Escolha seu plano                  │  <- Titulo
│  Desbloqueie todo o potencial       │  <- Subtitulo
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ STARTER              R$ 59/mes │ │  <- Card de plano
│ │ ✓ 200 fotos/mes                │ │
│ │ ✓ 3 formularios                │ │
│ │ ✓ 3 usuarios                   │ │
│ │ ✓ PDF sem marca d'agua         │ │
│ │          [Assinar]             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ ⭐ RECOMENDADO                 │ │  <- Badge de destaque
│ │ PRO                  R$ 119/mes│ │
│ │ ✓ 500 fotos/mes                │ │
│ │ ✓ 10 formularios               │ │
│ │ ✓ 5 usuarios                   │ │
│ │ ✓ PDF sem marca d'agua         │ │
│ │          [Assinar]             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ BUSINESS             R$ 249/mes│ │
│ │ ✓ Fotos ilimitadas             │ │
│ │ ✓ Formularios ilimitados       │ │
│ │ ✓ Usuarios ilimitados          │ │
│ │ ✓ PDF sem marca d'agua         │ │
│ │          [Assinar]             │ │
│ └─────────────────────────────────┘ │
│                                     │
│  Seu plano atual: Free              │  <- Indicador de plano atual
│                                     │
│  Termos de Uso | Politica Privac.   │  <- Links legais
└─────────────────────────────────────┘
```

### 4.2 Estrutura do Codigo

```dart
class PlansScreen extends StatefulWidget {
  final bool isModal; // Se true, mostra botao de fechar em vez de voltar
  final String? highlightFeature; // Feature a destacar (ex: "fotos")

  const PlansScreen({
    super.key,
    this.isModal = false,
    this.highlightFeature,
  });

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _isLoading = false;
  String? _selectedPlan;
  String _currentPlan = 'free';

  @override
  void initState() {
    super.initState();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    // Buscar plano atual da Company
  }

  Future<void> _purchasePlan(String planId) async {
    // Acionar RevenueCat para compra
  }

  Future<void> _restorePurchases() async {
    // Restaurar compras anteriores
  }
}
```

### 4.3 Componentes

#### PlanCard Widget

```dart
class PlanCard extends StatelessWidget {
  final String planId;        // 'starter', 'pro', 'business'
  final String name;
  final String price;         // "R$ 59/mes"
  final List<String> features;
  final bool isRecommended;
  final bool isCurrentPlan;
  final bool isLoading;
  final VoidCallback onTap;

  // Cores por plano
  // Starter: CupertinoColors.activeBlue
  // Pro: CupertinoColors.activeOrange (ou customizado)
  // Business: CupertinoColors.systemPurple
}
```

#### FeatureRow Widget

```dart
class FeatureRow extends StatelessWidget {
  final String text;
  final bool isIncluded;
  final bool isHighlighted; // Destaca feature especifica

  // Icone: CupertinoIcons.checkmark_circle_fill (verde) ou
  //        CupertinoIcons.xmark_circle_fill (vermelho para nao incluido)
}
```

### 4.4 Comportamentos

1. **Carregamento inicial:**
   - Mostrar `CupertinoActivityIndicator` enquanto busca plano atual
   - Carregar offerings do RevenueCat

2. **Selecao de plano:**
   - Ao clicar "Assinar", mostrar loading no botao
   - Chamar `Purchases.purchasePackage()`
   - Em caso de sucesso, navegar para `SubscriptionSuccessScreen`
   - Em caso de erro, mostrar `CupertinoAlertDialog`

3. **Restaurar compras:**
   - Botao no canto superior direito
   - Mostrar loading durante processo
   - Atualizar UI se encontrar assinatura

4. **Plano atual:**
   - Se usuario ja tem plano pago, mostrar "Plano atual" no card
   - Desabilitar botao do plano atual

### 4.5 Deep Link

Configurar rota `praticos://upgrade` para abrir `PlansScreen`:

```dart
// Em routes.dart ou deep_link_handler.dart
case 'upgrade':
  return CupertinoPageRoute(
    builder: (_) => const PlansScreen(isModal: true),
  );
```

---

## 5. Especificacao: SubscriptionSuccessScreen

### 5.1 Layout

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│          ✓ (checkmark grande)       │  <- Icone de sucesso animado
│                                     │
│       Parabens!                     │  <- Titulo
│                                     │
│  Voce agora tem acesso ao plano     │
│           Pro                       │  <- Nome do plano em destaque
│                                     │
│  Recursos liberados:                │
│  ✓ 500 fotos por mes                │
│  ✓ 10 formularios                   │
│  ✓ 5 usuarios                       │
│  ✓ PDF profissional                 │
│                                     │
│      [Comecar a usar]               │  <- Botao principal
│                                     │
└─────────────────────────────────────┘
```

### 5.2 Codigo

```dart
class SubscriptionSuccessScreen extends StatelessWidget {
  final String planName;
  final List<String> features;

  const SubscriptionSuccessScreen({
    super.key,
    required this.planName,
    required this.features,
  });
}
```

---

## 6. Especificacao: ManageSubscriptionScreen

### 6.1 Layout

```
┌─────────────────────────────────────┐
│ ← Assinatura                        │
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Seu plano atual                 │ │
│ │                                 │ │
│ │ Pro               R$ 119/mes    │ │
│ │ Status: Ativo                   │ │
│ │ Renova em: 15/05/2026           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ > Alterar plano                 │ │  -> Navega para PlansScreen
│ │ > Restaurar compras             │ │  -> Aciona restore
│ │ > Cancelar assinatura           │ │  -> Abre App Store/Play Store
│ └─────────────────────────────────┘ │
│                                     │
│ Cancelamento: A assinatura permanece│
│ ativa ate a data de renovacao.      │
│                                     │
└─────────────────────────────────────┘
```

---

## 7. Especificacao: UpgradePromptModal

### 7.1 Layout

```
┌─────────────────────────────────────┐
│                                     │
│     📷 (icone relacionado)          │
│                                     │
│  Limite de fotos atingido           │  <- Titulo contextual
│                                     │
│  Voce usou 30 de 30 fotos este mes  │  <- Contador
│                                     │
│  Com o Starter voce pode enviar     │
│  ate 200 fotos por mes!             │  <- Beneficio
│                                     │
│  Por apenas R$ 59/mes               │  <- Preco
│                                     │
│      [Fazer upgrade]                │  <- Botao primario
│      [Talvez depois]                │  <- Botao secundario
│                                     │
└─────────────────────────────────────┘
```

### 7.2 Codigo

```dart
class UpgradePromptModal extends StatelessWidget {
  final String featureName;    // "fotos", "formularios", "usuarios"
  final int currentUsage;
  final int limit;
  final String suggestedPlan;  // "starter", "pro"
  final int newLimit;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  static void show(BuildContext context, {...}) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => UpgradePromptModal(...),
    );
  }
}
```

---

## 8. Dados dos Planos

### 8.1 Constantes

```dart
// lib/constants/subscription_plans.dart

class SubscriptionPlans {
  static const free = PlanDefinition(
    id: 'free',
    name: 'Free',
    price: 'Gratis',
    priceMonthly: 0,
    features: {
      'photosPerMonth': 30,
      'formTemplates': 1,
      'users': 1,
      'pdfWatermark': true,
    },
    featureDescriptions: [
      '30 fotos por mes',
      '1 formulario',
      '1 usuario',
      'PDF com marca d\'agua',
    ],
  );

  static const starter = PlanDefinition(
    id: 'starter',
    name: 'Starter',
    price: 'R\$ 59/mes',
    priceMonthly: 59,
    productId: 'praticos_starter_monthly',
    features: {
      'photosPerMonth': 200,
      'formTemplates': 3,
      'users': 3,
      'pdfWatermark': false,
    },
    featureDescriptions: [
      '200 fotos por mes',
      '3 formularios',
      '3 usuarios',
      'PDF profissional',
    ],
  );

  static const pro = PlanDefinition(
    id: 'pro',
    name: 'Pro',
    price: 'R\$ 119/mes',
    priceMonthly: 119,
    productId: 'praticos_pro_monthly',
    isRecommended: true,
    features: {
      'photosPerMonth': 500,
      'formTemplates': 10,
      'users': 5,
      'pdfWatermark': false,
    },
    featureDescriptions: [
      '500 fotos por mes',
      '10 formularios',
      '5 usuarios',
      'PDF profissional',
    ],
  );

  static const business = PlanDefinition(
    id: 'business',
    name: 'Business',
    price: 'R\$ 249/mes',
    priceMonthly: 249,
    productId: 'praticos_business_monthly',
    features: {
      'photosPerMonth': -1, // ilimitado
      'formTemplates': -1,
      'users': -1,
      'pdfWatermark': false,
    },
    featureDescriptions: [
      'Fotos ilimitadas',
      'Formularios ilimitados',
      'Usuarios ilimitados',
      'PDF profissional',
    ],
  );

  static const all = [free, starter, pro, business];
  static const paid = [starter, pro, business];
}
```

---

## 9. Integracao com MobX

### 9.1 SubscriptionStore

```dart
// lib/mobx/subscription_store.dart

import 'package:mobx/mobx.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

part 'subscription_store.g.dart';

class SubscriptionStore = _SubscriptionStore with _$SubscriptionStore;

abstract class _SubscriptionStore with Store {
  @observable
  String currentPlan = 'free';

  @observable
  Subscription? subscription;

  @observable
  Offerings? offerings;

  @observable
  bool isLoading = false;

  @observable
  String? error;

  @computed
  bool get isPaidUser => currentPlan != 'free';

  @computed
  bool get isTrialing => subscription?.status == 'trialing';

  @action
  Future<void> loadSubscription() async {
    // Carregar do Company atual
  }

  @action
  Future<void> loadOfferings() async {
    offerings = await Purchases.getOfferings();
  }

  @action
  Future<bool> purchase(String productId) async {
    // Implementar compra
  }

  @action
  Future<bool> restore() async {
    // Implementar restore
  }
}
```

---

## 10. Rotas

Adicionar ao sistema de rotas:

```dart
// Em routes.dart

static const subscriptionPlans = '/subscription/plans';
static const subscriptionSuccess = '/subscription/success';
static const subscriptionManage = '/subscription/manage';

// Handlers
case subscriptionPlans:
  return CupertinoPageRoute(
    builder: (_) => const PlansScreen(),
  );

case subscriptionSuccess:
  final args = settings.arguments as Map<String, dynamic>;
  return CupertinoPageRoute(
    builder: (_) => SubscriptionSuccessScreen(
      planName: args['planName'],
      features: args['features'],
    ),
  );

case subscriptionManage:
  return CupertinoPageRoute(
    builder: (_) => const ManageSubscriptionScreen(),
  );
```

---

## 11. Consideracoes de UX

### 11.1 Seguindo UX_GUIDELINES.md

- Usar `CupertinoPageScaffold` para estrutura base
- Usar `CupertinoNavigationBar` para barra superior
- Usar `CupertinoColors` com `.resolveFrom(context)` para dark mode
- Botoes de acao: usar `CupertinoButton.filled` para primario
- Loading: usar `CupertinoActivityIndicator`
- Alertas: usar `CupertinoAlertDialog`

### 11.2 Acessibilidade

- Usar `Semantics` para elementos interativos
- Contraste adequado entre texto e fundo
- Tamanho minimo de toque de 44x44

### 11.3 Feedback Visual

- Feedback haptico em compras bem-sucedidas
- Animacao de transicao suave entre estados
- Loading overlay durante processamento

---

## 12. Testes Sugeridos

### 12.1 Testes Unitarios

- `SubscriptionStore` - states e actions
- `PlanDefinition` - parsing e comparacoes

### 12.2 Testes de Widget

- `PlanCard` - renderizacao correta
- `UpgradePromptModal` - callbacks

### 12.3 Testes de Integracao

- Fluxo completo de compra (sandbox)
- Restore purchase
- Deep link `praticos://upgrade`

---

## 13. Checklist de Implementacao

- [ ] Criar pasta `lib/screens/subscription/`
- [ ] Implementar `plans_screen.dart`
- [ ] Implementar `plan_card.dart` widget
- [ ] Implementar `feature_row.dart` widget
- [ ] Implementar `subscription_success_screen.dart`
- [ ] Implementar `manage_subscription_screen.dart`
- [ ] Implementar `upgrade_prompt_modal.dart`
- [ ] Criar `lib/constants/subscription_plans.dart`
- [ ] Criar/atualizar `lib/mobx/subscription_store.dart`
- [ ] Adicionar rotas em `routes.dart`
- [ ] Configurar deep link `praticos://upgrade`
- [ ] Testar dark mode
- [ ] Testar em iOS e Android
- [ ] Code review

---

**Documento criado por:** CTO Agent
**Aprovacao:** Em andamento
**Implementacao:** Flutter Engineer (PRA-18)
