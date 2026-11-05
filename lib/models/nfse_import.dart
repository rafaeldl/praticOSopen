/// Import of the notas a CNPJ already issued (issue #569, spec §4.3):
/// `companies/{cid}/nfseImports/{batchId}`, written only by the server
/// (`nfseApi`), read by the owner and admins. Parsed by hand: the app only
/// reads it, and the proposal is nested data of the server's shape
/// (`firebase/functions/src/services/nfse/import-proposal.ts`).
library;

import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/fiscal_emitter.dart';

enum NfseImportStatus {
  reading,
  proposed,
  applied,
  undone,
  failed;

  static NfseImportStatus parse(Object? value) =>
      NfseImportStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => NfseImportStatus.failed,
      );
}

/// What the import does with everyone who got a nota under one CPF/CNPJ.
enum NfseImportAction {
  /// Fills an existing customer (sure match).
  complete,

  /// Creates a new customer.
  create,

  /// "Este é o mesmo cliente?": needs the owner's answer.
  ask;

  static NfseImportAction parse(Object? value) =>
      NfseImportAction.values.firstWhere(
        (a) => a.name == value,
        orElse: () => NfseImportAction.create,
      );
}

String? _str(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int _int(Object? value) => value is num ? value.toInt() : 0;

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _list(Object? value) => [
  for (final item in (value is List ? value : const []))
    if (item is Map) Map<String, dynamic>.from(item),
];

class NfseImportStore {
  const NfseImportStore({required this.customerId, required this.customerName});

  final String customerId;
  final String customerName;

  factory NfseImportStore.fromJson(Map<String, dynamic> json) =>
      NfseImportStore(
        customerId: _str(json['customerId']) ?? '',
        customerName: _str(json['customerName']) ?? '',
      );
}

/// Everyone the CNPJ issued notas to, under one CPF/CNPJ.
class NfseImportGroup {
  const NfseImportGroup({
    required this.key,
    required this.legalName,
    required this.taxId,
    required this.action,
    required this.notas,
    this.customerId,
    this.customerName,
    this.stores = const [],
    this.links = 0,
  });

  final String key;
  final String legalName;
  final String taxId;
  final NfseImportAction action;
  final int notas;

  /// The existing customer it completes (or the one asked about).
  final String? customerId;
  final String? customerName;

  /// Stores that will send their notas to this customer ("Nota fiscal para").
  final List<NfseImportStore> stores;

  /// Notas that link to orders when this customer is confirmed.
  final int links;

  factory NfseImportGroup.fromJson(Map<String, dynamic> json) =>
      NfseImportGroup(
        key: _str(json['key']) ?? '',
        legalName: _str(json['legalName']) ?? '',
        taxId: _str(json['taxId']) ?? '',
        action: NfseImportAction.parse(json['action']),
        notas: _int(json['notas']),
        customerId: _str(json['customerId']),
        customerName: _str(json['customerName']),
        stores: _list(json['stores']).map(NfseImportStore.fromJson).toList(),
        links: _list(json['links']).length,
      );
}

/// A customer with a nota in almost every order: "Emitir sozinha" is offered.
class NfseImportAutoIssue {
  const NfseImportAutoIssue({
    required this.customerId,
    required this.customerName,
  });

  final String customerId;
  final String customerName;

  factory NfseImportAutoIssue.fromJson(Map<String, dynamic> json) =>
      NfseImportAutoIssue(
        customerId: _str(json['customerId']) ?? '',
        customerName: _str(json['customerName']) ?? '',
      );
}

/// The emitter as it will be after the import (current value, or the one to fill).
class NfseImportEmitter {
  const NfseImportEmitter({
    this.legalName,
    this.regime,
    this.municipalRegistration,
    this.service,
    this.dpsSeries,
  });

  final String? legalName;
  final FiscalRegime? regime;
  final String? municipalRegistration;
  final FiscalEmitterService? service;
  final String? dpsSeries;

  factory NfseImportEmitter.fromJson(Map<String, dynamic>? json) {
    final service = _map(json?['service']);
    final regime = json?['regime'];
    return NfseImportEmitter(
      legalName: _str(json?['legalName']),
      regime: regime == 'mei'
          ? FiscalRegime.mei
          : regime == 'simples'
          ? FiscalRegime.simples
          : null,
      municipalRegistration: _str(json?['municipalRegistration']),
      service: service == null
          ? null
          : FiscalEmitterService(
              nationalCode: _str(service['nationalCode']),
              municipalCode: _str(service['municipalCode']),
              name: _str(service['name']),
              issRate: (service['issRate'] as num?)?.toDouble(),
            ),
      dpsSeries: _str(json?['dpsSeries']),
    );
  }
}

class NfseImportProposal {
  const NfseImportProposal({
    required this.notas,
    required this.customers,
    required this.newCustomers,
    required this.completedCustomers,
    required this.linked,
    required this.historyOnly,
    required this.emitter,
    required this.groups,
    required this.autoIssue,
  });

  final int notas;
  final int customers;
  final int newCustomers;
  final int completedCustomers;
  final int linked;
  final int historyOnly;
  final NfseImportEmitter emitter;
  final List<NfseImportGroup> groups;
  final List<NfseImportAutoIssue> autoIssue;

  List<NfseImportGroup> get toAsk =>
      groups.where((g) => g.action == NfseImportAction.ask).toList();

  /// Groups whose CNPJ goes to one customer while other stores point to it.
  List<NfseImportGroup> get withStores =>
      groups.where((g) => g.stores.isNotEmpty).toList();

  factory NfseImportProposal.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['counts']) ?? const {};
    return NfseImportProposal(
      notas: _int(counts['notas']),
      customers: _int(counts['customers']),
      newCustomers: _int(counts['newCustomers']),
      completedCustomers: _int(counts['completedCustomers']),
      linked: _int(counts['linked']),
      historyOnly: _int(counts['historyOnly']),
      emitter: NfseImportEmitter.fromJson(_map(_map(json['emitter'])?['view'])),
      groups: _list(json['groups']).map(NfseImportGroup.fromJson).toList(),
      autoIssue: _list(
        json['autoIssue'],
      ).map(NfseImportAutoIssue.fromJson).toList(),
    );
  }
}

