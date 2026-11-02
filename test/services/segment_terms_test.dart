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

const _carTerms = [
  'óleo',
  'frear',
  'pneu',
  'placa',
  'veículo',
  'oil',
  'brak',
  'tire',
  'plate',
  'vehicle',
  'aceite',
  'frenar',
  'neumático',
  'vehículo',
];

List<String> _examples(AppLocalizations l10n, String segment) => [
  l10n.serviceNameHint(segment),
  l10n.productNameHint(segment),
  l10n.orderCustomerRequestPlaceholder(segment),
  l10n.checklistQuestionPlaceholder(segment),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  tearDown(SegmentConfigService().clear);

  final languages = <AppLocalizations>[
    AppLocalizationsPt(),
    AppLocalizationsEn(),
    AppLocalizationsEs(),
  ];

  test('only automotive talks about cars, in the three languages', () {
    const segments = [
      'hvac',
      'smartphones',
      'computers',
      'appliances',
      'electrical',
      'plumbing',
      'security',
      'printers',
      'building_maintenance',
      'asset_maintenance',
      'public_works',
      'other',
      'a_new_segment',
    ];
    for (final l10n in languages) {
      for (final segment in segments) {
        for (final text in _examples(l10n, segment)) {
          for (final term in _carTerms) {
            expect(
              text.toLowerCase().contains(term),
              isFalse,
              reason: '$segment: "$text" has "$term"',
            );
          }
        }
      }
    }
  });

  test('automotive keeps its examples', () {
    final pt = AppLocalizationsPt();
    expect(pt.serviceNameHint('automotive'), 'Ex.: Troca de óleo');
    expect(
      pt.orderCustomerRequestPlaceholder('automotive'),
      'Ex.: barulho ao frear',
    );
    expect(pt.serviceNameHint('hvac'), 'Ex.: Limpeza do split');
  });

  test('segment for the examples: neutral when there is none', () {
    final service = SegmentConfigService();
    expect(service.exampleSegment, 'other');
    service.debugSetSegment('hvac');
    expect(service.exampleSegment, 'hvac');
  });

  test('the device icon follows the segment', () {
    final provider = SegmentConfigProvider();
    SegmentConfigService().debugSetSegment('hvac');
    expect(provider.deviceIcon, CupertinoIcons.snow);
    SegmentConfigService().debugSetSegment('automotive');
    expect(provider.deviceIcon, CupertinoIcons.car_detailed);
  });

  test('the serial is named as the segment names it', () {
    final provider = SegmentConfigProvider();
    final service = SegmentConfigService();
    service.setL10n(AppLocalizationsPt());
    expect(provider.serialValue('123'), 'Número de Série 123');
    expect(provider.serialLabelInSentence, 'número de série');

    service.debugSetCustomFields([
      CustomField.fromJson({
        'key': 'device.serial',
        'type': 'text',
        'labels': {'pt-BR': 'IMEI'},
      }),
    ]);
    expect(provider.serialValue('123'), 'IMEI 123');
    expect(provider.serialLabelInSentence, 'IMEI');
  });
}
