import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';

part 'fiscal_emitter.g.dart';

/// Tax regime of an emitter. Decides the fields of the nota.
@JsonEnum()
enum FiscalRegime { mei, simples }

/// State of the emitter's certificate. `pending` was sent by the accountant
/// and waits for the owner to confirm.
@JsonEnum()
enum FiscalCertificateStatus { active, pending, expired, deleted }

/// What the app may know about a certificate (never the certificate itself).
@JsonSerializable(explicitToJson: true)
class FiscalEmitterCertificate {
  String? holderName;

  /// End of validity.
  DateTime? notAfter;
  DateTime? uploadedAt;
  UserAggr? uploadedBy;

  @JsonKey(unknownEnumValue: FiscalCertificateStatus.deleted)
  FiscalCertificateStatus? status;

  FiscalEmitterCertificate({
    this.holderName,
    this.notAfter,
    this.uploadedAt,
    this.uploadedBy,
    this.status,
  });

  factory FiscalEmitterCertificate.fromJson(Map<String, dynamic> json) =>
      _$FiscalEmitterCertificateFromJson(json);

  Map<String, dynamic> toJson() => _$FiscalEmitterCertificateToJson(this);
}

/// Default service of the notas of one emitter.
@JsonSerializable()
class FiscalEmitterService {
  /// National service code (cTribNac).
  String? nationalCode;

  /// City's own service code (cTribMun), when the city uses one.
  String? municipalCode;
  String? nbs;
  String? name;

  /// ISS rate in percent.
  double? issRate;

  FiscalEmitterService({
    this.nationalCode,
    this.municipalCode,
    this.nbs,
    this.name,
    this.issRate,
  });

  factory FiscalEmitterService.fromJson(Map<String, dynamic> json) =>
      _$FiscalEmitterServiceFromJson(json);

  Map<String, dynamic> toJson() => _$FiscalEmitterServiceToJson(this);
}

/// How the description of the notas is written (learned from old notas).
@JsonSerializable()
class FiscalDescriptionStyle {
  @JsonKey(defaultValue: false)
  bool uppercase;

  /// Joins the services of one order, e.g. " - ".
  @JsonKey(defaultValue: ', ')
  String separator;

  FiscalDescriptionStyle({this.uppercase = false, this.separator = ', '});

  factory FiscalDescriptionStyle.fromJson(Map<String, dynamic> json) =>
      _$FiscalDescriptionStyleFromJson(json);

  Map<String, dynamic> toJson() => _$FiscalDescriptionStyleToJson(this);
}

/// Notas issued this year and this month, minus the canceled ones.
@JsonSerializable()
class FiscalEmitterTotals {
  int? year;
  @JsonKey(defaultValue: 0)
  double yearValue;

  /// 1-12.
  int? month;
  @JsonKey(defaultValue: 0)
  double monthValue;

  FiscalEmitterTotals({
    this.year,
    this.yearValue = 0,
    this.month,
    this.monthValue = 0,
  });

  factory FiscalEmitterTotals.fromJson(Map<String, dynamic> json) =>
      _$FiscalEmitterTotalsFromJson(json);

  Map<String, dynamic> toJson() => _$FiscalEmitterTotalsToJson(this);
}

/// `companies/{companyId}/fiscalEmitters/{id}`: one CNPJ that issues notas
/// directly in the national system (no Asaas). A company may have several
/// (one Simples and several MEIs). Written only by the server, read by the
/// owner, admin and manager. See
/// docs/superpowers/specs/2026-11-05-nfse-direta-design.md §7.
@JsonSerializable(explicitToJson: true)
class FiscalEmitter extends BaseAuditCompany {
  /// CNPJ, normalized (see lib/utils/tax_id.dart). Unique per company.
  String? taxId;
  String? legalName;
  String? tradeName;

  @JsonKey(unknownEnumValue: FiscalRegime.simples)
  FiscalRegime? regime;

  /// regApTribSN of the Simples; null for MEI.
  int? simplesOption;

  /// IBGE code of the city.
  String? cityCode;
  String? cityName;
  String? municipalRegistration;

  /// Enabled to issue in the city, per the national registry.
  @JsonKey(defaultValue: false)
  bool enabledInCity;
  FiscalEmitterService? service;
  FiscalDescriptionStyle? descriptionStyle;

  /// Series of our DPS (one the CNPJ never used).
  String? dpsSeries;
  FiscalEmitterCertificate? certificate;
  FiscalEmitterTotals? totals;
  String? importBatchId;

  FiscalEmitter({
    this.taxId,
    this.legalName,
    this.tradeName,
    this.regime,
    this.simplesOption,
    this.cityCode,
    this.cityName,
    this.municipalRegistration,
    this.enabledInCity = false,
    this.service,
    this.descriptionStyle,
    this.dpsSeries,
    this.certificate,
    this.totals,
    this.importBatchId,
  });

  factory FiscalEmitter.fromJson(Map<String, dynamic> json) =>
      _$FiscalEmitterFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$FiscalEmitterToJson(this);

  FiscalEmitterAggr toAggr() => FiscalEmitterAggr(
    id: id,
    taxId: taxId,
    legalName: legalName,
    regime: regime,
  );

  bool get isMei => regime == FiscalRegime.mei;

  /// The certificate is in force on [now]: confirmed and not past its end.
  bool certificateValid({DateTime? now}) {
    final cert = certificate;
    final end = cert?.notAfter;
    if (cert == null || end == null) return false;
    if (cert.status != FiscalCertificateStatus.active) return false;
    return (now ?? DateTime.now()).isBefore(end);
  }

  /// Can issue a nota now: valid certificate, enabled in the city and a
  /// default service.
  bool canIssue({DateTime? now}) =>
      certificateValid(now: now) && enabledInCity && service != null;
}

/// The emitter embedded in an invoice.
@JsonSerializable()
class FiscalEmitterAggr extends BaseAuditCompanyAggr {
  String? taxId;
  String? legalName;

  @JsonKey(unknownEnumValue: FiscalRegime.simples)
  FiscalRegime? regime;

  FiscalEmitterAggr({String? id, this.taxId, this.legalName, this.regime}) {
    this.id = id;
  }

  factory FiscalEmitterAggr.fromJson(Map<String, dynamic> json) =>
      _$FiscalEmitterAggrFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$FiscalEmitterAggrToJson(this);
}
