import 'package:mobx/mobx.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/v2/form_template_repository_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';

part 'form_template_store.g.dart';

class FormTemplateStore = _FormTemplateStore with _$FormTemplateStore;

abstract class _FormTemplateStore with Store {
  final FormTemplateRepositoryV2 repository = FormTemplateRepositoryV2();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<FormDefinition?>>? templateList;

  @observable
  bool isUploading = false;

  String? companyId;

  _FormTemplateStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
      retrieveTemplates();
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
}
