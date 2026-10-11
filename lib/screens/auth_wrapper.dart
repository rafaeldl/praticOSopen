import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/notification_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/screens/menu_navigation/navigation_controller.dart';
import 'package:praticos/screens/onboarding/onboarding_flow.dart';
import 'package:praticos/screens/onboarding/pending_invites_screen.dart';
import 'package:praticos/screens/loading_screen.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/notification_service.dart';
import 'package:praticos/services/notification_tap_handler.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Widget que verifica se o usuário tem empresa cadastrada E segmento definido
/// Se sim → NavigationController (Home)
/// Se não tem empresa → Verifica convites pendentes
/// Se tem convites → PendingInvitesScreen
/// Se não tem convites → OnboardingFlow (Ramo → Seu negócio → Início)
class AuthWrapper extends StatefulWidget {
  final AuthStore authStore;

  const AuthWrapper({super.key, required this.authStore});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<_CompanyCheckResult>? _companyCheckFuture;

  @override
  void initState() {
    super.initState();
    _companyCheckFuture = _checkUserCompany();
  }

  void _retryLoad() {
    widget.authStore.reloadUserAndCompany();
    setState(() {
      _companyCheckFuture = _checkUserCompany();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        // If the AuthStore had an error loading company data, show retry screen
        if (widget.authStore.hasCompanyLoadError) {
          return _buildErrorRetryScreen(context);
        }

        // Aguarda carregar companyAggr
        if (widget.authStore.companyAggr == null) {
          return FutureBuilder<_CompanyCheckResult>(
            future: _companyCheckFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              if (snapshot.hasError) {
                return _buildErrorRetryScreen(context, error: snapshot.error.toString());
              }

              if (snapshot.hasData) {
                final result = snapshot.data!;

                if (result.error != null) {
                  return _buildErrorRetryScreen(context, error: result.error);
                }

                if (result.hasCompany && !result.needsOnboarding) {
                  // Tem empresa com segmento, aguarda o store carregar
                  return const LoadingScreen();
                }

                // Não tem empresa → Verificar se tem convites pendentes
                if (!result.hasCompany) {
                  return _buildOnboardingDecision(result);
                }

                // Tem empresa mas precisa onboarding → Onboarding com dados
                return _onboarding(result);
              }

              // Fallback: verifica convites
              return _buildOnboardingDecision(_CompanyCheckResult(
                hasCompany: false,
                needsOnboarding: true,
              ));
            },
          );
        }

        // Tem companyAggr mas precisa verificar segmento
        return FutureBuilder<_CompanyCheckResult>(
          future: _companyCheckFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (snapshot.hasError) {
              return _buildErrorRetryScreen(context, error: snapshot.error.toString());
            }

            if (snapshot.hasData) {
              final result = snapshot.data!;

              if (result.error != null) {
                return _buildErrorRetryScreen(context, error: result.error);
              }

              if (result.needsOnboarding) {
                // Empresa existe mas não tem segmento → Onboarding com dados
                return _onboarding(result);
              }
            }

            // Tudo OK → Carregar segmento e depois Home
            return _SegmentLoader(
              key: ValueKey(widget.authStore.companyAggr!.id!),
              companyId: widget.authStore.companyAggr!.id!,
            );
          },
        );
      },
    );
  }

  /// First access without a company (or with a company that has no segment
  /// yet): Ramo → [Especialidades] → Seu negócio → Início.
  Widget _onboarding(_CompanyCheckResult result) {
    return OnboardingFlow(
      deps: OnboardingDeps.firebase(widget.authStore),
      companyId: result.companyId,
      initialName: result.companyName,
      initialPhone: result.companyPhone,
    );
  }

  /// Tela de erro com botão de retry. The exception is only logged: the user
  /// sees a fixed sentence.
  Widget _buildErrorRetryScreen(BuildContext context, {String? error}) {
    if (error != null) debugPrint('AuthWrapper: $error');
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 48,
                color: CupertinoColors.systemOrange.resolveFrom(context),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.errorLoadingData,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.networkError,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: _retryLoad,
                child: Text(context.l10n.tryAgain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Decide se mostra tela de convites ou de criação de empresa
  Widget _buildOnboardingDecision(_CompanyCheckResult result) {
    return FutureBuilder<bool>(
      future: _checkPendingInvites(),
      builder: (context, inviteSnapshot) {
        if (inviteSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final hasPendingInvites = inviteSnapshot.data ?? false;

        if (hasPendingInvites) {
          // Tem convites pendentes → Mostrar tela de convites
          return PendingInvitesScreen(
            onCreateCompany: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => _onboarding(result),
                ),
              );
            },
            onInviteAccepted: () {
              // Força rebuild para verificar novamente
              setState(() {});
            },
          );
        }

        // Sem convites → Onboarding normal
        return _onboarding(result);
      },
    );
  }

  /// Verifica se o usuário tem convites pendentes
  Future<bool> _checkPendingInvites() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return false;

      final invites = await FirebaseFirestore.instance
          .collection('invites')
          .where('email', isEqualTo: user!.email!.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return invites.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se o usuário tem empresa associada e se ela tem segmento definido
  Future<_CompanyCheckResult> _checkUserCompany() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return _CompanyCheckResult(hasCompany: false, needsOnboarding: true);
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return _CompanyCheckResult(hasCompany: false, needsOnboarding: true);
      }

      final companies = userDoc.data()?['companies'] as List?;
      if (companies == null || companies.isEmpty) {
        return _CompanyCheckResult(hasCompany: false, needsOnboarding: true);
      }

      // Pega a primeira empresa (ou a empresa já carregada no store)
      final companyId = widget.authStore.companyAggr?.id ??
          companies[0]['company']['id'] as String;

      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        return _CompanyCheckResult(hasCompany: false, needsOnboarding: true);
      }

      final companyData = companyDoc.data()!;

      final segment = companyData['segment'] as String?;
      final needsOnboarding = segment == null || segment.isEmpty;

      return _CompanyCheckResult(
        hasCompany: true,
        needsOnboarding: needsOnboarding,
        companyId: companyId,
        companyName: companyData['name'] as String?,
        companyPhone: companyData['phone'] as String?,
        companyAddress: companyData['address'] as String?,
        companyEmail: companyData['email'] as String?,
        companySite: companyData['site'] as String?,
        companyLogo: companyData['logo'] as String?,
      );
    } catch (e) {
      // Return error instead of silently redirecting to onboarding
      return _CompanyCheckResult(
        hasCompany: false,
        needsOnboarding: false,
        error: e.toString(),
      );
    }
  }
}

