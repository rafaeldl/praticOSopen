import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/onboarding_service.dart';

const segment = OnboardingSegment(
  id: 'automotive',
  name: 'Automotive',
  fieldServiceDefault: false,
  subspecialties: [
    OnboardingSubspecialty(id: 'mechanical'),
    OnboardingSubspecialty(id: 'carwash'),
  ],
);

OnboardingBusiness business({
  List<String> subs = const [],
  String? phone,
  bool useFinancial = true,
  OnboardingSegment seg = segment,
}) =>
    OnboardingBusiness(
      segment: seg,
      subspecialties: subs,
      name: ' Oficina do Zé ',
      phone: phone,
      useFinancial: useFinancial,
    );

void main() {
  group('OnboardingSegment.fromMap', () {
    test('reads name, icon, specialties and defaults', () {
      final s = OnboardingSegment.fromMap('hvac', {
        'name': 'Refrigeração',
        'nameI18n': {'pt-BR': 'Refrigeração', 'en-US': 'HVAC'},
        'icon': '❄️',
        'fieldService': false,
        'useFinancial': false,
        'defaultTermsOfService': {'pt-BR': 'Termos', 'en-US': 'Terms'},
        'subspecialties': [
          {
            'id': 'split',
            'name': {'pt-BR': 'Split', 'en-US': 'Split AC'},
            'icon': '🌀',
          },
          {'name': 'sem id'},
        ],
      });
      expect(s.nameFor(const Locale('en', 'US')), 'HVAC');
      expect(s.nameFor(const Locale('pt')), 'Refrigeração');
      expect(s.icon, '❄️');
      expect(s.fieldServiceDefault, isFalse);
      expect(s.useFinancialDefault, isFalse);
      expect(s.termsFor('es-ES'), 'Termos'); // falls back to pt-BR
      expect(s.subspecialties.map((e) => e.id), ['split']);
      expect(s.subspecialties.single.nameFor(const Locale('en', 'US')),
          'Split AC');
    });

    test('missing fields keep the old defaults (true)', () {
      final s = OnboardingSegment.fromMap('other', {'name': 'Outro'});
      expect(s.fieldServiceDefault, isTrue);
      expect(s.useFinancialDefault, isTrue);
      expect(s.hasSubspecialties, isFalse);
      expect(s.nameFor(const Locale('pt', 'BR')), 'Outro');
    });
  });

  group('applyBusiness', () {
    test('writes the same fields as before plus useFinancial', () {
      final company = Company();
      applyBusiness(
        company,
        business(subs: ['carwash'], phone: ' 11 99999-0000 ', useFinancial: false),
      );
      expect(company.name, 'Oficina do Zé');
      expect(company.phone, '11 99999-0000');
      expect(company.segment, 'automotive');
      expect(company.subspecialties, ['carwash']);
      expect(company.fieldService, isFalse); // segment default
      expect(company.useScheduling, isTrue);
      expect(company.useFinancial, isFalse);
    });

    test('blank phone keeps the existing one; no specialties is null', () {
      final company = Company()
        ..phone = '1234'
        ..address = 'Rua A'
        ..logo = 'logo.png';
      applyBusiness(company, business(phone: '   '));
      expect(company.phone, '1234');
      expect(company.subspecialties, isNull);
      // fields the first access no longer asks are untouched
      expect(company.address, 'Rua A');
      expect(company.logo, 'logo.png');
      expect(company.toJson()['useFinancial'], isTrue);
    });
  });

  group('seedSubspecialties', () {
    test('uses the picked ones', () {
      expect(business(subs: ['carwash']).seedSubspecialties, ['carwash']);
    });

    test('none picked in a segment with specialties uses all of them', () {
      expect(business().seedSubspecialties, ['mechanical', 'carwash']);
    });

    test('segment without specialties stays empty (_default bootstrap)', () {
      const plain = OnboardingSegment(id: 'other', name: 'Outro');
      expect(business(seg: plain).seedSubspecialties, isEmpty);
    });
  });

  test('localeTagFor maps to the sample-data locales', () {
    expect(localeTagFor(const Locale('pt', 'PT')), 'pt-BR');
    expect(localeTagFor(const Locale('es')), 'es-ES');
    expect(localeTagFor(const Locale('fr', 'FR')), 'en-US');
  });
}
