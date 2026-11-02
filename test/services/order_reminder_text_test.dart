import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/order_reminder_text.dart';

void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));

  Order order() => Order()
    ..number = 12
    ..customer = (CustomerAggr()..name = 'Ana Souza');

  test('says the time, who and which device', () {
    final text = OrderReminderText.format(
      order()..device = (DeviceAggr()..name = 'Onix 1.0'),
      pt,
      '14:00',
    );
    expect(text.title, 'Agendamento às 14:00');
    expect(text.body, 'OS 12 · Ana Souza · Onix 1.0');
  });

  test('without a device it stays on the customer', () {
    final text = OrderReminderText.format(order(), pt, '14:00');
    expect(text.body, 'OS 12 · Ana Souza');
  });

  test('several devices show how many more', () {
    final text = OrderReminderText.format(
      order()
        ..devices = [
          DeviceAggr()..name = 'Split sala',
          DeviceAggr()..name = 'Split quarto',
        ],
      pt,
      '09:30',
    );
    expect(text.body, 'OS 12 · Ana Souza · Split sala +1');
  });
}
