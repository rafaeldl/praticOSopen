// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_charge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderCharge _$OrderChargeFromJson(Map<String, dynamic> json) => OrderCharge(
  id: json['id'] as String?,
  asaasPaymentId: json['asaasPaymentId'] as String?,
  asaasInstallmentId: json['asaasInstallmentId'] as String?,
  mode: $enumDecodeNullable(
    _$ChargeModeEnumMap,
    json['mode'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  installmentCount: (json['installmentCount'] as num?)?.toInt(),
  value: (json['value'] as num?)?.toDouble(),
  dueDate: json['dueDate'] as String?,
  status: $enumDecodeNullable(
    _$ChargeStatusEnumMap,
    json['status'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  invoiceUrl: json['invoiceUrl'] as String?,
  paidAsaasPaymentIds: (json['paidAsaasPaymentIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  createdBy: json['createdBy'] == null
      ? null
      : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  paidAt: json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String),
);

Map<String, dynamic> _$OrderChargeToJson(OrderCharge instance) =>
    <String, dynamic>{
      'id': instance.id,
      'asaasPaymentId': instance.asaasPaymentId,
      'asaasInstallmentId': instance.asaasInstallmentId,
      'mode': _$ChargeModeEnumMap[instance.mode],
      'installmentCount': instance.installmentCount,
      'value': instance.value,
      'dueDate': instance.dueDate,
      'status': _$ChargeStatusEnumMap[instance.status],
      'invoiceUrl': instance.invoiceUrl,
      'paidAsaasPaymentIds': instance.paidAsaasPaymentIds,
      'createdBy': instance.createdBy?.toJson(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'paidAt': instance.paidAt?.toIso8601String(),
    };

const _$ChargeModeEnumMap = {
  ChargeMode.single: 'single',
  ChargeMode.cardInstallments: 'cardInstallments',
};

const _$ChargeStatusEnumMap = {
  ChargeStatus.pending: 'pending',
  ChargeStatus.paid: 'paid',
  ChargeStatus.overdue: 'overdue',
  ChargeStatus.canceled: 'canceled',
  ChargeStatus.refunded: 'refunded',
};
