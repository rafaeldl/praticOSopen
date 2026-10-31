/// NFS-e (nota fiscal de serviço) through Asaas. See docs/NFSE_ASAAS.md.
///
/// Everything here is written only by the server: the app reads the
/// invoices from Firestore (`companies/{cid}/invoices`) and talks to
/// `/v1/app/nfse` for the rest. Plain classes with hand-written `fromJson`
/// (read-only data, no `toJson`).
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

DateTime? _date(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

String? _str(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Status of a nota. `creating` is PraticOS's own (before Asaas answered);
/// the others mirror Asaas.
enum NfseStatus {
  creating,
  scheduled,
  synchronized,
  authorized,
  processingCancellation,
  cancellationDenied,
  canceled,
  error;

  static NfseStatus parse(Object? value) => NfseStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => NfseStatus.creating,
  );

  /// Still on the way to the city.
  bool get waiting =>
      this == creating || this == scheduled || this == synchronized;
}

/// One order covered by a nota and the services value it put in.
class NfseInvoiceOrder {
  const NfseInvoiceOrder({
    required this.orderId,
    this.orderNumber,
    required this.value,
  });

  final String orderId;
  final int? orderNumber;
  final double value;

  factory NfseInvoiceOrder.fromJson(Map<String, dynamic> json) =>
      NfseInvoiceOrder(
        orderId: json['orderId'] as String? ?? '',
        orderNumber: (json['orderNumber'] as num?)?.toInt(),
        value: _num(json['value']),
      );
}

/// `companies/{cid}/invoices/{id}`: one nota for one order (default) or for
/// several orders of the same customer.
class NfseInvoice {
  NfseInvoice({
    required this.id,
    required this.status,
    this.customerId,
    this.customerName,
    this.orderIds = const [],
    this.orders = const [],
    this.value = 0,
    this.serviceDescription,
    this.effectiveDate,
    this.number,
    this.pdfUrl,
    this.xmlUrl,
    this.statusDescription,
    this.errorCode,
    this.auto = false,
    this.createdAt,
    this.conflict = false,
  });

  final String id;
  final NfseStatus status;
  final String? customerId;
  final String? customerName;
  final List<String> orderIds;
  final List<NfseInvoiceOrder> orders;
  final double value;
  final String? serviceDescription;

  /// Day the nota is issued (YYYY-MM-DD).
  final String? effectiveDate;
  final String? number;
  final String? pdfUrl;
  final String? xmlUrl;

  /// Why the city refused it (raw text from the city, shown as detail only).
  final String? statusDescription;

  /// Why an automatic nota did not go out (server error code, see
  /// `asaasErrorText`); null for notas the user asked for.
  final String? errorCode;

  /// Issued by the server on its own (`autoIssue`).
  final bool auto;
  final DateTime? createdAt;

  /// A refused nota that came back on Asaas after the order already had
  /// another one: kept for the record, never counts as the order's nota.
  final bool conflict;

  /// A `creating` nota older than this never reached Asaas.
  static const staleCreating = Duration(minutes: 15);

  factory NfseInvoice.fromJson(Map<String, dynamic> json, {String? id}) {
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : const <String, dynamic>{};
    return NfseInvoice(
      id: id ?? json['id'] as String? ?? '',
      status: NfseStatus.parse(json['status']),
      customerId: _str(customer['id']),
      customerName: _str(customer['name']),
      orderIds: [
        for (final o in (json['orderIds'] as List? ?? const []))
          if (o is String) o,
      ],
      orders: [
        for (final o in (json['orders'] as List? ?? const []))
          if (o is Map) NfseInvoiceOrder.fromJson(Map<String, dynamic>.from(o)),
      ],
      value: _num(json['value']),
      serviceDescription: _str(json['serviceDescription']),
      effectiveDate: _str(json['effectiveDate']),
      number: _str(json['number']),
      pdfUrl: _str(json['pdfUrl']),
      xmlUrl: _str(json['xmlUrl']),
      statusDescription: _str(json['statusDescription']),
      errorCode: _str(json['errorCode']),
      auto: json['auto'] == true,
      createdAt: _date(json['createdAt']),
      conflict: json['conflict'] == true,
    );
  }

  DateTime? get effectiveDay =>
      effectiveDate == null ? null : DateTime.tryParse(effectiveDate!);

  /// Counts as "the order has a nota" (blocks a second one). An old
  /// `creating` stops counting here so "Emitir" shows again: the server then
  /// checks it with Asaas before issuing another.
  bool isActive({DateTime? now}) {
    if (conflict ||
        status == NfseStatus.canceled ||
        status == NfseStatus.error) {
      return false;
    }
    if (status == NfseStatus.creating) {
      final created = createdAt;
      if (created != null &&
          (now ?? DateTime.now()).difference(created) > staleCreating) {
        return false;
      }
    }
    return true;
  }

  /// Issued and still valid: counts in the month's total. A nota whose
  /// cancellation was denied keeps valid; one in conflict is not ours.
  bool get isIssued =>
      !conflict &&
      (status == NfseStatus.authorized ||
          status == NfseStatus.cancellationDenied);

  /// The user may ask to cancel it.
  bool get canCancel =>
      status == NfseStatus.scheduled ||
      status == NfseStatus.authorized ||
      status == NfseStatus.cancellationDenied;

  /// Order numbers covered ("182, 190").
  String get orderNumbers => [
    for (final o in orders)
      if (o.orderNumber != null) '${o.orderNumber}',
  ].join(', ');
}

/// The nota that represents [invoices] of one order on the order screen:
/// the active one, else the latest (so a refused or canceled nota still
/// shows until a new one is issued). Null when there is none.
NfseInvoice? currentInvoiceOf(List<NfseInvoice> invoices, {DateTime? now}) {
  if (invoices.isEmpty) return null;
  final sorted = [...invoices]
    ..sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
  for (final invoice in sorted) {
    if (invoice.isActive(now: now)) return invoice;
  }
  final latest = sorted.first;
  // A stale "creating" never reached Asaas: nothing to show.
  return latest.status == NfseStatus.creating ? null : latest;
}

/// The notas of one month, as the list shows them.
class NfseMonthList {
  const NfseMonthList({
    required this.attention,
    required this.rows,
    required this.issuedCount,
    required this.issuedTotal,
  });

  /// Problems waiting for the user, of the recent months (see
  /// [nfseMonthList]).
  final List<NfseInvoice> attention;

  /// The month's notas, newest first, without the ones in [attention].
  final List<NfseInvoice> rows;
  final int issuedCount;
  final double issuedTotal;

  bool get isEmpty => attention.isEmpty && rows.isEmpty;
}

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

/// First day read for [month]: that month, or the month before today when
/// it is earlier, so a problem does not vanish when the month turns.
DateTime nfseQuerySince(DateTime month, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final previous = DateTime(today.year, today.month - 1);
  final start = _monthOf(month);
  return start.isBefore(previous) ? start : previous;
}

/// Splits [invoices] for [month].
///
/// A refused nota stays in the database forever, so one whose orders all
/// have an active nota again is hidden (it never was a nota). A `creating`
/// nota past [NfseInvoice.staleCreating] never reached Asaas: hidden too.
/// Problems older than the month before today leave the list and stay only
/// on the order.
NfseMonthList nfseMonthList(
  List<NfseInvoice> invoices,
  DateTime month, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final attentionSince = DateTime(today.year, today.month - 1);
  final covered = <String>{
    for (final invoice in invoices)
      if (invoice.isActive(now: today)) ...invoice.orderIds,
  };
  bool reissued(NfseInvoice invoice) =>
      invoice.orderIds.isNotEmpty && invoice.orderIds.every(covered.contains);
  bool problem(NfseInvoice invoice) =>
      invoice.conflict ||
      invoice.status == NfseStatus.cancellationDenied ||
      (invoice.status == NfseStatus.error && !reissued(invoice));

  final newestFirst = [...invoices]
    ..sort((a, b) {
      final day = (b.effectiveDate ?? '').compareTo(a.effectiveDate ?? '');
      if (day != 0) return day;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });
  final start = _monthOf(month);
  final attention = <NfseInvoice>[];
  final rows = <NfseInvoice>[];
  var issuedCount = 0;
  var cents = 0;
  for (final invoice in newestFirst) {
    final day = invoice.effectiveDay;
    if (day == null) continue;
    final inMonth = _monthOf(day) == start;
    if (inMonth && invoice.isIssued) {
      issuedCount++;
      cents += (invoice.value * 100).round();
    }
    if (problem(invoice)) {
      if (!day.isBefore(attentionSince)) attention.add(invoice);
      continue;
    }
    if (!inMonth || invoice.status == NfseStatus.error) continue;
    if (invoice.status == NfseStatus.creating &&
        !invoice.isActive(now: today)) {
      continue;
    }
    rows.add(invoice);
  }
  return NfseMonthList(
    attention: attention,
    rows: rows,
    issuedCount: issuedCount,
    issuedTotal: cents / 100,
  );
}

String _searchable(String text) {
  const accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  return text
      .toLowerCase()
      .split('')
      .map((letter) => accents[letter] ?? letter)
      .join();
}

/// The nota has [query] in the customer's name, its number or an order
/// number. Accents and case do not matter.
bool nfseMatches(NfseInvoice invoice, String query) {
  final term = _searchable(query.trim());
  if (term.isEmpty) return true;
  return _searchable(invoice.customerName ?? '').contains(term) ||
      (invoice.number ?? '').contains(term) ||
      invoice.orders.any((o) => '${o.orderNumber ?? ''}'.contains(term));
}

/// One order of the preview.
class NfsePreviewOrder {
  const NfsePreviewOrder({
    required this.orderId,
    this.orderNumber,
    required this.value,
    required this.servicesTotal,
    required this.productsTotal,
    required this.discount,
  });

  final String orderId;
  final int? orderNumber;

  /// What goes into the nota (services minus their share of the discount).
  final double value;
  final double servicesTotal;
  final double productsTotal;
  final double discount;

  factory NfsePreviewOrder.fromJson(Map<String, dynamic> json) =>
      NfsePreviewOrder(
        orderId: json['orderId'] as String? ?? '',
        orderNumber: (json['orderNumber'] as num?)?.toInt(),
        value: _num(json['value']),
        servicesTotal: _num(json['servicesTotal']),
        productsTotal: _num(json['productsTotal']),
        discount: _num(json['discount']),
      );
}

/// `POST /v1/app/nfse/invoices/preview`: what the nota will have.
class NfsePreview {
  const NfsePreview({
    required this.value,
    required this.orders,
    required this.hasProducts,
    required this.serviceDescription,
    required this.effectiveDate,
    required this.customerName,
    required this.customerHasTaxId,
    required this.invoicedOrders,
    required this.municipalServiceName,
    this.customerContact = const {},
    this.customerMissing = const [],
  });

  final double value;
  final List<NfsePreviewOrder> orders;
  final bool hasProducts;
  final String serviceDescription;
  final String effectiveDate;
  final String? customerName;
  final bool customerHasTaxId;

  /// Orders that already have an active nota (orderId → invoiceId).
  final Map<String, String> invoicedOrders;
  final String municipalServiceName;

  /// E-mail and address of the customer as known (`email`, `postalCode`,
  /// `address`, `addressNumber`, `complement`, `province`): fills the fields.
  final Map<String, String> customerContact;

  /// What the city needs and the customer lacks (same keys, never
  /// `complement`): the sheet asks for it before the ✓.
  final List<String> customerMissing;

  factory NfsePreview.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : const <String, dynamic>{};
    final invoiced = json['invoicedOrders'] is Map
        ? Map<String, dynamic>.from(json['invoicedOrders'] as Map)
        : const <String, dynamic>{};
    return NfsePreview(
      value: _num(json['value']),
      orders: [
        for (final o in (json['orders'] as List? ?? const []))
          if (o is Map) NfsePreviewOrder.fromJson(Map<String, dynamic>.from(o)),
      ],
      hasProducts: json['hasProducts'] == true,
      serviceDescription: json['serviceDescription'] as String? ?? '',
      effectiveDate: json['effectiveDate'] as String? ?? '',
      customerName: _str(customer['name']),
      customerHasTaxId: customer['hasTaxId'] == true,
      invoicedOrders: {
        for (final e in invoiced.entries)
          if (e.value is String) e.key: e.value as String,
      },
      municipalServiceName: json['municipalServiceName'] as String? ?? '',
      customerContact: {
        if (customer['contact'] is Map)
          for (final e in (customer['contact'] as Map).entries)
            if (e.key is String && _str(e.value) != null)
              e.key as String: e.value as String,
      },
      customerMissing: [
        for (final field in (customer['missingData'] as List? ?? const []))
          if (field is String) field,
      ],
    );
  }
}

