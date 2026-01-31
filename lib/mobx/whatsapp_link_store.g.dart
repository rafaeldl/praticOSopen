// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whatsapp_link_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WhatsAppLinkStore on _WhatsAppLinkStore, Store {
  Computed<bool>? _$hasTokenComputed;

  @override
  bool get hasToken => (_$hasTokenComputed ??= Computed<bool>(
    () => super.hasToken,
    name: '_WhatsAppLinkStore.hasToken',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_WhatsAppLinkStore.isLoading',
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

  late final _$isLinkedAtom = Atom(
    name: '_WhatsAppLinkStore.isLinked',
    context: context,
  );

  @override
  bool get isLinked {
    _$isLinkedAtom.reportRead();
    return super.isLinked;
  }

  @override
  set isLinked(bool value) {
    _$isLinkedAtom.reportWrite(value, super.isLinked, () {
      super.isLinked = value;
    });
  }

  late final _$linkedNumberAtom = Atom(
    name: '_WhatsAppLinkStore.linkedNumber',
    context: context,
  );

  @override
  String? get linkedNumber {
    _$linkedNumberAtom.reportRead();
    return super.linkedNumber;
  }

  @override
  set linkedNumber(String? value) {
    _$linkedNumberAtom.reportWrite(value, super.linkedNumber, () {
      super.linkedNumber = value;
    });
  }

  late final _$linkedAtAtom = Atom(
    name: '_WhatsAppLinkStore.linkedAt',
    context: context,
  );

  @override
  DateTime? get linkedAt {
    _$linkedAtAtom.reportRead();
    return super.linkedAt;
  }

  @override
  set linkedAt(DateTime? value) {
    _$linkedAtAtom.reportWrite(value, super.linkedAt, () {
      super.linkedAt = value;
    });
  }

  late final _$currentTokenAtom = Atom(
    name: '_WhatsAppLinkStore.currentToken',
    context: context,
  );

  @override
  WhatsAppLinkToken? get currentToken {
    _$currentTokenAtom.reportRead();
    return super.currentToken;
  }

  @override
  set currentToken(WhatsAppLinkToken? value) {
    _$currentTokenAtom.reportWrite(value, super.currentToken, () {
      super.currentToken = value;
    });
  }

  late final _$errorAtom = Atom(
    name: '_WhatsAppLinkStore.error',
    context: context,
  );

  @override
  String? get error {
    _$errorAtom.reportRead();
    return super.error;
  }

  @override
  set error(String? value) {
    _$errorAtom.reportWrite(value, super.error, () {
      super.error = value;
    });
  }

  late final _$loadStatusAsyncAction = AsyncAction(
    '_WhatsAppLinkStore.loadStatus',
    context: context,
  );

  @override
  Future<void> loadStatus() {
    return _$loadStatusAsyncAction.run(() => super.loadStatus());
  }

  late final _$generateTokenAsyncAction = AsyncAction(
    '_WhatsAppLinkStore.generateToken',
    context: context,
  );

  @override
  Future<WhatsAppLinkToken?> generateToken() {
    return _$generateTokenAsyncAction.run(() => super.generateToken());
  }

  late final _$unlinkAsyncAction = AsyncAction(
    '_WhatsAppLinkStore.unlink',
    context: context,
  );

  @override
  Future<bool> unlink() {
    return _$unlinkAsyncAction.run(() => super.unlink());
  }

  late final _$_WhatsAppLinkStoreActionController = ActionController(
    name: '_WhatsAppLinkStore',
    context: context,
  );

  @override
  void clearToken() {
    final _$actionInfo = _$_WhatsAppLinkStoreActionController.startAction(
      name: '_WhatsAppLinkStore.clearToken',
    );
    try {
      return super.clearToken();
    } finally {
      _$_WhatsAppLinkStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_WhatsAppLinkStoreActionController.startAction(
      name: '_WhatsAppLinkStore.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_WhatsAppLinkStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
isLinked: ${isLinked},
linkedNumber: ${linkedNumber},
linkedAt: ${linkedAt},
currentToken: ${currentToken},
error: ${error},
hasToken: ${hasToken}
    ''';
  }
}