class NfseImportBatch extends BaseAuditCompany {
  NfseImportBatch({
    required String id,
    required this.emitterId,
    required this.status,
    this.documentsRead = 0,
    this.proposal,
    this.expiresAt,
  }) {
    this.id = id;
  }

  /// The batch id for the API calls (always set: it comes from the document).
  String get batchId => id ?? '';

  final String emitterId;
  final NfseImportStatus status;

  /// Documents read from the government so far (progress while reading).
  final int documentsRead;
  final NfseImportProposal? proposal;

  /// "Desfazer importação" is offered until then.
  final DateTime? expiresAt;

  bool canUndo({DateTime? now}) =>
      status == NfseImportStatus.applied &&
      expiresAt != null &&
      (now ?? DateTime.now()).isBefore(expiresAt!);

  factory NfseImportBatch.fromJson(Map<String, dynamic> json, {String? id}) {
    final proposal = _map(json['proposal']);
    return NfseImportBatch(
      id: id ?? _str(json['id']) ?? '',
      emitterId: _str(json['emitterId']) ?? '',
      status: NfseImportStatus.parse(json['status']),
      documentsRead: _int(_map(json['read'])?['documents']),
      proposal: proposal == null ? null : NfseImportProposal.fromJson(proposal),
      expiresAt: DateTime.tryParse(_str(json['expiresAt']) ?? ''),
    );
  }

  /// Written only by the server; kept for [BaseAuditCompany].
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'emitterId': emitterId,
    'status': status.name,
  };
}

/// An order offered in "Ligar a uma OS".
class NfseLinkCandidate {
  const NfseLinkCandidate({
    required this.id,
    this.number,
    this.customerName,
    this.value = 0,
    this.date,
    this.hasNota = false,
    this.sameCustomer = false,
  });

  final String id;
  final int? number;
  final String? customerName;
  final double value;
  final DateTime? date;
  final bool hasNota;
  final bool sameCustomer;

  factory NfseLinkCandidate.fromJson(Map<String, dynamic> json) =>
      NfseLinkCandidate(
        id: _str(json['id']) ?? '',
        number: (json['number'] as num?)?.toInt(),
        customerName: _str(json['customerName']),
        value: (json['value'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(_str(json['date']) ?? ''),
        hasNota: json['hasNota'] == true,
        sameCustomer: json['sameCustomer'] == true,
      );
}
