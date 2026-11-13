import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/contracts/contracts_title.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:praticos/widgets/plan_feature_notice.dart';
import 'package:praticos/services/feature_gate_service.dart';

/// Writes `useContracts` on the company document.
typedef ContractsSwitchWriter = Future<void> Function(String companyId);

Future<void> _turnOnContracts(String companyId) => FirebaseFirestore.instance
    .collection('companies')
    .doc(companyId)
    .update({'useContracts': true});

/// "Contratos" while the company switch is off: says what it is for and
/// turns it on, then opens the list. The switch stays: a company without
/// fixed customers keeps the feature out of its screens (design rule 4).
class ContractsOffScreen extends StatefulWidget {
  const ContractsOffScreen({
    super.key,
    required this.companyId,
    this.writer = _turnOnContracts,
    this.onTurnedOn,
  });

  /// Null when there is no current company: the button is disabled.
  final String? companyId;
  final ContractsSwitchWriter writer;

  /// Defaults to replacing this screen with the list.
  final VoidCallback? onTurnedOn;

  @override
  State<ContractsOffScreen> createState() => _ContractsOffScreenState();
}

class _ContractsOffScreenState extends State<ContractsOffScreen> {
  bool _saving = false;

  Future<void> _turnOn() async {
    final companyId = widget.companyId;
    if (companyId == null || _saving) return;
    // Contracts are Pro (#724).
    if (!ensurePlanFeature(context, PlanFeature.contracts)) return;
    final l10n = context.l10n;
    final provider = context.read<SegmentConfigProvider>();
    setState(() => _saving = true);
    try {
      await widget.writer(companyId);
      provider.setCompanyConfig(
        fieldService: provider.fieldService,
        useScheduling: provider.useScheduling,
        useDeviceManagement: provider.useDeviceManagement,
        useContracts: true,
        useFinancial: provider.useFinancial,
      );
      if (!mounted) return;
      final done = widget.onTurnedOn;
      if (done != null) {
        done();
      } else {
        Navigator.of(context).pushReplacementNamed('/contract_list');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          content: Text(l10n.companySettingSaveError),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          AppNavBar(
            largeTitle: Text(contractsTitleOf(context)),
            previousTitle: l10n.myCompany,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.md,
                AppSpacing.pageMargin,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.contractsOffQuestion,
                    style: AppTypography.highlight.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.contractsOffMessage(l10n.orderShort),
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Semantics(
              identifier: 'contracts_turn_on',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.blockMargin,
                ),
                child: PrimaryButton(
                  label: l10n.contractsOffAction,
                  onPressed: widget.companyId == null || _saving
                      ? null
                      : _turnOn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
