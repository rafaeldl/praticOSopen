import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

@JsonSerializable(explicitToJson: true)
class Customer extends BaseAuditCompany {
  String? name;
  String? phone;
  String? email;
  String? address;

  Customer();
  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
  CustomerAggr toAggr() => _$CustomerAggrFromJson(toJson());
}

@JsonSerializable()
class CustomerAggr extends BaseAuditCompanyAggr {
  String? name;
  String? phone;
  String? email;

  CustomerAggr();
  factory CustomerAggr.fromJson(Map<String, dynamic> json) =>
      _$CustomerAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CustomerAggrToJson(this);
}
