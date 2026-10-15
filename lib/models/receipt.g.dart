// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Receipt _$ReceiptFromJson(Map<String, dynamic> json) => Receipt()
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
  ..customer = json['customer'] == null
      ? null
      : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
  ..amount = (json['amount'] as num?)?.toDouble()
  ..paidAt = json['paidAt'] == null
      ? null
      : DateTime.parse(json['paidAt'] as String)
  ..receiptFile = json['receiptFile'] == null
      ? null
      : ReceiptFile.fromJson(json['receiptFile'] as Map<String, dynamic>)
  ..allocations = (json['allocations'] as List<dynamic>?)
      ?.map((e) => ReceiptAllocation.fromJson(e as Map<String, dynamic>))
      .toList()
  ..status = json['status'] as String?;

Map<String, dynamic> _$ReceiptToJson(Receipt instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'customer': instance.customer?.toJson(),
  'amount': instance.amount,
  'paidAt': instance.paidAt?.toIso8601String(),
  'receiptFile': instance.receiptFile?.toJson(),
  'allocations': instance.allocations?.map((e) => e.toJson()).toList(),
  'status': instance.status,
};

ReceiptAllocation _$ReceiptAllocationFromJson(Map<String, dynamic> json) =>
    ReceiptAllocation(
      orderId: json['orderId'] as String?,
      orderNumber: (json['orderNumber'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble(),
      transactionId: json['transactionId'] as String?,
    );

Map<String, dynamic> _$ReceiptAllocationToJson(ReceiptAllocation instance) =>
    <String, dynamic>{
      'orderId': instance.orderId,
      'orderNumber': instance.orderNumber,
      'amount': instance.amount,
      'transactionId': instance.transactionId,
    };

ReceiptFile _$ReceiptFileFromJson(Map<String, dynamic> json) => ReceiptFile(
  url: json['url'] as String?,
  storagePath: json['storagePath'] as String?,
  fileName: json['fileName'] as String?,
  contentType: json['contentType'] as String?,
);

Map<String, dynamic> _$ReceiptFileToJson(ReceiptFile instance) =>
    <String, dynamic>{
      'url': instance.url,
      'storagePath': instance.storagePath,
      'fileName': instance.fileName,
      'contentType': instance.contentType,
    };
