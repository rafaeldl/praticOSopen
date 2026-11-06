import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_en.dart';
import 'package:praticos/l10n/app_localizations_es.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/segment_config_service.dart';

// "Software e TI" (docs/SEGMENT_SOFTWARE_IT.md): no machine words.
const _hardwareTerms = [
  'aparelho',
  'defeito',
  'veículo',
  'peça',
  'não liga',
  'device',
  'vehicle',
  'part',
  "won't turn on",
  'aparato',
  'vehículo',
  'repuesto',
  'no enciende',
];

List<String> _examples(AppLocalizations l10n) => [
  l10n.serviceNameHint('software_it'),
  l10n.productNameHint('software_it'),
  l10n.orderCustomerRequestPlaceholder('software_it'),
  l10n.checklistQuestionPlaceholder('software_it'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  tearDown(SegmentConfigService().clear);

  test('the examples speak of software, in the three languages', () {
    expect(AppLocalizationsPt().serviceNameHint('software_it'),
        'Ex.: Suporte técnico mensal');
    expect(AppLocalizationsPt().productNameHint('software_it'),
        'Ex.: Licença Microsoft 365');
    expect(AppLocalizationsEn().orderCustomerRequestPlaceholder('software_it'),
        "E.g.: report won't open");
    expect(AppLocalizationsEs().checklistQuestionPlaceholder('software_it'),
        'Ej.: ¿Se hizo la copia de seguridad?');

    for (final l10n in <AppLocalizations>[
      AppLocalizationsPt(),
      AppLocalizationsEn(),
      AppLocalizationsEs(),
    ]) {
      for (final text in _examples(l10n)) {
        for (final term in _hardwareTerms) {
          expect(text.toLowerCase().contains(term), isFalse,
              reason: '"$text" has "$term"');
        }
      }
    }
  });

  test('the device of the segment is a system, with a code icon', () {
    final provider = SegmentConfigProvider();
    final service = SegmentConfigService();
    service.setL10n(AppLocalizationsPt());
    service.debugSetSegment('software_it');
    // Same labels as segments/software_it in firebase/scripts/seed_segments.js
    service.debugSetCustomFields([
      for (final entry in {
        'device._entity': 'Sistema',
        'device.serial': 'Endereço',
        'product._entity': 'Licença',
      }.entries)
        CustomField.fromJson({
          'key': entry.key,
          'type': 'label',
          'labels': {'pt-BR': entry.value},
        }),
    ]);

    expect(provider.deviceIcon, CupertinoIcons.chevron_left_slash_chevron_right);
    expect(provider.label('device._entity'), 'Sistema');
    expect(provider.label('product._entity'), 'Licença');
    expect(provider.serialValue('erp.cliente.com.br'),
        'Endereço erp.cliente.com.br');
    expect(provider.serialLabelInSentence, 'endereço');
  });
}
