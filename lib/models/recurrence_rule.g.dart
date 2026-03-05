// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurrence_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecurrenceRule _$RecurrenceRuleFromJson(Map<String, dynamic> json) =>
    RecurrenceRule()
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
      ..frequency = json['frequency'] as String?
      ..interval = (json['interval'] as num?)?.toInt()
      ..startDate = json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String)
      ..endDate = json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String)
      ..nextDueDate = json['nextDueDate'] == null
          ? null
          : DateTime.parse(json['nextDueDate'] as String)
      ..lastGeneratedDate = json['lastGeneratedDate'] == null
          ? null
          : DateTime.parse(json['lastGeneratedDate'] as String)
      ..generatedCount = (json['generatedCount'] as num?)?.toInt()
      ..active = json['active'] as bool?
      ..autoGenerate = json['autoGenerate'] as bool?
      ..templateDescription = json['templateDescription'] as String?
      ..customer = json['customer'] == null
          ? null
          : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
      ..devices = (json['devices'] as List<dynamic>?)
          ?.map((e) => DeviceAggr.fromJson(e as Map<String, dynamic>))
          .toList()
      ..deviceIds = (json['deviceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList()
      ..services = (json['services'] as List<dynamic>?)
          ?.map((e) => OrderService.fromJson(e as Map<String, dynamic>))
          .toList()
      ..products = (json['products'] as List<dynamic>?)
          ?.map((e) => OrderProduct.fromJson(e as Map<String, dynamic>))
          .toList()
      ..assignedTo = json['assignedTo'] == null
          ? null
          : UserAggr.fromJson(json['assignedTo'] as Map<String, dynamic>)
      ..reminderDaysBefore = (json['reminderDaysBefore'] as num?)?.toInt();

Map<String, dynamic> _$RecurrenceRuleToJson(RecurrenceRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt?.toIso8601String(),
      'createdBy': instance.createdBy?.toJson(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'updatedBy': instance.updatedBy?.toJson(),
      'company': instance.company?.toJson(),
      'name': instance.name,
      'frequency': instance.frequency,
      'interval': instance.interval,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'nextDueDate': instance.nextDueDate?.toIso8601String(),
      'lastGeneratedDate': instance.lastGeneratedDate?.toIso8601String(),
      'generatedCount': instance.generatedCount,
      'active': instance.active,
      'autoGenerate': instance.autoGenerate,
      'templateDescription': instance.templateDescription,
      'customer': instance.customer?.toJson(),
      'devices': instance.devices?.map((e) => e.toJson()).toList(),
      'deviceIds': instance.deviceIds,
      'services': instance.services?.map((e) => e.toJson()).toList(),
      'products': instance.products?.map((e) => e.toJson()).toList(),
      'assignedTo': instance.assignedTo?.toJson(),
      'reminderDaysBefore': instance.reminderDaysBefore,
    };
