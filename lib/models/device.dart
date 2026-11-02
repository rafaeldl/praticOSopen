import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
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
  String? status; // 'active', 'maintenance', 'inactive', 'decommissioned'
  List<String>? keywords;
  Map<String, dynamic>? customData;

  /// Day of the next maintenance, `YYYY-MM-DD`: a day, not a moment, so the
  /// app and the daily job read the same one in any time zone. A reminder
  /// only: it creates no order and stays out of the open orders and Financeiro.
  ///
  /// Read-only here, like `Order.completedAt`: only
  /// `TenantDeviceRepository.setNextMaintenance` writes it, so saving a Device
  /// rebuilt from an aggregate (which has no date) never erases it.
  @JsonKey(includeToJson: false)
  String? nextMaintenanceDate;

  /// Who the maintenance is for. A device has no customer of its own: this is
  /// the order's customer when the date was set. Only id and name.
  @JsonKey(includeToJson: false)
  CustomerAggr? nextMaintenanceCustomer;

  Device();
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
  DeviceAggr toAggr() => _$DeviceAggrFromJson(toJson());

  /// [nextMaintenanceDate] at local midnight, or null.
  DateTime? get nextMaintenance {
    final day = nextMaintenanceDate;
    return day == null ? null : DateTime.tryParse(day);
  }
}

@JsonSerializable()
class DeviceAggr extends BaseAuditCompanyAggr {
  String? serial;
  String? name;
  String? photo;
  String? category;
  String? manufacturer;
  String? status;

  DeviceAggr();
  factory DeviceAggr.fromJson(Map<String, dynamic> json) =>
      _$DeviceAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$DeviceAggrToJson(this);
}
