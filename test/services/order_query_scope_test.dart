import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/utils/order_scope.dart';

/// Order list queries must match the Firestore rules: the consultant reads
/// only the orders they created and the technician also the ones assigned to
/// them, so every list query they run filters by it (otherwise the whole
/// query is denied).
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

    test('the consultant filters by the orders they created', () {
      expect(
        AuthorizationService.orderCreatorFilterFor(
          role: RolesType.consultant,
          userId: 'me',
        ),
        const OrderScope('me'),
      );
    });

    test('the technician also sees the orders assigned to them', () {
      expect(
        AuthorizationService.orderCreatorFilterFor(
          role: RolesType.technician,
          userId: 'me',
        ),
        const OrderScope('me', assigned: true),
      );
    });

    test('an unknown role filters by creator (the query never fails)', () {
      expect(
        AuthorizationService.orderCreatorFilterFor(role: null, userId: 'me'),
        const OrderScope('me'),
      );
    });
  });

  group('scopedArgs', () {
    test('adds createdBy.id when there is a creator', () {
      final args = TenantOrderRepository.scopedArgs([
        QueryArgs('status', 'done'),
      ], const OrderScope('me'));
      expect(args.map((a) => a.key), ['status', 'createdBy.id']);
      expect(args.last.value, 'me');
      expect(args.last.oper, 'isEqualTo');
    });

    test('created by or assigned to the technician', () {
      final args = TenantOrderRepository.scopedArgs([
        QueryArgs('status', 'done'),
      ], const OrderScope('me', assigned: true));
      expect(args.map((a) => a.key), ['status', 'createdBy.id']);
      expect(args.last.value, 'me');
      expect(args.last.oper, TenantOrderRepository.createdOrAssignedOper);
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
      ], const OrderScope('me', assigned: true));
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

    test('the technician opens the orders assigned to them', () {
      final assigned = by('other')..assignedTo = (UserAggr()..id = 'me');
      expect(
        AuthorizationService.canAccessOrderFor(
          role: RolesType.technician,
          userId: 'me',
          order: assigned,
        ),
        isTrue,
      );
      expect(
        AuthorizationService.canAccessOrderFor(
          role: RolesType.consultant,
          userId: 'me',
          order: assigned,
        ),
        isFalse,
      );
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

  group('who generates from a contract template', () {
    Order template(String author) =>
        Order()..createdBy = (UserAggr()..id = author);

    test('admin and supervisor generate from any template', () {
      for (final role in [RolesType.admin, RolesType.supervisor]) {
        expect(
          canGenerateFromTemplate(
            role: role,
            userId: 'me',
            template: template('boss'),
          ),
          isTrue,
          reason: '$role',
        );
      }
    });

    test('technician and consultant only from their own template', () {
      for (final role in [RolesType.technician, RolesType.consultant]) {
        expect(
          canGenerateFromTemplate(
            role: role,
            userId: 'me',
            template: template('boss'),
          ),
          isFalse,
          reason: '$role on the admin template',
        );
        expect(
          canGenerateFromTemplate(
            role: role,
            userId: 'me',
            template: template('me'),
          ),
          isTrue,
          reason: '$role on their own template',
        );
      }
    });

    test('the manager never generates, not even their own', () {
      expect(
        canGenerateFromTemplate(
          role: RolesType.manager,
          userId: 'me',
          template: template('me'),
        ),
        isFalse,
      );
    });
  });

  group('creatorFilterChanges (role arrives late)', () {
    Future<List<OrderScope?>> run(RolesType? initial, List<RolesType?> roles) =>
        AuthorizationService.creatorFilterChanges(
          initial: initial,
          roles: Stream.fromIterable(roles),
          userId: 'me',
        ).toList();

    test('unknown role filters, then drops the filter for an admin', () async {
      expect(await run(null, [null, RolesType.admin]), [
        const OrderScope('me'),
        null,
      ]);
    });

    test('unknown role that turns out consultant keeps the filter', () async {
      expect(await run(null, [RolesType.consultant]), [const OrderScope('me')]);
    });

    test('unknown role that turns out technician adds the assigned', () async {
      expect(await run(null, [RolesType.technician]), [
        const OrderScope('me'),
        const OrderScope('me', assigned: true),
      ]);
    });

    test('known role stays put when the user doc is briefly missing', () async {
      expect(await run(RolesType.admin, [null, RolesType.admin]), [null]);
    });

    test('a role change after load updates the filter', () async {
      expect(await run(RolesType.admin, [RolesType.technician]), [
        null,
        const OrderScope('me', assigned: true),
      ]);
    });
  });
}
