// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InviteStore on _InviteStore, Store {
  Computed<bool>? _$hasPendingInvitesComputed;

  @override
  bool get hasPendingInvites => (_$hasPendingInvitesComputed ??= Computed<bool>(
    () => super.hasPendingInvites,
    name: '_InviteStore.hasPendingInvites',
  )).value;

  late final _$pendingInvitesAtom = Atom(
    name: '_InviteStore.pendingInvites',
    context: context,
  );

  @override
  ObservableList<Invite> get pendingInvites {
    _$pendingInvitesAtom.reportRead();
    return super.pendingInvites;
  }

  @override
  set pendingInvites(ObservableList<Invite> value) {
    _$pendingInvitesAtom.reportWrite(value, super.pendingInvites, () {
      super.pendingInvites = value;
    });
  }

  late final _$isLoadingAtom = Atom(
    name: '_InviteStore.isLoading',
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
    name: '_InviteStore.errorMessage',
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

  late final _$loadPendingInvitesAsyncAction = AsyncAction(
    '_InviteStore.loadPendingInvites',
    context: context,
  );

  @override
  Future<void> loadPendingInvites() {
    return _$loadPendingInvitesAsyncAction.run(
      () => super.loadPendingInvites(),
    );
  }

  late final _$acceptInviteAsyncAction = AsyncAction(
    '_InviteStore.acceptInvite',
    context: context,
  );

  @override
  Future<void> acceptInvite(Invite invite) {
    return _$acceptInviteAsyncAction.run(() => super.acceptInvite(invite));
  }

  late final _$rejectInviteAsyncAction = AsyncAction(
    '_InviteStore.rejectInvite',
    context: context,
  );

  @override
  Future<void> rejectInvite(Invite invite) {
    return _$rejectInviteAsyncAction.run(() => super.rejectInvite(invite));
  }

  @override
  String toString() {
    return '''
pendingInvites: ${pendingInvites},
isLoading: ${isLoading},
errorMessage: ${errorMessage},
hasPendingInvites: ${hasPendingInvites}
    ''';
  }
}
