import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/nfse.dart' hide NfseDirectAutoIssue;
import 'package:praticos/models/nfse_import.dart';
import 'package:praticos/repositories/tenant/fiscal_emitter_repository.dart';
import 'package:praticos/services/api_headers.dart';

/// Version of the certificate terms the app shows. Must match
/// `NFSE_CERTIFICATE_TERMS_VERSION` on the server (certificate-vault.service.ts).
const nfseCertificateTermsVersion = '2026-11-05';

/// Base URL of the `nfseApi` function: [appApiBaseUrl] with its trailing
/// `/api` swapped for `/nfseApi` (same rule as `accountApiBaseUrl`).
String get nfseApiBaseUrl => resolveNfseApiBaseUrl(appApiBaseUrl);

String resolveNfseApiBaseUrl(String apiBaseUrl) {
  const suffix = '/api';
  if (!apiBaseUrl.endsWith(suffix)) return apiBaseUrl;
  return '${apiBaseUrl.substring(0, apiBaseUrl.length - suffix.length)}/nfseApi';
}

/// Error from the NFS-e direct endpoints. [message] is diagnostic text and
/// never reaches the UI: map [code] with `nfseDirectErrorText`.
class NfseDirectApiException implements Exception {
  NfseDirectApiException(this.code, this.message, {this.details});

  final String? code;
  final String message;

  /// Extra data of the answer (`error.details`): the government's refusal,
  /// the emitter's problem, `usePortal`...
  final Map<String, dynamic>? details;

  /// The government's refusal in plain words (NFSE_REFUSED, CANCEL_REFUSED).
  NfseRefusal? get refusal => NfseRefusal.fromJson(details?['refusal']);

  @override
  String toString() => message;
}

/// Client for the NFS-e direct setup (`nfseApi`, docs/NFSE_DIRECT.md):
/// certificate upload, replace and delete, the emitter's lines and
/// settings/nfse. The certificate password only travels in the upload
/// request; the app never keeps it.
class NfseDirectApiService {
  NfseDirectApiService._(this._client, this._headersProvider, this._baseUrl);

  final http.Client _client;
  final Future<Map<String, String>> Function() _headersProvider;
  final String Function() _baseUrl;

  static final NfseDirectApiService instance = NfseDirectApiService._(
    http.Client(),
    () => appApiHeaders(),
    () => nfseApiBaseUrl,
  );

  /// Test seam.
  static NfseDirectApiService withClient(
    http.Client client, {
    required Future<Map<String, String>> Function() headersProvider,
    String baseUrl = 'https://test/nfseApi',
  }) => NfseDirectApiService._(client, headersProvider, () => baseUrl);

