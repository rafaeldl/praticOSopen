import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/order/new_order_offers.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/services/notification_tap_handler.dart';

/// `/order`: the order screen ([OrderScreenV2]). It reads the route
/// arguments (`order`, and `scrollToComments` / `commentId` from a
/// notification).
class OrderRoute extends StatelessWidget {
  const OrderRoute({super.key, this.builder});

  /// Injected in tests.
  final WidgetBuilder? builder;

  @override
  Widget build(BuildContext context) =>
      builder?.call(context) ?? const OrderScreenV2();
}

/// "Nova OS" from the "+": a large sheet ("X" and "✓" at the top), like
/// Lembretes and Calendário. Dragging down is off so what was filled is
/// never lost without the "Descartar esta OS?" question. Pickers (customer,
/// vehicle, item) push inside the sheet through its own navigator, which
/// knows the app's named routes.
///
/// [repeat] starts the order with "Repetir" turned on (from Contratos).
/// [onCreated] gets the new order id once it is saved (files shared from
/// another app are attached then). [startTalking] opens it already listening,
/// from the assistant's first-use sheet. Resolves with `true` on "✓"; the
/// offers that follow a save ([runNewOrderOffers]) do not hold it up.
Future<Object?> openNewOrder(
  BuildContext context, {
  bool repeat = false,
  bool startTalking = false,
  void Function(String orderId)? onCreated,
}) async {
  final saved = Completer<Order>();
  final arguments = {
    ...?newOrderArguments(
      repeat: repeat,
      startTalking: startTalking,
      onCreated: onCreated,
    ),
    'onSaved': saved.complete,
  };
  final result = await Navigator.of(context, rootNavigator: true).push<Object?>(
    CupertinoSheetRoute<Object?>(
      enableDrag: false,
      builder: (_) => Navigator(
        onGenerateRoute: (settings) {
          if (settings.name == Navigator.defaultRouteName) {
            return CupertinoPageRoute<Object?>(
              settings: RouteSettings(
                name: settings.name,
                arguments: arguments,
              ),
              builder: (_) => const OrderScreenV2(),
            );
          }
          final builder = appRoutes[settings.name];
          if (builder == null) return null;
          return CupertinoPageRoute<Object?>(
            settings: settings,
            builder: builder,
          );
        },
      ),
    ),
  );
  if (result == true) unawaited(_offersAfterSave(saved.future));
  return result;
}

/// Saving offline never gives the order an id: then only what does not need
/// it is offered. The sheet's own context is gone by now.
Future<void> _offersAfterSave(Future<Order> saved) async {
  final order = await saved
      .then<Order?>((order) => order)
      .timeout(_savedWait, onTimeout: () => null);
  final context = NotificationTapHandler.navigatorKey.currentContext;
  if (context != null && context.mounted) {
    await runNewOrderOffers(context, order);
  }
}

const _savedWait = Duration(seconds: 3);

/// Route arguments of the "Nova OS" ([OrderScreenV2] reads them).
Map<String, dynamic>? newOrderArguments({
  bool repeat = false,
  bool startTalking = false,
  void Function(String orderId)? onCreated,
}) {
  if (!repeat && !startTalking && onCreated == null) return null;
  return {
    if (repeat) 'repeat': true,
    if (startTalking) 'startTalking': true,
    if (onCreated != null) 'onCreated': onCreated,
  };
}
