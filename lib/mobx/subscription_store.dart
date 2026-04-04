import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide Store;
import 'package:praticos/services/subscription_service.dart';

part 'subscription_store.g.dart';

class SubscriptionStore = _SubscriptionStore with _$SubscriptionStore;

/// Gerenciador de instancia global do SubscriptionStore.
/// Usado para acesso em contextos sem Provider (ex: OrderStore).
class SubscriptionStoreHolder {
  static SubscriptionStore? instance;
}

/// Store MobX para gerenciar estado de assinaturas.
///
/// Responsavel por:
/// - Manter estado reativo da assinatura atual
/// - Carregar e atualizar informacoes do assinante
/// - Gerenciar fluxo de compra
/// - Expor computed properties para UI
abstract class _SubscriptionStore with Store {
  final SubscriptionService _service = SubscriptionService.instance;

  // ============================================================
  // OBSERVABLES
  // ============================================================

  /// Informacoes do assinante do RevenueCat
  @observable
  CustomerInfo? customerInfo;

  /// Ofertas/planos disponiveis
  @observable
  Offerings? offerings;

  /// Indica se esta carregando dados
  @observable
  bool isLoading = false;

  /// Indica se uma compra esta em progresso
  @observable
  bool isPurchasing = false;

  /// Mensagem de erro, se houver
  @observable
  String? errorMessage;

  // ============================================================
  // COMPUTED
  // ============================================================

  /// Plano atual do usuario: 'free', 'starter', 'pro', 'business'
  @computed
  String get currentPlan {
    if (customerInfo == null) return 'free';
    return _service.getPlanFromEntitlements(customerInfo!);
  }

  /// Verifica se o usuario tem um plano pago ativo
  @computed
  bool get hasPaidPlan => currentPlan != 'free';

  /// Verifica se esta em periodo de trial
  @computed
  bool get isInTrial {
    if (customerInfo == null) return false;
    return _service.isInTrial(customerInfo!);
  }

  /// Data de expiracao do plano atual
  @computed
  DateTime? get expirationDate {
    if (customerInfo == null) return null;
    return _service.getExpirationDate(customerInfo!);
  }

  /// Indica se a assinatura vai renovar automaticamente
  @computed
  bool get willRenew {
    if (customerInfo == null) return false;
    return _service.willRenew(customerInfo!);
  }

  /// Ofertas da "current offering" do RevenueCat
  @computed
  List<Package> get availablePackages {
    return offerings?.current?.availablePackages ?? [];
  }

  /// Pacote mensal, se disponivel
  @computed
  Package? get monthlyPackage => offerings?.current?.monthly;

  /// Pacote anual, se disponivel
  @computed
  Package? get annualPackage => offerings?.current?.annual;

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Inicializa o store carregando dados do assinante e ofertas.
  ///
  /// [userId] - ID do usuario/empresa para identificar no RevenueCat
  @action
  Future<void> initialize(String userId) async {
    isLoading = true;
    errorMessage = null;

    try {
      await _service.initialize(userId);
      await Future.wait([
        _loadCustomerInfo(),
        _loadOfferings(),
      ]);
    } catch (e, stack) {
      debugPrint('SubscriptionStore: Error initializing: $e\n$stack');
      errorMessage = 'Erro ao carregar informacoes de assinatura';
    } finally {
      isLoading = false;
    }
  }

  /// Recarrega informacoes do assinante.
  @action
  Future<void> refreshCustomerInfo() async {
    try {
      await _loadCustomerInfo();
    } catch (e) {
      debugPrint('SubscriptionStore: Error refreshing customer info: $e');
    }
  }

  /// Recarrega ofertas disponiveis.
  @action
  Future<void> refreshOfferings() async {
    try {
      await _loadOfferings();
    } catch (e) {
      debugPrint('SubscriptionStore: Error refreshing offerings: $e');
    }
  }

  /// Realiza a compra de um pacote.
  ///
  /// Retorna true se a compra foi bem-sucedida, false se cancelada ou erro.
  @action
  Future<bool> purchasePackage(Package package) async {
    isPurchasing = true;
    errorMessage = null;

    try {
      customerInfo = await _service.purchasePackage(package);
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // Usuario cancelou, nao e um erro
        debugPrint('SubscriptionStore: Purchase cancelled by user');
        return false;
      }
      errorMessage = 'Erro ao processar compra. Tente novamente.';
      return false;
    } catch (e, stack) {
      debugPrint('SubscriptionStore: Purchase error: $e\n$stack');
      errorMessage = 'Erro ao processar compra. Tente novamente.';
      return false;
    } finally {
      isPurchasing = false;
    }
  }

  /// Restaura compras anteriores.
  ///
  /// Retorna true se restaurou alguma assinatura, false caso contrario.
  @action
  Future<bool> restorePurchases() async {
    isLoading = true;
    errorMessage = null;

    try {
      final info = await _service.restorePurchases();
      customerInfo = info;

      final restored = _service.hasActivePlan(info);
      if (!restored) {
        errorMessage = 'Nenhuma assinatura encontrada para restaurar';
      }
      return restored;
    } catch (e, stack) {
      debugPrint('SubscriptionStore: Restore error: $e\n$stack');
      errorMessage = 'Erro ao restaurar compras. Tente novamente.';
      return false;
    } finally {
      isLoading = false;
    }
  }

  /// Limpa o estado ao fazer logout.
  @action
  Future<void> logout() async {
    await _service.logout();
    customerInfo = null;
    offerings = null;
    errorMessage = null;
  }

  /// Faz login com novo usuario.
  @action
  Future<void> logIn(String userId) async {
    isLoading = true;
    errorMessage = null;

    try {
      customerInfo = await _service.logIn(userId);
      await _loadOfferings();
    } catch (e, stack) {
      debugPrint('SubscriptionStore: Login error: $e\n$stack');
      errorMessage = 'Erro ao carregar assinatura';
    } finally {
      isLoading = false;
    }
  }

  /// Limpa mensagem de erro.
  @action
  void clearError() {
    errorMessage = null;
  }

  // ============================================================
  // HELPERS PRIVADOS
  // ============================================================

  Future<void> _loadCustomerInfo() async {
    customerInfo = await _service.getCustomerInfo();
    debugPrint('SubscriptionStore: Loaded customer info, plan: $currentPlan');
  }

  Future<void> _loadOfferings() async {
    offerings = await _service.getOfferings();
    debugPrint('SubscriptionStore: Loaded offerings, packages: ${availablePackages.length}');
  }
}
