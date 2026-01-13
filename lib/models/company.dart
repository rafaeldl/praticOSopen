import 'package:praticos/models/base.dart';
import 'package:praticos/models/base_audit.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'company.g.dart';

@JsonSerializable(explicitToJson: true)
class Company extends BaseAudit {
  String? name;
  String? email;
  String? address;
  String? logo;
  String? phone;
  String? site;
  String? segment; // ID do segmento de negócio (hvac, automotive, etc.)
  String? country; // Código do país (ISO 3166-1 alpha-2): BR, US, PT, ES, etc.
  List<String>? subspecialties; // IDs das subcategorias: ['mechanical', 'carwash']
  UserAggr? owner;
  List<UserRoleAggr>? users;

  Company();
  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CompanyToJson(this);
  CompanyAggr toAggr() => _$CompanyAggrFromJson(toJson());
}

@JsonSerializable(explicitToJson: true)
class CompanyAggr extends Base {
  String? name;
  String? country; // Código do país (ISO 3166-1 alpha-2): BR, US, PT, ES, etc.

  CompanyAggr();
  factory CompanyAggr.fromJson(Map<String, dynamic> json) =>
      _$CompanyAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CompanyAggrToJson(this);
}
