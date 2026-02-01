import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:praticos/models/share_token.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for managing order share links (magic links)
class ShareLinkService {
  static final ShareLinkService _instance = ShareLinkService._internal();
  static ShareLinkService get instance => _instance;
  ShareLinkService._internal();

  // API base URL - uses emulator in debug mode, production otherwise
  static String get _baseUrl {
    if (kDebugMode) {
      // Use 10.0.2.2 for Android emulator, localhost for iOS simulator
      final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      return 'http://$host:5001/praticos/southamerica-east1/api';
    }
    return 'https://southamerica-east1-praticos.cloudfunctions.net/api';
  }

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
      throw ShareLinkException('Failed to generate share link: ${response.statusCode}');
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
    } else {
      throw ShareLinkException('Could not open WhatsApp');
    }
  }

  /// Copy link to clipboard
  Future<void> copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
  }

  /// Build a share message for the customer
  String buildShareMessage({
    required String customerName,
    required int orderNumber,
    String? companyName,
    String? locale,
  }) {
    final loc = locale ?? 'pt';

    if (loc.startsWith('en')) {
      return 'Hi $customerName! Here is the link to track your service order #$orderNumber${companyName != null ? ' at $companyName' : ''}. You can view details, approve quotes, and leave comments:';
    } else if (loc.startsWith('es')) {
      return 'Hola $customerName! Aquí está el enlace para seguir tu orden de servicio #$orderNumber${companyName != null ? ' en $companyName' : ''}. Puedes ver detalles, aprobar presupuestos y dejar comentarios:';
    } else {
      // Portuguese (default)
      return 'Olá $customerName! Segue o link para acompanhar sua OS #$orderNumber${companyName != null ? ' na $companyName' : ''}. Você pode ver os detalhes, aprovar orçamentos e deixar comentários:';
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
