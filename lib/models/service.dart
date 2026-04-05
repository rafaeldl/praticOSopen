import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable(explicitToJson: true)
class Service extends BaseAuditCompany {
  String? name;
  double? value;
  String? photo;
  List<String>? keywords;
  Map<String, dynamic>? customData;

  Service();
  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
  ServiceAggr toAggr() => _$ServiceAggrFromJson(toJson());
}

@JsonSerializable()
class ServiceAggr extends BaseAuditCompanyAggr {
  String? name;
  double? value;
  String? photo;

  ServiceAggr();
  factory ServiceAggr.fromJson(Map<String, dynamic> json) =>
      _$ServiceAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ServiceAggrToJson(this);
}
