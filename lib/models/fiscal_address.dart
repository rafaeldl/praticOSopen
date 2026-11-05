import 'package:json_annotation/json_annotation.dart';

part 'fiscal_address.g.dart';

/// Structured address of a nota (customer and recipient), as the national
/// system asks for it. See docs/superpowers/specs/2026-11-05-nfse-direta-design.md §4.5.
@JsonSerializable()
class FiscalAddress {
  /// CEP, digits only.
  String? postalCode;
  String? street;
  String? number;
  String? complement;
  String? district;

  /// IBGE code of the city (7 digits).
  String? cityCode;
  String? cityName;

  /// UF, two letters.
  String? state;

  FiscalAddress({
    this.postalCode,
    this.street,
    this.number,
    this.complement,
    this.district,
    this.cityCode,
    this.cityName,
    this.state,
  });

  factory FiscalAddress.fromJson(Map<String, dynamic> json) =>
      _$FiscalAddressFromJson(json);

  Map<String, dynamic> toJson() => _$FiscalAddressToJson(this);

  /// Has what the nota needs to send an address: CEP, street, number,
  /// district and city. The complement is optional.
  bool get isComplete => [
    postalCode,
    street,
    number,
    district,
    cityCode,
    state,
  ].every((value) => value != null && value.trim().isNotEmpty);
}
