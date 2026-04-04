import 'package:praticos/models/company.dart';
import 'package:praticos/models/subscription.dart';

/// Resultado da verificacao de feature gate.
class FeatureGateResult {
  /// Se a acao e permitida
  final bool isAllowed;

  /// Uso atual da feature
  final int currentUsage;

  /// Limite do plano atual (-1 = ilimitado)
  final int limit;

  /// Percentual de uso (0.0 a 1.0+)
  final double usagePercentage;

  /// Mensagem para exibir ao usuario
  final String? message;

  /// Plano sugerido para upgrade
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
///
/// Os feature gates limitam funcionalidades baseado no plano de assinatura:
/// - Free: 30 fotos/mes, 1 formulario, 1 usuario, PDF com marca d'agua
/// - Starter: 200 fotos/mes, 3 formularios, 3 usuarios
/// - Pro: 500 fotos/mes, 10 formularios, 5 usuarios
/// - Business: Ilimitado (-1)
class FeatureGateService {
  /// Limites padrao para plano Free (lazy initialized)
  static SubscriptionLimits? _defaultLimitsInstance;

  static SubscriptionLimits get _defaultLimits {
    _defaultLimitsInstance ??= SubscriptionLimitsConst.create(
      photosPerMonth: 30,
      formTemplates: 1,
      users: 1,
      pdfWatermark: true,
    );
    return _defaultLimitsInstance!;
  }

  /// Verifica se pode adicionar mais fotos.
  static FeatureGateResult canAddPhoto(Company company) {
    return canAddPhotoWithSubscription(company.subscription);
  }

  /// Verifica se pode adicionar mais fotos usando Subscription diretamente.
  /// Util quando nao temos acesso ao Company completo.
  static FeatureGateResult canAddPhotoWithSubscription(Subscription? subscription) {
    final limits = subscription?.limits ?? _defaultLimits;
    final usage = subscription?.usage;

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

    final percentage = limit > 0 ? current / limit : 0.0;
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

    final percentage = limit > 0 ? current / limit : 0.0;
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

    final percentage = limit > 0 ? current / limit : 0.0;
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

/// Extensao para SubscriptionLimits com construtor const.
extension SubscriptionLimitsConst on SubscriptionLimits {
  /// Cria uma instancia com valores constantes.
  static SubscriptionLimits create({
    int? photosPerMonth,
    int? formTemplates,
    int? users,
    bool? pdfWatermark,
  }) {
    final limits = SubscriptionLimits();
    limits.photosPerMonth = photosPerMonth;
    limits.formTemplates = formTemplates;
    limits.users = users;
    limits.pdfWatermark = pdfWatermark;
    return limits;
  }
}
