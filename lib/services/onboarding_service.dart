import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/services/bootstrap_service.dart';
import 'package:praticos/services/claims_service.dart';

/// A business segment ("ramo") offered in the first access, read from
/// `/segments/{id}`.
class OnboardingSegment {
  const OnboardingSegment({
    required this.id,
    required this.name,
    this.nameI18n = const {},
    this.icon,
    this.subspecialties = const [],
    this.fieldServiceDefault = true,
    this.useFinancialDefault = true,
    this.termsOfServiceI18n = const {},
  });

  final String id;
  final String name;
  final Map<String, String> nameI18n;
  final String? icon;
  final List<OnboardingSubspecialty> subspecialties;

  /// Segment defaults applied to the new company (`Company.fieldService`,
  /// `Company.useFinancial`), same as `SegmentConfigService`.
  final bool fieldServiceDefault;
  final bool useFinancialDefault;
  final Map<String, String> termsOfServiceI18n;

  bool get hasSubspecialties => subspecialties.isNotEmpty;

  factory OnboardingSegment.fromMap(String id, Map<String, dynamic> data) {
    final subs = (data['subspecialties'] as List?) ?? const [];
    return OnboardingSegment(
      id: id,
      name: data['name'] as String? ?? id,
      nameI18n: _stringMap(data['nameI18n']),
      icon: data['icon'] as String?,
      subspecialties: [
        for (final s in subs)
          if (s is Map && s['id'] is String)
            OnboardingSubspecialty.fromMap(Map<String, dynamic>.from(s)),
      ],
      fieldServiceDefault: data['fieldService'] as bool? ?? true,
      useFinancialDefault: data['useFinancial'] as bool? ?? true,
      termsOfServiceI18n: _stringMap(data['defaultTermsOfService']),
    );
  }

  /// Name in [locale]: full tag (pt-BR), then the language, then [name].
  String nameFor(Locale locale) => _pick(nameI18n, locale) ?? name;

  /// Default terms of service for [localeTag] (pt-BR, en-US, es-ES).
  String? termsFor(String localeTag) =>
      termsOfServiceI18n[localeTag] ?? termsOfServiceI18n['pt-BR'];
}

/// A specialty inside a segment (e.g. "Funilaria" in "Mecânica").
class OnboardingSubspecialty {
  const OnboardingSubspecialty({
    required this.id,
    this.names = const {},
    this.icon,
  });

  final String id;
  final Map<String, String> names;
  final String? icon;

  factory OnboardingSubspecialty.fromMap(Map<String, dynamic> data) {
    final rawName = data['name'];
    return OnboardingSubspecialty(
      id: data['id'] as String,
      names: rawName is String ? {'pt-BR': rawName} : _stringMap(rawName),
      icon: data['icon'] as String?,
    );
  }

  String nameFor(Locale locale) =>
      _pick(names, locale) ?? (names.isNotEmpty ? names.values.first : id);
}

/// What the owner filled in the first access.
class OnboardingBusiness {
  const OnboardingBusiness({
    required this.segment,
    required this.subspecialties,
    required this.name,
    this.phone,
    required this.useFinancial,
  });

  final OnboardingSegment segment;

  /// Picked specialties. Empty means "none picked".
  final List<String> subspecialties;
  final String name;

  /// Optional: null when left blank.
  final String? phone;
  final bool useFinancial;

  /// Specialties used to import checklists and sample data. With none picked
  /// in a segment that has specialties, all of them are used, so the owner
  /// still gets examples (the segment's `_default` bootstrap may not exist).
  List<String> get seedSubspecialties =>
      subspecialties.isEmpty && segment.hasSubspecialties
          ? [for (final s in segment.subspecialties) s.id]
          : subspecialties;
}

/// Creates the company of the first access. Split in steps so a retry after
/// a failure reuses the company already saved instead of creating another.
abstract class OnboardingSetup {
  /// The owner started the setup (analytics only).
  void started();

  /// Creates the company (or completes the existing [companyId] that has no
  /// segment yet) and waits for the company claim. Returns the company id.
  Future<String> saveCompany(OnboardingBusiness data, {String? companyId});

  /// Imports the segment checklists and, with [withSamples], the sample
  /// services, products, devices, customer and orders.
  Future<void> seedCompany(
    String companyId,
    OnboardingBusiness data, {
    required bool withSamples,
  });

  /// Reloads the signed-in user and company before entering the app.
  Future<void> finish();
}

/// Active segments, ordered by name.
Stream<List<OnboardingSegment>> firestoreOnboardingSegments() {
  return FirebaseFirestore.instance
      .collection('segments')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              OnboardingSegment.fromMap(doc.id, doc.data()),
          ]);
}

