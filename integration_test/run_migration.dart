import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:praticos/services/tenant_data_migration.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Run Tenant Data Migration', (WidgetTester tester) async {
    // Initialize Firebase
    // If firebase_options.dart is missing, we rely on the native configuration (GoogleService-Info.plist / google-services.json)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    print('Starting migration...');

    final migration = TenantDataMigration();
    final report = await migration.migrateAll();

    print('Migration finished.');
    print(report.summary());

    int totalErrors = 0;
    report.results.forEach((collection, result) {
      totalErrors += result.errors.length;
    });

    if (totalErrors > 0) {
      print('Errors details:');
      report.results.forEach((collection, result) {
        if (result.errors.isNotEmpty) {
           print('Collection $collection errors:');
           result.errors.forEach((e) => print(e));
        }
      });
    }

    expect(totalErrors, 0, reason: 'Migration completed with errors.');
  });
}
