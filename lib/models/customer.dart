import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

@JsonSerializable(explicitToJson: true)
class Customer extends BaseAuditCompany {
  String? name;
  String? phone;
  String? email;

  /// CPF or CNPJ, normalized (digits; uppercase letters for alphanumeric CNPJ).
  /// See normalizeTaxId in lib/utils/tax_id.dart.
  String? taxId;
  String? address;
  double? latitude;
  double? longitude;
  List<String>? keywords;
  Map<String, dynamic>? customData;

  // Data for the nota (NFS-e direct, spec 2026-11-05-nfse-direta-design §4.5).

  /// Razão social (CNPJ) or full name (CPF) as the nota shows it.
  String? legalName;
  FiscalAddress? fiscalAddress;

  /// E-mail the nota goes to; falls back to [email].
  String? invoiceEmail;

  /// "Nota fiscal para": another customer of the company gets this
  /// customer's notas (each branch is a customer; the CNPJ stays in one).
  CustomerAggr? invoiceRecipient;

  /// Issue the nota when an order of this customer is done.
  bool? autoIssueInvoice;

  /// Last emitter used for this customer, kept by the server: the issue
  /// sheet marks it first. Never written as null by the app.
  @JsonKey(includeIfNull: false)
  String? lastEmitterId;

  /// Last activity (created, edited or one of the orders changed), kept by
  /// the server (docs/CUSTOMER_LAST_ACTIVITY.md). Read only: the app never
  /// writes it, so a save never puts back an older date.
  @JsonKey(includeToJson: false)
  DateTime? lastActivityAt;

  /// Open orders (quote, approved, progress) of every user, kept by the
  /// server for the Clientes list. Read only, like [lastActivityAt].
  @JsonKey(includeToJson: false)
  int? openOrders;

  /// "Falta receber" (the A receber rule), kept by the server. Read only.
  @JsonKey(includeToJson: false)
  double? owed;

  /// Promised days of the open orders that have one, oldest first, kept by
  /// the server: the ones before today are the late orders. Read only.
  @JsonKey(includeToJson: false)
  List<DateTime>? openDueDates;

  Customer();
  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
  CustomerAggr toAggr() => _$CustomerAggrFromJson(toJson());

  /// The e-mail the nota goes to.
  String? get effectiveInvoiceEmail {
    final invoice = invoiceEmail?.trim();
    if (invoice != null && invoice.isNotEmpty) return invoice;
    final main = email?.trim();
    return main == null || main.isEmpty ? null : main;
  }
}

@JsonSerializable()
class CustomerAggr extends BaseAuditCompanyAggr {
  String? name;
  String? phone;
  String? email;

  /// CPF or CNPJ, normalized (see lib/utils/tax_id.dart).
  String? taxId;

  CustomerAggr();
  factory CustomerAggr.fromJson(Map<String, dynamic> json) =>
      _$CustomerAggrFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$CustomerAggrToJson(this);
}
