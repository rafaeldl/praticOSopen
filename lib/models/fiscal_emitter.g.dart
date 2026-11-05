// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fiscal_emitter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FiscalEmitterCertificate _$FiscalEmitterCertificateFromJson(
  Map<String, dynamic> json,
) => FiscalEmitterCertificate(
  holderName: json['holderName'] as String?,
  notAfter: json['notAfter'] == null
      ? null
      : DateTime.parse(json['notAfter'] as String),
  uploadedAt: json['uploadedAt'] == null
      ? null
      : DateTime.parse(json['uploadedAt'] as String),
  uploadedBy: json['uploadedBy'] == null
      ? null
      : UserAggr.fromJson(json['uploadedBy'] as Map<String, dynamic>),
  status: $enumDecodeNullable(
    _$FiscalCertificateStatusEnumMap,
    json['status'],
    unknownValue: FiscalCertificateStatus.deleted,
  ),
);

Map<String, dynamic> _$FiscalEmitterCertificateToJson(
  FiscalEmitterCertificate instance,
) => <String, dynamic>{
  'holderName': instance.holderName,
  'notAfter': instance.notAfter?.toIso8601String(),
  'uploadedAt': instance.uploadedAt?.toIso8601String(),
  'uploadedBy': instance.uploadedBy?.toJson(),
  'status': _$FiscalCertificateStatusEnumMap[instance.status],
};

const _$FiscalCertificateStatusEnumMap = {
  FiscalCertificateStatus.active: 'active',
  FiscalCertificateStatus.pending: 'pending',
  FiscalCertificateStatus.expired: 'expired',
  FiscalCertificateStatus.deleted: 'deleted',
};

FiscalEmitterService _$FiscalEmitterServiceFromJson(
  Map<String, dynamic> json,
) => FiscalEmitterService(
  nationalCode: json['nationalCode'] as String?,
  municipalCode: json['municipalCode'] as String?,
  nbs: json['nbs'] as String?,
  name: json['name'] as String?,
  issRate: (json['issRate'] as num?)?.toDouble(),
);

Map<String, dynamic> _$FiscalEmitterServiceToJson(
  FiscalEmitterService instance,
) => <String, dynamic>{
  'nationalCode': instance.nationalCode,
  'municipalCode': instance.municipalCode,
  'nbs': instance.nbs,
  'name': instance.name,
  'issRate': instance.issRate,
};

FiscalDescriptionStyle _$FiscalDescriptionStyleFromJson(
  Map<String, dynamic> json,
) => FiscalDescriptionStyle(
  uppercase: json['uppercase'] as bool? ?? false,
  separator: json['separator'] as String? ?? ', ',
);

Map<String, dynamic> _$FiscalDescriptionStyleToJson(
  FiscalDescriptionStyle instance,
) => <String, dynamic>{
  'uppercase': instance.uppercase,
  'separator': instance.separator,
};

FiscalEmitterTotals _$FiscalEmitterTotalsFromJson(Map<String, dynamic> json) =>
    FiscalEmitterTotals(
      year: (json['year'] as num?)?.toInt(),
      yearValue: (json['yearValue'] as num?)?.toDouble() ?? 0,
      month: (json['month'] as num?)?.toInt(),
      monthValue: (json['monthValue'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$FiscalEmitterTotalsToJson(
  FiscalEmitterTotals instance,
) => <String, dynamic>{
  'year': instance.year,
  'yearValue': instance.yearValue,
  'month': instance.month,
  'monthValue': instance.monthValue,
};

FiscalEmitter _$FiscalEmitterFromJson(
  Map<String, dynamic> json,
) => FiscalEmitter(
  id: json['id'] as String?,
  taxId: json['taxId'] as String?,
  legalName: json['legalName'] as String?,
  tradeName: json['tradeName'] as String?,
  regime: $enumDecodeNullable(
    _$FiscalRegimeEnumMap,
    json['regime'],
    unknownValue: FiscalRegime.simples,
  ),
  simplesOption: (json['simplesOption'] as num?)?.toInt(),
  cityCode: json['cityCode'] as String?,
  cityName: json['cityName'] as String?,
  municipalRegistration: json['municipalRegistration'] as String?,
  enabledInCity: json['enabledInCity'] as bool? ?? false,
  service: json['service'] == null
      ? null
      : FiscalEmitterService.fromJson(json['service'] as Map<String, dynamic>),
  descriptionStyle: json['descriptionStyle'] == null
      ? null
      : FiscalDescriptionStyle.fromJson(
          json['descriptionStyle'] as Map<String, dynamic>,
        ),
  dpsSeries: json['dpsSeries'] as String?,
  certificate: json['certificate'] == null
      ? null
      : FiscalEmitterCertificate.fromJson(
          json['certificate'] as Map<String, dynamic>,
        ),
  totals: json['totals'] == null
      ? null
      : FiscalEmitterTotals.fromJson(json['totals'] as Map<String, dynamic>),
  importBatchId: json['importBatchId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$FiscalEmitterToJson(FiscalEmitter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taxId': instance.taxId,
      'legalName': instance.legalName,
      'tradeName': instance.tradeName,
      'regime': _$FiscalRegimeEnumMap[instance.regime],
      'simplesOption': instance.simplesOption,
      'cityCode': instance.cityCode,
      'cityName': instance.cityName,
      'municipalRegistration': instance.municipalRegistration,
      'enabledInCity': instance.enabledInCity,
      'service': instance.service?.toJson(),
      'descriptionStyle': instance.descriptionStyle?.toJson(),
      'dpsSeries': instance.dpsSeries,
      'certificate': instance.certificate?.toJson(),
      'totals': instance.totals?.toJson(),
      'importBatchId': instance.importBatchId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$FiscalRegimeEnumMap = {
  FiscalRegime.mei: 'mei',
  FiscalRegime.simples: 'simples',
};

FiscalEmitterAggr _$FiscalEmitterAggrFromJson(Map<String, dynamic> json) =>
    FiscalEmitterAggr(
      id: json['id'] as String?,
      taxId: json['taxId'] as String?,
      legalName: json['legalName'] as String?,
      regime: $enumDecodeNullable(
        _$FiscalRegimeEnumMap,
        json['regime'],
        unknownValue: FiscalRegime.simples,
      ),
    );

Map<String, dynamic> _$FiscalEmitterAggrToJson(FiscalEmitterAggr instance) =>
    <String, dynamic>{
      'id': instance.id,
      'taxId': instance.taxId,
      'legalName': instance.legalName,
      'regime': _$FiscalRegimeEnumMap[instance.regime],
    };
