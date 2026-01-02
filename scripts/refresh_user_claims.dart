import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// Entry point for running the script
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final refresher = UserClaimsRefresher();
  await refresher.refreshAllUsers();
}

class UserClaimsRefresher {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int batchSize = 500;

  /// Força a atualização de todos os usuários para disparar a Cloud Function de claims
  Future<void> refreshAllUsers() async {
    print('════════════════════════════════════════════════════════════');
    print('  INICIANDO ATUALIZAÇÃO DE CLAIMS DE USUÁRIOS');
    print('════════════════════════════════════════════════════════════\n');

    final snapshot = await _db.collection('users').get();
    
    print('► Total de usuários encontrados: ${snapshot.docs.length}');

    WriteBatch batch = _db.batch();
    int batchCount = 0;
    int processedCount = 0;

    for (final doc in snapshot.docs) {
      // Atualiza o campo 'updatedAt' para forçar o trigger da Cloud Function
      // Se preferir não alterar dados reais, pode-se usar um campo de controle interno
      // como '_claimsRefreshAt'.
      batch.update(doc.reference, {
        'updatedAt': DateTime.now().toIso8601String(),
        '_claimsRefreshedAt': FieldValue.serverTimestamp(),
      });

      batchCount++;
      processedCount++;

      if (batchCount >= batchSize) {
        await batch.commit();
        print('  ✓ Processados $processedCount usuários...');
        batch = _db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    print('\n════════════════════════════════════════════════════════════');
    print('  ATUALIZAÇÃO CONCLUÍDA');
    print('  Total processado: $processedCount usuários');
    print('  A Cloud Function updateUserClaims foi disparada para cada um.');
    print('════════════════════════════════════════════════════════════');
  }
}
