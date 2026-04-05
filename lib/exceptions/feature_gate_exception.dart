/// Excecao lancada quando um feature gate bloqueia a acao.
class FeatureGateLimitException implements Exception {
  /// Nome da feature que foi bloqueada: 'fotos', 'formularios', 'usuarios'
  final String feature;

  /// Mensagem descritiva para o usuario
  final String message;

  /// Plano sugerido para upgrade: 'starter', 'pro', 'business'
  final String? suggestedPlan;

  const FeatureGateLimitException({
    required this.feature,
    required this.message,
    this.suggestedPlan,
  });

  @override
  String toString() => 'FeatureGateLimitException: $message';
}
