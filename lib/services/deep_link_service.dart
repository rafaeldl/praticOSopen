import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service para lidar com deep links do app
///
/// Suporta os seguintes deep links:
/// - praticos://upgrade - Abre a tela de planos
/// - praticos://restore - Restaura compras anteriores
/// - praticos://subscription - Abre gerenciamento de assinatura
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

  /// Retorna a rota correspondente ao deep link path
  static String? getRouteForPath(String path) {
    switch (path) {
      case 'upgrade':
      case 'plans':
        return '/plans';
      case 'restore':
        return '/manage_subscription';
      case 'subscription':
        return '/manage_subscription';
      default:
        return null;
    }
  }
}
