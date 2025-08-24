import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

@JsonSerializable(explicitToJson: true)
class Order extends BaseAuditCompany {
  CustomerAggr? customer;
  DeviceAggr? device;
  List<OrderService>? services = [];
  List<OrderProduct>? products = [];
  double? total;
  double? discount;
  DateTime? dueDate;
  bool? done;
  bool? paid;
  String? payment; // unpaid, paid
  String? status;
  String? mainPhoto;
  int? number;

  static Map statusMap = {
    'quote': 'Orçamento',
    'approved': 'Aprovado',
    'progress': 'Em Andamento',
    'done': 'Concluído',
    'canceled': 'Cancelado',
  };

  // static Map payment = {'open': 'A receber', 'paid': 'Pago'};

  Order();

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
  OrderAggr toAggr() => _$OrderAggrFromJson(this.toJson());

  int compareToCustomer(Order? b) {
    if (b == null) return 0;
    String name = b.customer?.name?.toString() ?? '';
    int? compare = this.customer?.name?.toString().compareTo(name);
    if (compare == 0 && b.number != null && this.number != null) {
      compare = b.number!.compareTo(this.number!);
    }
    return compare ?? 0;
  }

  int compareToDueDate(Order? b) {
    if (b == null) return 0;
    String name = b.customer?.name?.toString() ?? '';
    int? compare = this.customer?.name.toString().compareTo(name);
    if (compare == 0 && b.dueDate != null && this.dueDate != null) {
      compare = b.dueDate!.compareTo(this.dueDate!);
    }
    return compare ?? 0;
  }
}

@JsonSerializable(explicitToJson: true)
class OrderAggr extends BaseAuditCompanyAggr {
  CustomerAggr? customer;
  DeviceAggr? device;

  OrderAggr();
  factory OrderAggr.fromJson(Map<String, dynamic> json) =>
      _$OrderAggrFromJson(json);
  Map<String, dynamic> toJson() => _$OrderAggrToJson(this);
}

@JsonSerializable(explicitToJson: true)
class OrderProduct {
  ProductAggr? product;
  String? description;
  double? value;
  int? quantity;
  double? total;

  OrderProduct();
  factory OrderProduct.fromJson(Map<String, dynamic> json) =>
      _$OrderProductFromJson(json);
  Map<String, dynamic> toJson() => _$OrderProductToJson(this);
}

@JsonSerializable(explicitToJson: true)
class OrderService {
  ServiceAggr? service;
  String? description;
  double? value;

  OrderService();
  factory OrderService.fromJson(Map<String, dynamic> json) =>
      _$OrderServiceFromJson(json);
  Map<String, dynamic> toJson() => _$OrderServiceToJson(this);
}
