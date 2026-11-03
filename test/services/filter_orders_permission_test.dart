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
  final assigned = createdBy('other')..assignedTo = (UserAggr()..id = 'me');
  final orders = [mine, other, orphan, assigned];

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

  test('the consultant sees only the orders they created', () {
    expect(filter(RolesType.consultant), [mine]);
  });

  test('the technician also sees the orders assigned to them', () {
    expect(filter(RolesType.technician), [mine, assigned]);
  });

  test('no role or no user sees nothing', () {
    expect(filter(null), isEmpty);
    for (final role in RolesType.values) {
      expect(filter(role, userId: null), isEmpty, reason: '$role');
    }
  });
}
