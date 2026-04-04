# Especificacao Tecnica: Feature Gates (PRA-13)

**Data:** 2026-04-03
**Autor:** CTO Agent
**Status:** Em especificacao
**Issue:** PRA-13
**Dependencia:** PRA-11 (In-App Purchase)

---

## 1. Visao Geral

Implementar sistema de feature gates que limita funcionalidades baseado no plano de assinatura da empresa. Os limites devem ser aplicados de forma transparente ao usuario, com mensagens claras e oportunidades de upgrade.

## 2. Matriz de Limites

| Feature | Free | Starter | Pro | Business |
|---------|------|---------|-----|----------|
| Fotos/mes | 30 | 200 | 500 | Ilimitado (-1) |
| Formularios ativos | 1 | 3 | 10 | Ilimitado (-1) |
| PDF marca dagua | Sim | Nao | Nao | Nao |
| Usuarios | 1 | 3 | 5 | Ilimitado (-1) |

---

## 3. Arquitetura

### 3.1 Fluxo de Dados

```
Company.subscription.limits (Firestore)
           ↓
   SubscriptionStore (MobX)
           ↓
    FeatureGateService (validacao)
           ↓
   Componentes UI (feedback ao usuario)
```

### 3.2 Modelo de Dados (Existente)

O modelo `Subscription` ja possui estrutura adequada em `lib/models/subscription.dart`:

```dart
class SubscriptionLimits {
  int? photosPerMonth;    // -1 = ilimitado
  int? formTemplates;     // -1 = ilimitado
  int? users;             // -1 = ilimitado
  bool? pdfWatermark;     // true = mostrar marca dagua
}

class SubscriptionUsage {
  int? photosThisMonth;
  int? formTemplatesActive;
  int? usersActive;
  DateTime? usageResetAt;
}
```

---

## 4. Feature Gate Service

### 4.1 Criar Arquivo

**Caminho:** `lib/services/feature_gate_service.dart`

### 4.2 Implementacao

