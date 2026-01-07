// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_template_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$FormTemplateStore on _FormTemplateStore, Store {
  late final _$templateListAtom = Atom(
    name: '_FormTemplateStore.templateList',
    context: context,
  );

  @override
  ObservableStream<List<FormDefinition?>>? get templateList {
    _$templateListAtom.reportRead();
    return super.templateList;
  }

  @override
  set templateList(ObservableStream<List<FormDefinition?>>? value) {
    _$templateListAtom.reportWrite(value, super.templateList, () {
      super.templateList = value;
    });
  }

  late final _$isUploadingAtom = Atom(
    name: '_FormTemplateStore.isUploading',
    context: context,
  );

  @override
  bool get isUploading {
    _$isUploadingAtom.reportRead();
    return super.isUploading;
  }

  @override
  set isUploading(bool value) {
    _$isUploadingAtom.reportWrite(value, super.isUploading, () {
      super.isUploading = value;
    });
  }

  late final _$saveTemplateAsyncAction = AsyncAction(
    '_FormTemplateStore.saveTemplate',
    context: context,
  );

  @override
  Future<void> saveTemplate(FormDefinition template) {
    return _$saveTemplateAsyncAction.run(() => super.saveTemplate(template));
  }

  late final _$updateTemplateAsyncAction = AsyncAction(
    '_FormTemplateStore.updateTemplate',
    context: context,
  );

  @override
  Future<void> updateTemplate(FormDefinition template) {
    return _$updateTemplateAsyncAction.run(
      () => super.updateTemplate(template),
    );
  }

  late final _$deleteTemplateAsyncAction = AsyncAction(
    '_FormTemplateStore.deleteTemplate',
    context: context,
  );

  @override
  Future<void> deleteTemplate(FormDefinition template) {
    return _$deleteTemplateAsyncAction.run(
      () => super.deleteTemplate(template),
    );
  }

  late final _$toggleTemplateStatusAsyncAction = AsyncAction(
    '_FormTemplateStore.toggleTemplateStatus',
    context: context,
  );

  @override
  Future<void> toggleTemplateStatus(FormDefinition template) {
    return _$toggleTemplateStatusAsyncAction.run(
      () => super.toggleTemplateStatus(template),
    );
  }

  late final _$_FormTemplateStoreActionController = ActionController(
    name: '_FormTemplateStore',
    context: context,
  );

  @override
  dynamic retrieveTemplates() {
    final _$actionInfo = _$_FormTemplateStoreActionController.startAction(
      name: '_FormTemplateStore.retrieveTemplates',
    );
    try {
      return super.retrieveTemplates();
    } finally {
      _$_FormTemplateStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
templateList: ${templateList},
isUploading: ${isUploading}
    ''';
  }
}
