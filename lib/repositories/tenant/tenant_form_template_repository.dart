import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Repository tenant-aware para FormDefinition (templates).
///
/// Path: `/companies/{companyId}/form_templates/{templateId}`
class TenantFormTemplateRepository extends TenantRepository<FormDefinition?> {
  TenantFormTemplateRepository() : super('form_templates');

  @override
  FormDefinition fromJson(Map<String, dynamic> data) =>
      FormDefinition.fromJson(data);

  @override
  Map<String, dynamic> toJson(FormDefinition? template) => template!.toJson();

  /// Stream de todos os templates do tenant ordenados por título.
  Stream<List<FormDefinition?>> streamTemplates(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('title')],
    );
  }

  /// Busca templates ativos do tenant.
  Future<List<FormDefinition?>> getActiveTemplates(String companyId) {
    return getQueryList(
      companyId,
      args: [QueryArgs('isActive', true)],
      orderBy: [OrderBy('title')],
    );
  }
}
