import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';

void main() {
  test('vehicle in the title, "Cliente · OS n" under it', () {
    final header = orderHeaderTexts(
      deviceName: 'Chevrolet Classic',
      customerName: 'Paulo Nunes',
      orderLabel: 'OS 186',
    );
    expect(header.title, 'Chevrolet Classic');
    expect(header.subtitle, 'Paulo Nunes · OS 186');
  });

  test('without vehicle the customer is the title', () {
    final header = orderHeaderTexts(
      customerName: 'Paulo Nunes',
      orderLabel: 'OS 186',
    );
    expect(header.title, 'Paulo Nunes');
    expect(header.subtitle, 'OS 186');
  });

  test('without vehicle and customer only the order label', () {
    final header = orderHeaderTexts(deviceName: ' ', orderLabel: 'OS 186');
    expect(header.title, 'OS 186');
    expect(header.subtitle, isNull);
  });
}
