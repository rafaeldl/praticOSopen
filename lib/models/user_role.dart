import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_role.g.dart';

enum RolesType { admin, manager, user }

@JsonSerializable(explicitToJson: true)
class UserRole extends BaseAuditCompany {
  UserAggr? user;
  RolesType? role;

  UserRole();
  factory UserRole.fromJson(Map<String, dynamic> json) =>
      _$UserRoleFromJson(json);
  Map<String, dynamic> toJson() => _$UserRoleToJson(this);
  UserRoleAggr toUserRoleAggr() => _$UserRoleAggrFromJson(this.toJson());
  CompanyRoleAggr toCompanyRoleAggr() =>
      _$CompanyRoleAggrFromJson(this.toJson());
}

@JsonSerializable(explicitToJson: true)
class UserRoleAggr {
  UserAggr? user;
  RolesType? role;

  UserRoleAggr();
  factory UserRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$UserRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$UserRoleAggrToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CompanyRoleAggr {
  CompanyAggr? company;
  RolesType? role;

  CompanyRoleAggr();
  factory CompanyRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$CompanyRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyRoleAggrToJson(this);
}
