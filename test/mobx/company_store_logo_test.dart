import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/photo_service.dart';

class _FirebaseCoreMockWithBucket extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
        CoreInitializeResponse(
          name: defaultFirebaseAppName,
          options: CoreFirebaseOptions(
            apiKey: '123',
            projectId: '123',
            appId: '123',
            messagingSenderId: '123',
            storageBucket: 'test.appspot.com',
          ),
          pluginConstants: {},
        ),
      ];
}

class _Photos implements PhotoService {
  @override
  Future<String?> uploadImage({
    required File file,
    required String storagePath,
  }) async => 'https://x/$storagePath';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseCoreMockWithBucket());
    await Firebase.initializeApp();
  });

  test('a new logo writes only the logo, never the stale company', () async {
    final writes = <String, Map<String, dynamic>>{};
    final store = CompanyStore(
      photoService: _Photos(),
      writeFields: (id, fields) async => writes[id] = fields,
    );
    // The copy the screen loaded: Valores e cobrança was on then.
    final company = Company()
      ..id = 'c1'
      ..name = 'Oficina'
      ..useFinancial = true;

    final url = await store.uploadCompanyLogo(File('a.jpg'), company);

    expect(url, 'https://x/tenants/c1/logo/logo.jpg');
    expect(company.logo, url);
    expect(writes.keys, ['c1']);
    expect(writes['c1']!['logo'], url);
    expect(writes['c1']!.containsKey('updatedAt'), isTrue);
    expect(
      writes['c1']!.keys.where((k) => k != 'updatedBy'),
      unorderedEquals(['logo', 'updatedAt']),
    );
  });
}
