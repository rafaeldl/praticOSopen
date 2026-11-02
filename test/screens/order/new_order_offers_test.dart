import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/order/new_order_offers.dart';

void main() {
  Order vehicle() => Order()
    ..id = 'o1'
    ..device = (DeviceAggr()..name = 'Onix');

  bool offer(
    Order order, {
    String? segment = 'automotive',
    bool canManage = true,
    int declined = 0,
  }) => shouldOfferChecklist(
    order: order,
    segmentId: segment,
    canManageForms: canManage,
    declined: declined,
  );

  test('offers on a saved vehicle order of a workshop', () {
    expect(offer(vehicle()), isTrue);
  });

  test('not on other segments, nor without a vehicle', () {
    expect(offer(vehicle(), segment: 'hvac'), isFalse);
    expect(offer(Order()..id = 'o1'), isFalse);
  });

  test('not before the order has its id, nor without permission', () {
    expect(offer(vehicle()..id = null), isFalse);
    expect(offer(vehicle(), canManage: false), isFalse);
  });

  test('not on a contract', () {
    expect(offer(vehicle()..contract = OrderContract()), isFalse);
  });

  test('stops after being declined too many times', () {
    expect(offer(vehicle(), declined: kChecklistOfferLimit - 1), isTrue);
    expect(offer(vehicle(), declined: kChecklistOfferLimit), isFalse);
  });
}
