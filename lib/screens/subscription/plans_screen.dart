import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Colors;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide Store;
import 'package:praticos/mobx/subscription_store.dart';
import 'package:praticos/services/format_service.dart';

/// Dados de um plano de assinatura para exibição.
class PlanData {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> features;
  final bool isRecommended;

  const PlanData({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.isRecommended = false,
  });
}

/// Tela de comparação e seleção de planos de assinatura.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final FormatService _formatService = FormatService();
  String? _selectedPlanId;
  late SubscriptionStore _subscriptionStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscriptionStore = Provider.of<SubscriptionStore>(context, listen: false);
  }

  static const List<PlanData> _plans = [
    PlanData(
      id: 'free',
      name: 'Gratuito',
      price: 0,
      description: 'Para começar',
      features: [
        'Clientes ilimitados',
        'Ordens de serviço ilimitadas',
        '30 fotos/mês',
        '1 formulário customizado',
        '1 usuário',
        'PDF com marca d\'água',
      ],
    ),
    PlanData(
      id: 'starter',
      name: 'Starter',
      price: 59,
      description: 'Para MEI e autônomos',
      features: [
        'Tudo do Gratuito',
        '200 fotos/mês',
        '3 formulários customizados',
        '3 usuários',
        'PDF sem marca d\'água',
        'Suporte por email',
      ],
    ),
    PlanData(
      id: 'pro',
      name: 'Pro',
      price: 119,
      description: 'Para pequenas empresas',
      features: [
        'Tudo do Starter',
        '500 fotos/mês',
        '10 formulários customizados',
        '5 usuários',
        'Suporte prioritário',
        'Relatórios avançados',
      ],
      isRecommended: true,
    ),
    PlanData(
      id: 'business',
      name: 'Business',
      price: 249,
      description: 'Para empresas médias',
      features: [
        'Tudo do Pro',
        'Fotos ilimitadas',
        'Formulários ilimitados',
        'Usuários ilimitados',
        'API de integração',
        'Suporte dedicado',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: Observer(
          builder: (_) {
            final isLoading = _subscriptionStore.isLoading;
            final isPurchasing = _subscriptionStore.isPurchasing;
            final currentPlan = _subscriptionStore.currentPlan;

            return CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('Planos'),
                  previousPageTitle: 'Voltar',
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: isLoading ? null : _restorePurchases,
                    child: isLoading
                        ? const CupertinoActivityIndicator()
                        : const Text('Restaurar'),
                  ),
                ),
                // Header com plano atual
                SliverToBoxAdapter(
                  child: _buildCurrentPlanHeader(currentPlan),
                ),
                // Cards de planos
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _plans.length) return null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildPlanCard(
                            _plans[index],
                            currentPlan: currentPlan,
                            isPurchasing: isPurchasing,
                          ),
                        );
                      },
                      childCount: _plans.length,
                    ),
                  ),
                ),
                // Footer com FAQs e termos
                SliverToBoxAdapter(
                  child: _buildFooter(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentPlanHeader(String currentPlan) {
    final currentPlanData = _plans.firstWhere(
      (p) => p.id == currentPlan,
      orElse: () => _plans.first,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.checkmark_seal_fill,
              color: CupertinoColors.activeBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu plano atual',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentPlanData.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          if (currentPlan != 'free')
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text(
                'Gerenciar',
                style: TextStyle(fontSize: 15),
              ),
              onPressed: () {
                // Navegar para gerenciamento de assinatura
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    PlanData plan, {
    required String currentPlan,
    required bool isPurchasing,
  }) {
    final isCurrentPlan = plan.id == currentPlan;
    final isSelected = plan.id == _selectedPlanId;
    final canSubscribe = !isCurrentPlan && plan.price > 0;

    return GestureDetector(
      onTap: canSubscribe
          ? () => setState(() => _selectedPlanId = plan.id)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : plan.isRecommended
                    ? CupertinoColors.activeBlue.withValues(alpha: 0.3)
                    : CupertinoColors.systemGrey5.resolveFrom(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge de recomendado
            if (plan.isRecommended)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: const Text(
                  'RECOMENDADO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome e preço
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.price > 0
                                ? _formatService.formatCurrency(plan.price)
                                : 'Grátis',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: plan.isRecommended
                                  ? CupertinoColors.activeBlue
                                  : CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          if (plan.price > 0)
                            Text(
                              '/mês',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Features
                  ...plan.features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 18,
                          color: plan.isRecommended
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.systemGreen,
                        ),
                        const SizedBox(width: 10),
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
                  const SizedBox(height: 16),
                  // Botão de ação
                  _buildActionButton(plan, isCurrentPlan, isSelected, isPurchasing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    PlanData plan,
    bool isCurrentPlan,
    bool isSelected,
    bool isPurchasing,
  ) {
    if (isCurrentPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Plano atual',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      );
    }

    if (plan.price == 0) {
      return const SizedBox.shrink();
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isPurchasing ? null : () => _subscribeToPlan(plan),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: plan.isRecommended
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isPurchasing && isSelected
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : Text(
                'Assinar ${plan.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: plan.isRecommended
                      ? CupertinoColors.white
                      : CupertinoColors.activeBlue,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // FAQs
          _buildFaqItem(
            'Posso cancelar a qualquer momento?',
            'Sim! Você pode cancelar sua assinatura a qualquer momento. Seu plano permanecerá ativo até o final do período pago.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            'Como funciona o período de teste?',
            'Ao assinar pela primeira vez, você tem 7 dias para testar. Se não gostar, cancele antes do fim do período e não será cobrado.',
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            'Posso trocar de plano depois?',
            'Sim! Você pode fazer upgrade ou downgrade do seu plano a qualquer momento. O valor será ajustado proporcionalmente.',
          ),
          const SizedBox(height: 24),
          // Links de termos
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  'Termos de Uso',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                onPressed: () {
                  // Abrir termos de uso
                },
              ),
              Text(
                ' • ',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  'Política de Privacidade',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                onPressed: () {
                  // Abrir política de privacidade
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _subscribeToPlan(PlanData plan) async {
    setState(() => _selectedPlanId = plan.id);

    // Encontrar o pacote correspondente ao plano nas offerings
    final package = _findPackageForPlan(plan.id);

    if (package == null) {
      // Fallback: mostrar erro se pacote não encontrado
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Erro'),
          content: const Text('Plano não disponível no momento. Tente novamente mais tarde.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final success = await _subscriptionStore.purchasePackage(package);

    if (!mounted) return;

    if (success) {
      // Navegar para tela de sucesso
      Navigator.pushReplacementNamed(
        context,
        '/subscription/success',
        arguments: {'plan': plan.name},
      );
    } else if (_subscriptionStore.errorMessage != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Erro'),
          content: Text(_subscriptionStore.errorMessage!),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                _subscriptionStore.clearError();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }
    // Se success == false e errorMessage == null, usuário cancelou
  }

  Package? _findPackageForPlan(String planId) {
    final packages = _subscriptionStore.availablePackages;
    if (packages.isEmpty) return null;

    // Tentar encontrar pacote pelo identifier que contenha o planId
    // RevenueCat usa identificadores como "starter_monthly", "pro_monthly", etc.
    for (final package in packages) {
      final identifier = package.storeProduct.identifier.toLowerCase();
      if (identifier.contains(planId.toLowerCase())) {
        return package;
      }
    }

    // Fallback: tentar encontrar pelo tipo de pacote
    switch (planId) {
      case 'starter':
        return packages.isNotEmpty ? packages[0] : null;
      case 'pro':
        return packages.length > 1 ? packages[1] : null;
      case 'business':
        return packages.length > 2 ? packages[2] : null;
      default:
        return null;
    }
  }

  Future<void> _restorePurchases() async {
    final restored = await _subscriptionStore.restorePurchases();

    if (!mounted) return;

    if (restored) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Compras restauradas'),
          content: const Text('Suas compras anteriores foram restauradas com sucesso.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } else if (_subscriptionStore.errorMessage != null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Aviso'),
          content: Text(_subscriptionStore.errorMessage!),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                _subscriptionStore.clearError();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }
  }
}
