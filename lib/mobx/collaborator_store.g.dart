// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collaborator_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CollaboratorStore on _CollaboratorStore, Store {
  late final _$collaboratorsAtom = Atom(
    name: '_CollaboratorStore.collaborators',
    context: context,
  );

  @override
  ObservableList<Membership> get collaborators {
    _$collaboratorsAtom.reportRead();
    return super.collaborators;
  }

  @override
  set collaborators(ObservableList<Membership> value) {
    _$collaboratorsAtom.reportWrite(value, super.collaborators, () {
      super.collaborators = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_CollaboratorStore.isLoading',
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

  late final _$errorMessageAtom = Atom(
    name: '_CollaboratorStore.errorMessage',
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

  late final _$loadCollaboratorsAsyncAction = AsyncAction(
    '_CollaboratorStore.loadCollaborators',
    context: context,
  );

  @override
  Future<void> loadCollaborators() {
    return _$loadCollaboratorsAsyncAction.run(() => super.loadCollaborators());
  }

  late final _$addCollaboratorAsyncAction = AsyncAction(
    '_CollaboratorStore.addCollaborator',
    context: context,
  );

  @override
  Future<void> addCollaborator(String email, RolesType roleType) {
    return _$addCollaboratorAsyncAction.run(
      () => super.addCollaborator(email, roleType),
    );
  }

  late final _$updateCollaboratorRoleAsyncAction = AsyncAction(
    '_CollaboratorStore.updateCollaboratorRole',
    context: context,
  );

  @override
  Future<void> updateCollaboratorRole(String userId, RolesType newRoleType) {
    return _$updateCollaboratorRoleAsyncAction.run(
      () => super.updateCollaboratorRole(userId, newRoleType),
    );
  }

  late final _$removeCollaboratorAsyncAction = AsyncAction(
    '_CollaboratorStore.removeCollaborator',
    context: context,
  );

  @override
  Future<void> removeCollaborator(String userId) {
    return _$removeCollaboratorAsyncAction.run(
      () => super.removeCollaborator(userId),
    );
  }

  @override
  String toString() {
    return '''
collaborators: ${collaborators},
isLoading: ${isLoading},
errorMessage: ${errorMessage}
    ''';
  }
}
