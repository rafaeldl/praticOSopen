import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/repositories/tenant_order_repository.dart';

class TenantDataMigration {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int batchSize = 500;
  static const List<String> collectionsToMigrate = [
    'orders',
    'customers',
    'devices',
    'products',
    'services',
    'roles',
  ];

  /// Executa migração completa
  Future<MigrationReport> migrateAll() async {
    final report = MigrationReport();

    print('════════════════════════════════════════════════════════════');
    print('  INICIANDO MIGRAÇÃO DE DADOS PARA SUBCOLLECTIONS');
    print('════════════════════════════════════════════════════════════\n');

    for (final collection in collectionsToMigrate) {
      final result = await migrateCollection(collection);
      report.addResult(collection, result);
    }

    print('\n════════════════════════════════════════════════════════════');
    print('  MIGRAÇÃO CONCLUÍDA');
    print('════════════════════════════════════════════════════════════');
    print(report.summary());

    return report;
  }

  /// Migra uma collection específica
  Future<CollectionMigrationResult> migrateCollection(String collectionName) async {
    print('► Migrando collection: $collectionName');

    final result = CollectionMigrationResult(collectionName);
    final snapshot = await _db.collection(collectionName).get();

    WriteBatch batch = _db.batch();
    int batchCount = 0;

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        // Accessing nested company.id safely
        final company = data['company'];
        String? companyId;
        if (company is Map) {
          companyId = company['id'];
        }

        if (companyId == null || companyId.isEmpty) {
          print('  ⚠️  Doc ${doc.id} sem company.id - pulando');
          result.skipped++;
          continue;
        }

        // Verificar se já existe na nova estrutura
        final existingDoc = await _db
            .collection('companies')
            .doc(companyId)
            .collection(collectionName)
            .doc(doc.id)
            .get();

        if (existingDoc.exists) {
          // Comparar timestamps para decidir qual é mais recente
          // Assuming timestamps are Timestamp objects from Firestore or ISO Strings
          final existingUpdatedAt = existingDoc.data()?['updatedAt'];
          final currentUpdatedAt = data['updatedAt'];

          bool skip = false;
          if (existingUpdatedAt != null && currentUpdatedAt != null) {
             // Basic comparison if they are comparable
             try {
                if ((existingUpdatedAt as Comparable).compareTo(currentUpdatedAt) >= 0) {
                   skip = true;
                }
             } catch (e) {
               // ignore comparison error
             }
          }

          if (skip) {
            result.skipped++;
            continue;
          }
        }

        // Criar referência na nova estrutura (mantendo mesmo ID)
        final newRef = _db
            .collection('companies')
            .doc(companyId)
            .collection(collectionName)
            .doc(doc.id);

        batch.set(newRef, data);
        batchCount++;
        result.migrated++;

        // Commit a cada batchSize documentos
        if (batchCount >= batchSize) {
          await batch.commit();
          print('  ✓ Migrados ${result.migrated} documentos...');
          batch = _db.batch();
          batchCount = 0;
        }

      } catch (e) {
        print('  ✗ Erro ao migrar ${doc.id}: $e');
        result.errors.add('${doc.id}: $e');
      }
    }

    // Commit final
    if (batchCount > 0) {
      await batch.commit();
    }

    print('  ✓ $collectionName: ${result.migrated} migrados, '
          '${result.skipped} pulados, ${result.errors.length} erros\n');

    return result;
  }
}

class MigrationReport {
  final Map<String, CollectionMigrationResult> results = {};

  void addResult(String collection, CollectionMigrationResult result) {
    results[collection] = result;
  }

  String summary() {
    final buffer = StringBuffer();
    int totalMigrated = 0;
    int totalSkipped = 0;
    int totalErrors = 0;

    for (final entry in results.entries) {
      totalMigrated += entry.value.migrated;
      totalSkipped += entry.value.skipped;
      totalErrors += entry.value.errors.length;
    }

    buffer.writeln('Total migrado: $totalMigrated documentos');
    buffer.writeln('Total pulado: $totalSkipped documentos');
    buffer.writeln('Total erros: $totalErrors');

    return buffer.toString();
  }
}

class CollectionMigrationResult {
  final String collection;
  int migrated = 0;
  int skipped = 0;
  final List<String> errors = [];

  CollectionMigrationResult(this.collection);
}
