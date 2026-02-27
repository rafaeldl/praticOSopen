import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:praticos/models/invite.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';

/// Service for managing collaborator invites via API.
///
/// Uses the backend API (Admin SDK) instead of writing directly to Firestore,
/// which bypasses security rules and centralizes business logic.
class InviteApiService {
  static final InviteApiService _instance = InviteApiService._internal();
  static InviteApiService get instance => _instance;
  InviteApiService._internal();

  // API base URL - uses emulator in debug mode, production otherwise
  static String get _baseUrl {
    if (kDebugMode) {
      // Use ngrok for iOS simulator (localhost:5000 conflicts with AirTunes)
      // For Android emulator, use 10.0.2.2
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:5000/praticos/southamerica-east1/api';
      }
      // iOS simulator - use ngrok tunnel
      return 'https://acidogenic-lorinda-unnymphean.ngrok-free.dev/praticos/southamerica-east1/api';
    }
    return 'https://southamerica-east1-praticos.cloudfunctions.net/api';
  }

  /// Get Firebase Auth token for API requests
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  /// Create a new invite
  /// Returns the created invite token and expiration date
  Future<InviteResult> createInvite({
    String? name,
    String? email,
    String? phone,
    required String role,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final body = <String, dynamic>{
      'role': role,
    };
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;

    final url = '$_baseUrl/v1/app/invites';
    print('[InviteApiService] Creating invite: $body');
    print('[InviteApiService] POST URL: $url');
    print('[InviteApiService] Token (first 20 chars): ${token.substring(0, 20)}...');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    print('[InviteApiService] Response status: ${response.statusCode}');
    print('[InviteApiService] Response headers: ${response.headers}');
    print('[InviteApiService] Response body: ${response.body}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return InviteResult(
          token: data['data']['token'],
          expiresAt: DateTime.parse(data['data']['expiresAt']),
        );
      }
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to create invite',
      );
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body);
      throw InviteApiException(
        data['error']?['message'] ?? 'Invalid request',
      );
    } else if (response.statusCode == 403) {
      throw InviteApiException('You do not have permission to create invites');
    } else {
      throw InviteApiException('Failed to create invite: ${response.statusCode}');
    }
  }

  /// List all invites for the current company
  Future<List<Invite>> listInvites() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final url = '$_baseUrl/v1/app/invites';
    print('[InviteApiService] listInvites URL: $url');
    print('[InviteApiService] kDebugMode: $kDebugMode');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List<dynamic> invitesJson = data['data']['invites'] ?? [];
        return invitesJson.map((i) => _inviteFromApiJson(i)).toList();
      }
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to list invites',
      );
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else {
      throw InviteApiException('Failed to list invites: ${response.statusCode}');
    }
  }

  /// Get invite details by token (for code entry flow)
  Future<Invite?> getInviteByToken(String inviteToken) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final url = '$_baseUrl/v1/app/invites/$inviteToken';
    print('[InviteApiService] getInviteByToken URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('[InviteApiService] Response status: ${response.statusCode}');
    print('[InviteApiService] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return _inviteFromApiJson(data['data']);
      }
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to get invite',
      );
    } else if (response.statusCode == 404) {
      return null; // Invite not found
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body);
      final code = data['error']?['code'];
      final message = data['error']?['message'] ?? 'Invalid invite';

      // Return specific error messages for known codes
      if (code == 'INVALID_INVITE' || code == 'EXPIRED') {
        throw InviteApiException(message);
      }
      throw InviteApiException(message);
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else {
      throw InviteApiException('Failed to get invite: ${response.statusCode}');
    }
  }

  /// List pending invites for the current user
  Future<List<Invite>> listPendingInvites() async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/v1/app/invites/pending'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List<dynamic> invitesJson = data['data']['invites'] ?? [];
        return invitesJson.map((i) => _inviteFromApiJson(i)).toList();
      }
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to list pending invites',
      );
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else {
      throw InviteApiException('Failed to list pending invites: ${response.statusCode}');
    }
  }

  /// Accept an invite
  Future<AcceptInviteResult> acceptInvite(String inviteToken) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/v1/app/invites/$inviteToken/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return AcceptInviteResult(
          companyId: data['data']['companyId'],
          companyName: data['data']['companyName'],
          role: data['data']['role'],
        );
      }
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to accept invite',
      );
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else if (response.statusCode == 400) {
      final data = json.decode(response.body);
      throw InviteApiException(
        data['error']?['message'] ?? 'Invalid invite',
      );
    } else {
      throw InviteApiException('Failed to accept invite: ${response.statusCode}');
    }
  }

  /// Cancel an invite
  Future<void> cancelInvite(String inviteToken) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw InviteApiException('User not authenticated');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/v1/app/invites/$inviteToken'),
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
      throw InviteApiException(
        data['error']?['message'] ?? 'Failed to cancel invite',
      );
    } else if (response.statusCode == 401) {
      throw InviteApiException('Authentication required');
    } else if (response.statusCode == 404) {
      throw InviteApiException('Invite not found');
    } else if (response.statusCode == 403) {
      throw InviteApiException('You do not have permission to cancel this invite');
    } else {
      throw InviteApiException('Failed to cancel invite: ${response.statusCode}');
    }
  }

  /// Convert API JSON to Invite model
  Invite _inviteFromApiJson(Map<String, dynamic> json) {
    final invite = Invite()
      ..token = json['token']
      ..name = json['name']
      ..email = json['email']
      ..phone = json['phone']
      ..status = _parseStatus(json['status'])
      ..role = _parseRole(json['role'])
      ..createdAt = json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null
      ..expiresAt = json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null;

    // Handle company
    if (json['companyId'] != null) {
      invite.company = CompanyAggr()
        ..id = json['companyId']
        ..name = json['companyName'];
    } else if (json['company'] != null) {
      invite.company = CompanyAggr()
        ..id = json['company']['id']
        ..name = json['company']['name'];
    }

    // Handle invitedBy
    if (json['invitedBy'] != null) {
      if (json['invitedBy'] is String) {
        invite.invitedBy = UserAggr()..name = json['invitedBy'];
      } else if (json['invitedBy'] is Map) {
        invite.invitedBy = UserAggr()
          ..id = json['invitedBy']['id']
          ..name = json['invitedBy']['name'];
      }
    }

    return invite;
  }

  InviteStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return InviteStatus.pending;
      case 'accepted':
        return InviteStatus.accepted;
      case 'rejected':
        return InviteStatus.rejected;
      case 'cancelled':
        return InviteStatus.cancelled;
      default:
        return InviteStatus.pending;
    }
  }

  RolesType _parseRole(String? role) {
    switch (role) {
      case 'admin':
        return RolesType.admin;
      case 'supervisor':
        return RolesType.supervisor;
      case 'manager':
        return RolesType.manager;
      case 'consultant':
        return RolesType.consultant;
      case 'technician':
        return RolesType.technician;
      default:
        return RolesType.technician;
    }
  }
}

/// Result of creating an invite
class InviteResult {
  final String token;
  final DateTime expiresAt;

  InviteResult({
    required this.token,
    required this.expiresAt,
  });
}

/// Result of accepting an invite
class AcceptInviteResult {
  final String companyId;
  final String companyName;
  final String role;

  AcceptInviteResult({
    required this.companyId,
    required this.companyName,
    required this.role,
  });
}

/// Exception for invite API operations
class InviteApiException implements Exception {
  final String message;
  InviteApiException(this.message);

  @override
  String toString() => message;
}
