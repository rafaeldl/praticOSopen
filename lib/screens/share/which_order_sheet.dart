import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/received_share.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "1 foto e 2 PDFs" for what was received.
String summarizeBatch(AppLocalizations l10n, ReceivedBatch batch) {
  final photos = batch.photos.length;
  final pdfs = batch.pdfs.length;
  if (photos > 0 && pdfs > 0) {
    return l10n.receivedSummaryBoth(
        l10n.receivedPhotosCount(photos), l10n.receivedPdfsCount(pdfs));
  }
  if (photos > 0) return l10n.receivedPhotosCount(photos);
  return l10n.receivedPdfsCount(pdfs);
}

/// Open (not done, not canceled) orders, newest first, capped at [limit].
List<Order> recentOpenOrders(Iterable<Order?> orders, {int limit = 20}) {
  final open = orders
      .whereType<Order>()
      .where((o) => o.id != null && o.status != 'done' && o.status != 'canceled')
      .toList()
    ..sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
  return open.take(limit).toList();
}

/// Sheet "Em qual OS?": lists recent open orders; tapping one pops it right
/// away (no confirm button, "Cancelar" is in the top bar).
class WhichOrderSheet extends StatelessWidget {
  const WhichOrderSheet({
    super.key,
    required this.batch,
    required this.orders,
    this.loading = false,
  });

  final ReceivedBatch batch;
  final List<Order> orders;
  final bool loading;

  /// Loads the open orders of the current company and shows the sheet.
  static Future<Order?> show(BuildContext context,
      {required ReceivedBatch batch}) {
    return AppSheet.show<Order>(
      context,
      (_) => _WhichOrderLoader(batch: batch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return AppSheet(
      title: l10n.receivedWhichOrder,
      child: loading
          ? const Center(child: CupertinoActivityIndicator())
          : orders.isEmpty
              ? EmptyState(title: l10n.noOpenOrders)
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageMargin,
                        AppSpacing.md,
                        AppSpacing.pageMargin,
                        0,
                      ),
                      child: Text(
                        summarizeBatch(l10n, batch),
                        style: AppTypography.callout.copyWith(color: secondary),
                      ),
                    ),
                    SectionLabel(l10n.openOrdersCount(orders.length)),
                    for (final o in orders)
                      AppListRow(
                        key: ValueKey('order-${o.id}'),
                        leading: StatusDot(
                          color: OrderStatusStyle.dotColor(o.status),
                          size: 10,
                        ),
                        title: o.customer?.name ?? '#${o.number ?? ''}',
                        subtitle: OrderStatusStyle.label(l10n, o.status),
                        trailing: o.number == null ? null : '#${o.number}',
                        onTap: () => Navigator.of(context).pop(o),
                      ),
                  ],
                ),
    );
  }
}

class _WhichOrderLoader extends StatefulWidget {
  const _WhichOrderLoader({required this.batch});
  final ReceivedBatch batch;

  @override
  State<_WhichOrderLoader> createState() => _WhichOrderLoaderState();
}

class _WhichOrderLoaderState extends State<_WhichOrderLoader> {
  List<Order>? _orders;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = Global.companyAggr?.id;
    var result = <Order>[];
    if (companyId != null) {
      try {
        final repo = TenantOrderRepository();
        final lists = await Future.wait([
          repo.streamOrders(companyId, status: 'due_date').first,
          repo.streamOrders(companyId, status: 'quote').first,
        ]).timeout(const Duration(seconds: 10));
        result = recentOpenOrders(lists.expand((l) => l));
      } catch (_) {}
    }
    if (mounted) setState(() => _orders = result);
  }

  @override
  Widget build(BuildContext context) => WhichOrderSheet(
        batch: widget.batch,
        orders: _orders ?? const [],
        loading: _orders == null,
      );
}
