import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:provider/provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/providers/segment_config_provider.dart';

/// Screen to display all customer ratings for completed orders
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  final OrderRepositoryV2 _repository = OrderRepositoryV2();
  List<Order>? _ratedOrders;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRatedOrders();
  }

  Future<void> _loadRatedOrders() async {
    try {
      final companyId = Global.companyAggr?.id;
      if (companyId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Company not found';
        });
        return;
      }

      final orders = await _repository.getRatedOrders(companyId);
      setState(() {
        _ratedOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  double get _averageRating {
    if (_ratedOrders == null || _ratedOrders!.isEmpty) return 0;
    final totalScore = _ratedOrders!.fold<int>(
      0,
      (sum, order) => sum + (order.rating?.score ?? 0),
    );
    return totalScore / _ratedOrders!.length;
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(context.l10n.ratings),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() => _isLoading = true);
                _loadRatedOrders();
              },
              child: const Icon(CupertinoIcons.refresh),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 48,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.errorOccurred,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _loadRatedOrders();
                      },
                      child: Text(context.l10n.tryAgain),
                    ),
                  ],
                ),
              ),
            )
          else if (_ratedOrders == null || _ratedOrders!.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.star,
                      size: 64,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noRatingsYet,
                      style: TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Summary card
            SliverToBoxAdapter(
              child: _buildSummaryCard(context),
            ),
            // Ratings list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
                child: Text(
                  context.l10n.ratings.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = _ratedOrders![index];
                  return _buildRatingRow(context, order, config, index == _ratedOrders!.length - 1);
                },
                childCount: _ratedOrders!.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final totalRatings = _ratedOrders?.length ?? 0;
    final average = _averageRating;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Average rating with stars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.averageRating,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              final filled = index < average.round();
                              return Icon(
                                filled ? CupertinoIcons.star_fill : CupertinoIcons.star,
                                color: filled
                                    ? const Color(0xFFFFD700)
                                    : CupertinoColors.systemGrey3.resolveFrom(context),
                                size: 16,
                              );
                            }),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.totalRatings,
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Total count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    totalRatings.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  Text(
                    context.l10n.ratings.toLowerCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(
    BuildContext context,
    Order order,
    SegmentConfigProvider config,
    bool isLast,
  ) {
    final rating = order.rating;
    if (rating == null) return const SizedBox.shrink();

    final score = rating.score ?? 0;
    final badgeColor = _getScoreBadgeColor(score);

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: isLast ? 0 : 0,
      ),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              )
            : (_ratedOrders?.indexOf(order) == 0
                ? const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  )
                : BorderRadius.zero),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/order', arguments: {'order': order});
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        score.toString(),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer name and order number
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rating.customerName ?? order.customer?.name ?? context.l10n.customer,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '#${order.number}',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                        // Stars
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < score ? CupertinoIcons.star_fill : CupertinoIcons.star,
                              color: index < score
                                  ? const Color(0xFFFFD700)
                                  : CupertinoColors.systemGrey4.resolveFrom(context),
                              size: 14,
                            );
                          }),
                        ),
                        // Comment (truncated)
                        if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${rating.comment}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Date
                        if (rating.createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            FormatService().formatDateTime(rating.createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Chevron
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: CupertinoColors.systemGrey3.resolveFrom(context),
                  ),
                ],
              ),
            ),
          ),
          if (!isLast)
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 64),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
        ],
      ),
    );
  }

  Color _getScoreBadgeColor(int score) {
    switch (score) {
      case 5:
        return CupertinoColors.systemGreen;
      case 4:
        return CupertinoColors.systemTeal;
      case 3:
        return CupertinoColors.systemYellow;
      case 2:
        return CupertinoColors.systemOrange;
      case 1:
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }
}
