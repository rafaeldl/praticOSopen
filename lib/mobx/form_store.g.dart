// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic

mixin _$FormStore on _FormStore, Store {
  final _$availableFormsAtom = Atom(name: '_FormStore.availableForms');

  @override
  ObservableList<FormDefinition> get availableForms {
    _$availableFormsAtom.reportRead();
    return super.availableForms;
  }

  @override
  set availableForms(ObservableList<FormDefinition> value) {
    _$availableFormsAtom.reportWrite(value, super.availableForms, () {
      super.availableForms = value;
    });
  }

  final _$orderFormsAtom = Atom(name: '_FormStore.orderForms');

  @override
  ObservableList<OrderForm> get orderForms {
    _$orderFormsAtom.reportRead();
    return super.orderForms;
  }

  @override
  set orderForms(ObservableList<OrderForm> value) {
    _$orderFormsAtom.reportWrite(value, super.orderForms, () {
      super.orderForms = value;
    });
  }

  final _$isLoadingAtom = Atom(name: '_FormStore.isLoading');

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

  final _$errorMessageAtom = Atom(name: '_FormStore.errorMessage');

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

  final _$loadAvailableFormsAsyncAction =
      AsyncAction('_FormStore.loadAvailableForms');

  @override
  Future<void> loadAvailableForms() {
    return _$loadAvailableFormsAsyncAction
        .run(() => super.loadAvailableForms());
  }

  final _$loadOrderFormsAsyncAction = AsyncAction('_FormStore.loadOrderForms');

  @override
  Future<void> loadOrderForms(String orderId) {
    return _$loadOrderFormsAsyncAction.run(() => super.loadOrderForms(orderId));
  }

  final _$getOrLoadFormDefinitionAsyncAction =
      AsyncAction('_FormStore.getOrLoadFormDefinition');

  @override
  Future<FormDefinition?> getOrLoadFormDefinition(String templateId) {
    return _$getOrLoadFormDefinitionAsyncAction
        .run(() => super.getOrLoadFormDefinition(templateId));
  }

  final _$addFormToOrderAsyncAction = AsyncAction('_FormStore.addFormToOrder');

  @override
  Future<void> addFormToOrder(String orderId, FormDefinition template) {
    return _$addFormToOrderAsyncAction
        .run(() => super.addFormToOrder(orderId, template));
  }

  final _$saveFormResponseAsyncAction =
      AsyncAction('_FormStore.saveFormResponse');

  @override
  Future<void> saveFormResponse(String orderId, OrderForm form) {
    return _$saveFormResponseAsyncAction
        .run(() => super.saveFormResponse(orderId, form));
  }

  final _$uploadPhotoAsyncAction = AsyncAction('_FormStore.uploadPhoto');

  @override
  Future<String?> uploadPhoto(String orderId, String formId, File file) {
    return _$uploadPhotoAsyncAction.run(() => super.uploadPhoto(orderId, formId, file));
  }

  @override
  String toString() {
    return '''
availableForms: ${availableForms},
orderForms: ${orderForms},
isLoading: ${isLoading},
errorMessage: ${errorMessage}
    ''';
  }
}
