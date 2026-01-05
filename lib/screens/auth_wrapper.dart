import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/menu_navigation/navigation_controller.dart';
import 'package:praticos/screens/onboarding/welcome_screen.dart';
import 'package:praticos/screens/loading_screen.dart';
import 'package:praticos/providers/segment_config_provider.dart';

/// Widget que verifica se o usuário tem empresa cadastrada E segmento definido
/// Se sim → NavigationController (Home)
/// Se não → CompanyInfoScreen (Onboarding)
class AuthWrapper extends StatelessWidget {
  final AuthStore authStore;

  const AuthWrapper({super.key, required this.authStore});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        // Aguarda carregar companyAggr
        if (authStore.companyAggr == null) {
          return FutureBuilder<_CompanyCheckResult>(
            future: _checkUserCompany(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              if (snapshot.hasData) {
                final result = snapshot.data!;

                if (result.hasCompany && !result.needsOnboarding) {
                  // Tem empresa com segmento, aguarda o store carregar
                  return const LoadingScreen();
                }

                // Não tem empresa OU não tem segmento → Onboarding
                return WelcomeScreen(
                  companyId: result.companyId,
                  initialName: result.companyName,
                  initialAddress: result.companyAddress,
                  initialLogoUrl: result.companyLogo,
                  initialPhone: result.companyPhone,
                  initialEmail: result.companyEmail,
                  initialSite: result.companySite,
                );
              }

              // Fallback para onboarding vazio
              return const WelcomeScreen();
            },
          );
        }

        // Tem companyAggr mas precisa verificar segmento
        return FutureBuilder<_CompanyCheckResult>(
          future: _checkUserCompany(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }

            if (snapshot.hasData && snapshot.data!.needsOnboarding) {
              // Empresa existe mas não tem segmento → Onboarding com dados
              final result = snapshot.data!;
              return WelcomeScreen(
                companyId: result.companyId,
                initialName: result.companyName,
                initialAddress: result.companyAddress,
                initialLogoUrl: result.companyLogo,
                initialPhone: result.companyPhone,
                initialEmail: result.companyEmail,
                initialSite: result.companySite,
              );
            }

            // Tudo OK → Carregar segmento e depois Home
            return _SegmentLoader(
              companyId: authStore.companyAggr!.id!,
            );
          },
        );
      },
    );
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
      final companyId = authStore.companyAggr?.id ?? companies[0];

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
      return _CompanyCheckResult(hasCompany: false, needsOnboarding: true);
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
  });
}

/// Widget que carrega a configuração do segmento antes de mostrar o app
class _SegmentLoader extends StatefulWidget {
  final String companyId;

  const _SegmentLoader({required this.companyId});

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

      if (!companyDoc.exists) {
        throw Exception('Empresa não encontrada');
      }

      final segment = companyDoc.data()?['segment'] as String?;

      if (segment == null || segment.isEmpty) {
        throw Exception('Empresa sem segmento definido');
      }

      // Carregar configuração do segmento
      final segmentProvider = context.read<SegmentConfigProvider>();
      await segmentProvider.initialize(segment);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erro ao carregar configuração'),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return NavigationController();
  }
}
