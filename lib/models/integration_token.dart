import 'package:json_annotation/json_annotation.dart';

part 'integration_token.g.dart';

@JsonSerializable()
class IntegrationToken {
  String? id;
  String? name;
  DateTime? createdAt;
  DateTime? lastUsedAt;
  DateTime? expiresAt;

  IntegrationToken({
    this.id,
    this.name,
    this.createdAt,
    this.lastUsedAt,
    this.expiresAt,
  });

  factory IntegrationToken.fromJson(Map<String, dynamic> json) =>
      _$IntegrationTokenFromJson(json);

  Map<String, dynamic> toJson() => _$IntegrationTokenToJson(this);
}

@JsonSerializable()
class CreatedIntegrationToken {
  String? id;
  String? url;
  DateTime? expiresAt;

  CreatedIntegrationToken({this.id, this.url, this.expiresAt});

  factory CreatedIntegrationToken.fromJson(Map<String, dynamic> json) =>
      _$CreatedIntegrationTokenFromJson(json);

  Map<String, dynamic> toJson() => _$CreatedIntegrationTokenToJson(this);
}
