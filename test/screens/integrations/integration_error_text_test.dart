import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/integrations/integration_list_screen.dart';
import 'package:praticos/services/integration_api_service.dart';

void main() {
  final l10n = AppLocalizationsPt();

  group('integrationErrorText', () {
    test('FORBIDDEN maps to the forbidden message', () {
      final e = IntegrationApiException('raw backend text', code: 'FORBIDDEN');

      final text = integrationErrorText(l10n, e);

      expect(text, l10n.integrationsErrorForbidden);
    });

    test('NOT_FOUND maps to the not-found message', () {
      final e = IntegrationApiException('raw backend text', code: 'NOT_FOUND');

      final text = integrationErrorText(l10n, e);

      expect(text, l10n.integrationsErrorNotFound);
    });

    test('null code maps to the generic message', () {
      final e = IntegrationApiException('raw backend text', code: null);

      final text = integrationErrorText(l10n, e);

      expect(text, l10n.integrationsErrorGeneric);
    });

    test('an unmapped code (INTERNAL_ERROR) maps to the generic message', () {
      final e =
          IntegrationApiException('raw backend text', code: 'INTERNAL_ERROR');

      final text = integrationErrorText(l10n, e);

      expect(text, l10n.integrationsErrorGeneric);
    });

    test('never returns the exception raw message', () {
      final e = IntegrationApiException(
        'raw backend text that must never reach the UI',
        code: 'FORBIDDEN',
      );

      final text = integrationErrorText(l10n, e);

      expect(text, isNot(contains('raw backend text')));
    });
  });
}
