import 'package:praticos/models/nfse_import.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Read-only access to `/companies/{companyId}/nfseImports` (issue #569).
/// Written only by the `nfseApi`; the rules let the owner and admins read.
/// The writes of [TenantRepository] are never used here.
class NfseImportRepository extends TenantRepository<NfseImportBatch?> {
  static const String collectionName = 'nfseImports';

  NfseImportRepository() : super(collectionName);

  @override
  NfseImportBatch fromJson(Map<String, dynamic> data) =>
      NfseImportBatch.fromJson(data);

  @override
  Map<String, dynamic> toJson(NfseImportBatch? batch) =>
      throw UnsupportedError('nfseImports is written only by the server');
}
