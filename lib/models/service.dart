import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable(explicitToJson: true)
class Service extends BaseAuditCompany {
  String? name;
  double? value;

  Service();
  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
  ServiceAggr toAggr() => _$ServiceAggrFromJson(this.toJson());
}

@JsonSerializable()
class ServiceAggr extends BaseAuditCompanyAggr {
  String? name;
  double? value;

  ServiceAggr();
  factory ServiceAggr.fromJson(Map<String, dynamic> json) =>
      _$ServiceAggrFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceAggrToJson(this);
}
