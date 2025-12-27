import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable(explicitToJson: true)
class Product extends BaseAuditCompany {
  String? name;
  double? value;
  String? photo;

  Product();
  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
  ProductAggr toAggr() => _$ProductAggrFromJson(this.toJson());
}

@JsonSerializable()
class ProductAggr extends BaseAuditCompanyAggr {
  String? name;
  double? value;
  String? photo;

  ProductAggr();
  factory ProductAggr.fromJson(Map<String, dynamic> json) =>
      _$ProductAggrFromJson(json);
  Map<String, dynamic> toJson() => _$ProductAggrToJson(this);
}