class _CompanyCheckResult {
  final bool hasCompany;
  final bool needsOnboarding;
  final String? companyId;
  final String? companyName;
  final String? companyPhone;
  final String? companyAddress;
  final String? companyEmail;
  final String? companySite;
  final String? companyLogo;
  final String? error;

  _CompanyCheckResult({
    required this.hasCompany,
    required this.needsOnboarding,
    this.companyId,
    this.companyName,
    this.companyPhone,
    this.companyAddress,
    this.companyEmail,
    this.companySite,
    this.companyLogo,
    this.error,
  });
}

/// Widget que carrega a configuração do segmento antes de mostrar o app
class _SegmentLoader extends StatefulWidget {
  final String companyId;

  const _SegmentLoader({super.key, required this.companyId});

  @override
  State<_SegmentLoader> createState() => _SegmentLoaderState();
}

class _SegmentLoaderState extends State<_SegmentLoader> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSegmentConfig();
  }

  Future<void> _loadSegmentConfig() async {
    try {
      // Buscar segmento da empresa
      final companyDoc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      if (!companyDoc.exists) {
        throw Exception(context.l10n.companyNotFound);
      }

      final companyData = companyDoc.data();
      final segment = companyData?['segment'] as String?;
      final country = companyData?['country'] as String?;

      if (segment == null || segment.isEmpty) {
        throw Exception(context.l10n.companyNoSegment);
      }

      // Carregar configuração do segmento e país
      // Como o widget tem key única baseada no companyId, ele é recriado quando muda
      // Então o initialize sempre será chamado para a empresa correta
      final segmentProvider = context.read<SegmentConfigProvider>();
      await segmentProvider.initialize(segment);

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      // Seta o país para formatação de telefone
      if (country != null) {
        segmentProvider.setCountry(country);
      }

      // Resolve feature toggles (company > segment default > hardcoded default)
      final bool fieldService = companyData?['fieldService'] as bool?
          ?? segmentProvider.segmentFieldServiceDefault;
      final bool useScheduling = companyData?['useScheduling'] as bool? ?? true;
      final bool useDeviceManagement = companyData?['useDeviceManagement'] as bool? ?? false;
      final bool useContracts = companyData?['useContracts'] as bool? ?? false;
      // Not backfilled: absent stays absent, so clients that predate the
      // field keep their current behavior.
      final bool useFinancial = companyData?['useFinancial'] as bool?
          ?? segmentProvider.segmentUseFinancialDefault;

      // Backfill: persist resolved values on first access
      final needsUpdate = companyData?['fieldService'] == null
          || companyData?['useScheduling'] == null;
      if (needsUpdate) {
        FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .update({
          if (companyData?['fieldService'] == null) 'fieldService': fieldService,
          if (companyData?['useScheduling'] == null) 'useScheduling': useScheduling,
        });
        // Fire-and-forget, does not block startup
      }

      // Set resolved values for direct runtime access
      segmentProvider.setCompanyConfig(
        fieldService: fieldService,
        useScheduling: useScheduling,
        useDeviceManagement: useDeviceManagement,
        useContracts: useContracts,
        useFinancial: useFinancial,
      );

      // Wire push taps before initialize(), which replays the tap that
      // launched the app from a terminated state.
      NotificationService.instance.onNotificationTap =
          NotificationTapHandler.handleTap;

      // Initialize notifications after user is fully authenticated
      final notificationStore = context.read<NotificationStore>();
      notificationStore.initialize();

      // Check and auto-generate due contract orders (fire-and-forget)
      if (useContracts) {
        OrderStore().checkAndGenerateDueOrders();
      }

      // The segmentation questionnaire (users/{uid}.onboardingSegment) left
      // the first access: nothing read it (spec telas-mapa, decision 1).
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadSegmentConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    if (_error != null) {
      debugPrint('SegmentLoader: $_error');
      return CupertinoPageScaffold(
        child: ErrorState(
          message: context.l10n.errorLoadingConfig,
          onRetry: _retry,
        ),
      );
    }

    return NavigationController();
  }
}
