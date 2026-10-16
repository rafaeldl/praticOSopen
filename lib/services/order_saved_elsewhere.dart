import 'dart:async';

import 'package:praticos/models/order.dart';

/// Orders saved outside their open screen (e.g. files shared from another
/// app, see `ReceiveShareService.saveToOrder`). An open OS listens and shows
/// the new photos and documents without being reopened.
class OrderSavedElsewhere {
  OrderSavedElsewhere._();

  static final StreamController<Order> _controller =
      StreamController<Order>.broadcast();

  static Stream<Order> get stream => _controller.stream;

  static void notify(Order order) => _controller.add(order);
}
