import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/routes.dart';

void main() {
  test('removed form routes are no longer registered', () {
    // Invites open InviteFormScreen directly; the company form became
    // the editors in "Sua empresa".
    expect(appRoutes.containsKey('/collaborator_form'), isFalse);
    expect(appRoutes.containsKey('/company_form'), isFalse);
  });

  test('team list route is still registered', () {
    expect(appRoutes.containsKey('/collaborator_list'), isTrue);
  });
}
