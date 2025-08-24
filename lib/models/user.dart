import 'package:praticos/models/base.dart';
import 'package:praticos/models/user_role.dart';
import 'package:json_annotation/json_annotation.dart';

import 'base_audit.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User extends BaseAudit {
  String? name;
  String? email;
  List<CompanyRoleAggr>? companies;

  User();
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  UserAggr toAggr() => _$UserAggrFromJson(this.toJson());
}

@JsonSerializable(explicitToJson: true)
class UserAggr extends Base {
  String? name;

  UserAggr();
  factory UserAggr.fromJson(Map<String, dynamic> json) =>
      _$UserAggrFromJson(json);
  Map<String, dynamic> toJson() => _$UserAggrToJson(this);
}
