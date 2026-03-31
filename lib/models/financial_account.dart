import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'financial_account.g.dart';

enum FinancialAccountType {
  @JsonValue('bank')
  bank,
  @JsonValue('cash')
  cash,
  @JsonValue('creditCard')
  creditCard,
  @JsonValue('digitalWallet')
  digitalWallet,
}

@JsonSerializable(explicitToJson: true)
class FinancialAccount extends BaseAuditCompany {
  String? name;
  FinancialAccountType? type;
  double? initialBalance;
  double? currentBalance;
  String? currency;
  String? color;
  String? icon;
  bool? active;
  bool? isDefault;
  DateTime? lastReconciledAt;

  FinancialAccount();
  factory FinancialAccount.fromJson(Map<String, dynamic> json) =>
      _$FinancialAccountFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$FinancialAccountToJson(this);
  FinancialAccountAggr toAggr() => _$FinancialAccountAggrFromJson(toJson());
}

@JsonSerializable()
class FinancialAccountAggr extends BaseAuditCompanyAggr {
  String? name;
  FinancialAccountType? type;

  FinancialAccountAggr();
  factory FinancialAccountAggr.fromJson(Map<String, dynamic> json) =>
      _$FinancialAccountAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$FinancialAccountAggrToJson(this);
}
