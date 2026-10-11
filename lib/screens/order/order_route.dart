import 'package:flutter/widgets.dart';
import 'package:praticos/screens/order/order_screen_v2.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/services/order_screen_preference.dart';

/// `/order`: opens the redesigned order screen when "Nova tela da OS" is on,
/// otherwise the legacy [OrderForm] (default).
///
/// The choice is read once when the route is built, so flipping the switch
/// never swaps a screen that is already open. Both screens read the same
/// `order` argument. Opening the comments (`scrollToComments`, from a
/// notification) stays on the legacy screen until the new one has them.
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _useNew ??= OrderScreenPreference.useNewScreen.value &&
        args?['scrollToComments'] != true;
    if (_useNew!) {
      return widget.newScreenBuilder?.call(context) ?? const OrderScreenV2();
    }
    return widget.legacyBuilder?.call(context) ?? OrderForm();
  }
}
