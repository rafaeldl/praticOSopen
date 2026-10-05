import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/asaas_api_service.dart';

/// Maps a server error code to localized, user-facing text.
///
/// Never exposes the raw server message; unknown codes fall back to a
/// generic text.
String asaasErrorText(AppLocalizations l10n, AsaasApiException e) {
  switch (e.code) {
    case 'FORBIDDEN':
    case 'INSUFFICIENT_PERMISSIONS':
      return l10n.asaasErrorForbidden;
    case 'ASAAS_INVALID_API_KEY':
      return l10n.asaasErrorInvalidKey;
    case 'ASAAS_NOT_CONNECTED':
    case 'ASAAS_NOT_ENABLED':
      return l10n.asaasErrorNotConnected;
    case 'INVALID_VALUE':
      return l10n.asaasErrorExceedsBalance;
    case 'TAX_ID_REQUIRED':
      return l10n.asaasErrorTaxIdRequired;
    case 'INVALID_TAX_ID':
      return l10n.invalidTaxId;
    case 'CUSTOMER_REQUIRED':
      return l10n.asaasErrorCustomerRequired;
    case 'INSTALLMENTS_IN_PROGRESS':
      return l10n.asaasErrorInstallmentsInProgress;
    case 'ORDER_CANCELED':
      return l10n.asaasErrorOrderCanceled;
    case 'INVALID_DUE_DATE':
      return l10n.asaasErrorInvalidDueDate;
    case 'INVALID_INSTALLMENT_COUNT':
      return l10n.asaasErrorInvalidInstallmentCount;
    case 'CHARGE_NOT_OPEN':
      return l10n.asaasErrorChargeNotOpen;
    case 'ASAAS_VALIDATION_ERROR':
      return l10n.asaasErrorValidation;
    case 'ASAAS_UNAVAILABLE':
      return l10n.asaasErrorUnavailable;
    case 'NETWORK_ERROR':
      return l10n.noInternetConnection;
    default:
      return l10n.asaasErrorGeneric;
  }
}
