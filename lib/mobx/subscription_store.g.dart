// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SubscriptionStore on _SubscriptionStore, Store {
  Computed<Subscription?>? _$subscriptionComputed;

  @override
  Subscription? get subscription =>
      (_$subscriptionComputed ??= Computed<Subscription?>(
        () => super.subscription,
        name: '_SubscriptionStore.subscription',
      )).value;
  Computed<SubscriptionPlan>? _$effectivePlanComputed;

  @override
  SubscriptionPlan get effectivePlan =>
      (_$effectivePlanComputed ??= Computed<SubscriptionPlan>(
        () => super.effectivePlan,
        name: '_SubscriptionStore.effectivePlan',
      )).value;

  late final _$companyIdAtom = Atom(
    name: '_SubscriptionStore.companyId',
    context: context,
  );

  @override
  String? get companyId {
    _$companyIdAtom.reportRead();
    return super.companyId;
  }

  @override
  set companyId(String? value) {
    _$companyIdAtom.reportWrite(value, super.companyId, () {
      super.companyId = value;
    });
  }

  late final _$latestAtom = Atom(
    name: '_SubscriptionStore.latest',
    context: context,
  );

  @override
  Subscription? get latest {
    _$latestAtom.reportRead();
    return super.latest;
  }

  @override
  set latest(Subscription? value) {
    _$latestAtom.reportWrite(value, super.latest, () {
      super.latest = value;
    });
  }

  late final _$bindCompanyAsyncAction = AsyncAction(
    '_SubscriptionStore.bindCompany',
    context: context,
  );

  @override
  Future<void> bindCompany(String id) {
    return _$bindCompanyAsyncAction.run(() => super.bindCompany(id));
  }

  late final _$unbindAsyncAction = AsyncAction(
    '_SubscriptionStore.unbind',
    context: context,
  );

  @override
  Future<void> unbind() {
    return _$unbindAsyncAction.run(() => super.unbind());
  }

  late final _$_SubscriptionStoreActionController = ActionController(
    name: '_SubscriptionStore',
    context: context,
  );

  @override
  void applyCompanyDoc(Map<String, dynamic>? data) {
    final _$actionInfo = _$_SubscriptionStoreActionController.startAction(
      name: '_SubscriptionStore.applyCompanyDoc',
    );
    try {
      return super.applyCompanyDoc(data);
    } finally {
      _$_SubscriptionStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
companyId: ${companyId},
latest: ${latest},
subscription: ${subscription},
effectivePlan: ${effectivePlan}
    ''';
  }
}
