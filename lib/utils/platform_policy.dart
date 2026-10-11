import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// Store policy rules that change behavior per platform.
///
/// ## Company creation (App Store guideline 3.1.1)
///
/// Apple treats creating a company (tenant) inside the iOS app as "account
/// registration for businesses and organizations". On iOS the app is used by
/// team members invited by their company and by owners of existing
/// companies, so it never creates a new company. Android and web keep the
/// in-app onboarding.
///
/// On iOS a user without a company sees `NoCompanyScreen` (join with an
/// invite code, sign out or delete the account). That screen must not point
/// to any other place where a company could be created.
class PlatformPolicy {
  PlatformPolicy._();

  /// Overrides [canCreateCompanyInApp] in tests. Always reset to null.
  @visibleForTesting
  static bool? debugCanCreateCompanyOverride;

  /// False on iOS: the app must not create a new company there.
  static bool get canCreateCompanyInApp {
    final override = debugCanCreateCompanyOverride;
    if (override != null) return override;
    if (kIsWeb) return true;
    return !Platform.isIOS;
  }

  /// Guard for code that creates a company (`UserStore.createCompanyForUser`).
  /// Throws [CompanyCreationNotAllowedException] on iOS.
  static void ensureCanCreateCompany() {
    if (!canCreateCompanyInApp) {
      throw const CompanyCreationNotAllowedException();
    }
  }
}

/// Thrown when code tries to create a company where [PlatformPolicy]
/// forbids it.
class CompanyCreationNotAllowedException implements Exception {
  const CompanyCreationNotAllowedException();

  @override
  String toString() =>
      'CompanyCreationNotAllowedException: '
      'company creation is not available on this platform';
}

/// Where a signed-in user without a company goes.
enum NoCompanyDestination { pendingInvites, welcome, noCompany }

/// Routing for a user with no company: pending invites first, then the
/// onboarding (where creation is allowed) or the "no company" screen.
NoCompanyDestination noCompanyDestination({
  required bool hasPendingInvites,
  required bool canCreateCompany,
}) {
  if (hasPendingInvites) return NoCompanyDestination.pendingInvites;
  return canCreateCompany
      ? NoCompanyDestination.welcome
      : NoCompanyDestination.noCompany;
}
