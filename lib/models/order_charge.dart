import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/user.dart';

part 'order_charge.g.dart';

/// Lifecycle of an Asaas charge, mirrored from the server.
enum ChargeStatus { pending, paid, overdue, canceled, refunded }

/// How the customer pays the charge.
///
/// `single`: the customer picks Pix, boleto or card on the Asaas invoice.
/// `cardInstallments`: credit card split in 2–12 installments.
enum ChargeMode { single, cardInstallments }

/// Asaas charge of an order.
///
/// Path: `/companies/{companyId}/orders/{orderId}/charges/{chargeId}`.
/// Written only by Cloud Functions; the app only reads it.
@JsonSerializable(explicitToJson: true)
class OrderCharge {
  String? id;
  String? asaasPaymentId;
  String? asaasInstallmentId;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ChargeMode? mode;

  int? installmentCount;
  double? value;

  /// Due date in the server format `YYYY-MM-DD`.
  String? dueDate;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ChargeStatus? status;

  String? invoiceUrl;
  List<String>? paidAsaasPaymentIds;
  UserAggr? createdBy;
  DateTime? createdAt;
  DateTime? paidAt;

  OrderCharge({
    this.id,
    this.asaasPaymentId,
    this.asaasInstallmentId,
    this.mode,
    this.installmentCount,
    this.value,
    this.dueDate,
    this.status,
    this.invoiceUrl,
    this.paidAsaasPaymentIds,
    this.createdBy,
    this.createdAt,
    this.paidAt,
  });

  factory OrderCharge.fromJson(Map<String, dynamic> json) =>
      _$OrderChargeFromJson(json);

  Map<String, dynamic> toJson() => _$OrderChargeToJson(this);

  /// Pending or overdue: the customer can still pay it.
  bool get isOpen =>
      status == ChargeStatus.pending || status == ChargeStatus.overdue;

  /// [dueDate] parsed as a local date (no time).
  DateTime? get dueDateValue =>
      dueDate == null ? null : DateTime.tryParse(dueDate!);

  /// The charge the order screen shows: the open one, else the most recent.
  ///
  /// [charges] must be sorted by `createdAt` descending, as
  /// `OrderChargeRepository.watch` returns them.
  static OrderCharge? current(List<OrderCharge> charges) {
    for (final charge in charges) {
      if (charge.isOpen) return charge;
    }
    return charges.isEmpty ? null : charges.first;
  }
}
