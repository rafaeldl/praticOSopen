import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/api_headers.dart';

void main() {
  group('appApiHeaders', () {
    tearDown(() => Global.companyAggr = null);

    test('inclui Authorization e X-Company-Id da empresa atual', () async {
      Global.companyAggr = CompanyAggr()..id = 'comp-42';

      final headers = await appApiHeaders(tokenProvider: () async => 'tok');

      expect(headers['Authorization'], 'Bearer tok');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['X-Company-Id'], 'comp-42');
    });

    test('companyId explícito tem prioridade', () async {
      Global.companyAggr = CompanyAggr()..id = 'comp-42';

      final headers = await appApiHeaders(
        companyId: 'other',
        tokenProvider: () async => 'tok',
      );

      expect(headers['X-Company-Id'], 'other');
    });

    test('sem empresa selecionada não envia X-Company-Id', () async {
      final headers = await appApiHeaders(tokenProvider: () async => 'tok');

      expect(headers.containsKey('X-Company-Id'), isFalse);
    });

    test('sem token lança AppApiUnauthenticatedException', () async {
      expect(
        () => appApiHeaders(tokenProvider: () async => null),
        throwsA(isA<AppApiUnauthenticatedException>()),
      );
    });
  });
}