/// [OnboardingSetup] over Firestore, using the same writes as the previous
/// onboarding (`UserStore.createCompanyForUser` -> `AuthService.signup`,
/// `CompanyStore.updateCompany`, `BootstrapService`). The only new field is
/// `Company.useFinancial`.
class FirebaseOnboardingSetup implements OnboardingSetup {
  FirebaseOnboardingSetup({required this.authStore});

  final AuthStore authStore;

  /// Locale tag of the sample data and checklists (pt-BR, en-US, es-ES).
  static String get deviceLocaleTag =>
      localeTagFor(PlatformDispatcher.instance.locale);

  @override
  void started() {
    AnalyticsService.instance.logTutorialBegin(variant: 'setup');
  }

  @override
  Future<String> saveCompany(
    OnboardingBusiness data, {
    String? companyId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No signed-in user');

    final userStore = UserStore();
    final dbUser = await userStore.findUserById(user.uid);
    if (dbUser == null) throw StateError('User document not found');
    final userAggr = dbUser.toAggr();
    final now = DateTime.now();

    if (companyId != null) {
      // Company exists without a segment: complete it, keep everything else.
      final companyStore = CompanyStore();
      final company = await companyStore.retrieveCompany(companyId);
      applyBusiness(company, data);
      company.updatedAt = now;
      company.updatedBy = userAggr;
      await companyStore.updateCompany(company);
      await ClaimsService.instance.waitForCompanyClaim(companyId);
      return companyId;
    }

    final newId = FirebaseFirestore.instance.collection('companies').doc().id;
    final company = Company()
      ..id = newId
      ..termsOfService = data.segment.termsFor(deviceLocaleTag)
      ..owner = userAggr
      ..createdAt = now
      ..createdBy = userAggr
      ..updatedAt = now
      ..updatedBy = userAggr;
    applyBusiness(company, data);

    await userStore.createCompanyForUser(company);
    AnalyticsService.instance.logCompanyCreated(
      companyId: newId,
      segment: data.segment.id,
    );
    // Claims first: sample data writes need them (permission denied otherwise).
    await ClaimsService.instance.waitForCompanyClaim(newId);
    return newId;
  }

  @override
  Future<void> seedCompany(
    String companyId,
    OnboardingBusiness data, {
    required bool withSamples,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No signed-in user');
    final dbUser = await UserStore().findUserById(user.uid);
    if (dbUser == null) throw StateError('User document not found');
    final userAggr = dbUser.toAggr();
    final locale = deviceLocaleTag;
    final subspecialties = data.seedSubspecialties;

    final bootstrap = BootstrapService();
    await bootstrap.syncCompanyFormsFromSegment(
      companyId: companyId,
      segmentId: data.segment.id,
      subspecialties: subspecialties,
      userAggr: userAggr,
      locale: locale,
    );
    if (withSamples) {
      final company = await CompanyStore().retrieveCompany(companyId);
      await bootstrap.executeBootstrap(
        companyId: companyId,
        segmentId: data.segment.id,
        subspecialties: subspecialties,
        userAggr: userAggr,
        companyAggr: company.toAggr(),
        locale: locale,
      );
    }
  }

  @override
  Future<void> finish() async {
    await authStore.reloadUserAndCompany();
    AnalyticsService.instance.logTutorialComplete();
  }
}

/// Writes the first-access answers on [company]. Scheduling stays on and
/// field service follows the segment, as the old "Quase lá" defaults did.
@visibleForTesting
void applyBusiness(Company company, OnboardingBusiness data) {
  final phone = data.phone?.trim();
  company
    ..name = data.name.trim()
    ..phone = (phone == null || phone.isEmpty) ? company.phone : phone
    ..segment = data.segment.id
    ..subspecialties =
        data.subspecialties.isEmpty ? null : List.of(data.subspecialties)
    ..fieldService = data.segment.fieldServiceDefault
    ..useScheduling = true
    ..useFinancial = data.useFinancial;
}

/// Maps a device locale to the tags used by segments and sample data.
String localeTagFor(Locale locale) {
  switch (locale.languageCode) {
    case 'pt':
      return 'pt-BR';
    case 'es':
      return 'es-ES';
    default:
      return 'en-US';
  }
}

String? _pick(Map<String, String> values, Locale locale) {
  if (values.isEmpty) return null;
  final full =
      '${locale.languageCode}-${locale.countryCode ?? locale.languageCode.toUpperCase()}';
  final exact = values[full];
  if (exact != null) return exact;
  for (final entry in values.entries) {
    if (entry.key.startsWith(locale.languageCode)) return entry.value;
  }
  return values['en-US'];
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key.toString(): entry.value as String,
  };
}
