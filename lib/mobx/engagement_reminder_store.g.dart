// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engagement_reminder_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$EngagementReminderStore on _EngagementReminderStore, Store {
  late final _$dailyEnabledAtom = Atom(
    name: '_EngagementReminderStore.dailyEnabled',
    context: context,
  );

  @override
  bool get dailyEnabled {
    _$dailyEnabledAtom.reportRead();
    return super.dailyEnabled;
  }

  @override
  set dailyEnabled(bool value) {
    _$dailyEnabledAtom.reportWrite(value, super.dailyEnabled, () {
      super.dailyEnabled = value;
    });
  }

  late final _$inactivityEnabledAtom = Atom(
    name: '_EngagementReminderStore.inactivityEnabled',
    context: context,
  );

  @override
  bool get inactivityEnabled {
    _$inactivityEnabledAtom.reportRead();
    return super.inactivityEnabled;
  }

  @override
  set inactivityEnabled(bool value) {
    _$inactivityEnabledAtom.reportWrite(value, super.inactivityEnabled, () {
      super.inactivityEnabled = value;
    });
  }

  late final _$pendingOsEnabledAtom = Atom(
    name: '_EngagementReminderStore.pendingOsEnabled',
    context: context,
  );

  @override
  bool get pendingOsEnabled {
    _$pendingOsEnabledAtom.reportRead();
    return super.pendingOsEnabled;
  }

  @override
  set pendingOsEnabled(bool value) {
    _$pendingOsEnabledAtom.reportWrite(value, super.pendingOsEnabled, () {
      super.pendingOsEnabled = value;
    });
  }

  late final _$_loadPreferencesAsyncAction = AsyncAction(
    '_EngagementReminderStore._loadPreferences',
    context: context,
  );

  @override
  Future<void> _loadPreferences() {
    return _$_loadPreferencesAsyncAction.run(() => super._loadPreferences());
  }

  late final _$setDailyEnabledAsyncAction = AsyncAction(
    '_EngagementReminderStore.setDailyEnabled',
    context: context,
  );

  @override
  Future<void> setDailyEnabled(bool value) {
    return _$setDailyEnabledAsyncAction.run(() => super.setDailyEnabled(value));
  }

  late final _$setInactivityEnabledAsyncAction = AsyncAction(
    '_EngagementReminderStore.setInactivityEnabled',
    context: context,
  );

  @override
  Future<void> setInactivityEnabled(bool value) {
    return _$setInactivityEnabledAsyncAction.run(
      () => super.setInactivityEnabled(value),
    );
  }

  late final _$setPendingOsEnabledAsyncAction = AsyncAction(
    '_EngagementReminderStore.setPendingOsEnabled',
    context: context,
  );

  @override
  Future<void> setPendingOsEnabled(bool value) {
    return _$setPendingOsEnabledAsyncAction.run(
      () => super.setPendingOsEnabled(value),
    );
  }

  @override
  String toString() {
    return '''
dailyEnabled: ${dailyEnabled},
inactivityEnabled: ${inactivityEnabled},
pendingOsEnabled: ${pendingOsEnabled}
    ''';
  }
}
