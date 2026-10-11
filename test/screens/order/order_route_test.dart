import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/services/order_screen_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {Map<String, dynamic>? args}) async {
  await tester.pumpWidget(
    CupertinoApp(
      onGenerateRoute: (settings) => CupertinoPageRoute(
        settings: RouteSettings(name: '/order', arguments: args),
        builder: (_) => OrderRoute(
          newScreenBuilder: (_) => const Text('new screen'),
          legacyBuilder: (_) => const Text('legacy screen'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => OrderScreenPreference.useNewScreen.value = false);

  group('"Nova tela da OS" routing', () {
    testWidgets('legacy screen by default', (tester) async {
      expect(OrderScreenPreference.defaultValue, isFalse);
      await _pump(tester);
      expect(find.text('legacy screen'), findsOneWidget);
      expect(find.text('new screen'), findsNothing);
    });

    testWidgets('new screen when the switch is on', (tester) async {
      OrderScreenPreference.useNewScreen.value = true;
      await _pump(tester, args: {'order': null});
      expect(find.text('new screen'), findsOneWidget);
    });

    testWidgets('comments from a notification open on the new screen',
        (tester) async {
      OrderScreenPreference.useNewScreen.value = true;
      await _pump(tester, args: {'scrollToComments': true});
      expect(find.text('new screen'), findsOneWidget);
    });

    testWidgets('an open screen is not swapped when the switch flips',
        (tester) async {
      await _pump(tester);
      OrderScreenPreference.useNewScreen.value = true;
      await tester.pump();
      expect(find.text('legacy screen'), findsOneWidget);
    });
  });

  group('OrderScreenPreference', () {
    test('loads the saved value and saves changes', () async {
      SharedPreferences.setMockInitialValues({
        OrderScreenPreference.storageKey: true,
      });
      await OrderScreenPreference.load();
      expect(OrderScreenPreference.useNewScreen.value, isTrue);

      await OrderScreenPreference.set(false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OrderScreenPreference.storageKey), isFalse);
      expect(OrderScreenPreference.useNewScreen.value, isFalse);
    });

    test('defaults to off when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      await OrderScreenPreference.load();
      expect(OrderScreenPreference.useNewScreen.value, isFalse);
    });
  });
}