/// What is still missing before notas can be issued.
enum NfseMissing { fiscalInfo, cityAccess, service }

/// Fiscal info kept in Asaas (`GET /v3/fiscalInfo`, the fields shown).
class NfseFiscalInfo {
  const NfseFiscalInfo({
    this.email,
    this.municipalInscription,
    this.simplesNacional,
    this.cnae,
    this.specialTaxRegime,
    this.serviceListItem,
  });

  final String? email;
  final String? municipalInscription;
  final bool? simplesNacional;
  final String? cnae;
  final String? specialTaxRegime;
  final String? serviceListItem;

  factory NfseFiscalInfo.fromJson(Map<String, dynamic> json) => NfseFiscalInfo(
    email: _str(json['email']),
    municipalInscription: _str(json['municipalInscription']),
    simplesNacional: json['simplesNacional'] as bool?,
    cnae: _str(json['cnae']),
    specialTaxRegime: _str(json['specialTaxRegime']),
    serviceListItem: _str(json['serviceListItem']),
  );
}

/// City rules (`GET /v3/fiscalInfo/municipalOptions`).
class NfseCityOptions {
  const NfseCityOptions({
    this.authenticationType,
    this.supportsCancellation,
    this.usesSpecialTaxRegimes = false,
    this.usesServiceListItem = false,
    this.specialTaxRegimes = const [],
  });

