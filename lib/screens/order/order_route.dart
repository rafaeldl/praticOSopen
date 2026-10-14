import 'package:flutter/cupertino.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';

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
Future<Object?> openNewOrder(BuildContext context, {bool repeat = false}) {
  final arguments = repeat ? const {'repeat': true} : null;
  return Navigator.of(context, rootNavigator: true).push<Object?>(
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
}
