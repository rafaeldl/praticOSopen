// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$UserStore on _UserStore, Store {
  late final _$userAtom = Atom(name: '_UserStore.user', context: context);

  @override
  ObservableStream<User>? get user {
    _$userAtom.reportRead();
    return super.user;
  }

  @override
  set user(ObservableStream<User>? value) {
    _$userAtom.reportWrite(value, super.user, () {
      super.user = value;
    });
  }

  late final _$findCurrentUserAsyncAction = AsyncAction(
    '_UserStore.findCurrentUser',
    context: context,
  );

  @override
  Future findCurrentUser() {
    return _$findCurrentUserAsyncAction.run(() => super.findCurrentUser());
  }

  @override
  String toString() {
    return '''
user: ${user}
    ''';
  }
}
