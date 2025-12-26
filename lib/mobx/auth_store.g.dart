// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AuthStore on _AuthStore, Store {
  late final _$currentUserAtom = Atom(
    name: '_AuthStore.currentUser',
    context: context,
  );

  @override
  ObservableStream<User?>? get currentUser {
    _$currentUserAtom.reportRead();
    return super.currentUser;
  }

  @override
  set currentUser(ObservableStream<User?>? value) {
    _$currentUserAtom.reportWrite(value, super.currentUser, () {
      super.currentUser = value;
    });
  }

  late final _$companyAggrAtom = Atom(
    name: '_AuthStore.companyAggr',
    context: context,
  );

  @override
  CompanyAggr? get companyAggr {
    _$companyAggrAtom.reportRead();
    return super.companyAggr;
  }

  @override
  set companyAggr(CompanyAggr? value) {
    _$companyAggrAtom.reportWrite(value, super.companyAggr, () {
      super.companyAggr = value;
    });
  }

  late final _$switchCompanyAsyncAction = AsyncAction(
    '_AuthStore.switchCompany',
    context: context,
  );

  @override
  Future<void> switchCompany(String companyId) {
    return _$switchCompanyAsyncAction.run(() => super.switchCompany(companyId));
  }

  late final _$signOutGoogleAsyncAction = AsyncAction(
    '_AuthStore.signOutGoogle',
    context: context,
  );

  @override
  Future signOutGoogle() {
    return _$signOutGoogleAsyncAction.run(() => super.signOutGoogle());
  }

  late final _$_AuthStoreActionController = ActionController(
    name: '_AuthStore',
    context: context,
  );

  @override
  dynamic signInWithGoogle() {
    final _$actionInfo = _$_AuthStoreActionController.startAction(
      name: '_AuthStore.signInWithGoogle',
    );
    try {
      return super.signInWithGoogle();
    } finally {
      _$_AuthStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
currentUser: ${currentUser},
companyAggr: ${companyAggr}
    ''';
  }
}
