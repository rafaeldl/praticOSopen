import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/global.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/claims_service.dart';
import 'company_info_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId;
  final String? initialName;
  final String? initialAddress;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialSite;
  final String? initialLogoUrl;

  const WelcomeScreen({
    super.key,
    required this.authStore,
    this.companyId,
    this.initialName,
    this.initialAddress,
    this.initialPhone,
    this.initialEmail,
    this.initialSite,
    this.initialLogoUrl,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isCreatingDefaultCompany = false;

  void _startSetup(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CompanyInfoScreen(
          authStore: widget.authStore,
          companyId: widget.companyId,
          initialName: widget.initialName,
          initialAddress: widget.initialAddress,
          initialPhone: widget.initialPhone,
          initialEmail: widget.initialEmail,
          initialSite: widget.initialSite,
          initialLogoUrl: widget.initialLogoUrl,
        ),
      ),
    );
  }

  /// Cria uma empresa padrão e pula o onboarding
  Future<void> _skipOnboarding() async {
    if (_isCreatingDefaultCompany) return;

    setState(() => _isCreatingDefaultCompany = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final db = FirebaseFirestore.instance;
      final companyId = db.collection('companies').doc().id;

      // Busca o usuário do Firestore para preencher os campos de auditoria
      final userStore = UserStore();
      final dbUser = await userStore.findUserById(user.uid);

      if (dbUser == null) {
        throw Exception('Usuário não encontrado no Firestore');
      }

      final userAggr = dbUser.toAggr();

      // Cria a empresa padrão com TODOS os campos de auditoria preenchidos
      final company = Company()
        ..id = companyId
        ..name = "Minha Empresa"
        ..segment = "other" // segmento padrão
        ..owner = userAggr
        ..createdAt = DateTime.now()
        ..createdBy = userAggr
        ..updatedAt = DateTime.now()
        ..updatedBy = userAggr;

      // Usa o UserStore que já tem toda a lógica de criação de empresa e vínculo
      await userStore.createCompanyForUser(company);

      // IMPORTANTE: Busca o usuário do Firestore para garantir que a empresa foi salva
      var updatedUser = await userStore.findUserById(user.uid);

      // Verifica se a empresa foi realmente adicionada
      int maxRetries = 5;
      int retryCount = 0;
      while ((updatedUser == null ||
              updatedUser.companies == null ||
              !updatedUser.companies!.any((c) => c.company?.id == companyId)) &&
             retryCount < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 500));
        updatedUser = await userStore.findUserById(user.uid);
        retryCount++;
      }

      if (updatedUser == null ||
          updatedUser.companies == null ||
          !updatedUser.companies!.any((c) => c.company?.id == companyId)) {
        throw Exception('Empresa não foi salva corretamente no Firestore');
      }

      // Salva nas SharedPreferences e atualiza Global
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('companyId', companyId);
      await prefs.setString('companyName', company.name!);

      // Atualiza o Global para que o AuthWrapper reconheça a empresa
      Global.companyAggr = company.toAggr();

      // Atualiza também o Global.currentUser se necessário
      Global.currentUser ??= user;

      // IMPORTANTE: Recarrega o AuthStore para que ele busque os dados atualizados do Firestore
      await widget.authStore.reloadUserAndCompany();

      // Wait for Cloud Function to update custom claims
      // This prevents "permission denied" errors on first access
      await ClaimsService.instance.waitForCompanyClaim(companyId);

      if (mounted) {
        // Navega E força rebuild completo removendo todas as rotas
        // Isso garante que o AuthWrapper reconstrua com o novo companyAggr
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Error creating default company: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() => _isCreatingDefaultCompany = false);
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.error),
            content: Text('${context.l10n.errorCreatingCompany}: $e'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.ok),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22), // iOS App Icon style
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      CupertinoIcons.briefcase_fill,
                      size: 80,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.professionalizeYourBusiness,
                style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.configureCompanyProfile,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 17,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              _buildFeatureItem(
                context,
                icon: CupertinoIcons.doc_text_fill,
                title: context.l10n.professionalOrders,
                description: context.l10n.createDigitalOrders,
              ),
              const SizedBox(height: 24),
              _buildFeatureItem(
                context,
                icon: CupertinoIcons.person_2_fill,
                title: context.l10n.customerManagement,
                description: context.l10n.keepHistoryOrganized,
              ),

              const Spacer(),

              // Botão principal - Configurar
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isCreatingDefaultCompany ? null : () => _startSetup(context),
                  child: Text(context.l10n.configureMyBusiness),
                ),
              ),
              const SizedBox(height: 12),

              // Botão secundário - Pular
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  onPressed: _isCreatingDefaultCompany ? null : _skipOnboarding,
                  child: _isCreatingDefaultCompany
                      ? const CupertinoActivityIndicator()
                      : Text(
                          context.l10n.configureLater,
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Row(
      children: [
        Icon(icon, size: 32, color: CupertinoColors.activeBlue),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
