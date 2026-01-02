import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// Entry point for running the rollback
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final rollback = TenantDataRollback();
  await rollback.emergencyRollback();
}

class TenantDataRollback {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> collectionsToMigrate = [
    'orders',
    'customers',
    'devices',
    'products',
    'services',
    'roles',
  ];

  /// Executa rollback de emergência
  /// Sincroniza dados da nova estrutura de volta para a antiga
  Future<void> emergencyRollback() async {
    print('════════════════════════════════════════════════════════════');
    print('  INICIANDO ROLLBACK DE DADOS');
    print('════════════════════════════════════════════════════════════\n');

    final companies = await _db.collection('companies').get();

    for (final company in companies.docs) {
      print('► Processando empresa: ${company.id}');
      
      for (final collection in collectionsToMigrate) {
        print('  - Collection: $collection');
        
        final newDocs = await _db
            .collection('companies')
            .doc(company.id)
            .collection(collection)
            .get();

        if (newDocs.docs.isEmpty) {
          continue;
        }

        WriteBatch batch = _db.batch();
        int batchCount = 0;
        int restoredCount = 0;

        for (final doc in newDocs.docs) {
          final oldRef = _db.collection(collection).doc(doc.id);
          
          // Set com merge para não sobrescrever campos que talvez não tenham mudado,
          // mas idealmente deveríamos sobrescrever tudo para garantir consistência com a "nova" versão que está sendo rejeitada?
          // Ou garantir que a versão "nova" é a fonte da verdade até o momento do rollback?
          // O plano diz: "Sincronizar de volta para estrutura antiga"
          batch.set(oldRef, doc.data(), SetOptions(merge: true));
          
          batchCount++;
          restoredCount++;

          if (batchCount >= 500) {
            await batch.commit();
            print('    ✓ Restaurados $restoredCount documentos...');
            batch = _db.batch();
            batchCount = 0;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }
        
        print('    ✓ Total restaurados em $collection: $restoredCount');
      }
    }

    print('\n════════════════════════════════════════════════════════════');
    print('  ROLLBACK CONCLUÍDO');
    print('════════════════════════════════════════════════════════════');
  }
}
