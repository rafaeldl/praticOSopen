import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order_document.dart';
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
  List<DeviceAggr>? devices = [];
  List<OrderService>? services = [];
  List<OrderProduct>? products = [];
  List<OrderPhoto>? photos = [];
  double? total;
  double? discount;
  DateTime? dueDate;
  DateTime? scheduledDate;
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

  /// Service location address
  String? address;
  double? latitude;
  double? longitude;

  /// Dynamic custom fields from segment config
  Map<String, dynamic>? customData;

  /// Attached documents (receipts, invoices, contracts, etc.)
  List<OrderDocument>? documents;

  /// Denormalized device IDs for Firestore arrayContains queries
  List<String>? deviceIds;

  /// Contract sub-document (null = normal order, filled = recurring contract)
  OrderContract? contract;

  /// Denormalized for Firestore queries (Firestore can't query nested nulls)
  bool? isContract;

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

  /// Returns effective devices list (fallback to singular device)
  List<DeviceAggr> get effectiveDevices {
    if (devices != null && devices!.isNotEmpty) return devices!;
    if (device != null) return [device!];
    return [];
  }

  bool get isMultiDevice => effectiveDevices.length > 1;

  factory Order.fromJson(Map<String, dynamic> json) {
    final order = _$OrderFromJson(json);
    // Backward compat: old singular device → devices
    if ((order.devices == null || order.devices!.isEmpty) &&
        order.device != null) {
      order.devices = [order.device!];
    }
    // Forward sync: devices → device (first)
    if (order.devices != null && order.devices!.isNotEmpty) {
      order.device = order.devices!.first;
    }
    // Sync deviceIds from devices list
    order.syncDeviceIds();
    return order;
  }

  /// Syncs deviceIds from devices list (for Firestore arrayContains queries)
  void syncDeviceIds() {
    final ids = effectiveDevices
        .where((d) => d.id != null)
        .map((d) => d.id!)
        .toList();
    deviceIds = ids.isEmpty ? null : ids;
  }
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
  List<DeviceAggr>? devices;

  OrderAggr();
  factory OrderAggr.fromJson(Map<String, dynamic> json) {
    final aggr = _$OrderAggrFromJson(json);
    // Backward compat: old singular device → devices
    if ((aggr.devices == null || aggr.devices!.isEmpty) &&
        aggr.device != null) {
      aggr.devices = [aggr.device!];
    }
    // Forward sync: devices → device (first)
    if (aggr.devices != null && aggr.devices!.isNotEmpty) {
      aggr.device = aggr.devices!.first;
    }
    return aggr;
  }
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
  String? deviceId;

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
  String? deviceId;

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

/// Contract sub-document for recurring orders
@JsonSerializable()
class OrderContract {
  String? frequency; // 'daily', 'weekly', 'monthly', 'yearly'
  int? interval; // 1 = every period, 3 = every 3 periods
  DateTime? startDate;
  DateTime? endDate; // null = indefinite
  DateTime? nextDueDate;
  DateTime? lastGeneratedDate;
  int? generatedCount;
  bool? autoGenerate; // true = creates OS, false = reminder only
  bool? active;
  int? reminderDaysBefore;
  String? parentOrderId; // For generated orders: ID of the template order
  int? parentOrderNumber; // For generated orders: number of the template order

  OrderContract();

  factory OrderContract.fromJson(Map<String, dynamic> json) =>
      _$OrderContractFromJson(json);
  Map<String, dynamic> toJson() => _$OrderContractToJson(this);

  /// Computes the next due date based on frequency and interval
  DateTime? computeNextDueDate() {
    final base = lastGeneratedDate ?? startDate;
    if (base == null) return null;
    final step = interval ?? 1;

    switch (frequency) {
      case 'daily':
        return base.add(Duration(days: step));
      case 'weekly':
        return base.add(Duration(days: 7 * step));
      case 'monthly':
        return DateTime(base.year, base.month + step, base.day);
      case 'yearly':
        return DateTime(base.year + step, base.month, base.day);
      default:
        return null;
    }
  }

  /// Whether the contract is due (nextDueDate <= now and active)
  bool get isDue {
    if (active != true || nextDueDate == null) return false;
    return nextDueDate!.isBefore(DateTime.now()) ||
        nextDueDate!.isAtSameMomentAs(DateTime.now());
  }

  /// Whether the contract has expired (endDate passed)
  bool get isExpired {
    if (endDate == null) return false;
    return endDate!.isBefore(DateTime.now());
  }
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
