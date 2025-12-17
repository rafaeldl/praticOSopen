// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order()
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
  ..device = json['device'] == null
      ? null
      : DeviceAggr.fromJson(json['device'] as Map<String, dynamic>)
  ..services = (json['services'] as List<dynamic>?)
      ?.map((e) => OrderService.fromJson(e as Map<String, dynamic>))
      .toList()
  ..products = (json['products'] as List<dynamic>?)
      ?.map((e) => OrderProduct.fromJson(e as Map<String, dynamic>))
      .toList()
  ..photos = (json['photos'] as List<dynamic>?)
      ?.map((e) => OrderPhoto.fromJson(e as Map<String, dynamic>))
      .toList()
  ..total = (json['total'] as num?)?.toDouble()
  ..discount = (json['discount'] as num?)?.toDouble()
  ..dueDate = json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String)
  ..done = json['done'] as bool?
  ..paid = json['paid'] as bool?
  ..payment = json['payment'] as String?
  ..status = json['status'] as String?
  ..number = (json['number'] as num?)?.toInt();

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy?.toJson(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'updatedBy': instance.updatedBy?.toJson(),
  'company': instance.company?.toJson(),
  'customer': instance.customer?.toJson(),
  'device': instance.device?.toJson(),
  'services': instance.services?.map((e) => e.toJson()).toList(),
  'products': instance.products?.map((e) => e.toJson()).toList(),
  'photos': instance.photos?.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'discount': instance.discount,
  'dueDate': instance.dueDate?.toIso8601String(),
  'done': instance.done,
  'paid': instance.paid,
  'payment': instance.payment,
  'status': instance.status,
  'number': instance.number,
};

OrderAggr _$OrderAggrFromJson(Map<String, dynamic> json) => OrderAggr()
  ..id = json['id'] as String?
  ..customer = json['customer'] == null
      ? null
      : CustomerAggr.fromJson(json['customer'] as Map<String, dynamic>)
  ..device = json['device'] == null
      ? null
      : DeviceAggr.fromJson(json['device'] as Map<String, dynamic>);

Map<String, dynamic> _$OrderAggrToJson(OrderAggr instance) => <String, dynamic>{
  'id': instance.id,
  'customer': instance.customer?.toJson(),
  'device': instance.device?.toJson(),
};

OrderProduct _$OrderProductFromJson(Map<String, dynamic> json) => OrderProduct()
  ..product = json['product'] == null
      ? null
      : ProductAggr.fromJson(json['product'] as Map<String, dynamic>)
  ..description = json['description'] as String?
  ..value = (json['value'] as num?)?.toDouble()
  ..quantity = (json['quantity'] as num?)?.toInt()
  ..total = (json['total'] as num?)?.toDouble();

Map<String, dynamic> _$OrderProductToJson(OrderProduct instance) =>
    <String, dynamic>{
      'product': instance.product?.toJson(),
      'description': instance.description,
      'value': instance.value,
      'quantity': instance.quantity,
      'total': instance.total,
    };

OrderService _$OrderServiceFromJson(Map<String, dynamic> json) => OrderService()
  ..service = json['service'] == null
      ? null
      : ServiceAggr.fromJson(json['service'] as Map<String, dynamic>)
  ..description = json['description'] as String?
  ..value = (json['value'] as num?)?.toDouble();

Map<String, dynamic> _$OrderServiceToJson(OrderService instance) =>
    <String, dynamic>{
      'service': instance.service?.toJson(),
      'description': instance.description,
      'value': instance.value,
    };
