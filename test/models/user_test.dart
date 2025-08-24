import 'package:praticos/models/user.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    test('Create aggregation', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';

      UserAggr aggr = user.toAggr();

      expect(aggr.id, equals(user.id));
      expect(aggr.name, equals(user.name));
    });

    test('Create from json', () {
      User user = User();
      user.id = 'JHjHJshjhsjjsh8s7n';
      user.name = 'User Test';

      User newUser = User.fromJson(user.toJson());

      expect(newUser.id, equals(user.id));
      expect(newUser.name, equals(user.name));
    });
  });
}
