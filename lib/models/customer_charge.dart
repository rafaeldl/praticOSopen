/// One Asaas charge covering several orders of the same customer
/// ("Mandar cobrança" from "Receber de João").
///
/// Lives at `/companies/{companyId}/customerCharges/{chargeId}`. Written only
/// by Cloud Functions; read like the order charges (financial roles and the
/// owner). Plain class (no codegen): the app only reads it.
class CustomerCharge {
  CustomerCharge({
    this.id,
    this.customerId,
    this.customerName,
    this.value,
    this.dueDate,
    this.status,
    this.invoiceUrl,
    this.allocations = const [],
    this.paidOutside = false,
  });

  final String? id;
  final String? customerId;
  final String? customerName;

  /// Total charged (sum of [allocations]).
  final double? value;

  /// YYYY-MM-DD, as Asaas.
  final String? dueDate;

  /// pending, overdue, paid, canceled or refunded.
  final String? status;

  /// Asaas payment page the customer opens (Pix, boleto or card).
  final String? invoiceUrl;

  /// Oldest order first.
  final List<CustomerChargeAllocation> allocations;

  /// Paid outside Asaas (marked as received in cash by the server).
  final bool paidOutside;

  bool get isOpen => status == 'pending' || status == 'overdue';

  DateTime? get dueDay => dueDate == null ? null : DateTime.tryParse(dueDate!);

  List<int> get orderNumbers => [
    for (final a in allocations)
      if (a.orderNumber != null) a.orderNumber!,
  ];

  factory CustomerCharge.fromJson(Map<String, dynamic> json, {String? id}) {
    final customer = json['customer'];
    final raw = json['allocations'];
    return CustomerCharge(
      id: id ?? json['id'] as String?,
      customerId: customer is Map ? customer['id'] as String? : null,
      customerName: customer is Map ? customer['name'] as String? : null,
      value: (json['value'] as num?)?.toDouble(),
      dueDate: json['dueDate'] as String?,
      status: json['status'] as String?,
      invoiceUrl: json['invoiceUrl'] as String?,
      allocations: raw is List
          ? [
              for (final a in raw)
                if (a is Map)
                  CustomerChargeAllocation.fromJson(
                    Map<String, dynamic>.from(a),
                  ),
            ]
          : const [],
      paidOutside: json['paidOutside'] == true,
    );
  }
}

class CustomerChargeAllocation {
  const CustomerChargeAllocation({
    required this.orderId,
    required this.amount,
    this.orderNumber,
  });

  final String orderId;
  final int? orderNumber;
  final double amount;

  factory CustomerChargeAllocation.fromJson(Map<String, dynamic> json) =>
      CustomerChargeAllocation(
        orderId: json['orderId'] as String? ?? '',
        orderNumber: (json['orderNumber'] as num?)?.toInt(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}
