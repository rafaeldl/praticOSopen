import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/screens/menu_navigation/navigation_controller.dart';
import 'package:praticos/screens/onboarding/company_info_screen.dart';

/// Widget que verifica se o usuário tem empresa cadastrada E segmento definido
/// Se sim → NavigationController (Home)
/// Se não → CompanyInfoScreen (Onboarding)
class AuthWrapper extends StatelessWidget {
  final AuthStore authStore;

  const AuthWrapper({Key? key, required this.authStore}) : super(key: key);

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
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasData) {
                final result = snapshot.data!;

                if (result.hasCompany && !result.needsOnboarding) {
                  // Tem empresa com segmento, aguarda o store carregar
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Não tem empresa OU não tem segmento → Onboarding
                return CompanyInfoScreen(
                  companyId: result.companyId,
                  initialName: result.companyName,
                  initialPhone: result.companyPhone,
                  initialAddress: result.companyAddress,
                );
              }

              // Fallback para onboarding vazio
              return const CompanyInfoScreen();
            },
          );
        }

        // Tem companyAggr mas precisa verificar segmento
        return FutureBuilder<_CompanyCheckResult>(
          future: _checkUserCompany(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data!.needsOnboarding) {
              // Empresa existe mas não tem segmento → Onboarding com dados
              final result = snapshot.data!;
              return CompanyInfoScreen(
                companyId: result.companyId,
                initialName: result.companyName,
                initialPhone: result.companyPhone,
                initialAddress: result.companyAddress,
              );
            }

            // Tudo OK → Home
            return NavigationController();
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

  _CompanyCheckResult({
    required this.hasCompany,
    required this.needsOnboarding,
    this.companyId,
    this.companyName,
    this.companyPhone,
    this.companyAddress,
  });
}
