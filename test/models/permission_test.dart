import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';

void main() {
  group('PermissionType.chargeOrder', () {
    test('admin e gerente podem cobrar a OS', () {
      expect(
        RolePermissions.hasPermission(RolesType.admin, PermissionType.chargeOrder),
        isTrue,
      );
      expect(
        RolePermissions.hasPermission(RolesType.manager, PermissionType.chargeOrder),
        isTrue,
      );
    });

    test('supervisor, consultor e técnico não podem', () {
      for (final role in [
        RolesType.supervisor,
        RolesType.consultant,
        RolesType.technician,
      ]) {
        expect(
          RolePermissions.hasPermission(role, PermissionType.chargeOrder),
          isFalse,
          reason: role.name,
        );
      }
    });
  });
}
