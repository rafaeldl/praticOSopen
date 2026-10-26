import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/authorization_service.dart';

/// Order list queries must match the Firestore rules: consultant and
/// technician read only the orders they created, so every list query they
/// run filters `createdBy.id == uid` (otherwise the whole query is denied).
void main() {
  const allRoles = RolesType.values;
  const seeAll = [RolesType.admin, RolesType.manager, RolesType.supervisor];
  const ownOnly = [RolesType.consultant, RolesType.technician];

  group('orderCreatorFilterFor', () {
    test('admin, manager and supervisor query without the filter', () {
      for (final role in seeAll) {
        expect(
          AuthorizationService.orderCreatorFilterFor(role: role, userId: 'me'),
          isNull,
          reason: '$role',
        );
      }
    });

    test('consultant and technician filter by their own uid', () {
      for (final role in ownOnly) {
        expect(
          AuthorizationService.orderCreatorFilterFor(role: role, userId: 'me'),
          'me',
          reason: '$role',
        );
      }
    });

    test('an unknown role filters too (the filtered query never fails)', () {
      expect(
        AuthorizationService.orderCreatorFilterFor(role: null, userId: 'me'),
        'me',
      );
    });
  });

  group('scopedArgs', () {
    test('adds createdBy.id when there is a creator', () {
      final args = TenantOrderRepository.scopedArgs([
        QueryArgs('status', 'done'),
      ], 'me');
      expect(args.map((a) => a.key), ['status', 'createdBy.id']);
      expect(args.last.value, 'me');
    });

    test('keeps the query as is without a creator', () {
      final args = TenantOrderRepository.scopedArgs([
        QueryArgs('status', 'done'),
      ], null);
      expect(args.map((a) => a.key), ['status']);
      expect(TenantOrderRepository.scopedArgs(null, null), isEmpty);
    });

    test('does not repeat an existing createdBy.id filter', () {
      final args = TenantOrderRepository.scopedArgs([
        QueryArgs('createdBy.id', 'me'),
      ], 'me');
      expect(args, hasLength(1));
    });
  });

  group('canAccessOrderFor', () {
    Order by(String uid) => Order()..createdBy = (UserAggr()..id = uid);

    test('follows the rules: technician only the orders they created', () {
      for (final role in seeAll) {
        expect(
          AuthorizationService.canAccessOrderFor(
            role: role,
            userId: 'me',
            order: by('other'),
          ),
          isTrue,
          reason: '$role',
        );
      }
      for (final role in ownOnly) {
        expect(
          AuthorizationService.canAccessOrderFor(
            role: role,
            userId: 'me',
            order: by('other'),
          ),
          isFalse,
          reason: '$role',
        );
        expect(
          AuthorizationService.canAccessOrderFor(
            role: role,
            userId: 'me',
            order: by('me'),
          ),
          isTrue,
          reason: '$role',
        );
      }
    });

    test('no role or no user opens nothing', () {
      expect(
        AuthorizationService.canAccessOrderFor(
          role: null,
          userId: 'me',
          order: by('me'),
        ),
        isFalse,
      );
      for (final role in allRoles) {
        expect(
          AuthorizationService.canAccessOrderFor(
            role: role,
            userId: null,
            order: by('me'),
          ),
          isFalse,
        );
      }
    });
  });

  test('only who can create orders generates the due contract orders', () {
    expect(canGenerateContractOrders(RolesType.manager), isFalse);
    expect(canGenerateContractOrders(null), isFalse);
    for (final role in [
      RolesType.admin,
      RolesType.supervisor,
      RolesType.consultant,
      RolesType.technician,
    ]) {
      expect(canGenerateContractOrders(role), isTrue, reason: '$role');
    }
  });

  group('creatorFilterChanges (role arrives late)', () {
    Future<List<String?>> run(RolesType? initial, List<RolesType?> roles) =>
        AuthorizationService.creatorFilterChanges(
          initial: initial,
          roles: Stream.fromIterable(roles),
          userId: 'me',
        ).toList();

    test('unknown role filters, then drops the filter for an admin', () async {
      expect(await run(null, [null, RolesType.admin]), ['me', null]);
    });

    test('unknown role that turns out technician keeps the filter', () async {
      expect(await run(null, [RolesType.technician]), ['me']);
    });

    test('known role stays put when the user doc is briefly missing', () async {
      expect(await run(RolesType.admin, [null, RolesType.admin]), [null]);
    });

    test('a role change after load updates the filter', () async {
      expect(
        await run(RolesType.admin, [RolesType.technician]),
        [null, 'me'],
      );
    });
  });
}
