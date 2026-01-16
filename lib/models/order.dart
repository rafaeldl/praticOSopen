import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/last_activity.dart';
import 'package:praticos/models/order_photo.dart';
import 'package:praticos/models/payment_transaction.dart';
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
  List<OrderPhoto>? photos = [];
  double? total;
  double? discount;
  DateTime? dueDate;
  bool? done;
  bool? paid;
  String? payment; // unpaid, paid (partial is calculated in memory based on paidAmount)
  String? status;
  int? number;

  /// Valor total pago (soma dos pagamentos parciais)
  double? paidAmount;

  /// Lista de transações de pagamento e desconto
  List<PaymentTransaction>? transactions;

  /// Técnico atribuído à OS (para controle de acesso RBAC)
  UserAggr? assignedTo;

  /// Unique token for customer magic link
  String? customerToken;

  /// Last activity preview for list display
  LastActivity? lastActivity;

  /// Unread counts per user
  Map<String, int>? unreadCounts;

  /// Get unread count for a specific user
  int getUnreadCount(String userId) => unreadCounts?[userId] ?? 0;

  /// Check if order has unread messages for a user
  bool hasUnread(String userId) => getUnreadCount(userId) > 0;

  /// Retorna a URL da primeira foto (capa da OS)
  String? get coverPhotoUrl => photos?.isNotEmpty == true ? photos!.first.url : null;

  /// Calcula o saldo restante a pagar
  double get remainingBalance {
    final totalValue = total ?? 0.0;
    final paid = paidAmount ?? 0.0;
    return totalValue - paid;
  }

  /// Verifica se está totalmente pago
  bool get isFullyPaid => remainingBalance <= 0;

  /// Verifica se tem pagamento parcial
  bool get hasPartialPayment => (paidAmount ?? 0) > 0 && !isFullyPaid;

  /// Retorna o total de descontos das transações
  double get totalDiscounts {
    if (transactions == null || transactions!.isEmpty) return discount ?? 0.0;
    return transactions!
        .where((t) => t.type == PaymentTransactionType.discount)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Retorna o total de pagamentos das transações
  double get totalPayments {
    if (transactions == null || transactions!.isEmpty) return paidAmount ?? 0.0;
    return transactions!
        .where((t) => t.type == PaymentTransactionType.payment)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

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
  @override
  Map<String, dynamic> toJson() => _$OrderToJson(this);
  OrderAggr toAggr() => _$OrderAggrFromJson(toJson());

  int compareToCustomer(Order? b) {
    if (b == null) return 0;
    String name = b.customer?.name?.toString() ?? '';
    int? compare = customer?.name?.toString().compareTo(name);
    if (compare == 0 && b.number != null && number != null) {
      compare = b.number!.compareTo(number!);
    }
    return compare ?? 0;
  }

  int compareToDueDate(Order? b) {
    if (b == null) return 0;
    String name = b.customer?.name?.toString() ?? '';
    int? compare = customer?.name.toString().compareTo(name);
    if (compare == 0 && b.dueDate != null && dueDate != null) {
      compare = b.dueDate!.compareTo(dueDate!);
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
  @override
  Map<String, dynamic> toJson() => _$OrderAggrToJson(this);
}

@JsonSerializable(explicitToJson: true)
class OrderProduct {
  ProductAggr? product;
  String? description;
  double? value;
  int? quantity;
  double? total;
  String? photo;

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
  String? photo;

  OrderService();
  factory OrderService.fromJson(Map<String, dynamic> json) =>
      _$OrderServiceFromJson(json);
  Map<String, dynamic> toJson() => _$OrderServiceToJson(this);
}
