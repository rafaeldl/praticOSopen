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

  group('Company.useFinancial', () {
    test('on: every role keeps its own permissions', () {
      for (final role in RolesType.values) {
        for (final permission in PermissionType.values) {
          expect(
            RolePermissions.hasPermissionInCompany(role, permission,
                useFinancial: true),
            RolePermissions.hasPermission(role, permission),
            reason: '${role.name}.${permission.name}',
          );
        }
      }
    });

    test('off: no role (owner included) gets prices, billing or charges', () {
      for (final role in RolesType.values) {
        for (final permission in RolePermissions.financialPermissions) {
          expect(
            RolePermissions.hasPermissionInCompany(role, permission,
                useFinancial: false),
            isFalse,
            reason: '${role.name}.${permission.name}',
          );
        }
      }
    });

    test('off: the other permissions do not change', () {
      for (final role in RolesType.values) {
        for (final permission in PermissionType.values.where(
            (p) => !RolePermissions.financialPermissions.contains(p))) {
          expect(
            RolePermissions.hasPermissionInCompany(role, permission,
                useFinancial: false),
            RolePermissions.hasPermission(role, permission),
            reason: '${role.name}.${permission.name}',
          );
        }
      }
    });

    test('financial permissions cover prices, reports and charges', () {
      expect(RolePermissions.financialPermissions, {
        PermissionType.viewPrices,
        PermissionType.viewBilling,
        PermissionType.viewFinancialReports,
        PermissionType.editPrices,
        PermissionType.chargeOrder,
      });
    });
  });
}
