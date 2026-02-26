import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:praticos/models/share_token.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for managing order share links (magic links)
class ShareLinkService {
  static final ShareLinkService _instance = ShareLinkService._internal();
  static ShareLinkService get instance => _instance;
  ShareLinkService._internal();

  // API base URL - always uses production Cloud Functions
  static const String _baseUrl =
      'https://southamerica-east1-praticos.cloudfunctions.net/api';

  /// Get Firebase Auth token for API requests
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Generate a share link for an order
  /// Returns the share link result with token and URL
  Future<ShareLinkResult> generateShareLink({
    required String orderId,
    List<String> permissions = const ['view', 'approve', 'comment'],
    int expiresInDays = 7,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw ShareLinkException('User not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/app/orders/$orderId/share'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'permissions': permissions,
        'expiresInDays': expiresInDays,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return ShareLinkResult.fromJson(data['data']);
      }
      throw ShareLinkException(
        data['error']?['message'] ?? 'Failed to generate share link',
      );
    } else if (response.statusCode == 401) {
      throw ShareLinkException('Authentication required');
    } else if (response.statusCode == 404) {
      throw ShareLinkException('Order not found');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body);
      throw ShareLinkException(
        data['error']?['message'] ?? 'Invalid request',
      );
    } else {
      // Decode server error message for better debugging
      String serverMessage = 'Failed to generate share link: ${response.statusCode}';
      try {
        final data = json.decode(response.body);
        final errorMsg = data['error']?['message'];
        if (errorMsg != null) {
          serverMessage = '$errorMsg (${response.statusCode})';
        }
      } catch (_) {}
      throw ShareLinkException(serverMessage);
    }
  }

  /// Get all share tokens for an order
  Future<List<ShareToken>> getShareTokens(String orderId) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw ShareLinkException('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/v1/app/orders/$orderId/share'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List<dynamic> tokensJson = data['data'] ?? [];
        return tokensJson
            .map((t) => ShareToken.fromJson(t as Map<String, dynamic>))
            .toList();
      }
      throw ShareLinkException(
        data['error']?['message'] ?? 'Failed to get share tokens',
      );
    } else if (response.statusCode == 401) {
      throw ShareLinkException('Authentication required');
    } else {
      throw ShareLinkException('Failed to get share tokens: ${response.statusCode}');
    }
  }

  /// Revoke a share token
  Future<void> revokeShareToken(String orderId, String shareToken) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw ShareLinkException('User not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/v1/app/orders/$orderId/share/$shareToken'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return;
      }
      throw ShareLinkException(
        data['error']?['message'] ?? 'Failed to revoke share token',
      );
    } else if (response.statusCode == 401) {
      throw ShareLinkException('Authentication required');
    } else if (response.statusCode == 404) {
      throw ShareLinkException('Share token not found');
    } else {
      throw ShareLinkException('Failed to revoke share token: ${response.statusCode}');
    }
  }

  /// Share via system share sheet
  Future<void> shareViaSheet({
    required String url,
    String? message,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final text = message != null ? '$message\n\n$url' : url;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    AnalyticsService.instance.logShare(method: 'sheet', contentType: 'order');
  }

  /// Share via WhatsApp
  Future<void> shareViaWhatsApp({
    required String url,
    required String phone,
    String? message,
  }) async {
    // Normalize phone number (remove non-digits, ensure country code)
    String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!normalizedPhone.startsWith('55') && normalizedPhone.length <= 11) {
      normalizedPhone = '55$normalizedPhone';
    }

    final text = message != null ? '$message\n\n$url' : url;
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse('https://wa.me/$normalizedPhone?text=$encodedText');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      AnalyticsService.instance.logShare(method: 'whatsapp', contentType: 'order');
    } else {
      throw ShareLinkException('Could not open WhatsApp');
    }
  }

  /// Copy link to clipboard
  Future<void> copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    AnalyticsService.instance.logShare(method: 'clipboard', contentType: 'order');
  }

  /// Build a share message for the customer
  /// If [statusContext] is provided, builds a status-specific message
  String buildShareMessage({
    required String customerName,
    required int orderNumber,
    String? companyName,
    String? locale,
    String? statusContext,
  }) {
    final loc = locale ?? 'pt';
    final company = companyName != null
        ? (loc.startsWith('en') ? ' at $companyName' : (loc.startsWith('es') ? ' en $companyName' : ' na $companyName'))
        : '';

    if (statusContext != null) {
      return _buildStatusMessage(loc, statusContext, customerName, orderNumber, company);
    }

    if (loc.startsWith('en')) {
      return 'Hi $customerName! Here is the link to track your service order #$orderNumber$company. You can view details, approve quotes, and leave comments:';
    } else if (loc.startsWith('es')) {
      return 'Hola $customerName! Aquí está el enlace para seguir tu orden de servicio #$orderNumber$company. Puedes ver detalles, aprobar presupuestos y dejar comentarios:';
    } else {
      return 'Olá $customerName! Segue o link para acompanhar sua OS #$orderNumber$company. Você pode ver os detalhes, aprovar orçamentos e deixar comentários:';
    }
  }

  String _buildStatusMessage(String loc, String status, String name, int number, String company) {
    if (loc.startsWith('en')) {
      switch (status) {
        case 'approved':
          return 'Hi $name! The quote for your service order #$number$company has been approved! Track the details:';
        case 'progress':
          return 'Hi $name! Your service order #$number$company is now in progress! Follow along:';
        case 'done':
          return 'Hi $name! Your service order #$number$company has been completed! Check the details:';
        default:
          return 'Hi $name! There is an update on your service order #$number$company:';
      }
    } else if (loc.startsWith('es')) {
      switch (status) {
        case 'approved':
          return 'Hola $name! El presupuesto de tu orden de servicio #$number$company fue aprobado! Acompaña los detalles:';
        case 'progress':
          return 'Hola $name! Tu orden de servicio #$number$company está en progreso! Sigue el avance:';
        case 'done':
          return 'Hola $name! El servicio de tu orden #$number$company fue completado! Confiere los detalles:';
        default:
          return 'Hola $name! Hay una actualización en tu orden de servicio #$number$company:';
      }
    } else {
      switch (status) {
        case 'approved':
          return 'Olá $name! O orçamento da sua OS #$number$company foi aprovado! Acompanhe os detalhes:';
        case 'progress':
          return 'Olá $name! Sua OS #$number$company está em andamento! Acompanhe o progresso:';
        case 'done':
          return 'Olá $name! O serviço da sua OS #$number$company foi concluído! Confira os detalhes:';
        default:
          return 'Olá $name! Há uma atualização na sua OS #$number$company:';
      }
    }
  }
}

/// Exception for share link operations
class ShareLinkException implements Exception {
  final String message;
  ShareLinkException(this.message);

  @override
  String toString() => message;
}
