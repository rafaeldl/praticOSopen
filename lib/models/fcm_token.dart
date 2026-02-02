import 'package:json_annotation/json_annotation.dart';

part 'fcm_token.g.dart';

/// FCM token for push notifications with multi-device support
@JsonSerializable()
class FcmToken {
  /// The FCM registration token
  String? token;

  /// Unique device identifier
  String? deviceId;

  /// Platform: 'ios' or 'android'
  String? platform;

  /// When this token was first registered
  DateTime? createdAt;

  /// When this token was last used/refreshed
  DateTime? lastUsedAt;

  FcmToken({
    this.token,
    this.deviceId,
    this.platform,
    this.createdAt,
    this.lastUsedAt,
  });

  factory FcmToken.fromJson(Map<String, dynamic> json) =>
      _$FcmTokenFromJson(json);

  Map<String, dynamic> toJson() => _$FcmTokenToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FcmToken && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}
