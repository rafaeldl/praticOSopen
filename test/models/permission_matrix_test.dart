import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';

/// The role → permission matrix is shared with the Firestore rules tests
/// (firebase/functions/src/__tests__/rbac/). A change in RolePermissions must
/// update that file too, so the rules are checked against the same matrix.
/// See docs/E2E_ROLES_TESTING.md.
void main() {
  final matrix = jsonDecode(
    File('firebase/functions/src/__tests__/rbac/app-permissions.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final roles = matrix['roles'] as Map<String, dynamic>;

  Set<String> names(Iterable<PermissionType> permissions) =>
      permissions.map((p) => p.name).toSet();

  test('every role is in the shared matrix', () {
    expect(roles.keys.toSet(), RolesType.values.map((r) => r.name).toSet());
  });

  for (final role in RolesType.values) {
    test('${role.name}: RolePermissions matches the shared matrix', () {
      expect(
        names(RolePermissions.getPermissions(role)),
        (roles[role.name] as List).cast<String>().toSet(),
      );
    });
  }

  test('financial permissions match the shared matrix', () {
    expect(
      names(RolePermissions.financialPermissions),
      (matrix['financialPermissions'] as List).cast<String>().toSet(),
    );
  });

  test("'owner' is read as admin", () {
    expect(rolesTypeFromJson('owner'), RolesType.admin);
  });
}
