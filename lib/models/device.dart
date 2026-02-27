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
  String? photo;
  List<String>? keywords;
  Map<String, dynamic>? customData;

  Device();
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
  DeviceAggr toAggr() => _$DeviceAggrFromJson(toJson());
}

@JsonSerializable()
class DeviceAggr extends BaseAuditCompanyAggr {
  String? serial;
  String? name;
  String? photo;

  DeviceAggr();
  factory DeviceAggr.fromJson(Map<String, dynamic> json) =>
      _$DeviceAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$DeviceAggrToJson(this);
}
