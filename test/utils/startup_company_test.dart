import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/startup_company.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('isMissingCompanyError', () {
    test('deleted or left company counts as missing', () {
      expect(isMissingCompanyError(firestoreError('permission-denied')), isTrue);
      expect(isMissingCompanyError(firestoreError('not-found')), isTrue);
    });

    test('network problems are not a missing company', () {
      expect(isMissingCompanyError(firestoreError('unavailable')), isFalse);
      expect(isMissingCompanyError(firestoreError('deadline-exceeded')), isFalse);
      expect(isMissingCompanyError(Exception('offline')), isFalse);
    });
  });

  group('firstAccessibleCompany', () {
    test('returns null when every company was deleted', () async {
      final result = await firstAccessibleCompany<String>(
        ['deleted-1', 'deleted-2'],
        (id) async => throw firestoreError('permission-denied'),
      );
      expect(result, isNull);
    });

    test('skips a deleted cached company and opens the next one', () async {
      final tried = <String>[];
      final result = await firstAccessibleCompany<String>(
        ['deleted', 'deleted', 'alive'],
        (id) async {
          tried.add(id);
          if (id == 'deleted') throw firestoreError('permission-denied');
          return 'company $id';
        },
      );
      expect(result, 'company alive');
      expect(tried, ['deleted', 'alive']);
    });

    test('skips a company document that no longer exists', () async {
      final result = await firstAccessibleCompany<String>(
        ['gone', 'alive'],
        (id) async => id == 'gone' ? null : 'company $id',
      );
      expect(result, 'company alive');
    });

    test('keeps a real network error so the retry screen shows', () async {
      expect(
        firstAccessibleCompany<String>(
          ['a'],
          (id) async => throw firestoreError('unavailable'),
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('returns null for an empty list', () async {
      expect(
        await firstAccessibleCompany<String>([], (id) async => 'x'),
        isNull,
      );
    });
  });

  group('loadIfAccessible', () {
    test('owner fallback hitting permission-denied means no company',
        () async {
      expect(
        await loadIfAccessible<String>(
          () async => throw firestoreError('permission-denied'),
        ),
        isNull,
      );
    });

    test('rethrows other errors', () async {
      expect(
        loadIfAccessible<String>(() async => throw firestoreError('unavailable')),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
