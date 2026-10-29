import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';

void main() {
  final l10n = AppLocalizationsPt();

  String text(String? code) =>
      asaasErrorText(l10n, AsaasApiException(code, 'raw backend text'));

  group('asaasErrorText', () {
    test('FORBIDDEN e INSUFFICIENT_PERMISSIONS', () {
      expect(text('FORBIDDEN'), l10n.asaasErrorForbidden);
      expect(text('INSUFFICIENT_PERMISSIONS'), l10n.asaasErrorForbidden);
    });

    test('ASAAS_INVALID_API_KEY', () {
      expect(text('ASAAS_INVALID_API_KEY'), l10n.asaasErrorInvalidKey);
    });

    test('ASAAS_NOT_CONNECTED', () {
      expect(text('ASAAS_NOT_CONNECTED'), l10n.asaasErrorNotConnected);
    });

    test('ASAAS_NOT_ENABLED', () {
      expect(text('ASAAS_NOT_ENABLED'), l10n.asaasErrorNotConnected);
    });

    test('INVALID_VALUE', () {
      expect(text('INVALID_VALUE'), l10n.asaasErrorExceedsBalance);
    });

    test('TAX_ID_REQUIRED', () {
      expect(text('TAX_ID_REQUIRED'), l10n.asaasErrorTaxIdRequired);
    });

    test('INVALID_TAX_ID', () {
      expect(text('INVALID_TAX_ID'), l10n.invalidTaxId);
    });

    test('CUSTOMER_REQUIRED', () {
      expect(text('CUSTOMER_REQUIRED'), l10n.asaasErrorCustomerRequired);
    });

    test('INSTALLMENTS_IN_PROGRESS', () {
      expect(
        text('INSTALLMENTS_IN_PROGRESS'),
        l10n.asaasErrorInstallmentsInProgress,
      );
    });

    test('códigos de cobrança de várias OS', () {
      expect(text('VALUE_EXCEEDS_BALANCE'), l10n.asaasErrorExceedsBalance);
      expect(text('CUSTOMER_CHARGE_OPEN'), l10n.asaasErrorCustomerChargeOpen);
      expect(text('ORDER_NOT_PAYABLE'), l10n.asaasErrorOrderNotPayable);
    });

    test('criação concorrente e link anterior cancelado sem o novo', () {
      expect(text('CHARGE_SUPERSEDED'), l10n.asaasErrorChargeSuperseded);
      expect(
        text('PREVIOUS_LINK_CANCELED'),
        l10n.asaasErrorPreviousLinkCanceled,
      );
      expect(l10n.asaasErrorPreviousLinkCanceled, contains('link novo'));
    });

    test('ORDER_CANCELED', () {
      expect(text('ORDER_CANCELED'), l10n.asaasErrorOrderCanceled);
    });

    test('INVALID_DUE_DATE', () {
      expect(text('INVALID_DUE_DATE'), l10n.asaasErrorInvalidDueDate);
    });

    test('INVALID_INSTALLMENT_COUNT', () {
      expect(
        text('INVALID_INSTALLMENT_COUNT'),
        l10n.asaasErrorInvalidInstallmentCount,
      );
    });

    test('nota fiscal: reconectar, conta do Asaas trocada', () {
      expect(text('NFSE_RECONNECT_NEEDED'), l10n.nfseErrorReconnectNeeded);
      expect(
        l10n.nfseErrorReconnectNeeded,
        'Reconecte o Asaas para emitir notas.',
      );
      expect(text('NFSE_SETUP_NEEDED'), l10n.nfseErrorSetupNeeded);
      expect(text('INVOICE_OTHER_ACCOUNT'), l10n.nfseErrorOtherAccount);
    });

    test('CHARGE_NOT_OPEN', () {
      expect(text('CHARGE_NOT_OPEN'), l10n.asaasErrorChargeNotOpen);
    });

    test('ASAAS_VALIDATION_ERROR', () {
      expect(text('ASAAS_VALIDATION_ERROR'), l10n.asaasErrorValidation);
    });

    test('nas telas de nota a recusa do Asaas fala da nota', () {
      expect(
        asaasErrorText(
          l10n,
          AsaasApiException('ASAAS_VALIDATION_ERROR', 'raw'),
          nota: true,
        ),
        l10n.nfseErrorAsaasValidation,
      );
    });

    test('nas telas de nota mostra o texto do Asaas quando ele veio', () {
      String nota(String code, String? detail) => asaasErrorText(
        l10n,
        AsaasApiException(code, 'raw', detail: detail),
        nota: true,
      );
      const said = 'A descrição do serviço deve ter no máximo 250 caracteres.';
      expect(
        nota('ASAAS_VALIDATION_ERROR', said),
        l10n.nfseErrorAsaasSaid(said),
      );
      expect(nota('NFSE_SETUP_REJECTED', said), l10n.nfseErrorAsaasSaid(said));
      expect(
        nota('ASAAS_VALIDATION_ERROR', null),
        l10n.nfseErrorAsaasValidation,
      );
      // Charges keep the fixed text.
      expect(
        asaasErrorText(
          l10n,
          AsaasApiException('ASAAS_VALIDATION_ERROR', 'raw', detail: said),
        ),
        l10n.asaasErrorValidation,
      );
    });

    test('códigos de nota fiscal', () {
      expect(text('ORDER_HAS_INVOICE'), l10n.nfseErrorOrderHasInvoice);
      expect(text('CUSTOMER_DATA_REQUIRED'), l10n.nfseErrorCustomerData);
      expect(text('NFSE_SETUP_REJECTED'), l10n.nfseErrorSetupRejected);
      expect(text('CANCEL_NOT_SUPPORTED'), l10n.nfseErrorCancelNotSupported);
      expect(text('NO_SERVICES'), l10n.nfseErrorNoServices);
      expect(text('NFSE_NOT_READY'), l10n.nfseErrorNotReady);
    });

    test('ASAAS_UNAVAILABLE', () {
      expect(text('ASAAS_UNAVAILABLE'), l10n.asaasErrorUnavailable);
    });

    test('NETWORK_ERROR usa a chave existente de sem internet', () {
      expect(text('NETWORK_ERROR'), l10n.noInternetConnection);
    });

    test('demais códigos e null viram genérico', () {
      for (final code in [
        'VALIDATION_ERROR',
        'ORDER_NOT_FOUND',
        'INTERNAL_ERROR',
        'RATE_LIMIT_EXCEEDED',
        'UNAUTHENTICATED',
        'SOMETHING_NEW',
        null,
      ]) {
        expect(text(code), l10n.asaasErrorGeneric, reason: '$code');
      }
    });

    test('nunca devolve a mensagem crua', () {
      for (final code in [
        'FORBIDDEN',
        'INTERNAL_ERROR',
        'NETWORK_ERROR',
        null,
      ]) {
        expect(text(code), isNot(contains('raw backend text')));
      }
    });
  });
}
