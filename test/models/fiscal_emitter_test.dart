import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/fiscal_emitter.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/payment_settings.dart';

// Synthetic data only (the repository is public).
Map<String, dynamic> _emitterJson({
  String status = 'active',
  String notAfter = '2027-03-12T00:00:00.000Z',
}) => {
  'id': 'e1',
  'taxId': '00000000000191',
  'legalName': 'OFICINA EXEMPLO LTDA',
  'regime': 'mei',
  'cityCode': '4200000',
  'cityName': 'Cidade Exemplo',
  'enabledInCity': true,
  'service': {
    'nationalCode': '140101',
    'name': 'Lubrificação, limpeza e revisão',
    'issRate': 2.5,
  },
  'descriptionStyle': {'uppercase': true, 'separator': ' - '},
  'dpsSeries': '10',
  'certificate': {
    'holderName': 'OFICINA EXEMPLO LTDA',
    'notAfter': notAfter,
    'uploadedAt': '2026-11-05T12:00:00.000Z',
    'uploadedBy': {'id': 'u1', 'name': 'Dono'},
    'status': status,
  },
  'totals': {
    'year': 2026,
    'yearValue': 52000,
    'month': 11,
    'monthValue': 3100.5,
  },
  'createdAt': '2026-11-05T12:00:00.000Z',
};

