// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CompanyStore on _CompanyStore, Store {
  late final _$_CompanyStoreActionController = ActionController(
    name: '_CompanyStore',
    context: context,
  );

  late final _$addCollaboratorAsyncAction = AsyncAction(
    '_CompanyStore.addCollaborator',
    context: context,
  );

  @override
  Future<void> addCollaborator(String email, RolesType role) {
    return _$addCollaboratorAsyncAction
        .run(() => super.addCollaborator(email, role));
  }

  late final _$removeCollaboratorAsyncAction = AsyncAction(
    '_CompanyStore.removeCollaborator',
    context: context,
  );

  @override
  Future<void> removeCollaborator(String userId) {
    return _$removeCollaboratorAsyncAction
        .run(() => super.removeCollaborator(userId));
  }

  late final _$updateCollaboratorRoleAsyncAction = AsyncAction(
    '_CompanyStore.updateCollaboratorRole',
    context: context,
  );

  @override
  Future<void> updateCollaboratorRole(String userId, RolesType newRole) {
    return _$updateCollaboratorRoleAsyncAction
        .run(() => super.updateCollaboratorRole(userId, newRole));
  }

  late final _$updateCompanyAsyncAction = AsyncAction(
    '_CompanyStore.updateCompany',
    context: context,
  );

  @override
  Future<void> updateCompany(Company company) {
    return _$updateCompanyAsyncAction.run(() => super.updateCompany(company));
  }

  @override
  dynamic retrieveCompany(String? id) {
    final _$actionInfo = _$_CompanyStoreActionController.startAction(
      name: '_CompanyStore.retrieveCompany',
    );
    try {
      return super.retrieveCompany(id);
    } finally {
      _$_CompanyStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''

    ''';
  }
}
