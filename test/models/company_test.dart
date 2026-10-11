import 'package:praticos/models/company.dart';
import 'package:praticos/models/subscription.dart';
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

    test('never writes subscription (server-owned field)', () {
      final company = Company()
        ..id = 'c1'
        ..subscription = Subscription(plan: SubscriptionPlan.business);

      expect(company.toJson().containsKey('subscription'), isFalse);
    });

    test('still reads subscription from Firestore', () {
      final company = Company.fromJson({
        'id': 'c1',
        'subscription': {'plan': 'pro', 'status': 'active'},
      });

      expect(company.subscription?.plan, SubscriptionPlan.pro);
    });

    group('useFinancial', () {
      test('absent in Firestore reads as null (resolved as on)', () {
        final company = Company.fromJson({'id': 'c1'});
        expect(company.useFinancial, isNull);
      });

      test('round-trips false and true', () {
        for (final value in [false, true]) {
          final company = Company()
            ..id = 'c1'
            ..useFinancial = value;
          final json = company.toJson();
          expect(json['useFinancial'], value);
          expect(Company.fromJson(json).useFinancial, value);
        }
      });

      test('is not part of the aggregate embedded in other documents', () {
        final aggr = (Company()
              ..id = 'c1'
              ..useFinancial = false)
            .toAggr();
        expect(aggr.toJson().containsKey('useFinancial'), isFalse);
      });
    });
  });
}
