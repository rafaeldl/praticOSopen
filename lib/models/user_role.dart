import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_role.g.dart';

/// User roles in PraticOS with strict permission control (RBAC).
///
/// Role hierarchy:
/// - [admin]: Full system access
/// - [supervisor]: Operational management
/// - [manager]: Financial management
/// - [consultant]: Commercial profile
/// - [technician]: Service execution
///
/// Note: Fields using this enum should have @JsonKey(unknownEnumValue: RolesType.technician)
/// to prevent errors when legacy or invalid role data exists in Firestore.
enum RolesType {
  /// 👨‍💼 Admin - Full system access
  /// Can: manage users, roles, permissions, access all areas,
  /// configure templates, rules and global parameters
  admin,

  /// 🧑‍🔧 Supervisor - Operational management of technicians
  /// Can: view all orders, assign/reassign orders, operational reports
  /// Cannot: view financial values, billing, accounting data
  supervisor,

  /// 💰 Manager (Financial) - Financial management
  /// Can: view values, prices, billing, financial reports
  /// Cannot: alter technical execution, manage operational templates
  manager,

  /// 🧑‍💼 Consultant (Sales) - Commercial profile
  /// Can: create and track their own orders, view status and history
  /// Cannot: view others' orders, general reports, global financial data
  consultant,

  /// 👷 Technician - Service execution
  /// Can: execute services, fill forms, attach photos, update status
  /// Cannot: view values/prices, access reports, commercial data
  technician,
}

@JsonSerializable(explicitToJson: true)
class UserRole extends BaseAuditCompany {
  UserAggr? user;
  @JsonKey(unknownEnumValue: RolesType.technician)
  RolesType? role;

  UserRole();
  factory UserRole.fromJson(Map<String, dynamic> json) =>
      _$UserRoleFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$UserRoleToJson(this);
  UserRoleAggr toUserRoleAggr() => _$UserRoleAggrFromJson(toJson());
  CompanyRoleAggr toCompanyRoleAggr() =>
      _$CompanyRoleAggrFromJson(toJson());
}

@JsonSerializable(explicitToJson: true)
class UserRoleAggr {
  UserAggr? user;
  @JsonKey(unknownEnumValue: RolesType.technician)
  RolesType? role;

  UserRoleAggr();
  factory UserRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$UserRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$UserRoleAggrToJson(this);
}

@JsonSerializable(explicitToJson: true)
class CompanyRoleAggr {
  CompanyAggr? company;
  @JsonKey(unknownEnumValue: RolesType.technician)
  RolesType? role;

  CompanyRoleAggr();
  factory CompanyRoleAggr.fromJson(Map<String, dynamic> json) =>
      _$CompanyRoleAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyRoleAggrToJson(this);
}
