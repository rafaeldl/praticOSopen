import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'financial_entry.g.dart';

enum FinancialEntryDirection {
  @JsonValue('payable')
  payable,
  @JsonValue('receivable')
  receivable,
}

enum FinancialEntryStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('paid')
  paid,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable(explicitToJson: true)
class FinancialRecurrence {
  String? frequency; // daily | weekly | monthly | yearly
  int? interval; // Every N periods (1 = every month, 2 = bimonthly)
  DateTime? endDate;
  DateTime? nextDueDate;
  DateTime? lastGeneratedDate;
  bool? active;

  FinancialRecurrence();
  factory FinancialRecurrence.fromJson(Map<String, dynamic> json) =>
      _$FinancialRecurrenceFromJson(json);
  Map<String, dynamic> toJson() => _$FinancialRecurrenceToJson(this);
}

@JsonSerializable(explicitToJson: true)
class FinancialEntry extends BaseAuditCompany {
  // Classification
  FinancialEntryDirection? direction;
  FinancialEntryStatus? status;

  // Values
  String? description;
  double? amount;
  double? paidAmount;
  double? discountAmount;
  DateTime? dueDate;
  DateTime? competenceDate;
  DateTime? paidDate;

  // Categorization
  String? category;
  List<String>? tags;

  // Bank account
  String? accountId;
  FinancialAccountAggr? account;

  // Counterpart
  CustomerAggr? customer;
  String? supplier;

  // Order link
  String? orderId;
  int? orderNumber;

  // Notes and attachments
  String? notes;
  List<String>? attachments;

  // Recurrence
  FinancialRecurrence? recurrence;

  // Installments
  String? installmentGroupId;
  int? installmentNumber;
  int? installmentTotal;

  // Bidirectional sync with OS
  String? syncSource;

  // Soft delete
  DateTime? deletedAt;
  UserAggr? deletedBy;

  // Computed
  double get remainingBalance =>
      (amount ?? 0) - (paidAmount ?? 0) - (discountAmount ?? 0);
  bool get isFullyPaid => remainingBalance <= 0;
  bool get isOverdue =>
      status == FinancialEntryStatus.pending &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());
  bool get isInstallment =>
      installmentNumber != null && installmentTotal != null;

  FinancialEntry();
  factory FinancialEntry.fromJson(Map<String, dynamic> json) =>
      _$FinancialEntryFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$FinancialEntryToJson(this);
  FinancialEntryAggr toAggr() => _$FinancialEntryAggrFromJson(toJson());
}

@JsonSerializable()
class FinancialEntryAggr extends BaseAuditCompanyAggr {
  FinancialEntryDirection? direction;
  String? description;
  double? amount;
  DateTime? dueDate;
  FinancialEntryStatus? status;

  FinancialEntryAggr();
  factory FinancialEntryAggr.fromJson(Map<String, dynamic> json) =>
      _$FinancialEntryAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$FinancialEntryAggrToJson(this);
}