  /// CERTIFICATE | TOKEN | USER_AND_PASSWORD
  final String? authenticationType;
  final bool? supportsCancellation;
  final bool usesSpecialTaxRegimes;
  final bool usesServiceListItem;
  final List<({String label, String value})> specialTaxRegimes;

  factory NfseCityOptions.fromJson(Map<String, dynamic> json) =>
      NfseCityOptions(
        authenticationType: _str(json['authenticationType']),
        supportsCancellation: json['supportsCancellation'] as bool?,
        usesSpecialTaxRegimes: json['usesSpecialTaxRegimes'] == true,
        usesServiceListItem: json['usesServiceListItem'] == true,
        specialTaxRegimes: [
          for (final r in (json['specialTaxRegimesList'] as List? ?? const []))
            if (r is Map && r['value'] != null)
              (label: '${r['label'] ?? r['value']}', value: '${r['value']}'),
        ],
      );
}

/// Taxes of the notas, in percent.
class NfseTaxes {
  const NfseTaxes({
    this.retainIss = false,
    this.iss = 0,
    this.pis = 0,
    this.cofins = 0,
    this.csll = 0,
    this.inss = 0,
    this.ir = 0,
  });

  final bool retainIss;
  final double iss;
  final double pis;
  final double cofins;
  final double csll;
  final double inss;
  final double ir;

