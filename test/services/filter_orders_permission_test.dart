import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/services/authorization_service.dart';

void main() {
  Order createdBy(String? uid) =>
      Order()..createdBy = (uid == null ? null : (UserAggr()..id = uid));

  final mine = createdBy('me');
  final other = createdBy('other');
  final orphan = createdBy(null);
  final orders = [mine, other, orphan];

  List<Order> filter(RolesType? role, {String? userId = 'me'}) =>
      AuthorizationService.filterOrdersFor(
        role: role,
        userId: userId,
        orders: orders,
      );

  test('admin, manager and supervisor see every order', () {
    for (final role in [
      RolesType.admin,
      RolesType.manager,
      RolesType.supervisor,
    ]) {
      expect(filter(role), orders, reason: '$role');
    }
  });

  test('consultant and technician see only the orders they created', () {
    for (final role in [RolesType.consultant, RolesType.technician]) {
      expect(filter(role), [mine], reason: '$role');
    }
  });

  test('no role or no user sees nothing', () {
    expect(filter(null), isEmpty);
    for (final role in RolesType.values) {
      expect(filter(role, userId: null), isEmpty, reason: '$role');
    }
  });
}
