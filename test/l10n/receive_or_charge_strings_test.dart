import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_en.dart';
import 'package:praticos/l10n/app_localizations_es.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';

void main() {
  final pt = AppLocalizationsPt();
  final en = AppLocalizationsEn();
  final es = AppLocalizationsEs();

  test('receive and charge labels exist in the three languages', () {
    expect(pt.receiveMarkReceived, 'Marcar como recebido');
    expect(en.receiveMarkReceived, 'Mark as received');
    expect(es.receiveMarkReceived, 'Marcar como cobrado');

    expect(pt.chargeSend, 'Mandar cobrança');
    expect(en.chargeSend, 'Send charge');
    expect(es.chargeSend, 'Enviar cobro');
  });

  test('summary and preview take their values', () {
    expect(pt.receiveSummaryCount(6), 'A receber · 6 OS');
    expect(pt.receiveSummaryCount(1), 'A receber · 1 OS');
    expect(en.receiveSummarySome(2, 6), 'To receive · 2 of 6 orders');
    expect(es.receiveSummarySome(2, 6), 'Por cobrar · 2 de 6 OS');

    expect(pt.receivePreviewAll(1), 'Quita a OS.');
    expect(pt.receivePreviewAll(3), 'Quita as 3 OS.');
    expect(en.receivePreviewAll(3), 'Settles the 3 orders.');
    expect(es.receivePreviewAll(3), 'Salda las 3 OS.');
  });
}
