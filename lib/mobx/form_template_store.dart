import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/subscription.dart';
import 'package:praticos/repositories/v2/form_template_repository_v2.dart';
import 'package:praticos/repositories/segment/segment_form_template_repository.dart';
import 'package:praticos/services/feature_gate_service.dart';
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

      retrieveTemplates();

      // Busca o segmentId da company
      if (companyId != null) {
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            final segment = companyDoc.data()?['segment'] as String?;

            // Usa runInAction para garantir que a atualização seja observável
            runInAction(() {
              segmentId = segment;
            });

            // Chama retrieveGlobalTemplates DEPOIS de setar o segmentId
            retrieveGlobalTemplates();
          }
        } catch (e) {
          // Erro ao buscar segmentId
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
    if (segmentId == null) {
      globalTemplateList = null;
      return;
    }
    globalTemplateList = segmentRepository.streamTemplates(segmentId!).asObservable();
  }

  /// Cria um novo template.
  ///
  /// Verifica limite de formulários antes de criar. Se limite atingido,
  /// lança [FeatureGateLimitException].
  ///
  /// [subscription] - Assinatura a usar para verificação. Se null, usa Global.subscription.
  @action
  Future<void> saveTemplate(FormDefinition template, {Subscription? subscription}) async {
    if (companyId == null) return;

    // Verifica limite de formulários
    final sub = subscription ?? Global.subscription;
    final gateResult = FeatureGateService.canCreateFormTemplate(sub);
    if (!gateResult.isAllowed) {
      throw FeatureGateLimitException(gateResult);
    }

    template.createdAt = DateTime.now();
    template.updatedAt = DateTime.now();
    await repository.createItem(companyId!, template);

    // Atualiza contador de formulários
    await _updateFormTemplateCounter();
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

    // Atualiza contador de formulários
    await _updateFormTemplateCounter();
  }

  /// Ativa ou desativa um template.
  ///
  /// Ao ativar, verifica limite de formulários. Se limite atingido,
  /// lança [FeatureGateLimitException].
  ///
  /// [subscription] - Assinatura a usar para verificação. Se null, usa Global.subscription.
  @action
  Future<void> toggleTemplateStatus(FormDefinition template, {Subscription? subscription}) async {
    if (companyId == null) return;

    // Se estiver ativando, verifica limite
    if (!template.isActive) {
      final sub = subscription ?? Global.subscription;
      final gateResult = FeatureGateService.canCreateFormTemplate(sub);
      if (!gateResult.isAllowed) {
        throw FeatureGateLimitException(gateResult);
      }
    }

    template.isActive = !template.isActive;
    template.updatedAt = DateTime.now();
    await repository.updateItem(companyId!, template);

    // Atualiza contador de formulários
    await _updateFormTemplateCounter();
  }

  /// Importa um formulário global (do segmento) para a empresa.
  ///
  /// Verifica limite de formulários antes de importar. Se limite atingido,
  /// lança [FeatureGateLimitException].
  ///
  /// [subscription] - Assinatura a usar para verificação. Se null, usa Global.subscription.
  @action
  Future<void> importGlobalTemplate(FormDefinition globalTemplate, {Subscription? subscription}) async {
    if (companyId == null) return;

    // Verifica limite de formulários
    final sub = subscription ?? Global.subscription;
    final gateResult = FeatureGateService.canCreateFormTemplate(sub);
    if (!gateResult.isAllowed) {
      throw FeatureGateLimitException(gateResult);
    }

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

      // Atualiza contador de formulários
      await _updateFormTemplateCounter();
    } finally {
      isImporting = false;
    }
  }

  /// Atualiza o contador de formulários ativos no Firestore e local.
  ///
  /// Conta quantos templates ativos existem e atualiza:
  /// 1. Firestore: company.subscription.usage.formTemplates
  /// 2. Local: Global.subscription.usage.formTemplates
  Future<void> _updateFormTemplateCounter() async {
    if (companyId == null) return;

    try {
      // Conta templates ativos
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('formTemplates')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      final activeCount = snapshot.count ?? 0;

      // Atualiza no Firestore
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .update({
        'subscription.usage.formTemplates': activeCount,
      });

      // Atualiza local
      if (Global.subscription != null) {
        Global.subscription!.usage.formTemplates = activeCount;
      }
    } catch (e) {
      // Falha na atualização do contador não deve bloquear a operação
      // O contador será recalculado na próxima vez
    }
  }
}
