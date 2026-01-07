import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/v2/form_template_repository_v2.dart';
import 'package:praticos/repositories/segment/segment_form_template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';

part 'form_template_store.g.dart';

class FormTemplateStore = _FormTemplateStore with _$FormTemplateStore;

abstract class _FormTemplateStore with Store {
  final FormTemplateRepositoryV2 repository = FormTemplateRepositoryV2();
  final SegmentFormTemplateRepository segmentRepository = SegmentFormTemplateRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<FormDefinition?>>? templateList;

  @observable
  ObservableStream<List<FormDefinition>>? globalTemplateList;

  @observable
  bool isUploading = false;

  @observable
  bool isImporting = false;

  String? companyId;

  @observable
  String? segmentId;

  _FormTemplateStore() {
    SharedPreferences.getInstance().then((value) async {
      companyId = value.getString('companyId');
      print('[FormTemplateStore] companyId: $companyId');

      retrieveTemplates();

      // Busca o segmentId da company
      if (companyId != null) {
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          print('[FormTemplateStore] Company doc exists: ${companyDoc.exists}');

          if (companyDoc.exists) {
            final segment = companyDoc.data()?['segment'] as String?;
            print('[FormTemplateStore] segmentId from firestore: $segment');

            // Usa runInAction para garantir que a atualização seja observável
            runInAction(() {
              segmentId = segment;
              print('[FormTemplateStore] segmentId set to: $segmentId');
            });

            // Chama retrieveGlobalTemplates DEPOIS de setar o segmentId
            retrieveGlobalTemplates();
          }
        } catch (e) {
          print('[FormTemplateStore] Erro ao buscar segmentId: $e');
        }
      }
    });
  }

  @action
  retrieveTemplates() {
    if (companyId == null) {
      templateList = null;
      return;
    }
    templateList = repository.streamTemplates(companyId!).asObservable();
  }

  @action
  retrieveGlobalTemplates() {
    print('[FormTemplateStore] retrieveGlobalTemplates called. segmentId: $segmentId');
    if (segmentId == null) {
      print('[FormTemplateStore] segmentId is null, skipping global templates');
      globalTemplateList = null;
      return;
    }
    print('[FormTemplateStore] Streaming global templates for segment: $segmentId');
    globalTemplateList = segmentRepository.streamTemplates(segmentId!).asObservable();
  }

  @action
  Future<void> saveTemplate(FormDefinition template) async {
    if (companyId == null) return;
    template.createdAt = DateTime.now();
    template.updatedAt = DateTime.now();
    await repository.createItem(companyId!, template);
  }

  @action
  Future<void> updateTemplate(FormDefinition template) async {
    if (companyId == null) return;
    template.updatedAt = DateTime.now();
    await repository.updateItem(companyId!, template);
  }

  @action
  Future<void> deleteTemplate(FormDefinition template) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, template.id);
  }

  @action
  Future<void> toggleTemplateStatus(FormDefinition template) async {
    if (companyId == null) return;
    template.isActive = !template.isActive;
    template.updatedAt = DateTime.now();
    await repository.updateItem(companyId!, template);
  }

  /// Importa um formulário global (do segmento) para a empresa
  @action
  Future<void> importGlobalTemplate(FormDefinition globalTemplate) async {
    if (companyId == null) return;

    isImporting = true;

    try {
      // Cria uma cópia do template para a empresa
      final importedTemplate = FormDefinition(
        id: FirebaseFirestore.instance.collection('tmp').doc().id,
        title: globalTemplate.title,
        description: globalTemplate.description,
        isActive: globalTemplate.isActive,
        items: List.from(globalTemplate.items), // Cria uma cópia dos itens
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createItem(companyId!, importedTemplate);
    } finally {
      isImporting = false;
    }
  }
}
