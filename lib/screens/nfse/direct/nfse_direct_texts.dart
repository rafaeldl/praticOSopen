import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Annual limit of the MEI (R$ 81.000). The server keeps its own copy in
/// `config/nfse.meiAnnualLimit` for the sheet's warning; this one only feeds
/// the sentence on the emitter screen.
const meiAnnualLimit = 81000.0;

/// Days before the end of validity when the certificate turns amber (the
/// first notice of the server, certificate-expiry-notice.service.ts).
const certificateWarningDays = 30;

/// The sentence for an error of the NFS-e direct endpoints.
String nfseDirectErrorText(AppLocalizations l10n, Object error) {
  final code = error is NfseDirectApiException ? error.code : null;
  switch (code) {
    case 'CERT_INVALID_FILE':
      return l10n.nfseDirectErrorInvalidFile;
    case 'CERT_WRONG_PASSWORD':
      return l10n.nfseDirectErrorWrongPassword;
    case 'CERT_EXPIRED':
      return l10n.nfseDirectErrorExpired;
    case 'CERT_NOT_YET_VALID':
      return l10n.nfseDirectErrorNotYetValid;
    case 'CERT_NOT_ICP_BRASIL':
      return l10n.nfseDirectErrorNotIcpBrasil;
    case 'CERT_NO_TAX_ID':
      return l10n.nfseDirectErrorNoTaxId;
    case 'CERT_TAX_ID_MISMATCH':
      return l10n.nfseDirectErrorOtherTaxId;
    case 'EMITTER_ALREADY_EXISTS':
      return l10n.nfseDirectErrorAlreadyExists;
    case 'EMITTER_NOT_FOUND':
    case 'CERT_NOT_FOUND':
      return l10n.nfseDirectErrorNotFound;
    case 'NFSE_DIRECT_NOT_ENABLED':
      return l10n.nfseDirectErrorNotEnabled;
    case 'FORBIDDEN':
    case 'UNAUTHENTICATED':
      return l10n.nfseDirectErrorForbidden;
    case 'VALIDATION_ERROR':
      return l10n.nfseDirectErrorValidation;
    case 'ORDER_HAS_INVOICE':
      return l10n.nfseLinkErrorOrderHasNota;
    case 'INVOICE_HAS_ORDER':
      return l10n.nfseLinkErrorAlreadyLinked;
    case 'IMPORT_UNDO_EXPIRED':
      return l10n.nfseImportErrorUndoExpired;
    case 'KEY_VAULT_UNAVAILABLE':
    case 'SEFIN_UNAVAILABLE':
    case 'NETWORK_ERROR':
    case 'RATE_LIMIT_EXCEEDED':
      return l10n.nfseDirectErrorUnavailable;
    default:
      return l10n.nfseDirectErrorGeneric;
  }
}

String fiscalRegimeLabel(AppLocalizations l10n, FiscalRegime? regime) =>
    regime == FiscalRegime.mei
    ? l10n.nfseDirectRegimeMei
    : l10n.nfseDirectRegimeSimples;

String nfseDirectAutoIssueLabel(
  AppLocalizations l10n,
  NfseDirectAutoIssue value,
) => switch (value) {
  NfseDirectAutoIssue.never => l10n.nfseDirectAutoIssueNever,
  NfseDirectAutoIssue.selectedCustomers => l10n.nfseDirectAutoIssueSelected,
  NfseDirectAutoIssue.allOrders => l10n.nfseDirectAutoIssueAll,
};

String nfseDirectAutoIssueHint(
  AppLocalizations l10n,
  NfseDirectAutoIssue value,
) => switch (value) {
  NfseDirectAutoIssue.never => l10n.nfseDirectAutoIssueNeverHint,
  NfseDirectAutoIssue.selectedCustomers => l10n.nfseDirectAutoIssueSelectedHint,
  NfseDirectAutoIssue.allOrders => l10n.nfseDirectAutoIssueAllHint,
};

/// Where the certificate of an emitter stands.
enum CertificateState { valid, expiring, expired, pending, missing }

CertificateState certificateState(FiscalEmitter emitter, {DateTime? now}) {
  final cert = emitter.certificate;
  final end = cert?.notAfter;
  if (cert == null || cert.status == FiscalCertificateStatus.deleted) {
    return CertificateState.missing;
  }
  if (cert.status == FiscalCertificateStatus.pending) {
    return CertificateState.pending;
  }
  final today = now ?? DateTime.now();
  if (cert.status == FiscalCertificateStatus.expired ||
      end == null ||
      !today.isBefore(end)) {
    return CertificateState.expired;
  }
  if (end.difference(today).inDays < certificateWarningDays) {
    return CertificateState.expiring;
  }
  return CertificateState.valid;
}

/// Days until the end of validity, rounded up.
int certificateDaysLeft(FiscalEmitter emitter, {DateTime? now}) {
  final end = emitter.certificate?.notAfter;
  if (end == null) return 0;
  final hours = end.difference(now ?? DateTime.now()).inHours;
  return (hours / 24).ceil();
}

String certificateStateText(
  AppLocalizations l10n,
  FiscalEmitter emitter, {
  DateTime? now,
}) {
  final end = emitter.certificate?.notAfter;
  switch (certificateState(emitter, now: now)) {
    case CertificateState.valid:
      return l10n.nfseDirectCertValidUntil(
        FormatService().formatDate(end!.toLocal()),
      );
    case CertificateState.expiring:
      return l10n.nfseDirectCertExpiresIn(
        certificateDaysLeft(emitter, now: now),
      );
    case CertificateState.expired:
      return l10n.nfseDirectCertExpired;
    case CertificateState.pending:
      return l10n.nfseDirectCertPending;
    case CertificateState.missing:
      return l10n.nfseDirectCertMissing;
  }
}

/// Dot + text of the certificate: green valid, amber expiring, red and bold
/// expired, gray otherwise.
class CertificateStatusLine extends StatelessWidget {
  const CertificateStatusLine({super.key, required this.emitter, this.now});

  final FiscalEmitter emitter;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final state = certificateState(emitter, now: now);
    final expired = state == CertificateState.expired;
    final dot = switch (state) {
      CertificateState.valid => AppColors.success,
      CertificateState.expiring => AppColors.warning,
      CertificateState.expired => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    return Row(
      children: [
        StatusDot(color: dot.resolveFrom(context)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            certificateStateText(context.l10n, emitter, now: now),
            style: AppTypography.callout.copyWith(
              color: expired
                  ? AppColors.danger.resolveFrom(context)
                  : AppColors.textSecondary.resolveFrom(context),
              fontWeight: expired ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}
