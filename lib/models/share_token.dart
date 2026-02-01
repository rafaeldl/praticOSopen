import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'share_token.g.dart';

/// Permission types for share tokens
enum ShareTokenPermission {
  view,
  approve,
  comment,
}

/// Share token for customer magic link access
@JsonSerializable(explicitToJson: true)
class ShareToken {
  String? token;
  String? orderId;
  String? companyId;
  List<String>? permissions;
  CustomerAggr? customer;
  DateTime? createdAt;
  DateTime? expiresAt;
  UserAggr? createdBy;
  int? viewCount;
  DateTime? lastViewedAt;
  DateTime? approvedAt;
  DateTime? rejectedAt;
  String? rejectionReason;

  /// Check if token is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if token has a specific permission
  bool hasPermission(ShareTokenPermission permission) {
    if (permissions == null) return false;
    return permissions!.contains(permission.name);
  }

  /// Check if quote was approved via this token
  bool get wasApproved => approvedAt != null;

  /// Check if quote was rejected via this token
  bool get wasRejected => rejectedAt != null;

  ShareToken();

  factory ShareToken.fromJson(Map<String, dynamic> json) =>
      _$ShareTokenFromJson(json);
  Map<String, dynamic> toJson() => _$ShareTokenToJson(this);
}

/// Response from generating a share link
@JsonSerializable(explicitToJson: true)
class ShareLinkResult {
  String? token;
  String? url;
  List<String>? permissions;
  DateTime? expiresAt;
  CustomerAggr? customer;

  ShareLinkResult();

  factory ShareLinkResult.fromJson(Map<String, dynamic> json) =>
      _$ShareLinkResultFromJson(json);
  Map<String, dynamic> toJson() => _$ShareLinkResultToJson(this);
}
