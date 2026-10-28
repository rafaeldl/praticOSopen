import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/asaas_api_service.dart';

/// Maps a server error code to localized, user-facing text.
///
/// Never exposes the raw server message; unknown codes fall back to a
/// generic text.
///
/// [nota] is for the nota fiscal screens: an Asaas rejection there is about
/// the fiscal data, not a charge.
String asaasErrorText(
  AppLocalizations l10n,
  AsaasApiException e, {
  bool nota = false,
}) {
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
    case 'VALUE_EXCEEDS_BALANCE':
      return l10n.asaasErrorExceedsBalance;
    case 'TAX_ID_REQUIRED':
      return l10n.asaasErrorTaxIdRequired;
    case 'INVALID_TAX_ID':
      return l10n.invalidTaxId;
    case 'CUSTOMER_DATA_REQUIRED':
      return l10n.nfseErrorCustomerData;
    case 'CUSTOMER_REQUIRED':
      return l10n.asaasErrorCustomerRequired;
    case 'INSTALLMENTS_IN_PROGRESS':
      return l10n.asaasErrorInstallmentsInProgress;
    case 'CUSTOMER_CHARGE_OPEN':
      return l10n.asaasErrorCustomerChargeOpen;
    case 'CHARGE_SUPERSEDED':
      return l10n.asaasErrorChargeSuperseded;
    case 'PREVIOUS_LINK_CANCELED':
      return l10n.asaasErrorPreviousLinkCanceled;
    case 'ORDER_NOT_PAYABLE':
      return l10n.asaasErrorOrderNotPayable;
    case 'ORDER_CANCELED':
      return l10n.asaasErrorOrderCanceled;
    case 'INVALID_DUE_DATE':
      return l10n.asaasErrorInvalidDueDate;
    case 'INVALID_INSTALLMENT_COUNT':
      return l10n.asaasErrorInvalidInstallmentCount;
    case 'CHARGE_NOT_OPEN':
      return l10n.asaasErrorChargeNotOpen;
    case 'ASAAS_VALIDATION_ERROR':
      return nota ? l10n.nfseErrorAsaasValidation : l10n.asaasErrorValidation;
    case 'NFSE_NOT_ENABLED':
      return l10n.nfseErrorNotEnabled;
    case 'NFSE_NOT_READY':
      return l10n.nfseErrorNotReady;
    case 'NFSE_RECONNECT_NEEDED':
      return l10n.nfseErrorReconnectNeeded;
    case 'NFSE_SETUP_NEEDED':
      return l10n.nfseErrorSetupNeeded;
    case 'INVOICE_OTHER_ACCOUNT':
      return l10n.nfseErrorOtherAccount;
    case 'NFSE_ORDER_NOT_ALLOWED':
      return l10n.nfseErrorOrderNotAllowed;
    case 'NO_SERVICES':
      return l10n.nfseErrorNoServices;
    case 'ORDER_HAS_INVOICE':
      return l10n.nfseErrorOrderHasInvoice;
    case 'ORDER_NOT_OF_CUSTOMER':
      return l10n.nfseErrorOrderNotOfCustomer;
    case 'INVOICE_NOT_FOUND':
      return l10n.nfseErrorNotFound;
    case 'INVOICE_NOT_CANCELABLE':
      return l10n.nfseErrorNotCancelable;
    case 'CANCEL_NOT_SUPPORTED':
      return l10n.nfseErrorCancelNotSupported;
    case 'INVALID_EFFECTIVE_DATE':
      return l10n.nfseErrorInvalidDate;
    case 'INVALID_FISCAL_INFO':
      return l10n.nfseErrorInvalidFiscalInfo;
    case 'ASAAS_UNAVAILABLE':
      return l10n.asaasErrorUnavailable;
    case 'NETWORK_ERROR':
      return l10n.noInternetConnection;
    default:
      return l10n.asaasErrorGeneric;
  }
}
