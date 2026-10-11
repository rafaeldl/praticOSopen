import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/invite_api_service.dart';

/// Maps any invite failure to a fixed, localized sentence.
///
/// Never returns the raw exception text: API/Firebase messages are English
/// and technical. Unknown errors become [AppLocalizations.inviteGenericError].
String friendlyInviteError(Object error, AppLocalizations l10n) {
  final text = (error is InviteApiException ? error.message : error.toString())
      .toLowerCase();

  if (text.contains('expired')) return l10n.inviteExpired;
  if (text.contains('already used') ||
      text.contains('no longer valid') ||
      text.contains('already accepted')) {
    return l10n.inviteAlreadyUsed;
  }
  if (text.contains('cancel')) return l10n.inviteCancelled;
  if (text.contains('not found')) return l10n.inviteNotFound;
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('unavailable') ||
      text.contains('timeout') ||
      text.contains('connection')) {
    return l10n.networkError;
  }
  return l10n.inviteGenericError;
}
