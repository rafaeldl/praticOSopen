import 'dart:io';
import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/form/form_definition.dart';
import 'package:praticos/models/form/order_form.dart';
import 'package:praticos/repositories/form_repository.dart';
import 'package:praticos/services/photo_service.dart';

part 'form_store.g.dart';

class FormStore = _FormStore with _$FormStore;

abstract class _FormStore with Store {
  final FormRepository _repository = FormRepository();
  final PhotoService _photoService = PhotoService();

  @observable
  ObservableList<FormDefinition> availableForms = ObservableList<FormDefinition>();

  @observable
  ObservableList<OrderForm> orderForms = ObservableList<OrderForm>();

  @observable
  bool isLoading = false;

  @observable
  String? errorMessage;

  @action
  Future<void> loadAvailableForms() async {
    isLoading = true;
    errorMessage = null;
    try {
      final forms = await _repository.getAvailableForms();
      availableForms = ObservableList.of(forms);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadOrderForms(String orderId) async {
    isLoading = true;
    _repository.getOrderForms(orderId).listen((forms) {
      orderForms = ObservableList.of(forms);
      isLoading = false;
    }, onError: (e) {
      errorMessage = e.toString();
      isLoading = false;
    });
  }

  @action
  Future<FormDefinition?> getOrLoadFormDefinition(String templateId) async {
    // Check if already in availableForms
    try {
      final existing = availableForms.firstWhere((f) => f.id == templateId);
      return existing;
    } catch (_) {
      // Not found, fetch from repository
      isLoading = true;
      try {
        final definition = await _repository.getFormDefinition(templateId);
        if (definition != null) {
          // Optionally add to availableForms or just return it?
          // If we add it, we might mix active and inactive forms if the fetched one is inactive.
          // For now, just return it.
          return definition;
        }
      } catch (e) {
        errorMessage = e.toString();
      } finally {
        isLoading = false;
      }
    }
    return null;
  }

  @action
  Future<void> addFormToOrder(String orderId, FormDefinition template) async {
    isLoading = true;
    try {
      await _repository.addFormToOrder(orderId, template);
      // The stream listener will update the list
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> saveFormResponse(String orderId, OrderForm form) async {
    // Optimistic update
    int index = orderForms.indexWhere((f) => f.id == form.id);
    if (index != -1) {
      orderForms[index] = form;
    }

    try {
      await _repository.updateOrderForm(orderId, form);
    } catch (e) {
      errorMessage = e.toString();
      // Revert if needed, but for MVP we just show error
    }
  }

  @action
  Future<String?> uploadPhoto(String orderId, String formId, File file) async {
    isLoading = true;
    try {
      String? companyId = Global.companyAggr?.id;
      if (companyId == null) {
        throw Exception("Company ID not found");
      }

      final now = DateTime.now();
      final photoId = '${now.millisecondsSinceEpoch}-${now.microsecondsSinceEpoch % 1000000}';

      // Path: tenants/{companyId}/orders/{orderId}/forms/{formId}/photos/{photoId}.jpg
      String storagePath = 'tenants/$companyId/orders/$orderId/forms/$formId/photos/$photoId.jpg';

      String? url = await _photoService.uploadImage(file: file, storagePath: storagePath);
      return url;
    } catch (e) {
      errorMessage = e.toString();
      return null;
    } finally {
      isLoading = false;
    }
  }
}
