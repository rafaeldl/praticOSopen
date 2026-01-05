import 'package:flutter/cupertino.dart';
import 'company_info_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String? companyId;
  final String? initialName;
  final String? initialAddress;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialSite;
  final String? initialLogoUrl;

  const WelcomeScreen({
    Key? key,
    this.companyId,
    this.initialName,
    this.initialAddress,
    this.initialPhone,
    this.initialEmail,
    this.initialSite,
    this.initialLogoUrl,
  }) : super(key: key);

  void _startSetup(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CompanyInfoScreen(
          companyId: companyId,
          initialName: initialName,
          initialAddress: initialAddress,
          initialPhone: initialPhone,
          initialEmail: initialEmail,
          initialSite: initialSite,
          initialLogoUrl: initialLogoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
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
                      color: CupertinoColors.systemGrey.withOpacity(0.2),
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
                'Profissionalize seu negócio',
                style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Configure o perfil da sua empresa para emitir ordens de serviço profissionais agora mesmo.',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 17,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              _buildFeatureItem(
                context,
                icon: CupertinoIcons.doc_text_fill,
                title: 'Ordens Profissionais',
                description: 'Crie OS digitais personalizadas.',
              ),
              const SizedBox(height: 24),
              _buildFeatureItem(
                context,
                icon: CupertinoIcons.person_2_fill,
                title: 'Gestão de Clientes',
                description: 'Mantenha histórico e contatos organizados.',
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => _startSetup(context),
                  child: const Text('Configurar Meu Negócio'),
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
