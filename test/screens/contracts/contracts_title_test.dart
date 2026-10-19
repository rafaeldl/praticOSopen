import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_en.dart';
import 'package:praticos/l10n/app_localizations_es.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/contracts/contracts_title.dart';

void main() {
  final pt = AppLocalizationsPt();

  test('keeps "Contratos" when orders have another name', () {
    expect(contractsTitle(pt, 'OS'), 'Contratos');
    expect(contractsTitle(pt, 'Ordens de Serviço'), 'Contratos');
  });

  test('renames when each order is already called Contrato', () {
    expect(contractsTitle(pt, 'Contratos'), 'Contratos que se repetem');
    expect(
      contractsTitle(AppLocalizationsEn(), 'Contracts'),
      'Recurring Contracts',
    );
    expect(
      contractsTitle(AppLocalizationsEs(), 'Contratos'),
      'Contratos que se repiten',
    );
  });
}
