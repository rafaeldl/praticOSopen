import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/tenant/tenant_form_template_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para FormTemplates usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/form_templates/{templateId}`
class FormTemplateRepositoryV2 extends RepositoryV2<FormDefinition?> {
  final TenantFormTemplateRepository _tenant = TenantFormTemplateRepository();

  @override
  TenantRepository<FormDefinition?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // FormTemplate-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os templates do tenant ordenados por título.
  Stream<List<FormDefinition?>> streamTemplates(String companyId) {
    return _tenant.streamTemplates(companyId);
  }

  /// Busca templates ativos do tenant.
  Future<List<FormDefinition?>> getActiveTemplates(String companyId) async {
    return await _tenant.getActiveTemplates(companyId);
  }
}