void main() {
  group('FiscalEmitter', () {
    test('reads what the server writes', () {
      final emitter = FiscalEmitter.fromJson(_emitterJson());
      expect(emitter.taxId, '00000000000191');
      expect(emitter.regime, FiscalRegime.mei);
      expect(emitter.isMei, isTrue);
      expect(emitter.service?.issRate, 2.5);
      expect(emitter.descriptionStyle?.uppercase, isTrue);
      expect(emitter.descriptionStyle?.separator, ' - ');
      expect(emitter.certificate?.status, FiscalCertificateStatus.active);
      expect(emitter.certificate?.uploadedBy?.name, 'Dono');
      expect(emitter.totals?.yearValue, 52000);
      expect(emitter.totals?.monthValue, 3100.5);
    });

    test('round-trips through JSON', () {
      final again = FiscalEmitter.fromJson(
        FiscalEmitter.fromJson(_emitterJson()).toJson(),
      );
      expect(again.toJson(), FiscalEmitter.fromJson(_emitterJson()).toJson());
    });

    test('toAggr keeps what the nota embeds', () {
      final aggr = FiscalEmitter.fromJson(_emitterJson()).toAggr();
      expect(aggr.toJson(), {
        'id': 'e1',
        'taxId': '00000000000191',
        'legalName': 'OFICINA EXEMPLO LTDA',
        'regime': 'mei',
      });
    });

    test('unknown regime or certificate status does not crash', () {
      final emitter = FiscalEmitter.fromJson({
        ..._emitterJson(status: 'revoked'),
        'regime': 'lucroPresumido',
      });
      expect(emitter.regime, FiscalRegime.simples);
      expect(emitter.certificate?.status, FiscalCertificateStatus.deleted);
      expect(emitter.certificateValid(now: DateTime.utc(2026, 11, 5)), isFalse);
    });

    test('certificate is valid only while active and before its end', () {
      final now = DateTime.utc(2026, 11, 5);
      expect(
        FiscalEmitter.fromJson(_emitterJson()).certificateValid(now: now),
        isTrue,
      );
      expect(
        FiscalEmitter.fromJson(
          _emitterJson(notAfter: '2026-11-01T00:00:00.000Z'),
        ).certificateValid(now: now),
        isFalse,
      );
      expect(
        FiscalEmitter.fromJson(
          _emitterJson(status: 'pending'),
        ).certificateValid(now: now),
        isFalse,
      );
      expect(FiscalEmitter().certificateValid(now: now), isFalse);
    });

    test('canIssue needs certificate, city and service', () {
      final now = DateTime.utc(2026, 11, 5);
      expect(FiscalEmitter.fromJson(_emitterJson()).canIssue(now: now), isTrue);
      expect(
        FiscalEmitter.fromJson({
          ..._emitterJson(),
          'enabledInCity': false,
        }).canIssue(now: now),
        isFalse,
      );
      expect(
        FiscalEmitter.fromJson({
          ..._emitterJson(),
          'service': null,
        }).canIssue(now: now),
        isFalse,
      );
    });

    test('missing optional fields get defaults', () {
      final emitter = FiscalEmitter.fromJson({'id': 'e2'});
      expect(emitter.enabledInCity, isFalse);
      expect(FiscalDescriptionStyle.fromJson({}).separator, ', ');
      expect(FiscalEmitterTotals.fromJson({}).yearValue, 0);
    });
  });

  group('FiscalAddress', () {
    test('is complete without the complement', () {
      final address = FiscalAddress(
        postalCode: '00000000',
        street: 'Rua Exemplo',
        number: '10',
        district: 'Centro',
        cityCode: '4200000',
        state: 'SC',
      );
      expect(address.isComplete, isTrue);
      expect((address..number = ' ').isComplete, isFalse);
    });
  });

  group('Customer data for the nota', () {
    test('round-trips the new fields', () {
      final customer = Customer.fromJson({
        'id': 'cu1',
        'name': 'Loja Centro',
        'taxId': '00000000000191',
        'legalName': 'REVENDA EXEMPLO LTDA',
        'fiscalAddress': {'postalCode': '00000000', 'street': 'Rua A'},
        'invoiceEmail': 'nota@example.com',
        'invoiceRecipient': {'id': 'cu2', 'name': 'Matriz'},
        'autoIssueInvoice': true,
        'lastEmitterId': 'e1',
      });
      final json = customer.toJson();
      expect(json['legalName'], 'REVENDA EXEMPLO LTDA');
      expect(json['fiscalAddress'], containsPair('street', 'Rua A'));
      expect(json['invoiceRecipient'], containsPair('id', 'cu2'));
      expect(json['autoIssueInvoice'], isTrue);
      expect(json['lastEmitterId'], 'e1');
    });

    test('never writes lastEmitterId as null (the server keeps it)', () {
      final json = Customer.fromJson({'id': 'cu1', 'name': 'X'}).toJson();
      expect(json.containsKey('lastEmitterId'), isFalse);
      // Clearing "Nota fiscal para" must reach Firestore (merge writes).
      expect(json.containsKey('invoiceRecipient'), isTrue);
      expect(json['invoiceRecipient'], isNull);
    });

    test('nota e-mail falls back to the customer e-mail', () {
      final customer = Customer()..email = 'loja@example.com';
      expect(customer.effectiveInvoiceEmail, 'loja@example.com');
      customer.invoiceEmail = ' nota@example.com ';
      expect(customer.effectiveInvoiceEmail, 'nota@example.com');
      expect(Customer().effectiveInvoiceEmail, isNull);
    });
  });

  group('NfseInvoice of the direct engine', () {
    test('reads provider, source, emitter, recipient and dps', () {
      final invoice = NfseInvoice.fromJson({
        'status': 'authorized',
        'provider': 'direct',
        'source': 'external',
        'value': 150,
        'number': '29',
        'emitter': {
          'id': 'e1',
          'taxId': '00000000000191',
          'legalName': 'OFICINA EXEMPLO LTDA',
          'regime': 'simples',
        },
        'recipient': {
          'customerId': 'cu2',
          'taxId': '00000000000272',
          'legalName': 'REVENDA EXEMPLO LTDA',
          'address': {'postalCode': '00000000', 'cityCode': '4200000'},
          'email': 'nota@example.com',
        },
        'dps': {
          'id': 'DPS42000000000000000019100010000000000000001',
          'series': '10',
          'number': 1,
        },
        'accessKey': '4200000200000000000191000000000000292611000000000',
        'xmlPath': 'tenants/c1/invoices/nf1/nfse.xml',
        'pdfPath': 'tenants/c1/invoices/nf1/nfse.pdf',
        'cancelReason': 'serviceNotProvided',
        'importBatchId': 'b1',
      }, id: 'nf1');
      expect(invoice.provider, NfseProvider.direct);
      expect(invoice.isExternal, isTrue);
      expect(invoice.emitter?.regime, FiscalRegime.simples);
      expect(invoice.recipient?.customerId, 'cu2');
      expect(invoice.recipient?.address?.cityCode, '4200000');
      expect(invoice.dps?.series, '10');
      expect(invoice.dps?.number, 1);
      expect(invoice.xmlPath, endsWith('nfse.xml'));
      expect(invoice.cancelReason, NfseCancelReason.serviceNotProvided);
      expect(invoice.importBatchId, 'b1');
      expect(invoice.isIssued, isTrue);
    });

    test('an Asaas nota reads as before', () {
      final invoice = NfseInvoice.fromJson({'status': 'authorized'}, id: 'a');
      expect(invoice.provider, NfseProvider.asaas);
      expect(invoice.source, NfseSource.praticos);
      expect(invoice.isExternal, isFalse);
      expect(invoice.emitter, isNull);
      expect(invoice.cancelReason, isNull);
    });
  });

  group('settings/nfse of the direct engine', () {
    test('reads provider, default emitter and the direct autoIssue', () {
      final settings = NfseServiceSettings.fromJson({
        'provider': 'direct',
        'defaultEmitterId': 'e1',
        'autoIssue': 'selectedCustomers',
      });
      expect(settings.provider, NfseProvider.direct);
      expect(settings.defaultEmitterId, 'e1');
      expect(settings.directAutoIssue, NfseDirectAutoIssue.selectedCustomers);
      // The Asaas reading of the same key stays manual.
      expect(settings.autoIssue, NfseAutoIssue.manual);
      // Direct fields are never sent back by the Asaas setup.
      expect(settings.toJson().containsKey('provider'), isFalse);
      expect(settings.copyWith().defaultEmitterId, 'e1');
    });

    test('Asaas values read as never in the direct engine', () {
      expect(NfseDirectAutoIssue.parse('completed'), NfseDirectAutoIssue.never);
      expect(NfseDirectAutoIssue.parse(null), NfseDirectAutoIssue.never);
      expect(NfseServiceSettings.fromJson({}).provider, NfseProvider.asaas);
    });

    test('pilot flag defaults to off', () {
      expect(PaymentSettings.fromJson({}).nfseDirectEnabled, isFalse);
      expect(
        PaymentSettings.fromJson({'nfseDirectEnabled': true}).nfseDirectEnabled,
        isTrue,
      );
    });
  });
}
