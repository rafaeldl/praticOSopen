import 'package:flutter/widgets.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';

/// Opens the order referenced by a tapped push notification.
///
/// Uses the same route as the order list (`/order` with an [Order] holding
/// only the id; OrderScreenV2 loads the rest from the current company).
///
/// A notification for another company of the user is ignored: the order
/// screen reads the order from `Global.companyAggr`, so opening it would load
/// the wrong tenant. Switching company from a tap would rebuild the whole
/// session, which is out of scope for a tap handler.
class NotificationTapHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Route arguments for the tapped notification, or null when it should be
  /// ignored (no order, or an order from a company other than the current one).
  static Map<String, dynamic>? orderRouteArguments({
    required String? orderId,
    required String? companyId,
    required String? currentCompanyId,
  }) {
    if (orderId == null || orderId.isEmpty) return null;
    if (companyId != null && companyId != currentCompanyId) return null;
    return {'order': Order()..id = orderId};
  }

  static void handleTap(String? orderId, String? companyId) {
    final args = orderRouteArguments(
      orderId: orderId,
      companyId: companyId,
      currentCompanyId: Global.companyAggr?.id,
    );
    if (args == null) {
      debugPrint(
          '[NotificationTapHandler] Ignored tap: order=$orderId company=$companyId');
      return;
    }
    navigatorKey.currentState?.pushNamed('/order', arguments: args);
  }
}
