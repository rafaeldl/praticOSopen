import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/order/reminder_hint.dart';

void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));

  test('says when the app will remind', () {
    expect(
      reminderHintText(pt, minutes: 30, blocked: false),
      'O app avisa 30 min antes.',
    );
    expect(
      reminderHintText(pt, minutes: 120, blocked: false),
      'O app avisa 2 horas antes.',
    );
  });

  test('never promises a reminder that will not come', () {
    expect(
      reminderHintText(pt, minutes: 0, blocked: false),
      'Lembrete desligado.',
    );
    expect(
      reminderHintText(pt, minutes: 30, blocked: true),
      'Os avisos estão desligados nos Ajustes do celular.',
    );
  });
}
