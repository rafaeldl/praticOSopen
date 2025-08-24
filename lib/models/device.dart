import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable(explicitToJson: true)
class Device extends BaseAuditCompany {
  String? serial;
  String? name;
  String? manufacturer;
  String? category;
  String? description;

  Device();
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
  DeviceAggr toAggr() => _$DeviceAggrFromJson(this.toJson());
}

@JsonSerializable()
class DeviceAggr extends BaseAuditCompanyAggr {
  String? serial;
  String? name;

  DeviceAggr();
  factory DeviceAggr.fromJson(Map<String, dynamic> json) =>
      _$DeviceAggrFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceAggrToJson(this);
}