```dart
import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../models/company.dart';

/// Resultado da verificacao de feature gate.
class FeatureGateResult {
  final bool isAllowed;
  final int currentUsage;
  final int limit;
  final double usagePercentage;
  final String? message;
  final String? suggestedPlan;

  const FeatureGateResult({
    required this.isAllowed,
    required this.currentUsage,
    required this.limit,
    required this.usagePercentage,
    this.message,
    this.suggestedPlan,
  });

  /// Verifica se esta em 80% do limite (aviso suave).
  bool get isNearLimit => usagePercentage >= 0.8 && usagePercentage < 1.0;

  /// Verifica se atingiu o limite.
  bool get isAtLimit => usagePercentage >= 1.0;

  /// Se limite e ilimitado.
  bool get isUnlimited => limit == -1;
}

/// Servico para verificar e aplicar feature gates.
class FeatureGateService {
  static const _defaultLimits = SubscriptionLimits(
    photosPerMonth: 30,
    formTemplates: 1,
    users: 1,
    pdfWatermark: true,
  );

  /// Verifica se pode adicionar mais fotos.
  static FeatureGateResult canAddPhoto(Company company) {
    final limits = company.subscription?.limits ?? _defaultLimits;
    final usage = company.subscription?.usage;

    final limit = limits.photosPerMonth ?? 30;
    final current = usage?.photosThisMonth ?? 0;

    // Ilimitado
    if (limit == -1) {
      return FeatureGateResult(
        isAllowed: true,
        currentUsage: current,
        limit: -1,
        usagePercentage: 0,
      );
    }

    final percentage = current / limit;
    final isAllowed = current < limit;

    String? message;
    String? suggestedPlan;

    if (!isAllowed) {
      message = 'Voce atingiu o limite de $limit fotos este mes.';
      suggestedPlan = _suggestPlanForPhotos(limit);
    } else if (percentage >= 0.8) {
      final remaining = limit - current;
      message = 'Restam apenas $remaining fotos este mes.';
    }

    return FeatureGateResult(
      isAllowed: isAllowed,
      currentUsage: current,
      limit: limit,
      usagePercentage: percentage,
      message: message,
      suggestedPlan: suggestedPlan,
    );
  }

  /// Verifica se pode criar mais formularios.
  static FeatureGateResult canCreateFormTemplate(Company company) {
    final limits = company.subscription?.limits ?? _defaultLimits;
    final usage = company.subscription?.usage;

    final limit = limits.formTemplates ?? 1;
    final current = usage?.formTemplatesActive ?? 0;

    if (limit == -1) {
      return FeatureGateResult(
        isAllowed: true,
        currentUsage: current,
        limit: -1,
        usagePercentage: 0,
      );
    }

    final percentage = current / limit;
    final isAllowed = current < limit;

    String? message;
    String? suggestedPlan;

    if (!isAllowed) {
      message = 'Voce atingiu o limite de $limit formularios ativos.';
      suggestedPlan = _suggestPlanForForms(limit);
    } else if (percentage >= 0.8) {
      final remaining = limit - current;
      message = 'Voce pode criar mais $remaining formulario(s).';
    }

    return FeatureGateResult(
      isAllowed: isAllowed,
      currentUsage: current,
      limit: limit,
      usagePercentage: percentage,
      message: message,
      suggestedPlan: suggestedPlan,
    );
  }

  /// Verifica se pode adicionar mais usuarios.
  static FeatureGateResult canAddUser(Company company) {
    final limits = company.subscription?.limits ?? _defaultLimits;
    final usage = company.subscription?.usage;

    final limit = limits.users ?? 1;
    final current = usage?.usersActive ?? 0;

    if (limit == -1) {
      return FeatureGateResult(
        isAllowed: true,
        currentUsage: current,
        limit: -1,
        usagePercentage: 0,
      );
    }

    final percentage = current / limit;
    final isAllowed = current < limit;

    String? message;
    String? suggestedPlan;

    if (!isAllowed) {
      message = 'Voce atingiu o limite de $limit usuarios.';
      suggestedPlan = _suggestPlanForUsers(limit);
    } else if (percentage >= 0.8) {
      final remaining = limit - current;
      message = 'Voce pode adicionar mais $remaining usuario(s).';
    }

    return FeatureGateResult(
      isAllowed: isAllowed,
      currentUsage: current,
      limit: limit,
      usagePercentage: percentage,
      message: message,
      suggestedPlan: suggestedPlan,
    );
  }

  /// Verifica se PDF deve ter marca dagua.
  static bool shouldShowPdfWatermark(Company company) {
    final limits = company.subscription?.limits ?? _defaultLimits;
    return limits.pdfWatermark ?? true;
  }

  /// Sugere plano baseado no limite de fotos atual.
  static String _suggestPlanForPhotos(int currentLimit) {
    if (currentLimit <= 30) return 'starter';
    if (currentLimit <= 200) return 'pro';
    return 'business';
  }

  /// Sugere plano baseado no limite de formularios atual.
  static String _suggestPlanForForms(int currentLimit) {
    if (currentLimit <= 1) return 'starter';
    if (currentLimit <= 3) return 'pro';
    return 'business';
  }

  /// Sugere plano baseado no limite de usuarios atual.
  static String _suggestPlanForUsers(int currentLimit) {
    if (currentLimit <= 1) return 'starter';
    if (currentLimit <= 3) return 'pro';
    return 'business';
  }
}
```

---

## 5. Integracao com Componentes Existentes

### 5.1 PhotoService - Contador de Fotos

**Arquivo:** `lib/services/photo_service.dart`

Adicionar ao metodo `uploadOrderPhoto()`:

