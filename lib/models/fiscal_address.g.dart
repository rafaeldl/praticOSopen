// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fiscal_address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FiscalAddress _$FiscalAddressFromJson(Map<String, dynamic> json) =>
    FiscalAddress(
      postalCode: json['postalCode'] as String?,
      street: json['street'] as String?,
      number: json['number'] as String?,
      complement: json['complement'] as String?,
      district: json['district'] as String?,
      cityCode: json['cityCode'] as String?,
      cityName: json['cityName'] as String?,
      state: json['state'] as String?,
    );

Map<String, dynamic> _$FiscalAddressToJson(FiscalAddress instance) =>
    <String, dynamic>{
      'postalCode': instance.postalCode,
      'street': instance.street,
      'number': instance.number,
      'complement': instance.complement,
      'district': instance.district,
      'cityCode': instance.cityCode,
      'cityName': instance.cityName,
      'state': instance.state,
    };
