import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Service for managing WhatsApp linking with the PraticOS bot
class WhatsAppLinkService {
  static final WhatsAppLinkService _instance = WhatsAppLinkService._internal();
  static WhatsAppLinkService get instance => _instance;
  WhatsAppLinkService._internal();

  // API base URL - uses Cloud Functions endpoint
  static const String _baseUrl =
      'https://southamerica-east1-praticos.cloudfunctions.net/api';

  /// Get Firebase Auth token for API requests
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Generate a WhatsApp linking token
  /// Returns the token, WhatsApp deep link, and expiration time
  Future<WhatsAppLinkToken> generateToken() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw WhatsAppLinkException('User not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/user/link/whatsapp/token'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return WhatsAppLinkToken.fromJson(data['data']);
      }
      throw WhatsAppLinkException(
        data['error']?['message'] ?? 'Failed to generate token',
      );
    } else if (response.statusCode == 401) {
      throw WhatsAppLinkException('Authentication required');
    } else {
      throw WhatsAppLinkException('Failed to generate token: ${response.statusCode}');
    }
  }

  /// Check if the current user has WhatsApp linked
  Future<WhatsAppLinkStatus> getStatus() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw WhatsAppLinkException('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/user/link/whatsapp/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return WhatsAppLinkStatus.fromJson(data['data']);
      }
      throw WhatsAppLinkException(
        data['error']?['message'] ?? 'Failed to check status',
      );
    } else if (response.statusCode == 401) {
      throw WhatsAppLinkException('Authentication required');
    } else {
      throw WhatsAppLinkException('Failed to check status: ${response.statusCode}');
    }
  }

  /// Unlink WhatsApp from the current user
  Future<void> unlink() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw WhatsAppLinkException('User not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/user/link/whatsapp'),
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
      throw WhatsAppLinkException(
        data['error']?['message'] ?? 'Failed to unlink',
      );
    } else if (response.statusCode == 401) {
      throw WhatsAppLinkException('Authentication required');
    } else if (response.statusCode == 404) {
      throw WhatsAppLinkException('WhatsApp not linked');
    } else {
      throw WhatsAppLinkException('Failed to unlink: ${response.statusCode}');
    }
  }
}

/// Token generated for WhatsApp linking
class WhatsAppLinkToken {
  final String token;
  final String link;
  final String botNumber;
  final int expiresIn;

  WhatsAppLinkToken({
    required this.token,
    required this.link,
    required this.botNumber,
    required this.expiresIn,
  });

  factory WhatsAppLinkToken.fromJson(Map<String, dynamic> json) {
    return WhatsAppLinkToken(
      token: json['token'] as String,
      link: json['link'] as String,
      botNumber: json['botNumber'] as String? ?? '',
      expiresIn: json['expiresIn'] as int? ?? 900,
    );
  }
}

/// Status of WhatsApp link for a user
class WhatsAppLinkStatus {
  final bool linked;
  final String? number;
  final DateTime? linkedAt;

  WhatsAppLinkStatus({
    required this.linked,
    this.number,
    this.linkedAt,
  });

  factory WhatsAppLinkStatus.fromJson(Map<String, dynamic> json) {
    DateTime? linkedAt;
    if (json['linkedAt'] != null) {
      if (json['linkedAt'] is Map) {
        // Firestore Timestamp format
        final seconds = json['linkedAt']['_seconds'] as int?;
        if (seconds != null) {
          linkedAt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      } else if (json['linkedAt'] is String) {
        linkedAt = DateTime.tryParse(json['linkedAt']);
      }
    }

    return WhatsAppLinkStatus(
      linked: json['linked'] as bool? ?? false,
      number: json['number'] as String?,
      linkedAt: linkedAt,
    );
  }
}

/// Exception for WhatsApp link operations
class WhatsAppLinkException implements Exception {
  final String message;
  WhatsAppLinkException(this.message);

  @override
  String toString() => message;
}
