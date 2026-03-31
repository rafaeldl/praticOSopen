// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialAccount _$FinancialAccountFromJson(Map<String, dynamic> json) =>
    FinancialAccount()
      ..id = json['id'] as String?
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String)
      ..createdBy = json['createdBy'] == null
          ? null
          : UserAggr.fromJson(json['createdBy'] as Map<String, dynamic>)
      ..updatedAt = json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String)
      ..updatedBy = json['updatedBy'] == null
          ? null
          : UserAggr.fromJson(json['updatedBy'] as Map<String, dynamic>)
      ..company = json['company'] == null
          ? null
          : CompanyAggr.fromJson(json['company'] as Map<String, dynamic>)
      ..name = json['name'] as String?
      ..type = $enumDecodeNullable(_$FinancialAccountTypeEnumMap, json['type'])
      ..initialBalance = (json['initialBalance'] as num?)?.toDouble()
      ..currentBalance = (json['currentBalance'] as num?)?.toDouble()
      ..currency = json['currency'] as String?
      ..color = json['color'] as String?
      ..icon = json['icon'] as String?
      ..active = json['active'] as bool?
      ..isDefault = json['isDefault'] as bool?
      ..lastReconciledAt = json['lastReconciledAt'] == null
          ? null
          : DateTime.parse(json['lastReconciledAt'] as String);

Map<String, dynamic> _$FinancialAccountToJson(FinancialAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'name': instance.name,
      'type': _$FinancialAccountTypeEnumMap[instance.type],
      'initialBalance': instance.initialBalance,
      'currentBalance': instance.currentBalance,
      'currency': instance.currency,
      'color': instance.color,
      'icon': instance.icon,
      'active': instance.active,
      'isDefault': instance.isDefault,
      'lastReconciledAt': instance.lastReconciledAt?.toIso8601String(),
    };

const _$FinancialAccountTypeEnumMap = {
  FinancialAccountType.bank: 'bank',
  FinancialAccountType.cash: 'cash',
  FinancialAccountType.creditCard: 'creditCard',
  FinancialAccountType.digitalWallet: 'digitalWallet',
};

FinancialAccountAggr _$FinancialAccountAggrFromJson(
  Map<String, dynamic> json,
) => FinancialAccountAggr()
  ..id = json['id'] as String?
  ..name = json['name'] as String?
  ..type = $enumDecodeNullable(_$FinancialAccountTypeEnumMap, json['type']);

Map<String, dynamic> _$FinancialAccountAggrToJson(
  FinancialAccountAggr instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$FinancialAccountTypeEnumMap[instance.type],
};
