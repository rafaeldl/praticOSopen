import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/authorization_service.dart';

void main() {
  Order createdBy(String? uid) =>
      Order()..createdBy = (uid == null ? null : (UserAggr()..id = uid));

  bool onOrder(
    RolesType? role,
    Order? order, {
    String? userId = 'me',
    bool useFinancial = true,
  }) => AuthorizationService.canReceiveOnOrderFor(
    role: role,
    userId: userId,
    order: order,
    useFinancial: useFinancial,
  );

  group('canReceiveOnOrderFor', () {
    test('admin and manager receive on any order', () {
      for (final role in [RolesType.admin, RolesType.manager]) {
        expect(onOrder(role, createdBy('other')), isTrue, reason: '$role');
        expect(onOrder(role, createdBy(null)), isTrue, reason: '$role');
      }
    });

    test('consultant receives only on the orders they created', () {
      expect(onOrder(RolesType.consultant, createdBy('me')), isTrue);
      expect(onOrder(RolesType.consultant, createdBy('other')), isFalse);
      expect(onOrder(RolesType.consultant, createdBy(null)), isFalse);
      expect(onOrder(RolesType.consultant, null), isFalse);
      expect(
        onOrder(RolesType.consultant, createdBy('me'), userId: null),
        isFalse,
      );
    });

    test('supervisor and technician never receive, even on their own', () {
      for (final role in [RolesType.supervisor, RolesType.technician]) {
        expect(onOrder(role, createdBy('me')), isFalse, reason: '$role');
      }
    });

    test('nobody receives without a role or with values and billing off', () {
      expect(onOrder(null, createdBy('me')), isFalse);
      for (final role in RolesType.values) {
        expect(
          onOrder(role, createdBy('me'), useFinancial: false),
          isFalse,
          reason: '$role',
        );
      }
    });
  });

  group('canReceivePaymentsFor', () {
    test('financial roles and consultant; not supervisor or technician', () {
      bool can(RolesType? r, {bool useFinancial = true}) =>
          AuthorizationService.canReceivePaymentsFor(
            role: r,
            useFinancial: useFinancial,
          );
      expect(can(RolesType.admin), isTrue);
      expect(can(RolesType.manager), isTrue);
      expect(can(RolesType.consultant), isTrue);
      expect(can(RolesType.supervisor), isFalse);
      expect(can(RolesType.technician), isFalse);
      expect(can(null), isFalse);
      expect(can(RolesType.consultant, useFinancial: false), isFalse);
    });
  });
}
