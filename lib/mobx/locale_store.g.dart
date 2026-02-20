// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$LocaleStore on _LocaleStore, Store {
  Computed<String>? _$currentLocaleCodeComputed;

  @override
  String get currentLocaleCode =>
      (_$currentLocaleCodeComputed ??= Computed<String>(
        () => super.currentLocaleCode,
        name: '_LocaleStore.currentLocaleCode',
      )).value;
  Computed<String>? _$currentLocaleDisplayNameComputed;

  @override
  String get currentLocaleDisplayName =>
      (_$currentLocaleDisplayNameComputed ??= Computed<String>(
        () => super.currentLocaleDisplayName,
        name: '_LocaleStore.currentLocaleDisplayName',
      )).value;

  late final _$currentLocaleAtom = Atom(
    name: '_LocaleStore.currentLocale',
    context: context,
  );

  @override
  Locale get currentLocale {
    _$currentLocaleAtom.reportRead();
    return super.currentLocale;
  }

  @override
  set currentLocale(Locale value) {
    _$currentLocaleAtom.reportWrite(value, super.currentLocale, () {
      super.currentLocale = value;
    });
  }

  late final _$isLoadedAtom = Atom(
    name: '_LocaleStore.isLoaded',
    context: context,
  );

  @override
  bool get isLoaded {
    _$isLoadedAtom.reportRead();
    return super.isLoaded;
  }

  @override
  set isLoaded(bool value) {
    _$isLoadedAtom.reportWrite(value, super.isLoaded, () {
      super.isLoaded = value;
    });
  }

  late final _$loadAsyncAction = AsyncAction(
    '_LocaleStore.load',
    context: context,
  );

  @override
  Future<void> load() {
    return _$loadAsyncAction.run(() => super.load());
  }

  late final _$setLocaleAsyncAction = AsyncAction(
    '_LocaleStore.setLocale',
    context: context,
  );

  @override
  Future<void> setLocale(String localeCode) {
    return _$setLocaleAsyncAction.run(() => super.setLocale(localeCode));
  }

  late final _$syncFromFirestoreAsyncAction = AsyncAction(
    '_LocaleStore.syncFromFirestore',
    context: context,
  );

  @override
  Future<void> syncFromFirestore(String? firestoreLocale) {
    return _$syncFromFirestoreAsyncAction.run(
      () => super.syncFromFirestore(firestoreLocale),
    );
  }

  @override
  String toString() {
    return '''
currentLocale: ${currentLocale},
isLoaded: ${isLoaded},
currentLocaleCode: ${currentLocaleCode},
currentLocaleDisplayName: ${currentLocaleDisplayName}
    ''';
  }
}
