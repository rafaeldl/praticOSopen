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
  UserAggr? owner;
  List<UserRoleAggr>? users;

  Company();
  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyToJson(this);
  CompanyAggr toAggr() => _$CompanyAggrFromJson(this.toJson());
}

@JsonSerializable(explicitToJson: true)
class CompanyAggr extends Base {
  String? name;

  CompanyAggr();
  factory CompanyAggr.fromJson(Map<String, dynamic> json) =>
      _$CompanyAggrFromJson(json);
  Map<String, dynamic> toJson() => _$CompanyAggrToJson(this);
}
