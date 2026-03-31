// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'financial_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinancialRecurrence _$FinancialRecurrenceFromJson(Map<String, dynamic> json) =>
    FinancialRecurrence()
      ..frequency = json['frequency'] as String?
      ..interval = (json['interval'] as num?)?.toInt()
      ..endDate = json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String)
      ..nextDueDate = json['nextDueDate'] == null
          ? null
          : DateTime.parse(json['nextDueDate'] as String)
      ..lastGeneratedDate = json['lastGeneratedDate'] == null
          ? null
          : DateTime.parse(json['lastGeneratedDate'] as String)
      ..active = json['active'] as bool?;

Map<String, dynamic> _$FinancialRecurrenceToJson(
  FinancialRecurrence instance,
) => <String, dynamic>{
  'frequency': instance.frequency,
  'interval': instance.interval,
  'endDate': instance.endDate?.toIso8601String(),
  'nextDueDate': instance.nextDueDate?.toIso8601String(),
  'lastGeneratedDate': instance.lastGeneratedDate?.toIso8601String(),
  'active': instance.active,
};

FinancialEntry _$FinancialEntryFromJson(
  Map<String, dynamic> json,
) => FinancialEntry()
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
  ..direction = $enumDecodeNullable(
    _$FinancialEntryDirectionEnumMap,
    json['direction'],
  )
  ..status = $enumDecodeNullable(_$FinancialEntryStatusEnumMap, json['status'])
  ..description = json['description'] as String?
  ..amount = (json['amount'] as num?)?.toDouble()
  ..paidAmount = (json['paidAmount'] as num?)?.toDouble()
  ..discountAmount = (json['discountAmount'] as num?)?.toDouble()
  ..dueDate = json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String)
  ..competenceDate = json['competenceDate'] == null
      ? null
      : DateTime.parse(json['competenceDate'] as String)
  ..paidDate = json['paidDate'] == null
      ? null
      : DateTime.parse(json['paidDate'] as String)
  ..category = json['category'] as String?
  ..tags = (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList()
  ..accountId = json['accountId'] as String?
  ..account = json['account'] == null
      ? null
      : FinancialAccountAggr.fromJson(json['account'] as Map<String, dynamic>)
  ..customer = json['customer'] == null
      ? null
      : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
  ..supplier = json['supplier'] as String?
  ..orderId = json['orderId'] as String?
  ..orderNumber = (json['orderNumber'] as num?)?.toInt()
  ..notes = json['notes'] as String?
  ..attachments = (json['attachments'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList()
  ..recurrence = json['recurrence'] == null
      ? null
      : FinancialRecurrence.fromJson(json['recurrence'] as Map<String, dynamic>)
  ..installmentGroupId = json['installmentGroupId'] as String?
  ..installmentNumber = (json['installmentNumber'] as num?)?.toInt()
  ..installmentTotal = (json['installmentTotal'] as num?)?.toInt()
  ..syncSource = json['syncSource'] as String?
  ..deletedAt = json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String)
  ..deletedBy = json['deletedBy'] == null
      ? null
      : UserAggr.fromJson(json['deletedBy'] as Map<String, dynamic>);

Map<String, dynamic> _$FinancialEntryToJson(FinancialEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'direction': _$FinancialEntryDirectionEnumMap[instance.direction],
      'status': _$FinancialEntryStatusEnumMap[instance.status],
      'description': instance.description,
      'amount': instance.amount,
      'paidAmount': instance.paidAmount,
      'discountAmount': instance.discountAmount,
      'dueDate': instance.dueDate?.toIso8601String(),
      'competenceDate': instance.competenceDate?.toIso8601String(),
      'paidDate': instance.paidDate?.toIso8601String(),
      'category': instance.category,
      'tags': instance.tags,
      'accountId': instance.accountId,
      'account': instance.account?.toJson(),
      'customer': instance.customer?.toJson(),
      'supplier': instance.supplier,
      'orderId': instance.orderId,
      'orderNumber': instance.orderNumber,
      'notes': instance.notes,
      'attachments': instance.attachments,
      'recurrence': instance.recurrence?.toJson(),
      'installmentGroupId': instance.installmentGroupId,
      'installmentNumber': instance.installmentNumber,
      'installmentTotal': instance.installmentTotal,
      'syncSource': instance.syncSource,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'deletedBy': instance.deletedBy?.toJson(),
    };

const _$FinancialEntryDirectionEnumMap = {
  FinancialEntryDirection.payable: 'payable',
  FinancialEntryDirection.receivable: 'receivable',
};

const _$FinancialEntryStatusEnumMap = {
  FinancialEntryStatus.pending: 'pending',
  FinancialEntryStatus.paid: 'paid',
  FinancialEntryStatus.cancelled: 'cancelled',
};

FinancialEntryAggr _$FinancialEntryAggrFromJson(Map<String, dynamic> json) =>
    FinancialEntryAggr()
      ..id = json['id'] as String?
      ..direction = $enumDecodeNullable(
        _$FinancialEntryDirectionEnumMap,
        json['direction'],
      )
      ..description = json['description'] as String?
      ..amount = (json['amount'] as num?)?.toDouble()
      ..dueDate = json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String)
      ..status = $enumDecodeNullable(
        _$FinancialEntryStatusEnumMap,
        json['status'],
      );

Map<String, dynamic> _$FinancialEntryAggrToJson(FinancialEntryAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'direction': _$FinancialEntryDirectionEnumMap[instance.direction],
      'description': instance.description,
      'amount': instance.amount,
      'dueDate': instance.dueDate?.toIso8601String(),
      'status': _$FinancialEntryStatusEnumMap[instance.status],
    };
