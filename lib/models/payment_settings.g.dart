// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentSettings _$PaymentSettingsFromJson(Map<String, dynamic> json) =>
    PaymentSettings(
      asaasEnabled: json['asaasEnabled'] as bool? ?? false,
      asaasConnected: json['asaasConnected'] as bool? ?? false,
      asaasAccountName: json['asaasAccountName'] as String?,
      asaasEnvironment: json['asaasEnvironment'] as String?,
    );

Map<String, dynamic> _$PaymentSettingsToJson(PaymentSettings instance) =>
    <String, dynamic>{
      'asaasEnabled': instance.asaasEnabled,
      'asaasConnected': instance.asaasConnected,
      'asaasAccountName': instance.asaasAccountName,
      'asaasEnvironment': instance.asaasEnvironment,
    };
