import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Servico de assinaturas usando RevenueCat.
///
/// Responsavel por:
/// - Inicializar o SDK RevenueCat
/// - Buscar informacoes do assinante
/// - Listar ofertas/planos disponiveis
/// - Realizar compras
/// - Restaurar compras
/// - Determinar plano atual baseado em entitlements
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  SubscriptionService._();

  /// API Keys do RevenueCat (configuradas via --dart-define)
  static const _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );
  static const _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );

  bool _isInitialized = false;

  /// Inicializa o RevenueCat SDK.
  ///
  /// Deve ser chamado apos autenticacao, passando o userId (ou companyId)
  /// como appUserId para vincular assinaturas ao usuario.
  ///
  /// [userId] - ID do usuario ou empresa para vincular assinaturas
  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      debugPrint('SubscriptionService: Already initialized, updating appUserId');
      await Purchases.logIn(userId);
      return;
    }

    final apiKey = _getApiKey();
    if (apiKey.isEmpty) {
      debugPrint('SubscriptionService: No API key configured, skipping initialization');
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
      await Purchases.configure(configuration);
      _isInitialized = true;
      debugPrint('SubscriptionService: Initialized successfully for user $userId');
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error initializing: $e\n$stack');
      rethrow;
    }
  }

  /// Retorna a API key apropriada para a plataforma atual.
  String _getApiKey() {
    if (kIsWeb) return '';
    if (Platform.isIOS) return _iosApiKey;
    if (Platform.isAndroid) return _androidApiKey;
    return '';
  }

  /// Busca informacoes do assinante atual.
  ///
  /// Retorna [CustomerInfo] com entitlements ativos, datas de expiracao, etc.
  Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Busca ofertas/planos disponiveis para compra.
  ///
  /// Retorna [Offerings] com os pacotes configurados no RevenueCat.
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('SubscriptionService: Fetched offerings: ${offerings.current?.identifier}');
      return offerings;
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error fetching offerings: $e\n$stack');
      rethrow;
    }
  }

  /// Realiza a compra de um pacote.
  ///
  /// [package] - Pacote a ser comprado (obtido via getOfferings)
  /// Retorna [CustomerInfo] atualizado apos a compra.
  ///
  /// Throws [PurchasesErrorCode.purchaseCancelledError] se o usuario cancelar.
  Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      debugPrint('SubscriptionService: Purchasing package ${package.identifier}');
      final customerInfo = await Purchases.purchasePackage(package);
      debugPrint('SubscriptionService: Purchase successful');
      return customerInfo;
    } on PurchasesErrorCode catch (e) {
      debugPrint('SubscriptionService: Purchase error: $e');
      rethrow;
    }
  }

  /// Restaura compras anteriores.
  ///
  /// Util para usuarios que reinstalaram o app ou trocaram de dispositivo.
  /// Retorna [CustomerInfo] com assinaturas restauradas.
  Future<CustomerInfo> restorePurchases() async {
    try {
      debugPrint('SubscriptionService: Restoring purchases');
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('SubscriptionService: Restore completed');
      return customerInfo;
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error restoring purchases: $e\n$stack');
      rethrow;
    }
  }

  /// Determina o plano atual baseado nos entitlements ativos.
  ///
  /// Retorna: 'business', 'pro', 'starter', ou 'free'
  /// Prioriza planos maiores (business > pro > starter).
  String getPlanFromEntitlements(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    // Verifica do maior para o menor plano
    if (entitlements.containsKey('business')) return 'business';
    if (entitlements.containsKey('pro')) return 'pro';
    if (entitlements.containsKey('starter')) return 'starter';

    return 'free';
  }

  /// Verifica se o usuario tem um plano ativo (nao-free).
  bool hasActivePlan(CustomerInfo info) {
    return getPlanFromEntitlements(info) != 'free';
  }

  /// Retorna a data de expiracao do plano atual, se houver.
  DateTime? getExpirationDate(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    // Busca a expiracao do entitlement ativo de maior prioridade
    for (final key in ['business', 'pro', 'starter']) {
      if (entitlements.containsKey(key)) {
        final expDateStr = entitlements[key]?.expirationDate;
        if (expDateStr != null) {
          return DateTime.tryParse(expDateStr);
        }
        return null;
      }
    }

    return null;
  }

  /// Verifica se o plano esta em periodo de trial.
  bool isInTrial(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    for (final key in ['business', 'pro', 'starter']) {
      if (entitlements.containsKey(key)) {
        final periodType = entitlements[key]?.periodType;
        return periodType == PeriodType.trial;
      }
    }

    return false;
  }

  /// Verifica se a assinatura foi cancelada (mas ainda ativa ate expirar).
  bool willRenew(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    for (final key in ['business', 'pro', 'starter']) {
      if (entitlements.containsKey(key)) {
        return entitlements[key]?.willRenew ?? false;
      }
    }

    return false;
  }

  /// Faz logout do usuario atual no RevenueCat.
  ///
  /// Deve ser chamado quando o usuario faz logout do app.
  Future<void> logout() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      debugPrint('SubscriptionService: Logged out');
    } catch (e) {
      debugPrint('SubscriptionService: Error logging out: $e');
    }
  }

  /// Identifica um novo usuario no RevenueCat.
  ///
  /// Util quando o usuario faz login em uma conta diferente.
  Future<CustomerInfo> logIn(String userId) async {
    final result = await Purchases.logIn(userId);
    debugPrint('SubscriptionService: Logged in as $userId');
    return result.customerInfo;
  }
}
