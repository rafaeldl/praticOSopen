class FeatureFlags {
  /// Usar nova estrutura de subcollections para tenants
  static const bool useNewTenantStructure = false;

  /// Escrever em ambas as estruturas (antiga e nova)
  static const bool dualWriteEnabled = false;

  /// Ler da nova estrutura com fallback para antiga
  static const bool dualReadEnabled = false;
}
