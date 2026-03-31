import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'financial_payment.g.dart';

enum FinancialPaymentType {
  @JsonValue('income')
  income,
  @JsonValue('expense')
  expense,
  @JsonValue('transfer')
  transfer,
}

enum FinancialPaymentStatus {
  @JsonValue('completed')
  completed,
  @JsonValue('reversed')
  reversed,
}

@JsonSerializable(explicitToJson: true)
class FinancialPayment extends BaseAuditCompany {
  // Movement type
  FinancialPaymentType? type;

  // Status
  FinancialPaymentStatus? status;

  // Values
  double? amount;
  double? discount;
  DateTime? paymentDate;
  PaymentMethod? paymentMethod;
  String? description;
  String? notes;

  // Attachments
  List<String>? attachments;

  // Entry link
  String? entryId;

  // Bank account (source)
  String? accountId;
  FinancialAccountAggr? account;

  // Transfer (destination - only for type == transfer)
  String? targetAccountId;
  FinancialAccountAggr? targetAccount;
  String? transferGroupId;
  String? transferDirection; // 'out' | 'in'

  // Reversal
  String? reversedPaymentId;
  String? reversedByPaymentId;
  DateTime? reversedAt;
  String? reversalReason;

  // Order link
  String? orderId;
  int? orderNumber;

  // Counterpart
  CustomerAggr? customer;
  String? supplier;

  // Categorization
  String? category;

  // Bidirectional sync with OS
  String? syncSource;

  // Soft delete
  DateTime? deletedAt;
  UserAggr? deletedBy;

  FinancialPayment();
  factory FinancialPayment.fromJson(Map<String, dynamic> json) =>
      _$FinancialPaymentFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$FinancialPaymentToJson(this);
}
