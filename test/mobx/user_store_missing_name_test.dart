import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/user.dart';

void main() {
  test('fills the name Apple gave after the user document was created', () {
    final existing = User()..name = null;
    expect(missingUserNameFor(existing, ' Ana Souza '), 'Ana Souza');
    expect(missingUserNameFor(User()..name = '  ', 'Ana'), 'Ana');
  });

  test('never overwrites a name nor writes an empty one', () {
    expect(missingUserNameFor(User()..name = 'Bia', 'Ana'), isNull);
    expect(missingUserNameFor(User(), null), isNull);
    expect(missingUserNameFor(User(), '  '), isNull);
    expect(missingUserNameFor(null, 'Ana'), isNull);
  });
}
