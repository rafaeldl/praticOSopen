// Runs docs/web-app/contract-cases/contract-generation.json against the real
// app code: OrderContract (isDue, isExpired, computeNextDueDate) and
// OrderStore.generateOrderFromContract writing to an in-memory Firestore
// platform. The server side is
// firebase/functions/src/__tests__/contract-generation.cases.test.ts.
//
// The app reads DateTime.now() directly, so a case's `now` can't be set: the
// due checks shift the contract dates by (real now - case now), and the next
// due date is checked as computeNextDueDate from the lastGeneratedDate the app
// really wrote, plus computeNextDueDate from the case's `now`.
//
// The two platform-interface packages come with cloud_firestore; they are
// only needed here to stand in for Firestore.
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart' hide Order;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';

const _file = 'docs/web-app/contract-cases/contract-generation.json';
const _lang = 'dart';

class _FirebaseMock extends MockFirebaseApp {
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

/// Records every `set` by document path.
class _FakeFirestore extends FirebaseFirestorePlatform with MockPlatformInterfaceMixin {
  _FakeFirestore() : super(databaseChoice: '(default)');

  final writes = <String, List<(Map<String, dynamic>, bool)>>{};
  var _autoId = 0;

  String nextId() => 'auto${++_autoId}';

  @override
  FirebaseFirestorePlatform delegateFor({required FirebaseApp app, required String databaseId}) => this;

  @override
  CollectionReferencePlatform collection(String collectionPath) => _FakeCollection(this, collectionPath);

  @override
  DocumentReferencePlatform doc(String documentPath) => _FakeDoc(this, documentPath);
}

class _FakeCollection extends CollectionReferencePlatform {
  _FakeCollection(this.fake, String path) : super(fake, path);
  final _FakeFirestore fake;

  @override
  DocumentReferencePlatform doc([String? path]) => _FakeDoc(fake, '${this.path}/${path ?? fake.nextId()}');
}

class _FakeDoc extends DocumentReferencePlatform {
  _FakeDoc(this.fake, String path) : super(fake, path);
  final _FakeFirestore fake;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    fake.writes.putIfAbsent(path, () => []).add((data, options?.merge == true));
  }
}

Map<String, dynamic> _cast(Object? value) => (value as Map).cast<String, dynamic>();

/// JSON as Firestore stores it (no Dart objects, ints and doubles compared as numbers).
Object? _plain(Object? value) => jsonDecode(jsonEncode(value));

Map<String, dynamic> _pick(Map<String, dynamic> from, Map<String, dynamic> like) =>
    {for (final key in like.keys) key: from[key]};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeFirestore fake;
  final doc = _cast(jsonDecode(File(_file).readAsStringSync()));
  final templateId = doc['templateId'] as String;

  setUpAll(() async {
    TestFirebaseCoreHostApi.setUp(_FirebaseMock());
    await Firebase.initializeApp();
    fake = _FakeFirestore();
    FirebaseFirestorePlatform.instance = fake;
    Global.companyAggr = CompanyAggr.fromJson(_cast(doc['company']));
  });

  setUp(() => fake.writes.clear());

  test('runs in dart', () => expect(doc['runsIn'], contains(_lang)));

  for (final c in (doc['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['id'], () async {
      final want = {..._cast(c['correct'] ?? c['expect']), ...?(c['divergesIn']?[_lang] as Map?)?.cast<String, dynamic>()};
      final given = _cast(c['given']);
      final contractJson = {..._cast(doc['contract']), ...?(given['contract'] as Map?)?.cast<String, dynamic>()};
      final templateJson = {
        ..._cast(doc['template']),
        ...?(given['template'] as Map?)?.cast<String, dynamic>(),
        'contract': contractJson,
        'id': templateId,
      };
      final caseNow = DateTime.parse(given['now'] as String);
      final shift = DateTime.now().difference(caseNow);
      DateTime? shifted(String key) =>
          contractJson[key] == null ? null : DateTime.parse(contractJson[key] as String).add(shift);

      final template = Order.fromJson(templateJson);
      template.contract!
        ..nextDueDate = shifted('nextDueDate')
        ..endDate = shifted('endDate');

      // checkAndGenerateDueOrders' filter, on the real OrderContract.
      expect(template.contract!.isDue, want['due']);
      final generates = template.contract!.isDue && template.contract!.autoGenerate == true;
      expect(generates, want['generates']);
      if (!generates) return;

      final before = DateTime.now();
      await OrderStore().generateOrderFromContract(template);

      final orderPaths = fake.writes.keys.where((p) => !p.endsWith('/$templateId')).toList();
      expect(orderPaths, hasLength(1));
      final (order, merged) = fake.writes[orderPaths.single]!.single;
      expect(merged, isFalse, reason: 'a new order is a full write');
      final orderJson = _cast(_plain(order));
      // Both are DateTime.now() of the generation (two calls, microseconds apart).
      final createdAt = DateTime.parse(orderJson['createdAt'] as String);
      expect(createdAt.isBefore(before), isFalse);
      expect(DateTime.parse(orderJson['updatedAt'] as String).difference(createdAt).inSeconds, 0);
      if (want['order'] != null) {
        expect(_pick(orderJson, _cast(want['order'])), _plain(want['order']));
      }

      final (saved, savedMerge) = fake.writes['companies/${doc['company']['id']}/orders/$templateId']!.single;
      expect(savedMerge, isTrue);
      final after = OrderContract.fromJson(_cast(_plain(saved['contract'])));
      final wantContract = _cast(want['contract']);
      expect(after.generatedCount, wantContract['generatedCount']);
      expect(after.active, wantContract['active']);
      // lastGeneratedDate is the real now, and the next due date counts from it.
      expect(after.lastGeneratedDate!.isBefore(before), isFalse);
      expect(after.nextDueDate, after.computeNextDueDate());
      // From the case's now, the same rule gives the expected text.
      final fromCaseNow = OrderContract.fromJson(contractJson)..lastGeneratedDate = caseNow;
      expect(fromCaseNow.computeNextDueDate()?.toIso8601String(), wantContract['nextDueDate']);
    });
  }
}
