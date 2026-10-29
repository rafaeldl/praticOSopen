import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';

void main() {
  group('/order', () {
    testWidgets('always builds the order screen (OrderScreenV2)', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      );

      final route = appRoutes['/order']!(context);
      expect(route, isA<OrderRoute>());
      expect((route as OrderRoute).build(context), isA<OrderScreenV2>());
    });

    testWidgets('shows the injected screen with the route arguments', (
      tester,
    ) async {
      Object? seenArgs;
      await tester.pumpWidget(
        CupertinoApp(
          onGenerateRoute: (settings) => CupertinoPageRoute(
            settings: const RouteSettings(
              name: '/order',
              arguments: {'scrollToComments': true},
            ),
            builder: (_) => OrderRoute(
              builder: (context) {
                seenArgs = ModalRoute.of(context)!.settings.arguments;
                return const Text('order screen');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('order screen'), findsOneWidget);
      expect(seenArgs, {'scrollToComments': true});
    });
  });

  group('newOrderArguments', () {
    test('none for a plain Nova OS', () {
      expect(newOrderArguments(), isNull);
    });

    test('carries "repeat" and the onCreated callback', () {
      void onCreated(String id) {}
      expect(newOrderArguments(repeat: true), {'repeat': true});
      expect(newOrderArguments(onCreated: onCreated), {'onCreated': onCreated});
    });
  });
}
