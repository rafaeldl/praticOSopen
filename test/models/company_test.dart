import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:test/test.dart';

void main() {
  group('Company', () {
    test('Create aggregation', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';
      UserAggr userAggr = user.toAggr();

      Company company = Company();
      company.id = 'AKJjksSSDDDE67s';

      company.createdAt = DateTime.now();
      company.createdBy = userAggr;
      company.updatedAt = DateTime.now();
      company.updatedBy = userAggr;

      company.name = 'Company Test';
      company.address = 'address';
      company.logo = 'logo';
      company.phone = 'phone';
      company.site = 'site';

      company.owner = userAggr;
      CompanyAggr companyAggr = company.toAggr();

      UserRole userRole = UserRole();
      userRole.user = userAggr;
      userRole.company = companyAggr;
      userRole.role = RolesType.admin;
      company.users = [userRole.toUserRoleAggr()];

      expect(companyAggr.id, equals(company.id));
      expect(companyAggr.name, equals(company.name));
    });

    test('Create from json', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';
      UserAggr userAggr = user.toAggr();

      Company company = Company();
      company.id = 'AKJjksSSDDDE67s';

      company.createdAt = DateTime.now();
      company.createdBy = userAggr;
      company.updatedAt = DateTime.now();
      company.updatedBy = userAggr;

      company.name = 'Company Test';
      company.address = 'address';
      company.logo = 'logo';
      company.phone = 'phone';
      company.site = 'site';

      company.owner = userAggr;
      CompanyAggr companyAggr = company.toAggr();

      UserRole userRole = UserRole();
      userRole.user = userAggr;
      userRole.company = companyAggr;
      userRole.role = RolesType.admin;
      company.users = [userRole.toUserRoleAggr()];

      Company newCompany = Company.fromJson(company.toJson());

      expect(newCompany.toJson(), equals(company.toJson()));
    });
  });
}
