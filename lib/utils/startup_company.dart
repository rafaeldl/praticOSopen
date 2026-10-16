import 'package:firebase_core/firebase_core.dart';

/// True when reading a company failed because the user can no longer see it:
/// the company was deleted or the user's membership was removed. Firestore
/// rules answer `permission-denied` for a document that no longer exists, so
/// both codes mean "no company", never a network problem.
bool isMissingCompanyError(Object error) =>
    error is FirebaseException &&
    (error.code == 'permission-denied' || error.code == 'not-found');

/// Loads the first company in [ids] that still exists and that the user can
/// read, skipping the ones that were deleted or left. Returns null when none
/// is left. Any other error (offline, timeout) is rethrown so the caller can
/// keep showing the retry screen.
Future<T?> firstAccessibleCompany<T>(
  Iterable<String> ids,
  Future<T?> Function(String id) load,
) async {
  for (final id in ids.toSet()) {
    final company = await loadIfAccessible(() => load(id));
    if (company != null) return company;
  }
  return null;
}

/// Runs [load] and returns null instead of throwing when the company is gone.
Future<T?> loadIfAccessible<T>(Future<T?> Function() load) async {
  try {
    return await load();
  } catch (e) {
    if (isMissingCompanyError(e)) return null;
    rethrow;
  }
}
