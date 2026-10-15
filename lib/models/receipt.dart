import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';

part 'receipt.g.dart';

/// Status of a [Receipt]. Receipts are never hard-deleted (soft delete).
class ReceiptStatus {
  ReceiptStatus._();

  static const active = 'active';
  static const canceled = 'canceled';
}

/// One payment received from a customer, possibly split over several
/// orders ("Receber de João").
///
/// Path: `/companies/{companyId}/receipts/{receiptId}`. Each order covered
/// also gets a regular `payment` PaymentTransaction with its share and
/// `receiptGroupId` = this id, so every existing screen and report keeps
/// working from the orders alone.
@JsonSerializable(explicitToJson: true)
class Receipt extends BaseAuditCompany {
  CustomerAggr? customer;

  /// Total received (sum of [allocations]).
  double? amount;

  /// When the money came in (chosen by the user; defaults to now).
  DateTime? paidAt;

  /// Optional file attached (photo or PDF), stored once for every order.
  ReceiptFile? receiptFile;

  List<ReceiptAllocation>? allocations;

  /// [ReceiptStatus.active] or [ReceiptStatus.canceled].
  String? status;

  Receipt();

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$ReceiptToJson(this);
}

/// The share of a [Receipt] that went to one order.
@JsonSerializable()
class ReceiptAllocation {
  String? orderId;
  int? orderNumber;
  double? amount;

  /// Id of the PaymentTransaction written on the order for this share.
  String? transactionId;

  ReceiptAllocation({
    this.orderId,
    this.orderNumber,
    this.amount,
    this.transactionId,
  });

  factory ReceiptAllocation.fromJson(Map<String, dynamic> json) =>
      _$ReceiptAllocationFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptAllocationToJson(this);
}

/// File of the receipt in Storage
/// (`tenants/{companyId}/receipts/{receiptId}/{file}`).
@JsonSerializable()
class ReceiptFile {
  String? url;
  String? storagePath;
  String? fileName;
  String? contentType;

  ReceiptFile({this.url, this.storagePath, this.fileName, this.contentType});

  factory ReceiptFile.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFileFromJson(json);
  Map<String, dynamic> toJson() => _$ReceiptFileToJson(this);
}