```dart
import '../services/feature_gate_service.dart';

Future<OrderPhoto?> uploadOrderPhoto({
  required Company company,
  required Order order,
  required File file,
  required User user,
}) async {
  // NOVO: Verificar feature gate antes do upload
  final gateResult = FeatureGateService.canAddPhoto(company);

  if (!gateResult.isAllowed) {
    // Retornar null ou lancar excecao com mensagem
    throw FeatureGateLimitException(
      feature: 'fotos',
      message: gateResult.message!,
      suggestedPlan: gateResult.suggestedPlan,
    );
  }

  // ... codigo existente de upload ...

  // NOVO: Apos upload bem-sucedido, incrementar contador
  await _incrementPhotoUsage(company.id!);

  return orderPhoto;
}

/// Incrementa contador de fotos no Firestore.
Future<void> _incrementPhotoUsage(String companyId) async {
  await _firestore
      .collection('companies')
      .doc(companyId)
      .update({
        'subscription.usage.photosThisMonth': FieldValue.increment(1),
      });
}
```

### 5.2 FormTemplateStore - Contador de Formularios

**Arquivo:** `lib/mobx/form_template_store.dart`

Adicionar verificacao ao criar template:

```dart
import '../services/feature_gate_service.dart';

@action
Future<void> saveTemplate(FormDefinition template) async {
  // NOVO: Verificar feature gate antes de criar
  final gateResult = FeatureGateService.canCreateFormTemplate(company);

  if (!gateResult.isAllowed) {
    throw FeatureGateLimitException(
      feature: 'formularios',
      message: gateResult.message!,
      suggestedPlan: gateResult.suggestedPlan,
    );
  }

  // ... codigo existente ...

  // NOVO: Apos criar, incrementar contador
  await _updateFormTemplateUsage(company.id!);
}

/// Atualiza contador de templates ativos.
Future<void> _updateFormTemplateUsage(String companyId) async {
  // Conta templates ativos da empresa
  final templates = await _formsService.getCompanyTemplates(companyId);
  final activeCount = templates.where((t) => t.isActive).length;

  await _firestore
      .collection('companies')
      .doc(companyId)
      .update({
        'subscription.usage.formTemplatesActive': activeCount,
      });
}
```

### 5.3 CollaboratorStore - Contador de Usuarios

**Arquivo:** `lib/mobx/collaborator_store.dart`

Adicionar verificacao ao adicionar usuario:

```dart
import '../services/feature_gate_service.dart';

@action
Future<void> addCollaborator(User user, RolesType role) async {
  // NOVO: Verificar feature gate antes de adicionar
  final gateResult = FeatureGateService.canAddUser(company);

  if (!gateResult.isAllowed) {
    throw FeatureGateLimitException(
      feature: 'usuarios',
      message: gateResult.message!,
      suggestedPlan: gateResult.suggestedPlan,
    );
  }

  // ... codigo existente ...

  // NOVO: Apos adicionar, atualizar contador
  await _updateUserUsage(company.id!);
}

/// Atualiza contador de usuarios ativos.
Future<void> _updateUserUsage(String companyId) async {
  final memberships = await _loadMemberships(companyId);

  await _firestore
      .collection('companies')
      .doc(companyId)
      .update({
        'subscription.usage.usersActive': memberships.length,
      });
}
```

### 5.4 PdfService - Marca Dagua

**Arquivo:** `lib/services/pdf/pdf_service.dart`

Adicionar marca dagua condicional:

```dart
import '../feature_gate_service.dart';

Future<Uint8List> generateOsPdf(OsPdfData data, OsPdfOptions options) async {
  // ... codigo existente ...

  // NOVO: Verificar se deve adicionar marca dagua
  final shouldWatermark = FeatureGateService.shouldShowPdfWatermark(data.company);

  final mainOsBuilder = PdfMainOsBuilder(
    // ... parametros existentes ...
    showWatermark: shouldWatermark, // NOVO
  );

  // ... resto do codigo ...
}
```

**Arquivo:** `lib/services/pdf/pdf_main_os_builder.dart`

Adicionar suporte a marca dagua:

```dart
class PdfMainOsBuilder {
  final bool showWatermark;

  // ... construtor atualizado ...

  /// Constroi marca dagua PraticOS.
  pw.Widget buildWatermark() {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -0.785, // -45 graus
          child: pw.Opacity(
            opacity: 0.08,
            child: pw.Text(
              'PraticOS',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 72,
                color: PdfColors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constroi conteudo com ou sem marca dagua.
  List<pw.Widget> buildContentWithWatermark(/* params */) {
    final content = buildContent(/* params */);

    if (!showWatermark) return content;

    // Envolve cada pagina com marca dagua
    return content.map((widget) {
      return pw.Stack(
        children: [
          widget,
          buildWatermark(),
        ],
      );
    }).toList();
  }
}
```

