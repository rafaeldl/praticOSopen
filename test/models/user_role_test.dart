import 'package:praticos/models/company.dart';
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
}
