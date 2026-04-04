import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

/// Tela de gerenciamento de assinatura
///
/// Exibe informações sobre o plano atual, data de renovação e permite
/// alterar plano ou cancelar assinatura.
class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  State<ManageSubscriptionScreen> createState() =>
      _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;

  // TODO: Integrar com SubscriptionStore quando disponível
  String? _currentPlan;
  DateTime? _renewalDate;
  String? _subscriptionStatus;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Carregar informações reais do SubscriptionStore
      // Por enquanto, simular dados
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _currentPlan = 'free'; // free, starter, pro, business
        _renewalDate = null;
        _subscriptionStatus = 'active';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);

    try {
      // TODO: Implementar restauração real via in_app_purchase
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showSuccessDialog(
          context.l10n.restorePurchasesSuccess,
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          context.l10n.restorePurchasesError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.success),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubscriptionManagement() async {
    // Abre as configurações de assinatura da loja
    final Uri url;
    if (Platform.isIOS) {
      url = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      url = Uri.parse(
          'https://play.google.com/store/account/subscriptions');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToPlans() {
    Navigator.pushNamed(context, '/plans');
  }

  String _getPlanDisplayName(String? plan) {
    switch (plan) {
      case 'starter':
        return 'Starter';
      case 'pro':
        return 'Pro';
      case 'business':
        return 'Business';
      case 'free':
      default:
        return 'Free';
    }
  }

  String _getPlanPrice(String? plan) {
    switch (plan) {
      case 'starter':
        return 'R\$ 59/mês';
      case 'pro':
        return 'R\$ 119/mês';
      case 'business':
        return 'R\$ 249/mês';
      case 'free':
      default:
        return context.l10n.free;
    }
  }

  Color _getPlanColor(String? plan) {
    switch (plan) {
      case 'starter':
        return CupertinoColors.systemBlue;
      case 'pro':
        return CupertinoColors.systemPurple;
      case 'business':
        return CupertinoColors.systemOrange;
      case 'free':
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.subscription),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildCurrentPlanCard(),
                            const SizedBox(height: 16),
                            _buildActionsSection(),
                            const SizedBox(height: 24),
                            _buildRestoreSection(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final l10n = context.l10n;
    final planColor = _getPlanColor(_currentPlan);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).brightness == Brightness.dark
            ? CupertinoColors.systemGrey6.darkColor
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000), // black with 5% opacity
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: planColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.star_fill,
              color: planColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.currentPlan,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getPlanDisplayName(_currentPlan),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: planColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getPlanPrice(_currentPlan),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_renewalDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.renewsOn(_formatDate(_renewalDate!)),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
          if (_subscriptionStatus == 'cancelled') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.subscriptionCancelled,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final l10n = context.l10n;

    return CupertinoListSection.insetGrouped(
      children: [
        CupertinoListTile(
          leading: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              CupertinoIcons.arrow_up_circle_fill,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
          title: Text(l10n.changePlan),
          subtitle: Text(l10n.viewAvailablePlans),
          trailing: const CupertinoListTileChevron(),
          onTap: _navigateToPlans,
        ),
        if (_currentPlan != 'free')
          CupertinoListTile(
            leading: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                CupertinoIcons.xmark_circle_fill,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
            title: Text(
              l10n.cancelSubscription,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
            subtitle: Text(l10n.manageInStore),
            trailing: const CupertinoListTileChevron(),
            onTap: _openSubscriptionManagement,
          ),
      ],
    );
  }

  Widget _buildRestoreSection() {
    final l10n = context.l10n;

    return CupertinoListSection.insetGrouped(
      header: Text(l10n.purchaseHistory.toUpperCase()),
      children: [
        CupertinoListTile(
          leading: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              CupertinoIcons.arrow_counterclockwise,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
          title: Text(l10n.restorePurchases),
          subtitle: Text(l10n.restorePurchasesDescription),
          trailing: _isRestoring
              ? const CupertinoActivityIndicator()
              : const CupertinoListTileChevron(),
          onTap: _isRestoring ? null : _restorePurchases,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
