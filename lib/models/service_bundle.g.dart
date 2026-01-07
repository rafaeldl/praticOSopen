// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_bundle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceFormBundle _$ServiceFormBundleFromJson(Map<String, dynamic> json) =>
    ServiceFormBundle(
      formId: json['formId'] as String,
      formTitle: json['formTitle'] as String,
      isRequired: json['isRequired'] as bool? ?? false,
    );

Map<String, dynamic> _$ServiceFormBundleToJson(ServiceFormBundle instance) =>
    <String, dynamic>{
      'formId': instance.formId,
      'formTitle': instance.formTitle,
      'isRequired': instance.isRequired,
    };

ServiceProductBundle _$ServiceProductBundleFromJson(
        Map<String, dynamic> json) =>
    ServiceProductBundle(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      value: (json['value'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ServiceProductBundleToJson(
        ServiceProductBundle instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'value': instance.value,
    };
