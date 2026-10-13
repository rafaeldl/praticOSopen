import 'package:flutter/cupertino.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/services/order_screen_preference.dart';

/// `/order`: opens the redesigned order screen (default), or the legacy
/// [OrderForm] when "Nova tela da OS" is turned off.
///
/// The choice is read once when the route is built, so flipping the switch
/// never swaps a screen that is already open. Both screens read the same
/// arguments (`order`, and `scrollToComments` / `commentId` from a
/// notification).
class OrderRoute extends StatefulWidget {
  const OrderRoute({super.key, this.newScreenBuilder, this.legacyBuilder});

  /// Injected in tests.
  final WidgetBuilder? newScreenBuilder;
  final WidgetBuilder? legacyBuilder;

  @override
  State<OrderRoute> createState() => _OrderRouteState();
}

class _OrderRouteState extends State<OrderRoute> {
  bool? _useNew;

  @override
  Widget build(BuildContext context) {
    _useNew ??= OrderScreenPreference.useNewScreen.value;
    if (_useNew!) {
      return widget.newScreenBuilder?.call(context) ?? const OrderScreenV2();
    }
    return widget.legacyBuilder?.call(context) ?? OrderForm();
  }
}

/// "Nova OS" from the "+": a large sheet ("X" and "✓" at the top), like
/// Lembretes and Calendário. Dragging down is off so what was filled is
/// never lost without the "Descartar esta OS?" question. Pickers (customer,
/// vehicle, item) push inside the sheet through its own navigator, which
/// knows the app's named routes. With the legacy screen turned on, opens
/// `/order` as before.
Future<Object?> openNewOrder(BuildContext context) {
  if (!OrderScreenPreference.useNewScreen.value) {
    return Navigator.of(context, rootNavigator: true).pushNamed('/order');
  }
  return Navigator.of(context, rootNavigator: true).push<Object?>(
    CupertinoSheetRoute<Object?>(
      enableDrag: false,
      builder: (_) => Navigator(
        onGenerateRoute: (settings) {
          if (settings.name == Navigator.defaultRouteName) {
            return CupertinoPageRoute<Object?>(
              settings: settings,
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
}
