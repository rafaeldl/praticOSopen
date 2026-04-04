import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;

/// Tela de confirmação após compra bem-sucedida de assinatura.
class SubscriptionSuccessScreen extends StatefulWidget {
  const SubscriptionSuccessScreen({super.key});

  @override
  State<SubscriptionSuccessScreen> createState() => _SubscriptionSuccessScreenState();
}

class _SubscriptionSuccessScreenState extends State<SubscriptionSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String _planName = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('plan')) {
      _planName = args['plan'] as String;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<String> _getFeaturesForPlan(String planName) {
    switch (planName.toLowerCase()) {
      case 'starter':
        return [
          '200 fotos por mês',
          '3 formulários customizados',
          '3 usuários',
          'PDF sem marca d\'água',
          'Suporte por email',
        ];
      case 'pro':
        return [
          '500 fotos por mês',
          '10 formulários customizados',
          '5 usuários',
          'PDF sem marca d\'água',
          'Suporte prioritário',
          'Relatórios avançados',
        ];
      case 'business':
        return [
          'Fotos ilimitadas',
          'Formulários ilimitados',
          'Usuários ilimitados',
          'PDF sem marca d\'água',
          'API de integração',
          'Suporte dedicado',
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = _getFeaturesForPlan(_planName);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Ícone de sucesso animado
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 80,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Mensagem de sucesso
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Parabéns!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Você agora é assinante $_planName',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Features liberadas
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agora você tem acesso a:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...features.map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 20,
                                color: CupertinoColors.systemGreen,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.label.resolveFrom(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Botão de continuar
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _goToHome,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Começar a usar',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      'Ver detalhes da assinatura',
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    onPressed: () {
                      // Navegar para detalhes da assinatura
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToHome() {
    // Voltar para a tela principal, removendo as telas de assinatura da pilha
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
