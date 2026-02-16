// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whatsapp_setup_banner_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WhatsAppSetupBannerStore on _WhatsAppSetupBannerStore, Store {
  late final _$isVisibleAtom = Atom(
    name: '_WhatsAppSetupBannerStore.isVisible',
    context: context,
  );

  @override
  bool get isVisible {
    _$isVisibleAtom.reportRead();
    return super.isVisible;
  }

  @override
  set isVisible(bool value) {
    _$isVisibleAtom.reportWrite(value, super.isVisible, () {
      super.isVisible = value;
    });
  }

  late final _$isWhatsAppLinkedAtom = Atom(
    name: '_WhatsAppSetupBannerStore.isWhatsAppLinked',
    context: context,
  );

  @override
  bool get isWhatsAppLinked {
    _$isWhatsAppLinkedAtom.reportRead();
    return super.isWhatsAppLinked;
  }

  @override
  set isWhatsAppLinked(bool value) {
    _$isWhatsAppLinkedAtom.reportWrite(value, super.isWhatsAppLinked, () {
      super.isWhatsAppLinked = value;
    });
  }

  late final _$checkVisibilityAsyncAction = AsyncAction(
    '_WhatsAppSetupBannerStore.checkVisibility',
    context: context,
  );

  @override
  Future<void> checkVisibility() {
    return _$checkVisibilityAsyncAction.run(() => super.checkVisibility());
  }

  late final _$dismissAsyncAction = AsyncAction(
    '_WhatsAppSetupBannerStore.dismiss',
    context: context,
  );

  @override
  Future<void> dismiss() {
    return _$dismissAsyncAction.run(() => super.dismiss());
  }

  late final _$_WhatsAppSetupBannerStoreActionController = ActionController(
    name: '_WhatsAppSetupBannerStore',
    context: context,
  );

  @override
  void updateLinkStatus(bool linked) {
    final _$actionInfo = _$_WhatsAppSetupBannerStoreActionController
        .startAction(name: '_WhatsAppSetupBannerStore.updateLinkStatus');
    try {
      return super.updateLinkStatus(linked);
    } finally {
      _$_WhatsAppSetupBannerStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isVisible: ${isVisible},
isWhatsAppLinked: ${isWhatsAppLinked}
    ''';
  }
}