  factory NfseTaxes.fromJson(Map<String, dynamic> json) => NfseTaxes(
    retainIss: json['retainIss'] == true,
    iss: _num(json['iss']),
    pis: _num(json['pis']),
    cofins: _num(json['cofins']),
    csll: _num(json['csll']),
    inss: _num(json['inss']),
    ir: _num(json['ir']),
  );

  Map<String, dynamic> toJson() => {
    'retainIss': retainIss,
    'iss': iss,
    'pis': pis,
    'cofins': cofins,
    'csll': csll,
    'inss': inss,
    'ir': ir,
  };
}

/// `companies/{cid}/settings/nfse`: the default service of the notas.
class NfseServiceSettings {
  const NfseServiceSettings({
    this.municipalServiceId,
    this.municipalServiceCode,
    required this.municipalServiceName,
    this.taxes = const NfseTaxes(),
    this.descriptionTemplate = defaultTemplate,
    this.autoIssue,
  });

  /// `{servicos}` becomes the services of the order(s), `{os}` the numbers.
  static const defaultTemplate = '{servicos}';

  final String? municipalServiceId;
  final String? municipalServiceCode;
  final String municipalServiceName;
  final NfseTaxes taxes;
  final String descriptionTemplate;

  /// When the server issues the nota by itself; null keeps the saved choice
  /// on save (and reads as [NfseAutoIssue.manual]).
  final NfseAutoIssue? autoIssue;

