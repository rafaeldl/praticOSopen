import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/financial_tab_store.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/financial_summary.dart';

/// The list behind a value of the Financeiro tab (A receber, Em andamento,
/// Vendido): large title, one sentence with the total, then the rows. Reads
/// the tab's [store], so it follows what is received from here.
class FinancialListScreen extends StatelessWidget {
  const FinancialListScreen({
    super.key,
    required this.store,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.emptyMessage,
  });

  final FinancialTabStore store;
  final String title;
  final String Function(FinancialSummary summary) subtitle;
  final List<Widget> Function(FinancialSummary summary) rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Observer(
        builder: (_) {
          final summary = store.summary;
          final items = rows(summary);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverNavigationBar(
                backgroundColor: AppNavBar.barBackground(context),
                alwaysShowMiddle: false,
                largeTitle: Text(title),
                border: null,
              ),
              CupertinoSliverRefreshControl(onRefresh: store.refresh),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(title: emptyMessage),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      0,
                      AppSpacing.pageMargin,
                      AppSpacing.md,
                    ),
                    child: Text(
                      subtitle(summary),
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
                SliverList.list(children: items),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl + bottomInset),
              ),
            ],
          );
        },
      ),
    );
  }
}
