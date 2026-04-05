import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Servico de assinaturas usando RevenueCat.
///
/// Responsavel por:
/// - Inicializar o SDK RevenueCat
/// - Buscar informacoes do assinante
/// - Listar ofertas/planos disponiveis
/// - Realizar compras
/// - Restaurar compras
/// - Determinar plano atual baseado em entitlements
/// - Apresentar Paywalls nativos do RevenueCat
/// - Apresentar Customer Center para gerenciamento de assinaturas
///
/// ## Configuracao de API Keys
///
/// Para producao, use --dart-define:
/// ```bash
/// flutter run --dart-define=REVENUECAT_ANDROID_API_KEY=your_key
/// flutter run --dart-define=REVENUECAT_IOS_API_KEY=your_key
/// ```
///
/// Para teste/desenvolvimento local, voce pode usar a key de sandbox:
/// `test_rHipMRrqwezbhAuzyWKGLEqwfhP`
///
/// ## Entitlements Suportados
///
/// - `Rafsoft Pro` - Entitlement para acesso completo ao app (ambiente de teste)
/// - `business` - Plano Business (producao)
/// - `pro` - Plano Pro (producao)
/// - `starter` - Plano Starter (producao)
///
/// ## Produtos Configurados
///
/// - `monthly` - Assinatura mensal
/// - `yearly` - Assinatura anual
/// - `lifetime` - Compra unica vitalicia
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

  /// Entitlement principal para ambiente de teste
  static const _mainEntitlement = 'Rafsoft Pro';

  /// Entitlements de producao ordenados por prioridade
  static const _productionEntitlements = ['business', 'pro', 'starter'];

  /// Todos os entitlements reconhecidos
  static const _allEntitlements = [_mainEntitlement, ..._productionEntitlements];

  bool _isInitialized = false;

  /// Verifica se o SDK foi inicializado com sucesso.
  bool get isInitialized => _isInitialized;

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
  /// Pacotes esperados: monthly, yearly, lifetime
  Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('SubscriptionService: Fetched offerings: ${offerings.current?.identifier}');

      // Log dos pacotes disponiveis para debug
      if (offerings.current != null) {
        for (final package in offerings.current!.availablePackages) {
          debugPrint('  - Package: ${package.identifier} (${package.packageType})');
        }
      }

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

  /// Verifica se o usuario tem acesso ao entitlement principal (Rafsoft Pro).
  ///
  /// Retorna true se o usuario tem entitlement "Rafsoft Pro" ativo.
  bool hasProEntitlement(CustomerInfo info) {
    return info.entitlements.active.containsKey(_mainEntitlement);
  }

  /// Determina o plano atual baseado nos entitlements ativos.
  ///
  /// Retorna: 'Rafsoft Pro', 'business', 'pro', 'starter', ou 'free'
  /// Prioriza planos maiores e o entitlement de teste.
  String getPlanFromEntitlements(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    // Verifica todos os entitlements reconhecidos em ordem de prioridade
    for (final entitlement in _allEntitlements) {
      if (entitlements.containsKey(entitlement)) {
        return entitlement;
      }
    }

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
    for (final key in _allEntitlements) {
      if (entitlements.containsKey(key)) {
        final expDateStr = entitlements[key]?.expirationDate;
        if (expDateStr != null) {
          return DateTime.tryParse(expDateStr);
        }
        return null; // Lifetime purchase sem expiracao
      }
    }

    return null;
  }

  /// Verifica se o plano esta em periodo de trial.
  bool isInTrial(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    for (final key in _allEntitlements) {
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

    for (final key in _allEntitlements) {
      if (entitlements.containsKey(key)) {
        return entitlements[key]?.willRenew ?? false;
      }
    }

    return false;
  }

  /// Verifica se o usuario tem uma compra vitalicia (lifetime).
  bool hasLifetimePurchase(CustomerInfo info) {
    final entitlements = info.entitlements.active;

    for (final key in _allEntitlements) {
      if (entitlements.containsKey(key)) {
        // Lifetime purchases nao expiram
        return entitlements[key]?.expirationDate == null;
      }
    }

    return false;
  }

  // ============================================================
  // PAYWALL - RevenueCat Native Paywall
  // ============================================================

  /// Apresenta o Paywall nativo do RevenueCat.
  ///
  /// O Paywall e configurado no RevenueCat Dashboard e apresenta
  /// os planos disponiveis (monthly, yearly, lifetime) de forma
  /// nativa e otimizada para conversao.
  ///
  /// Retorna [PaywallResult] indicando se houve compra, cancelamento,
  /// ou erro.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// final result = await SubscriptionService.instance.presentPaywall();
  /// if (result == PaywallResult.purchased) {
  ///   // Usuario comprou - atualizar UI
  /// }
  /// ```
  Future<PaywallResult> presentPaywall({Offering? offering}) async {
    try {
      debugPrint('SubscriptionService: Presenting paywall');
      final result = await RevenueCatUI.presentPaywall(
        offering: offering,
      );
      debugPrint('SubscriptionService: Paywall result: $result');
      return result;
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error presenting paywall: $e\n$stack');
      rethrow;
    }
  }

  /// Apresenta o Paywall para um offering especifico identificado pelo nome.
  ///
  /// [offeringIdentifier] - Identificador do offering no RevenueCat Dashboard
  ///
  /// Primeiro busca o offering, depois apresenta o paywall.
  Future<PaywallResult> presentPaywallForOffering(String offeringIdentifier) async {
    try {
      final offerings = await getOfferings();
      final offering = offerings?.getOffering(offeringIdentifier);
      if (offering == null) {
        debugPrint('SubscriptionService: Offering $offeringIdentifier not found');
        throw Exception('Offering $offeringIdentifier not found');
      }
      return presentPaywall(offering: offering);
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error presenting paywall for offering: $e\n$stack');
      rethrow;
    }
  }

  /// Apresenta o Paywall condicionalmente se o usuario nao tiver entitlement.
  ///
  /// [requiredEntitlement] - Entitlement necessario (default: 'Rafsoft Pro')
  ///
  /// Retorna [PaywallResult] indicando a acao do usuario.
  /// Se o usuario ja tiver o entitlement, retorna [PaywallResult.notPresented].
  ///
  /// Exemplo de uso:
  /// ```dart
  /// final result = await SubscriptionService.instance.presentPaywallIfNeeded();
  /// if (result == PaywallResult.purchased) {
  ///   // Acesso liberado
  /// } else if (result == PaywallResult.notPresented) {
  ///   // Usuario ja tem acesso
  /// }
  /// ```
  Future<PaywallResult> presentPaywallIfNeeded({
    String? requiredEntitlement,
  }) async {
    try {
      final entitlement = requiredEntitlement ?? _mainEntitlement;
      debugPrint('SubscriptionService: Presenting paywall if needed for: $entitlement');
      final result = await RevenueCatUI.presentPaywallIfNeeded(entitlement);
      debugPrint('SubscriptionService: Paywall if needed result: $result');
      return result;
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error presenting paywall if needed: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================
  // CUSTOMER CENTER - Gerenciamento de Assinaturas
  // ============================================================

  /// Apresenta o Customer Center do RevenueCat.
  ///
  /// O Customer Center permite ao usuario:
  /// - Ver detalhes da assinatura atual
  /// - Cancelar assinatura
  /// - Alterar plano
  /// - Restaurar compras
  /// - Acessar suporte
  ///
  /// E configurado no RevenueCat Dashboard e usa telas nativas.
  ///
  /// Exemplo de uso:
  /// ```dart
  /// await SubscriptionService.instance.presentCustomerCenter();
  /// ```
  Future<void> presentCustomerCenter() async {
    try {
      debugPrint('SubscriptionService: Presenting customer center');
      await RevenueCatUI.presentCustomerCenter();
      debugPrint('SubscriptionService: Customer center closed');
    } catch (e, stack) {
      debugPrint('SubscriptionService: Error presenting customer center: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================
  // USER MANAGEMENT
  // ============================================================

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

  // ============================================================
  // HELPERS - Informacoes uteis
  // ============================================================

  /// Retorna informacoes formatadas sobre o entitlement ativo.
  ///
  /// Util para exibir na UI detalhes da assinatura.
  Map<String, dynamic> getSubscriptionDetails(CustomerInfo info) {
    final plan = getPlanFromEntitlements(info);
    final expiration = getExpirationDate(info);
    final inTrial = isInTrial(info);
    final renews = willRenew(info);
    final lifetime = hasLifetimePurchase(info);

    return {
      'plan': plan,
      'isPremium': plan != 'free',
      'expirationDate': expiration,
      'isInTrial': inTrial,
      'willRenew': renews,
      'isLifetime': lifetime,
      'status': _getStatusLabel(plan, inTrial, renews, lifetime),
    };
  }

  String _getStatusLabel(String plan, bool inTrial, bool renews, bool lifetime) {
    if (plan == 'free') return 'Gratuito';
    if (lifetime) return 'Vitalicio';
    if (inTrial) return 'Trial';
    if (!renews) return 'Cancelado';
    return 'Ativo';
  }
}
