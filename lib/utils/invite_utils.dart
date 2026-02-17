import 'package:praticos/models/invite.dart';

/// Finds an existing pending invite matching the given email or phone.
/// Pure function extracted from CollaboratorStore for testability.
Invite? findExistingPendingInvite(
  List<Invite> pendingInvites, {
  String? email,
  String? phone,
}) {
  final normalizedEmail = email?.toLowerCase().trim();
  final normalizedPhone = phone?.replaceAll(RegExp(r'\D'), '').trim();

  for (final invite in pendingInvites) {
    if (normalizedEmail != null &&
        normalizedEmail.isNotEmpty &&
        invite.email?.toLowerCase() == normalizedEmail) {
      return invite;
    }
    if (normalizedPhone != null &&
        normalizedPhone.isNotEmpty &&
        invite.phone?.replaceAll(RegExp(r'\D'), '') == normalizedPhone) {
      return invite;
    }
  }
  return null;
}
