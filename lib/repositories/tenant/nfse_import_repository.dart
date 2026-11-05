import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/nfse_import.dart';

/// Read-only access to `/companies/{companyId}/nfseImports` (issue #569).
/// Written only by the `nfseApi`; the rules let the owner and admins read.
class NfseImportRepository {
  NfseImportRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Stream<NfseImportBatch?> watch(String companyId, String batchId) => _db
      .collection('companies')
      .doc(companyId)
      .collection('nfseImports')
      .doc(batchId)
      .snapshots()
      .map(
        (snap) => snap.exists
            ? NfseImportBatch.fromJson(snap.data()!, id: snap.id)
            : null,
      );
}
