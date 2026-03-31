// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialPayment _$FinancialPaymentFromJson(Map<String, dynamic> json) =>
    FinancialPayment()
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
      ..type = $enumDecodeNullable(_$FinancialPaymentTypeEnumMap, json['type'])
      ..status = $enumDecodeNullable(
        _$FinancialPaymentStatusEnumMap,
        json['status'],
      )
      ..amount = (json['amount'] as num?)?.toDouble()
      ..discount = (json['discount'] as num?)?.toDouble()
      ..paymentDate = json['paymentDate'] == null
          ? null
          : DateTime.parse(json['paymentDate'] as String)
      ..paymentMethod = $enumDecodeNullable(
        _$PaymentMethodEnumMap,
        json['paymentMethod'],
      )
      ..description = json['description'] as String?
      ..notes = json['notes'] as String?
      ..attachments = (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..entryId = json['entryId'] as String?
      ..accountId = json['accountId'] as String?
      ..account = json['account'] == null
          ? null
          : FinancialAccountAggr.fromJson(
              json['account'] as Map<String, dynamic>,
            )
      ..targetAccountId = json['targetAccountId'] as String?
      ..targetAccount = json['targetAccount'] == null
          ? null
          : FinancialAccountAggr.fromJson(
              json['targetAccount'] as Map<String, dynamic>,
            )
      ..transferGroupId = json['transferGroupId'] as String?
      ..transferDirection = json['transferDirection'] as String?
      ..reversedPaymentId = json['reversedPaymentId'] as String?
      ..reversedByPaymentId = json['reversedByPaymentId'] as String?
      ..reversedAt = json['reversedAt'] == null
          ? null
          : DateTime.parse(json['reversedAt'] as String)
      ..reversalReason = json['reversalReason'] as String?
      ..orderId = json['orderId'] as String?
      ..orderNumber = (json['orderNumber'] as num?)?.toInt()
      ..customer = json['customer'] == null
          ? null
          : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
      ..supplier = json['supplier'] as String?
      ..category = json['category'] as String?
      ..syncSource = json['syncSource'] as String?
      ..deletedAt = json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String)
      ..deletedBy = json['deletedBy'] == null
          ? null
          : UserAggr.fromJson(json['deletedBy'] as Map<String, dynamic>);

Map<String, dynamic> _$FinancialPaymentToJson(FinancialPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'type': _$FinancialPaymentTypeEnumMap[instance.type],
      'status': _$FinancialPaymentStatusEnumMap[instance.status],
      'amount': instance.amount,
      'discount': instance.discount,
      'paymentDate': instance.paymentDate?.toIso8601String(),
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod],
      'description': instance.description,
      'notes': instance.notes,
      'attachments': instance.attachments,
      'entryId': instance.entryId,
      'accountId': instance.accountId,
      'account': instance.account?.toJson(),
      'targetAccountId': instance.targetAccountId,
      'targetAccount': instance.targetAccount?.toJson(),
      'transferGroupId': instance.transferGroupId,
      'transferDirection': instance.transferDirection,
      'reversedPaymentId': instance.reversedPaymentId,
      'reversedByPaymentId': instance.reversedByPaymentId,
      'reversedAt': instance.reversedAt?.toIso8601String(),
      'reversalReason': instance.reversalReason,
      'orderId': instance.orderId,
      'orderNumber': instance.orderNumber,
      'customer': instance.customer?.toJson(),
      'supplier': instance.supplier,
      'category': instance.category,
      'syncSource': instance.syncSource,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'deletedBy': instance.deletedBy?.toJson(),
    };

const _$FinancialPaymentTypeEnumMap = {
  FinancialPaymentType.income: 'income',
  FinancialPaymentType.expense: 'expense',
  FinancialPaymentType.transfer: 'transfer',
};

const _$FinancialPaymentStatusEnumMap = {
  FinancialPaymentStatus.completed: 'completed',
  FinancialPaymentStatus.reversed: 'reversed',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.pix: 'pix',
  PaymentMethod.cash: 'cash',
  PaymentMethod.creditCard: 'creditCard',
  PaymentMethod.debitCard: 'debitCard',
  PaymentMethod.transfer: 'transfer',
  PaymentMethod.check: 'check',
  PaymentMethod.other: 'other',
};
