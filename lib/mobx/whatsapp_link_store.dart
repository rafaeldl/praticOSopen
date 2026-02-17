import 'package:mobx/mobx.dart';
import 'package:praticos/services/whatsapp_link_service.dart';

part 'whatsapp_link_store.g.dart';

class WhatsAppLinkStore = _WhatsAppLinkStore with _$WhatsAppLinkStore;

abstract class _WhatsAppLinkStore with Store {
  final WhatsAppLinkService _service = WhatsAppLinkService.instance;

  @observable
  bool isLoading = false;

  @observable
  bool isLinked = false;

  @observable
  String? linkedNumber;

  @observable
  DateTime? linkedAt;

  @observable
  WhatsAppLinkToken? currentToken;

  @observable
  String? error;

  /// Bot number from API, with constant fallback
  String get botNumber => WhatsAppLinkService.botNumber;

  @computed
  bool get hasToken => currentToken != null;

  /// Load the current WhatsApp link status
  @action
  Future<void> loadStatus() async {
    isLoading = true;
    error = null;

    try {
      final status = await _service.getStatus();
      isLinked = status.linked;
      linkedNumber = status.number;
      linkedAt = status.linkedAt;
    } on WhatsAppLinkException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  /// Generate a new linking token
  @action
  Future<WhatsAppLinkToken?> generateToken() async {
    isLoading = true;
    error = null;
    currentToken = null;

    try {
      final token = await _service.generateToken();
      currentToken = token;
      return token;
    } on WhatsAppLinkException catch (e) {
      error = e.message;
      return null;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isLoading = false;
    }
  }

  /// Unlink WhatsApp from the current user
  @action
  Future<bool> unlink() async {
    isLoading = true;
    error = null;

    try {
      await _service.unlink();
      isLinked = false;
      linkedNumber = null;
      linkedAt = null;
      currentToken = null;
      return true;
    } on WhatsAppLinkException catch (e) {
      error = e.message;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }

  /// Clear the current token (e.g., when closing the linking sheet)
  @action
  void clearToken() {
    currentToken = null;
  }

  /// Clear any errors
  @action
  void clearError() {
    error = null;
  }
}
