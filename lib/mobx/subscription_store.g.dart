// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SubscriptionStore on _SubscriptionStore, Store {
  Computed<String>? _$currentPlanComputed;

  @override
  String get currentPlan => (_$currentPlanComputed ??= Computed<String>(
    () => super.currentPlan,
    name: '_SubscriptionStore.currentPlan',
  )).value;
  Computed<bool>? _$hasPaidPlanComputed;

  @override
  bool get hasPaidPlan => (_$hasPaidPlanComputed ??= Computed<bool>(
    () => super.hasPaidPlan,
    name: '_SubscriptionStore.hasPaidPlan',
  )).value;
  Computed<bool>? _$isInTrialComputed;

  @override
  bool get isInTrial => (_$isInTrialComputed ??= Computed<bool>(
    () => super.isInTrial,
    name: '_SubscriptionStore.isInTrial',
  )).value;
  Computed<DateTime?>? _$expirationDateComputed;

  @override
  DateTime? get expirationDate =>
      (_$expirationDateComputed ??= Computed<DateTime?>(
        () => super.expirationDate,
        name: '_SubscriptionStore.expirationDate',
      )).value;
  Computed<bool>? _$willRenewComputed;

  @override
  bool get willRenew => (_$willRenewComputed ??= Computed<bool>(
    () => super.willRenew,
    name: '_SubscriptionStore.willRenew',
  )).value;
  Computed<List<Package>>? _$availablePackagesComputed;

  @override
  List<Package> get availablePackages =>
      (_$availablePackagesComputed ??= Computed<List<Package>>(
        () => super.availablePackages,
        name: '_SubscriptionStore.availablePackages',
      )).value;
  Computed<Package?>? _$monthlyPackageComputed;

  @override
  Package? get monthlyPackage =>
      (_$monthlyPackageComputed ??= Computed<Package?>(
        () => super.monthlyPackage,
        name: '_SubscriptionStore.monthlyPackage',
      )).value;
  Computed<Package?>? _$annualPackageComputed;

  @override
  Package? get annualPackage => (_$annualPackageComputed ??= Computed<Package?>(
    () => super.annualPackage,
    name: '_SubscriptionStore.annualPackage',
  )).value;

  late final _$customerInfoAtom = Atom(
    name: '_SubscriptionStore.customerInfo',
    context: context,
  );

  @override
  CustomerInfo? get customerInfo {
    _$customerInfoAtom.reportRead();
    return super.customerInfo;
  }

  @override
  set customerInfo(CustomerInfo? value) {
    _$customerInfoAtom.reportWrite(value, super.customerInfo, () {
      super.customerInfo = value;
    });
  }

  late final _$offeringsAtom = Atom(
    name: '_SubscriptionStore.offerings',
    context: context,
  );

  @override
  Offerings? get offerings {
    _$offeringsAtom.reportRead();
    return super.offerings;
  }

  @override
  set offerings(Offerings? value) {
    _$offeringsAtom.reportWrite(value, super.offerings, () {
      super.offerings = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_SubscriptionStore.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$isPurchasingAtom = Atom(
    name: '_SubscriptionStore.isPurchasing',
    context: context,
  );

  @override
  bool get isPurchasing {
    _$isPurchasingAtom.reportRead();
    return super.isPurchasing;
  }

  @override
  set isPurchasing(bool value) {
    _$isPurchasingAtom.reportWrite(value, super.isPurchasing, () {
      super.isPurchasing = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_SubscriptionStore.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$initializeAsyncAction = AsyncAction(
    '_SubscriptionStore.initialize',
    context: context,
  );

  @override
  Future<void> initialize(String userId) {
    return _$initializeAsyncAction.run(() => super.initialize(userId));
  }

  late final _$refreshCustomerInfoAsyncAction = AsyncAction(
    '_SubscriptionStore.refreshCustomerInfo',
    context: context,
  );

  @override
  Future<void> refreshCustomerInfo() {
    return _$refreshCustomerInfoAsyncAction.run(
      () => super.refreshCustomerInfo(),
    );
  }

  late final _$refreshOfferingsAsyncAction = AsyncAction(
    '_SubscriptionStore.refreshOfferings',
    context: context,
  );

  @override
  Future<void> refreshOfferings() {
    return _$refreshOfferingsAsyncAction.run(() => super.refreshOfferings());
  }

  late final _$purchasePackageAsyncAction = AsyncAction(
    '_SubscriptionStore.purchasePackage',
    context: context,
  );

  @override
  Future<bool> purchasePackage(Package package) {
    return _$purchasePackageAsyncAction.run(
      () => super.purchasePackage(package),
    );
  }

  late final _$restorePurchasesAsyncAction = AsyncAction(
    '_SubscriptionStore.restorePurchases',
    context: context,
  );

  @override
  Future<bool> restorePurchases() {
    return _$restorePurchasesAsyncAction.run(() => super.restorePurchases());
  }

  late final _$logoutAsyncAction = AsyncAction(
    '_SubscriptionStore.logout',
    context: context,
  );

  @override
  Future<void> logout() {
    return _$logoutAsyncAction.run(() => super.logout());
  }

  late final _$logInAsyncAction = AsyncAction(
    '_SubscriptionStore.logIn',
    context: context,
  );

  @override
  Future<void> logIn(String userId) {
    return _$logInAsyncAction.run(() => super.logIn(userId));
  }

  late final _$_SubscriptionStoreActionController = ActionController(
    name: '_SubscriptionStore',
    context: context,
  );

  @override
  void clearError() {
    final _$actionInfo = _$_SubscriptionStoreActionController.startAction(
      name: '_SubscriptionStore.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_SubscriptionStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
customerInfo: ${customerInfo},
offerings: ${offerings},
isLoading: ${isLoading},
isPurchasing: ${isPurchasing},
errorMessage: ${errorMessage},
currentPlan: ${currentPlan},
hasPaidPlan: ${hasPaidPlan},
isInTrial: ${isInTrial},
expirationDate: ${expirationDate},
willRenew: ${willRenew},
availablePackages: ${availablePackages},
monthlyPackage: ${monthlyPackage},
annualPackage: ${annualPackage}
    ''';
  }
}
