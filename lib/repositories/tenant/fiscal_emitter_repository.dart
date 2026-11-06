import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// "Emitir sozinha quando concluir a OS" of the NFS-e direct (spec §4.1).
/// Same `autoIssue` key as the Asaas nota, with values of its own.
enum NfseDirectAutoIssue { never, selectedCustomers, allOrders }

/// What the app reads of `settings/nfse` for the NFS-e direct.
class NfseDirectSettings {
  const NfseDirectSettings({
    this.defaultEmitterId,
    this.autoIssue = NfseDirectAutoIssue.never,
    this.managerCanIssue = true,
    this.emailToCustomer = true,
  });

  final String? defaultEmitterId;
  final NfseDirectAutoIssue autoIssue;

  /// Whether managers issue and cancel notas (owner's choice; default yes).
  final bool managerCanIssue;

  /// Whether the nota goes to the customer's e-mail on its own (default yes).
  final bool emailToCustomer;

  /// Unknown or Asaas values ('manual', 'paid', 'completed') read as never.
  factory NfseDirectSettings.fromJson(Map<String, dynamic>? json) {
    final auto = json?['autoIssue'];
    return NfseDirectSettings(
      defaultEmitterId: json?['defaultEmitterId'] as String?,
      autoIssue: NfseDirectAutoIssue.values.firstWhere(
        (value) => value.name == auto,
        orElse: () => NfseDirectAutoIssue.never,
      ),
      managerCanIssue: json?['managerCanIssue'] != false,
      emailToCustomer: json?['emailToCustomer'] != false,
    );
  }
}

/// Read-only access to `/companies/{companyId}/fiscalEmitters` and the
/// NFS-e direct part of `settings/nfse`. Both are written only by the
/// server (the app saves through `NfseDirectApiService`); the writes of
/// [TenantRepository] are never used here.
class FiscalEmitterRepository extends TenantRepository<FiscalEmitter?> {
  static const String collectionName = 'fiscalEmitters';

  FiscalEmitterRepository() : super(collectionName);

  @override
  FiscalEmitter fromJson(Map<String, dynamic> data) =>
      FiscalEmitter.fromJson(data);

  @override
  Map<String, dynamic> toJson(FiscalEmitter? emitter) => emitter!.toJson();

  /// The company's emitters, by legal name.
  Stream<List<FiscalEmitter>> watchAll(String companyId) =>
      streamList(companyId).map((list) {
        final emitters = list.whereType<FiscalEmitter>().toList();
        emitters.sort(
          (a, b) => (a.legalName ?? '').toLowerCase().compareTo(
            (b.legalName ?? '').toLowerCase(),
          ),
        );
        return emitters;
      });

  Stream<NfseDirectSettings> watchSettings(String companyId) => firestore
      .collection('companies')
      .doc(companyId)
      .collection('settings')
      .doc('nfse')
      .snapshots()
      .map((snap) => NfseDirectSettings.fromJson(snap.data()));
}
