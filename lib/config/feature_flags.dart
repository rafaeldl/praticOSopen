/// Feature flags para controle da migração multi-tenancy.
///
/// Estas flags controlam o comportamento do sistema durante a migração
/// da arquitetura field-based para subcollections.
///
/// Ordem de ativação:
/// 1. dualWriteEnabled = true  → Escritas em ambas estruturas
/// 2. dualReadEnabled = true   → Leitura da nova estrutura com fallback
/// 3. useNewTenantStructure = true → Cutover completo para nova estrutura
class FeatureFlags {
  /// Usar nova estrutura de subcollections para tenants.
  ///
  /// Quando true, leituras e escritas usam a nova estrutura:
  /// `/companies/{companyId}/{collection}/{docId}`
  ///
  /// Quando false, usa a estrutura antiga:
  /// `/{collection}/{docId}` com filtro `company.id`
  static const bool useNewTenantStructure = false;

  /// Habilitar dual-write para ambas as estruturas.
  ///
  /// Quando true, todas as escritas vão para:
  /// - Estrutura antiga: `/{collection}/{docId}`
  /// - Estrutura nova: `/companies/{companyId}/{collection}/{docId}`
  ///
  /// Isso garante que ambas as estruturas permaneçam sincronizadas
  /// durante o período de migração.
  static const bool dualWriteEnabled = false;

  /// Habilitar dual-read com fallback para estrutura antiga.
  ///
  /// Quando true E useNewTenantStructure = true:
  /// - Leitura primária: nova estrutura
  /// - Em caso de erro: fallback para estrutura antiga
  ///
  /// Útil para identificar problemas na nova estrutura sem
  /// causar falhas para o usuário.
  static const bool dualReadEnabled = false;

  // ═══════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════

  /// Retorna true se devemos escrever na estrutura antiga.
  static bool get shouldWriteToLegacy =>
      !useNewTenantStructure || dualWriteEnabled;

  /// Retorna true se devemos escrever na nova estrutura.
  static bool get shouldWriteToNew =>
      useNewTenantStructure || dualWriteEnabled;

  /// Retorna true se devemos ler da nova estrutura.
  static bool get shouldReadFromNew => useNewTenantStructure;

  /// Retorna true se devemos usar fallback para estrutura antiga.
  static bool get shouldFallbackToLegacy =>
      useNewTenantStructure && dualReadEnabled;
}
