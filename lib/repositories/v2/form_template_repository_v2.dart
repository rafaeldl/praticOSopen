import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/form_template_repository.dart';
import 'package:praticos/repositories/tenant/tenant_form_template_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para FormTemplates com suporte a dual-write/dual-read.
class FormTemplateRepositoryV2 extends RepositoryV2<FormDefinition?> {
  final FormTemplateRepository _legacy = FormTemplateRepository();
  final TenantFormTemplateRepository _tenant = TenantFormTemplateRepository();

  @override
  Repository<FormDefinition?> get legacyRepo => _legacy;

  @override
  TenantRepository<FormDefinition?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // FormTemplate-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os templates do tenant ordenados por título.
  Stream<List<FormDefinition?>> streamTemplates(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamTemplates(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[FormTemplateRepositoryV2] Fallback streamTemplates: $error');
          return _legacy.streamQueryList(
            orderBy: [OrderBy('title')],
            args: [QueryArgs('company.id', companyId)],
          );
        });
      }

      return stream;
    }

    return _legacy.streamQueryList(
      orderBy: [OrderBy('title')],
      args: [QueryArgs('company.id', companyId)],
    );
  }

  /// Busca templates ativos do tenant.
  Future<List<FormDefinition?>> getActiveTemplates(String companyId) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getActiveTemplates(companyId);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[FormTemplateRepositoryV2] Fallback getActiveTemplates: $e');
          return await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('isActive', true),
            ],
            orderBy: [OrderBy('title')],
          );
        }
        rethrow;
      }
    }

    return await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('isActive', true),
      ],
      orderBy: [OrderBy('title')],
    );
  }
}
