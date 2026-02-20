import 'package:praticos/models/base.dart';
import 'package:praticos/models/fcm_token.dart';
import 'package:praticos/models/user_role.dart';
import 'package:json_annotation/json_annotation.dart';

import 'base_audit.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User extends BaseAudit {
  String? name;
  String? email;
  String? photo;
  List<CompanyRoleAggr>? companies;

  /// FCM tokens for push notifications (multi-device support)
  List<FcmToken>? fcmTokens;

  /// BCP47 language code (e.g., "pt-BR", "fr-FR", "de-DE")
  String? preferredLanguage;

  User();
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$UserToJson(this);
  UserAggr toAggr() => _$UserAggrFromJson(toJson());
}

@JsonSerializable(explicitToJson: true)
class UserAggr extends Base {
  String? name;
  String? email;
  String? photo;
  String? preferredLanguage;

  UserAggr();
  factory UserAggr.fromJson(Map<String, dynamic> json) =>
      _$UserAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$UserAggrToJson(this);
}
