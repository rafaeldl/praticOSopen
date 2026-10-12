import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Loads the orders that have a customer rating.
typedef RatedOrdersLoader = Future<List<Order>> Function();

/// "Avaliações": what the customers thought. Average first ("4,5 de 5"),
/// then the latest ratings; a row opens its order.
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key, this.loader, this.onOpenOrder});

  /// Test seam; defaults to the Firestore query of the current company.
  final RatedOrdersLoader? loader;

  /// Test seam; defaults to pushing '/order'.
  final void Function(BuildContext context, Order order)? onOpenOrder;

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  List<Order> _ratedOrders = const [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final loader = widget.loader ?? _defaultLoader;
      final orders = await loader();
      if (!mounted) return;
      setState(() {
        _ratedOrders = orders.where((o) => o.rating != null).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<List<Order>> _defaultLoader() {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) throw StateError('Company not found');
    return OrderRepositoryV2().getRatedOrders(companyId);
  }

  double get _average {
    if (_ratedOrders.isEmpty) return 0;
    final total = _ratedOrders.fold<int>(
      0,
      (sum, order) => sum + (order.rating?.score ?? 0),
    );
    return total / _ratedOrders.length;
  }

  void _openOrder(Order order) {
    final open = widget.onOpenOrder;
    if (open != null) {
      open(context, order);
      return;
    }
    Navigator.of(context).pushNamed('/order', arguments: {'order': order});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppNavBar.clearBackground(context),
            enableBackgroundFilterBlur: false,
            middle: AppNavBar.collapsedMiddle(context),
            alwaysShowMiddle: false,
            largeTitle: Text(l10n.ratings),
            border: null,
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                0,
                AppSpacing.pageMargin,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.ratingsSubtitle,
                style: AppTypography.callout.copyWith(
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingState(),
            )
          else if (_hasError)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(message: l10n.errorOccurred, onRetry: _load),
            )
          else if (_ratedOrders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(title: l10n.noRatingsYet),
            )
          else ...[
            SliverToBoxAdapter(child: _buildSummary(context)),
            SliverToBoxAdapter(child: SectionLabel(l10n.ratingsLatest)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _RatingRow(
                  order: _ratedOrders[index],
                  onTap: () => _openOrder(_ratedOrders[index]),
                ),
                childCount: _ratedOrders.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final l10n = context.l10n;
    final rounded = (_average * 10).round() / 10;
    final average = FormatService().formatDecimal(rounded);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.md,
        AppSpacing.pageMargin,
        0,
      ),
      child: Semantics(
        container: true,
        child: Column(
          key: const Key('ratingsSummary'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ratingScoreOf(average),
              style: AppTypography.title.copyWith(
                color: AppColors.text.resolveFrom(context),
                fontFeatures: AppTypography.tabular,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.ratingsAverageOf(_ratedOrders.length),
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name + "5 de 5", the stars, and "“comment” · OS 160".
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rating = order.rating!;
    final score = rating.score ?? 0;
    final name =
        rating.customerName ?? order.customer?.name ?? l10n.customerWithoutName;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final number = order.number ?? 0;
    final comment = rating.comment?.trim() ?? '';
    final detail = comment.isEmpty
        ? l10n.ratingNoCommentOrder(number)
        : l10n.ratingCommentOrder(comment, number);

    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey('rating-${order.id ?? order.number}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.body.copyWith(
                          color: AppColors.text.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          for (var i = 0; i < 5; i++)
                            Icon(
                              i < score
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.star,
                              size: 16,
                              color: i < score
                                  ? AppColors.warning.resolveFrom(context)
                                  : AppColors.separator.resolveFrom(context),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detail,
                        style: AppTypography.label.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  l10n.ratingScoreOf('$score'),
                  style: AppTypography.callout.copyWith(
                    color: secondary,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
