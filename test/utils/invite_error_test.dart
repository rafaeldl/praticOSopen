import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/services/invite_api_service.dart';
import 'package:praticos/utils/invite_error.dart';

void main() {
  final l10n = AppLocalizationsPt();

  test('maps API messages to localized sentences', () {
    expect(friendlyInviteError(InviteApiException('Invite expired'), l10n),
        l10n.inviteExpired);
    expect(
        friendlyInviteError(InviteApiException('Invite already used'), l10n),
        l10n.inviteAlreadyUsed);
    expect(friendlyInviteError(InviteApiException('Invite not found'), l10n),
        l10n.inviteNotFound);
    expect(friendlyInviteError(InviteApiException('Invite was cancelled'), l10n),
        l10n.inviteCancelled);
  });

  test('network failures map to the connection message', () {
    expect(friendlyInviteError(Exception('SocketException: x'), l10n),
        l10n.networkError);
  });

  test('unknown errors never leak the raw text', () {
    final msg = friendlyInviteError(
        Exception('[firebase_auth/internal-error] boom'), l10n);
    expect(msg, l10n.inviteGenericError);
    expect(msg, isNot(contains('firebase')));
  });
}