  NfseServiceSettings copyWith({NfseAutoIssue? autoIssue}) =>
      NfseServiceSettings(
        municipalServiceId: municipalServiceId,
        municipalServiceCode: municipalServiceCode,
        municipalServiceName: municipalServiceName,
        taxes: taxes,
        descriptionTemplate: descriptionTemplate,
        autoIssue: autoIssue ?? this.autoIssue,
      );

  factory NfseServiceSettings.fromJson(
    Map<String, dynamic> json,
  ) => NfseServiceSettings(
    municipalServiceId: _str(json['municipalServiceId']),
    municipalServiceCode: _str(json['municipalServiceCode']),
    municipalServiceName: json['municipalServiceName'] as String? ?? '',
    taxes: json['taxes'] is Map
        ? NfseTaxes.fromJson(Map<String, dynamic>.from(json['taxes'] as Map))
        : const NfseTaxes(),
    descriptionTemplate: _str(json['descriptionTemplate']) ?? defaultTemplate,
    autoIssue: NfseAutoIssue.parse(json['autoIssue']),
  );

  Map<String, dynamic> toJson() => {
    'municipalServiceId': municipalServiceId,
    'municipalServiceCode': municipalServiceCode,
    'municipalServiceName': municipalServiceName,
    'taxes': taxes.toJson(),
    'descriptionTemplate': descriptionTemplate,
    if (autoIssue != null) 'autoIssue': autoIssue!.name,
  };
}

/// When a nota is issued without anyone asking (`settings/nfse.autoIssue`).
enum NfseAutoIssue {
  /// Only when the user asks (default).
  manual,

  /// When the order becomes paid.
  paid,

  /// When the order is done.
  completed;

  static NfseAutoIssue parse(Object? value) => NfseAutoIssue.values.firstWhere(
    (v) => v.name == value,
    orElse: () => NfseAutoIssue.manual,
  );
}

/// A service of the city's list (`GET /v3/fiscalInfo/services`).
class NfseMunicipalService {
  const NfseMunicipalService({
    required this.id,
    required this.description,
    this.issTax,
  });

  final String id;
  final String description;
  final double? issTax;

  factory NfseMunicipalService.fromJson(Map<String, dynamic> json) =>
      NfseMunicipalService(
        id: '${json['id'] ?? ''}',
        description: json['description'] as String? ?? '',
        issTax: (json['issTax'] as num?)?.toDouble(),
      );
}

/// `GET /v1/app/nfse/setup`: what is filled and what is missing.
class NfseSetup {
  const NfseSetup({
    required this.ready,
    required this.missing,
    this.fiscalInfo,
    this.cityOptions,
    this.service,
  });

  final bool ready;
  final List<NfseMissing> missing;
  final NfseFiscalInfo? fiscalInfo;
  final NfseCityOptions? cityOptions;
  final NfseServiceSettings? service;

  factory NfseSetup.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(String key) =>
        json[key] is Map ? Map<String, dynamic>.from(json[key] as Map) : null;
    final fiscal = map('fiscalInfo');
    final options = map('municipalOptions');
    final service = map('service');
    return NfseSetup(
      ready: json['ready'] == true,
      missing: [
        for (final m in (json['missing'] as List? ?? const []))
          for (final v in NfseMissing.values)
            if (v.name == m) v,
      ],
      fiscalInfo: fiscal == null ? null : NfseFiscalInfo.fromJson(fiscal),
      cityOptions: options == null ? null : NfseCityOptions.fromJson(options),
      service: service == null ? null : NfseServiceSettings.fromJson(service),
    );
  }
}
