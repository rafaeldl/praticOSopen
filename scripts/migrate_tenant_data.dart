import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// Entry point for running the migration
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final migration = TenantDataMigration();
  await migration.migrateAll();
}

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
        final companyId = data['company']?['id'] as String?;

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
          final existingUpdatedAt = existingDoc.data()?['updatedAt'];
          final currentUpdatedAt = data['updatedAt'];

          // Se já existe e é mais novo ou igual, pula
          if (existingUpdatedAt != null && currentUpdatedAt != null) {
             // Handle Timestamp vs String or other types comparison
             if (existingUpdatedAt is Timestamp && currentUpdatedAt is Timestamp) {
                if (existingUpdatedAt.compareTo(currentUpdatedAt) >= 0) {
                  result.skipped++;
                  continue;
                }
             } else if (existingUpdatedAt is String && currentUpdatedAt is String) {
                // ISO8601 strings are comparable
                if (existingUpdatedAt.compareTo(currentUpdatedAt) >= 0) {
                  result.skipped++;
                  continue;
                }
             }
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

  /// Valida a migração comparando estruturas
  Future<ValidationReport> validateMigration(String collectionName) async {
    print('► Validando collection: $collectionName');

    final report = ValidationReport(collectionName);
    final oldDocs = await _db.collection(collectionName).get();

    for (final doc in oldDocs.docs) {
      final data = doc.data();
      final companyId = data['company']?['id'] as String?;

      if (companyId == null) {
        report.skipped++;
        continue;
      }

      final newDoc = await _db
          .collection('companies')
          .doc(companyId)
          .collection(collectionName)
          .doc(doc.id)
          .get();

      if (!newDoc.exists) {
        report.missing.add(doc.id);
      } else {
        final newData = newDoc.data()!;
        if (data['updatedAt'] != newData['updatedAt']) {
          report.divergent.add(doc.id);
        } else {
          report.valid++;
        }
      }
    }

    print('  Resultado: ${report.valid} válidos, ' 
          '${report.missing.length} faltando, ' 
          '${report.divergent.length} divergentes\n');

    return report;
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

class ValidationReport {
  final String collection;
  int valid = 0;
  int skipped = 0;
  final List<String> missing = [];
  final List<String> divergent = [];

  ValidationReport(this.collection);
}