---

## 6. UX de Limites

### 6.1 Widget de Aviso Suave (80%)

**Arquivo:** `lib/widgets/feature_gate_warning.dart`

```dart
import 'package:flutter/cupertino.dart';
import '../services/feature_gate_service.dart';

/// Widget que exibe aviso quando usuario esta proximo do limite.
class FeatureGateWarning extends StatelessWidget {
  final FeatureGateResult gateResult;
  final String featureName; // "fotos", "formularios", "usuarios"
  final VoidCallback? onUpgradeTap;

  const FeatureGateWarning({
    super.key,
    required this.gateResult,
    required this.featureName,
    this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!gateResult.isNearLimit) return const SizedBox.shrink();

    final remaining = gateResult.limit - gateResult.currentUsage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemYellow.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemYellow,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Restam $remaining $featureName este mes.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (onUpgradeTap != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onUpgradeTap,
              child: const Text(
                'Upgrade',
                style: TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
```

### 6.2 Modal de Limite Atingido (100%)

**Arquivo:** `lib/widgets/feature_gate_limit_modal.dart`

```dart
import 'package:flutter/cupertino.dart';
import '../constants/subscription_plans.dart';

/// Modal exibido quando usuario atinge 100% do limite.
class FeatureGateLimitModal extends StatelessWidget {
  final String featureName;
  final int currentUsage;
  final int limit;
  final String? suggestedPlan;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  const FeatureGateLimitModal({
    super.key,
    required this.featureName,
    required this.currentUsage,
    required this.limit,
    this.suggestedPlan,
    required this.onUpgrade,
    required this.onDismiss,
  });

  static void show(
    BuildContext context, {
    required String featureName,
    required int currentUsage,
    required int limit,
    String? suggestedPlan,
    required VoidCallback onUpgrade,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => FeatureGateLimitModal(
        featureName: featureName,
        currentUsage: currentUsage,
        limit: limit,
        suggestedPlan: suggestedPlan,
        onUpgrade: onUpgrade,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = suggestedPlan != null
        ? SubscriptionPlans.all.firstWhere((p) => p.id == suggestedPlan)
        : SubscriptionPlans.starter;

    final newLimit = _getNewLimit(plan.id, featureName);

    return CupertinoActionSheet(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIcon(),
            color: CupertinoColors.systemRed,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text('Limite de $featureName atingido'),
        ],
      ),
      message: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Voce usou $currentUsage de $limit $featureName este mes.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Com o ${plan.name} voce pode ter',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  newLimit == -1 ? '$featureName ilimitados!' : 'ate $newLimit $featureName!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por apenas ${plan.price}',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGreen.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: onUpgrade,
          isDefaultAction: true,
          child: const Text('Fazer upgrade'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: onDismiss,
        child: const Text('Talvez depois'),
      ),
    );
  }

  IconData _getIcon() {
    switch (featureName) {
      case 'fotos':
        return CupertinoIcons.photo;
      case 'formularios':
        return CupertinoIcons.doc_text;
      case 'usuarios':
        return CupertinoIcons.person_2;
      default:
        return CupertinoIcons.exclamationmark_circle;
    }
  }

  int _getNewLimit(String planId, String feature) {
    final plan = SubscriptionPlans.all.firstWhere((p) => p.id == planId);
    switch (feature) {
      case 'fotos':
        return plan.features['photosPerMonth'] as int;
      case 'formularios':
        return plan.features['formTemplates'] as int;
      case 'usuarios':
        return plan.features['users'] as int;
      default:
        return -1;
    }
  }
}
```

---

## 7. Excecao Customizada

**Arquivo:** `lib/exceptions/feature_gate_exception.dart`

