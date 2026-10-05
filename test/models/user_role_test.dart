import 'package:praticos/models/company.dart';
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:test/test.dart';

void main() {
  group('UserRole', () {
    test('Create role', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';

      Company company = Company();
      company.id = 'AKJjksSSDDDE67s';
      company.name = 'Company Test';

      UserRole role = UserRole();
      role.company = company.toAggr();
      role.user = user.toAggr();
      role.role = RolesType.admin;

      user.companies = [role.toCompanyRoleAggr()];
      company.users = [role.toUserRoleAggr()];

      User newUser = User.fromJson(user.toJson());
      Company newCompany = Company.fromJson(company.toJson());
      UserRole newRole = UserRole.fromJson(role.toJson());

      expect(user.id, equals(newRole.user!.id));
      expect(company.id, equals(newRole.company!.id));
      expect(RolesType.admin, equals(newRole.role));

      expect(user.id, equals(newCompany.users![0].user!.id));
      expect(company.id, equals(newUser.companies![0].company!.id));
    });

    test('Create aggregation', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';

      Company company = Company();
      company.id = 'AKJjksSSDDDE67s';
      company.name = 'Company Test';

      UserRole role = UserRole();
      role.company = company.toAggr();
      role.user = user.toAggr();
      role.role = RolesType.admin;

      user.companies = [role.toCompanyRoleAggr()];
      company.users = [role.toUserRoleAggr()];

      User newUser = User.fromJson(user.toJson());
      Company newCompany = Company.fromJson(company.toJson());
      UserRole newRole = UserRole.fromJson(role.toJson());

      expect(user.id, equals(newRole.user!.id));
      expect(company.id, equals(newRole.company!.id));
      expect(RolesType.admin, equals(newRole.role));

      expect(user.id, equals(newCompany.users![0].user!.id));
      expect(company.id, equals(newUser.companies![0].company!.id));
    });
  });

  group('rolesTypeFromJson', () {
    test("maps 'owner' (WhatsApp-registered owner) to admin", () {
      expect(rolesTypeFromJson('owner'), RolesType.admin);
    });

    test('keeps every known role', () {
      for (final role in RolesType.values) {
        expect(rolesTypeFromJson(role.name), role);
      }
    });

    test('falls back to technician for unknown values', () {
      expect(rolesTypeFromJson('viewer'), RolesType.technician);
      expect(rolesTypeFromJson('ADMIN'), RolesType.technician);
      expect(rolesTypeFromJson(42), RolesType.technician);
    });

    test('keeps null as null', () {
      expect(rolesTypeFromJson(null), isNull);
    });

    test("is used by every model that parses a role", () {
      final entry = {'company': {'id': 'c1', 'name': 'C1'}, 'role': 'owner'};
      expect(CompanyRoleAggr.fromJson(entry).role, RolesType.admin);
      expect(UserRole.fromJson(entry).role, RolesType.admin);
      expect(UserRoleAggr.fromJson({'role': 'owner'}).role, RolesType.admin);
      expect(Membership.fromJson({'role': 'owner'}).role, RolesType.admin);
      expect(Invite.fromJson({'role': 'owner'}).role, RolesType.admin);
      expect(Membership.fromJson({'role': 'bogus'}).role, RolesType.technician);
      expect(CompanyRoleAggr.fromJson({'company': null}).role, isNull);
    });

    test("an owner read from Firestore is admin in User.companies", () {
      final user = User.fromJson({
        'id': 'u1',
        'companies': [
          {'company': {'id': 'c1', 'name': 'C1'}, 'role': 'owner'},
        ],
      });
      expect(user.companies!.single.role, RolesType.admin);
    });
  });
}
