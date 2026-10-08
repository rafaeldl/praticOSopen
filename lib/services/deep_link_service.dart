import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:praticos/services/paywall_launcher.dart';
import 'package:praticos/services/subscription_service.dart';

/// Subscription actions reachable by deep link.
enum SubscriptionDeepLink { paywall, customerCenter, restore }

/// Service para lidar com deep links do app
///
/// Suporta os seguintes deep links:
/// - praticos://upgrade e praticos://plans - Abre o paywall
/// - praticos://restore - Restaura compras anteriores
/// - praticos://subscription - Abre o Customer Center
class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  static const _channel = MethodChannel('praticos/deep_links');

  /// Callback chamado quando um deep link é recebido
  void Function(String path)? onDeepLink;

  /// Inicializa o serviço de deep links
  Future<void> init() async {
    if (kIsWeb) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final uri = call.arguments as String?;
        if (uri != null) {
          _handleDeepLink(uri);
        }
      }
    });

    // Verifica se o app foi aberto via deep link
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } on PlatformException {
      // Ignora se o canal não estiver disponível
    }
  }

  void _handleDeepLink(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme == 'praticos') {
        final path = uri.host.isEmpty ? uri.path : uri.host;
        onDeepLink?.call(path);
      }
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
    }
  }

  /// Subscription action for a deep link path, or null. Always null while
  /// paid plans are disabled (no purchase UI without In-App Purchase).
  static SubscriptionDeepLink? subscriptionLinkForPath(String path) {
    if (!SubscriptionService.paidPlansEnabled) return null;
    switch (path) {
      case 'upgrade':
      case 'plans':
        return SubscriptionDeepLink.paywall;
      case 'subscription':
        return SubscriptionDeepLink.customerCenter;
      case 'restore':
        return SubscriptionDeepLink.restore;
      default:
        return null;
    }
  }

  /// Runs [link] through [PaywallLauncher] (owner/admin rule included).
  static Future<void> openSubscriptionLink(
    BuildContext context,
    SubscriptionDeepLink link,
  ) async {
    switch (link) {
      case SubscriptionDeepLink.paywall:
        await PaywallLauncher.showPaywall(context);
      case SubscriptionDeepLink.customerCenter:
        await PaywallLauncher.showCustomerCenter(context);
      case SubscriptionDeepLink.restore:
        await PaywallLauncher.restore(context);
    }
  }
}