```dart
/// Excecao lancada quando um feature gate bloqueia a acao.
class FeatureGateLimitException implements Exception {
  final String feature;
  final String message;
  final String? suggestedPlan;

  const FeatureGateLimitException({
    required this.feature,
    required this.message,
    this.suggestedPlan,
  });

  @override
  String toString() => 'FeatureGateLimitException: $message';
}
```

---

## 8. Cloud Function - Reset Mensal

**Arquivo:** `functions/src/subscription/resetMonthlyUsage.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function agendada para resetar contadores mensais.
 * Executa no primeiro dia de cada mes as 00:00 UTC-3.
 */
export const resetMonthlyUsage = functions.pubsub
  .schedule('0 3 1 * *') // 00:00 BRT = 03:00 UTC
  .timeZone('America/Sao_Paulo')
  .onRun(async (context) => {
    const db = admin.firestore();

    const companiesSnapshot = await db.collection('companies').get();

    const batch = db.batch();
    const now = new Date();
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    companiesSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        'subscription.usage.photosThisMonth': 0,
        'subscription.usage.usageResetAt': admin.firestore.Timestamp.fromDate(nextMonth),
      });
    });

    await batch.commit();

    console.log(`Reset usage for ${companiesSnapshot.size} companies`);
    return null;
  });
```

---

## 9. Estrutura de Arquivos

```
lib/
├── exceptions/
│   └── feature_gate_exception.dart         # NOVO
├── services/
│   ├── feature_gate_service.dart           # NOVO
│   ├── photo_service.dart                  # MODIFICAR
│   └── pdf/
│       ├── pdf_service.dart                # MODIFICAR
│       └── pdf_main_os_builder.dart        # MODIFICAR
├── mobx/
│   ├── form_template_store.dart            # MODIFICAR
│   └── collaborator_store.dart             # MODIFICAR
└── widgets/
    ├── feature_gate_warning.dart           # NOVO
    └── feature_gate_limit_modal.dart       # NOVO

functions/src/subscription/
└── resetMonthlyUsage.ts                    # NOVO
```

---

## 10. Checklist de Implementacao

### Backend / Services
- [ ] Criar `lib/exceptions/feature_gate_exception.dart`
- [ ] Criar `lib/services/feature_gate_service.dart`
- [ ] Modificar `lib/services/photo_service.dart` - verificacao e contador
- [ ] Modificar `lib/mobx/form_template_store.dart` - verificacao e contador
- [ ] Modificar `lib/mobx/collaborator_store.dart` - verificacao e contador

### PDF / Marca Dagua
- [ ] Modificar `lib/services/pdf/pdf_service.dart` - passar flag de watermark
- [ ] Modificar `lib/services/pdf/pdf_main_os_builder.dart` - implementar marca dagua

### UI / Widgets
- [ ] Criar `lib/widgets/feature_gate_warning.dart`
- [ ] Criar `lib/widgets/feature_gate_limit_modal.dart`
- [ ] Integrar warning nas telas relevantes (fotos, formularios, usuarios)
- [ ] Integrar modal quando limite atingido

### Cloud Functions
- [ ] Criar `functions/src/subscription/resetMonthlyUsage.ts`
- [ ] Configurar schedule no Firebase
- [ ] Testar em ambiente de staging

### Testes
- [ ] Testes unitarios para `FeatureGateService`
- [ ] Testes de widget para `FeatureGateWarning` e `FeatureGateLimitModal`
- [ ] Testes de integracao para fluxo completo

---

## 11. Observacoes Importantes

1. **Graceful Degradation:** Nao bloquear usuario completamente. Permitir continuar com aviso/modal.

2. **Sincronizacao de Contadores:** Contadores devem ser atualizados atomicamente no Firestore.

3. **Offline-First:** Verificacoes locais devem funcionar offline, mas contadores so sao confiáveis online.

4. **Performance:** Evitar queries extras. Usar dados ja carregados no Company/Subscription.

5. **Consistencia:** Se foto foi enviada mas contador nao atualizou, tratar no proximo upload.

---

**Documento criado por:** CTO Agent
**Proximos passos:** Delegar implementacao ao Flutter Engineer
