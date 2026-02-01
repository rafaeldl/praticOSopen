import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
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

  /// Link de compartilhamento ativo
  OrderShareLink? shareLink;

  /// Avaliação do cliente
  OrderRating? rating;

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

/// Link de compartilhamento da OS
@JsonSerializable()
class OrderShareLink {
  String? token;
  DateTime? expiresAt;
  List<String>? permissions;

  OrderShareLink();

  /// Verifica se o link está expirado
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Retorna a URL completa do link
  String? get url => token != null ? 'https://praticos.web.app/q/$token' : null;

  factory OrderShareLink.fromJson(Map<String, dynamic> json) =>
      _$OrderShareLinkFromJson(json);
  Map<String, dynamic> toJson() => _$OrderShareLinkToJson(this);
}

/// Customer rating for completed orders
@JsonSerializable()
class OrderRating {
  /// Rating score from 1 to 5 stars
  int? score;

  /// Optional customer comment (max 500 chars)
  String? comment;

  /// When the rating was submitted
  DateTime? createdAt;

  /// Name of the customer who rated
  String? customerName;

  OrderRating();

  /// Returns true if the order has a valid rating
  bool get hasRating => score != null && score! >= 1 && score! <= 5;

  factory OrderRating.fromJson(Map<String, dynamic> json) =>
      _$OrderRatingFromJson(json);
  Map<String, dynamic> toJson() => _$OrderRatingToJson(this);
}
