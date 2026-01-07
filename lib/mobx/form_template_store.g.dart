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

  late final _$globalTemplateListAtom = Atom(
    name: '_FormTemplateStore.globalTemplateList',
    context: context,
  );

  @override
  ObservableStream<List<FormDefinition>>? get globalTemplateList {
    _$globalTemplateListAtom.reportRead();
    return super.globalTemplateList;
  }

  @override
  set globalTemplateList(ObservableStream<List<FormDefinition>>? value) {
    _$globalTemplateListAtom.reportWrite(value, super.globalTemplateList, () {
      super.globalTemplateList = value;
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

  late final _$isImportingAtom = Atom(
    name: '_FormTemplateStore.isImporting',
    context: context,
  );

  @override
  bool get isImporting {
    _$isImportingAtom.reportRead();
    return super.isImporting;
  }

  @override
  set isImporting(bool value) {
    _$isImportingAtom.reportWrite(value, super.isImporting, () {
      super.isImporting = value;
    });
  }

  late final _$segmentIdAtom = Atom(
    name: '_FormTemplateStore.segmentId',
    context: context,
  );

  @override
  String? get segmentId {
    _$segmentIdAtom.reportRead();
    return super.segmentId;
  }

  @override
  set segmentId(String? value) {
    _$segmentIdAtom.reportWrite(value, super.segmentId, () {
      super.segmentId = value;
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

  late final _$importGlobalTemplateAsyncAction = AsyncAction(
    '_FormTemplateStore.importGlobalTemplate',
    context: context,
  );

  @override
  Future<void> importGlobalTemplate(FormDefinition globalTemplate) {
    return _$importGlobalTemplateAsyncAction.run(
      () => super.importGlobalTemplate(globalTemplate),
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
  dynamic retrieveGlobalTemplates() {
    final _$actionInfo = _$_FormTemplateStoreActionController.startAction(
      name: '_FormTemplateStore.retrieveGlobalTemplates',
    );
    try {
      return super.retrieveGlobalTemplates();
    } finally {
      _$_FormTemplateStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
templateList: ${templateList},
globalTemplateList: ${globalTemplateList},
isUploading: ${isUploading},
isImporting: ${isImporting},
segmentId: ${segmentId}
    ''';
  }
}