  static const _timeout = Duration(seconds: 60);

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final Map<String, String> headers;
    try {
      headers = {
        ...await _headersProvider(),
        'Content-Type': 'application/json',
      };
    } catch (_) {
      throw NfseDirectApiException('UNAUTHENTICATED', 'User not authenticated');
    }
    final request = http.Request(method, Uri.parse('${_baseUrl()}$path'))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw NfseDirectApiException('NETWORK_ERROR', 'Request timed out');
    } on http.ClientException catch (e) {
      throw NfseDirectApiException('NETWORK_ERROR', e.message);
    } on SocketException catch (e) {
      throw NfseDirectApiException('NETWORK_ERROR', e.message);
    }
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = decoded?['data'];
      return data is Map ? Map<String, dynamic>.from(data) : null;
    }
    final error = decoded?['error'];
    String? code = error is Map ? error['code'] as String? : null;
    code ??= switch (response.statusCode) {
      401 => 'UNAUTHENTICATED',
      403 => 'FORBIDDEN',
      429 => 'RATE_LIMIT_EXCEEDED',
      _ => null,
    };
    final details = error is Map ? error['details'] : null;
    throw NfseDirectApiException(
      code,
      'Request failed (${response.statusCode})',
      details: details is Map ? Map<String, dynamic>.from(details) : null,
    );
  }

  Map<String, dynamic> _upload(List<int> pfx, String password) => {
    'pfxBase64': base64Encode(pfx),
    'password': password,
    'termsVersion': nfseCertificateTermsVersion,
  };

  /// Adds a CNPJ from its A1 certificate; returns the new emitter's id.
  Future<String?> addCertificate(List<int> pfx, String password) async {
    final data = await _request(
      'POST',
      '/v1/app/nfse/emitters/certificate',
      _upload(pfx, password),
    );
    return (data?['emitterId'] ?? data?['id']) as String?;
  }

  /// Replaces the certificate of [emitterId] (same CNPJ).
  Future<void> replaceCertificate(
    String emitterId,
    List<int> pfx,
    String password,
  ) => _request(
    'PUT',
    '/v1/app/nfse/emitters/$emitterId/certificate',
    _upload(pfx, password),
  );

  /// Deletes the certificate of [emitterId] for good; the notas stay.
  Future<void> deleteCertificate(String emitterId) =>
      _request('DELETE', '/v1/app/nfse/emitters/$emitterId/certificate');

  Future<void> updateMunicipalRegistration(String emitterId, String? value) =>
      _request('PATCH', '/v1/app/nfse/setup/emitters/$emitterId', {
        'municipalRegistration': value,
      });

  Future<void> updateService(String emitterId, FiscalEmitterService service) =>
      _request('PATCH', '/v1/app/nfse/setup/emitters/$emitterId', {
        'service': {
          'nationalCode': service.nationalCode,
          if (service.municipalCode != null)
            'municipalCode': service.municipalCode,
          if (service.nbs != null) 'nbs': service.nbs,
          'name': service.name,
          'issRate': service.issRate ?? 0,
        },
      });

  Future<void> updateDescriptionStyle(
    String emitterId,
    FiscalDescriptionStyle style,
  ) => _request('PATCH', '/v1/app/nfse/setup/emitters/$emitterId', {
    'descriptionStyle': {
      'uppercase': style.uppercase,
      'separator': style.separator,
    },
  });

  Future<void> setDefaultEmitter(String emitterId) => _request(
    'PUT',
    '/v1/app/nfse/setup/settings',
    {'defaultEmitterId': emitterId},
  );

  Future<void> setAutoIssue(NfseDirectAutoIssue value) =>
      _request('PUT', '/v1/app/nfse/setup/settings', {'autoIssue': value.name});

  // ─── Issue, cancel, PDF (/v1/app/nfse/direct) ─────────────────────────

  /// What the nota of [orderIds] will have: the emitter marked
  /// ([emitterId] when the sheet changed it) and the recipient
  /// ([recipientCustomerId] when the sheet sent it elsewhere).
  Future<NfseDirectPreview> previewInvoice(
    List<String> orderIds, {
    String? emitterId,
    String? recipientCustomerId,
  }) async {
    final data =
        await _request('POST', '/v1/app/nfse/direct/invoices/preview', {
          'orderIds': orderIds,
          if (emitterId != null) 'emitterId': emitterId,
          if (recipientCustomerId != null)
            'recipientCustomerId': recipientCustomerId,
        });
    return NfseDirectPreview.fromJson(data ?? const {});
  }

  /// Issues the nota. Resolves with it `authorized` (the usual) or still
  /// `creating` when the government gave no clear answer; a refusal throws
  /// NFSE_REFUSED with [NfseDirectApiException.refusal].
  Future<NfseInvoice> issueInvoice(
    List<String> orderIds, {
    String? emitterId,
    String? description,
    String? recipientCustomerId,
    String? taxId,
    String? legalName,
    FiscalAddress? address,
    String? email,
  }) async {
    final recipient = <String, dynamic>{
      if (recipientCustomerId != null) 'customerId': recipientCustomerId,
      if (taxId != null) 'taxId': taxId,
      if (legalName != null) 'legalName': legalName,
      if (address != null)
        'address': {
          for (final e in address.toJson().entries)
            if (e.value != null) e.key: e.value,
        },
      if (email != null) 'email': email,
    };
    final data = await _request('POST', '/v1/app/nfse/direct/invoices', {
      'orderIds': orderIds,
      if (emitterId != null) 'emitterId': emitterId,
      if (description != null) 'description': description,
      if (recipient.isNotEmpty) 'recipient': recipient,
    });
    return NfseInvoice.fromJson(data ?? const {});
  }

  /// Cancels an issued direct nota; CANCEL_REFUSED (with `usePortal`) when
  /// the city does not take it.
  Future<NfseInvoice> cancelInvoice(
    String invoiceId,
    NfseCancelReason reason,
  ) async {
    final data = await _request(
      'POST',
      '/v1/app/nfse/direct/invoices/$invoiceId/cancel',
      {'reason': reason.name},
    );
    return NfseInvoice.fromJson(data ?? const {});
  }

  /// Asks the government now about a nota that got no clear answer.
  Future<NfseInvoice> reconcileInvoice(String invoiceId) async {
    final data = await _request(
      'POST',
      '/v1/app/nfse/direct/invoices/$invoiceId/reconcile',
    );
    return NfseInvoice.fromJson(data ?? const {});
  }

  /// "Enviar de novo": e-mails the nota (or the cancellation notice) to the
  /// customer now. Resolves with the result saved on the nota.
  Future<NfseEmailDelivery?> resendInvoiceEmail(String invoiceId) async {
    final data = await _request(
      'POST',
      '/v1/app/nfse/direct/invoices/$invoiceId/email',
    );
    return NfseEmailDelivery.fromJson(data?['emailDelivery']);
  }

  /// Makes the PDF (DANFSe) when needed; returns its Storage path.
  Future<String?> invoicePdfPath(String invoiceId) async {
    final data = await _request(
      'POST',
      '/v1/app/nfse/direct/invoices/$invoiceId/pdf',
    );
    return data?['pdfPath'] as String?;
  }

  // --------------------------------------------------------------------------
  // Import of the notas already issued (spec §4.3) and links to orders (§4.7)
  // --------------------------------------------------------------------------

  NfseImportBatch _batch(Map<String, dynamic>? data) {
    if (data == null) {
      throw NfseDirectApiException(null, 'Import answered without data');
    }
    return NfseImportBatch.fromJson(data);
  }

  /// Starts reading the emitter's notas in the government (or continues an
  /// import still open). The server reads for ~45 s per call.
  Future<NfseImportBatch> startImport(String emitterId) async => _batch(
    await _request('POST', '/v1/app/nfse/imports', {'emitterId': emitterId}),
  );

  /// Reads more; the proposal comes once everything was read.
  Future<NfseImportBatch> continueImport(String batchId) async =>
      _batch(await _request('POST', '/v1/app/nfse/imports/$batchId/continue'));

  /// "Importar": [sameCustomer] answers "Este é o mesmo cliente?" by group
  /// key; [autoIssueCustomerIds] turns "Emitir sozinha" on for them.
  Future<NfseImportBatch> applyImport(
    String batchId, {
    Map<String, bool> sameCustomer = const {},
    List<String> autoIssueCustomerIds = const [],
  }) async => _batch(
    await _request('POST', '/v1/app/nfse/imports/$batchId/apply', {
      'answers': {
        'sameCustomer': sameCustomer,
        'autoIssueCustomerIds': autoIssueCustomerIds,
      },
    }),
  );

  /// "Desfazer importação" (30 days).
  Future<NfseImportBatch> undoImport(String batchId) async =>
      _batch(await _request('POST', '/v1/app/nfse/imports/$batchId/undo'));

  /// Orders for "Ligar a uma OS", the likely ones first.
  Future<List<NfseLinkCandidate>> linkCandidates(String invoiceId) async {
    final data = await _request(
      'GET',
      '/v1/app/nfse/links/invoices/$invoiceId/candidates',
    );
    return [
      for (final o in (data?['orders'] as List? ?? const []))
        if (o is Map) NfseLinkCandidate.fromJson(Map<String, dynamic>.from(o)),
    ];
  }

  Future<void> linkInvoiceToOrder(String invoiceId, String orderId) => _request(
    'POST',
    '/v1/app/nfse/links/invoices/$invoiceId/link',
    {'orderId': orderId},
  );

  Future<void> unlinkInvoice(String invoiceId) =>
      _request('POST', '/v1/app/nfse/links/invoices/$invoiceId/unlink');

  /// Owner and admin: does the nota go to the customer's e-mail on its own.
  Future<void> setEmailToCustomer(bool value) => _request(
    'PUT',
    '/v1/app/nfse/setup/settings',
    {'emailToCustomer': value},
  );

  /// Owner only (the server refuses others with FORBIDDEN).
  Future<void> setManagerCanIssue(bool value) => _request(
    'PUT',
    '/v1/app/nfse/setup/settings',
    {'managerCanIssue': value},
  );
}
