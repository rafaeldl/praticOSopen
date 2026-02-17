/// Error codes for collaborator operations.
enum CollaboratorErrorCode {
  cannotRemoveOnlyAdmin,
  cannotChangeOnlyAdminRole,
  cannotRemoveSelf,
  invalidInvite,
  userNotFound,
}

/// Typed exception for collaborator operations.
///
/// Use [code] to map to localized messages in the UI.
class CollaboratorException implements Exception {
  final CollaboratorErrorCode code;

  CollaboratorException(this.code);

  @override
  String toString() => 'CollaboratorException: ${code.name}';
}
