import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/screens/notifications/notification_list_tile.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, String? type) async {
    final notification = AppNotification()
      ..title = 'Pagamento recebido'
      ..body = 'OS #42'
      ..type = type
      ..read = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: NotificationListTile(
            notification: notification,
            isFirst: true,
            isLast: true,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  test('payment_received matches the backend type', () {
    expect(NotificationType.paymentReceived, 'payment_received');
  });

  testWidgets('pagamento recebido usa cartão verde', (tester) async {
    await pumpTile(tester, NotificationType.paymentReceived);

    final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.creditcard));
    expect(icon.color, CupertinoColors.systemGreen);
    expect(find.byIcon(CupertinoIcons.bell), findsNothing);
  });

  testWidgets('tipo desconhecido usa o sino', (tester) async {
    await pumpTile(tester, 'something_new');

    expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
  });
}
