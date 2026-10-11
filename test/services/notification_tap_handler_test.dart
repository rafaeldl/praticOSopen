import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/notification_tap_handler.dart';

void main() {
  group('orderRouteArguments', () {
    test('opens the order of the current company', () {
      final args = NotificationTapHandler.orderRouteArguments(
        orderId: 'o1',
        companyId: 'c1',
        currentCompanyId: 'c1',
      );
      expect((args!['order'] as Order).id, 'o1');
    });

    test('opens the order when the payload has no companyId', () {
      final args = NotificationTapHandler.orderRouteArguments(
        orderId: 'o1',
        companyId: null,
        currentCompanyId: 'c1',
      );
      expect((args!['order'] as Order).id, 'o1');
    });

    test('ignores an order from another company', () {
      expect(
        NotificationTapHandler.orderRouteArguments(
          orderId: 'o1',
          companyId: 'c2',
          currentCompanyId: 'c1',
        ),
        isNull,
      );
    });

    test('ignores a notification without orderId', () {
      for (final orderId in [null, '']) {
        expect(
          NotificationTapHandler.orderRouteArguments(
            orderId: orderId,
            companyId: 'c1',
            currentCompanyId: 'c1',
          ),
          isNull,
        );
      }
    });
  });

  group('handleTap', () {
    late List<RouteSettings> pushed;

    Future<void> pumpApp(WidgetTester tester) async {
      pushed = [];
      await tester.pumpWidget(WidgetsApp(
        navigatorKey: NotificationTapHandler.navigatorKey,
        color: const Color(0xFF000000),
        onGenerateRoute: (settings) {
          if (settings.name == '/order') pushed.add(settings);
          return PageRouteBuilder(
            settings: settings,
            pageBuilder: (_, __, ___) => const SizedBox(),
          );
        },
      ));
    }

    setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
    tearDown(() => Global.companyAggr = null);

    testWidgets('pushes /order with the tapped order id', (tester) async {
      await pumpApp(tester);

      NotificationTapHandler.handleTap('o1', 'c1');
      await tester.pumpAndSettle();

      expect(pushed, hasLength(1));
      final args = pushed.single.arguments as Map<String, dynamic>;
      expect((args['order'] as Order).id, 'o1');
    });

    testWidgets('does not navigate for another company', (tester) async {
      await pumpApp(tester);

      NotificationTapHandler.handleTap('o1', 'c2');
      await tester.pumpAndSettle();

      expect(pushed, isEmpty);
    });
  });
}
