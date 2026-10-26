import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/received_share.dart';
import 'package:praticos/services/segment_config_service.dart';
import 'package:praticos/theme/status_style.dart';
import 'package:praticos/utils/search_utils.dart';

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

/// Letters and digits only, lower case and without accents: "ABC-1D23" and
/// "abc 1d23" are the same plate.
String _compact(String text) =>
    removeAccents(text).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// True when [order] matches [query]: customer name, number ("193" or
/// "#193") or a vehicle/device name or plate, ignoring case and accents.
bool orderMatchesSearch(Order order, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  final digits = q.startsWith('#') ? q.substring(1).trim() : q;
  if (RegExp(r'^\d+$').hasMatch(digits) &&
      order.number != null &&
      '${order.number}'.startsWith(digits)) {
    return true;
  }
  if (pickerMatches(order.customer?.name, q)) return true;
  final plate = _compact(q);
  for (final d in order.effectiveDevices) {
    if (pickerMatches(d.name, q)) return true;
    if (plate.isNotEmpty && _compact(d.serial ?? '').contains(plate)) {
      return true;
    }
  }
  return false;
}

/// Orders matching [query] among [orders] (open ones and the latest of the
/// company, so a finished order still waiting for payment is found too).
/// Canceled orders are left out; one row per order, newest first.
List<Order> searchOrders(
  Iterable<Order?> orders,
  String query, {
  int limit = 50,
}) {
  final seen = <String>{};
  final found = <Order>[];
  for (final o in orders.whereType<Order>()) {
    if (o.id == null || o.status == 'canceled') continue;
    if (!seen.add(o.id!)) continue;
    if (orderMatchesSearch(o, query)) found.add(o);
  }
  found.sort((a, b) => (b.number ?? 0).compareTo(a.number ?? 0));
  return found.take(limit).toList();
}

/// What was chosen in "Em qual OS?": an existing order, or "Nova OS".
class WhichOrderChoice {
  const WhichOrderChoice.order(Order this.order);
  const WhichOrderChoice.newOrder() : order = null;

  final Order? order;
  bool get isNewOrder => order == null;
}

/// How many recent orders the search looks at (newest first, no index).
const int kShareSearchLimit = 300;

/// Sheet "Em qual OS?" ([PickerScaffold]): recent open orders, a search that
/// also finds older and finished orders, and "+" for a new order. Tapping an
/// order pops it right away (no confirm button, "X" cancels).
class WhichOrderSheet extends StatelessWidget {
  const WhichOrderSheet({
    super.key,
    required this.batch,
    required this.orders,
    this.loading = false,
    this.searchPool,
    this.searching = false,
    this.onQueryChanged,
    this.canCreate = false,
    this.deviceLabel,
  });

  final ReceivedBatch batch;

  /// Recent open orders, shown while nothing is typed.
  final List<Order> orders;
  final bool loading;

  /// Orders the search looks at (open and latest); null until loaded, then
  /// the search falls back to [orders].
  final List<Order>? searchPool;

  /// Loading [searchPool] for the typed text.
  final bool searching;
  final ValueChanged<String>? onQueryChanged;

  /// Shows the "+" (Nova OS).
  final bool canCreate;

  /// "veículo" / "aparelho" for the search hint.
  final String? deviceLabel;

  /// Loads the open orders of the current company and shows the sheet.
  static Future<WhichOrderChoice?> show(BuildContext context,
      {required ReceivedBatch batch}) {
    return AppSheet.show<WhichOrderChoice>(
      context,
      (_) => _WhichOrderLoader(batch: batch),
    );
  }

  PickerItem<Order> _item(AppLocalizations l10n, Order o) {
    final device = o.effectiveDevices.isEmpty
        ? null
        : o.effectiveDevices.first.name ?? o.effectiveDevices.first.serial;
    return PickerItem<Order>(
      key: ValueKey('order-${o.id}'),
      value: o,
      leading: StatusDot(color: OrderStatusStyle.dotColor(o.status), size: 10),
      title: o.customer?.name ?? '#${o.number ?? ''}',
      subtitle: [
        OrderStatusStyle.label(l10n, o.status),
        if (device != null && device.isNotEmpty) device,
      ].join(' · '),
      trailing: o.number == null ? null : '#${o.number}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PickerScaffold<Order>(
      title: l10n.receivedWhichOrder,
      subtitle: summarizeBatch(l10n, batch),
      leading: GlassBarButton(
        key: const ValueKey('which_order_close'),
        label: l10n.cancel,
        icon: CupertinoIcons.xmark,
        onPressed: () => Navigator.of(context).pop(),
      ),
      // The search also reaches finished and older orders, not only the
      // listed ones, so it shows even with a short list.
      alwaysShowSearch: true,
      searchPlaceholder: deviceLabel == null
          ? l10n.homeSearchHint
          : l10n.homeSearchHintDevice(deviceLabel!.toLowerCase()),
      onQueryChanged: onQueryChanged,
      itemCount: orders.length,
      loading: loading || searching,
      addLabel: canCreate ? l10n.newOrderButton : null,
      onAdd: canCreate
          ? () => Navigator.of(context).pop(const WhichOrderChoice.newOrder())
          : null,
      emptyTitle: l10n.noOpenOrders,
      onSelect: (o) => Navigator.of(context).pop(WhichOrderChoice.order(o)),
      sections: (query) => query.isEmpty
          ? [
              PickerSection<Order>(
                label: l10n.openOrdersCount(orders.length),
                items: [for (final o in orders) _item(l10n, o)],
              ),
            ]
          : [
              PickerSection<Order>(
                items: [
                  for (final o in searchOrders(
                    [...orders, ...?searchPool],
                    query,
                  ))
                    _item(l10n, o),
                ],
              ),
            ],
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
  final TenantOrderRepository _repo = TenantOrderRepository();
  List<Order>? _orders;

  /// Every open order (not only the 20 listed), for the search.
  List<Order> _allOpen = const [];
  List<Order>? _pool;
  Future<void>? _poolLoad;
  bool _searching = false;

  /// Consultant and technician read only the orders they created (Firestore
  /// rules): one equality query, sorted here.
  String? get _ownOrdersOnly {
    final auth = AuthorizationService.instance;
    if (auth.isConsultant || auth.isTechnician) return Global.currentUser?.uid;
    return null;
  }

  /// Same rule as the "+" beside the tabs.
  bool get _canCreate {
    final auth = AuthorizationService.instance;
    return !auth.isTechnician && auth.hasPermission(PermissionType.createOrder);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companyId = Global.companyAggr?.id;
    var open = <Order>[];
    if (companyId != null) {
      try {
        final own = _ownOrdersOnly;
        if (own != null) {
          final mine = (await _repo
                  .streamOrders(companyId, createdById: own)
                  .first
                  .timeout(const Duration(seconds: 10)))
              .whereType<Order>()
              .toList();
          _pool = mine.take(kShareSearchLimit).toList();
          open = recentOpenOrders(mine, limit: mine.length);
        } else {
          final lists = await Future.wait([
            _repo.streamOrders(companyId, status: 'due_date').first,
            _repo.streamOrders(companyId, status: 'quote').first,
          ]).timeout(const Duration(seconds: 10));
          open = recentOpenOrders(
            lists.expand((l) => l),
            limit: 1 << 30,
          );
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _allOpen = open;
        _orders = open.take(20).toList();
      });
    }
  }

  /// The latest orders of the company, loaded once on the first search.
  /// Ordered by `createdAt`; for consultant/technician the repository adds
  /// `createdBy.id`, served by the (createdBy.id, createdAt) index.
  Future<void> _loadPool() async {
    final companyId = Global.companyAggr?.id;
    var pool = <Order>[];
    if (companyId != null) {
      try {
        pool = (await _repo.getQueryList(
          companyId,
          orderBy: [OrderBy('createdAt', descending: true)],
          limit: kShareSearchLimit,
        ).timeout(const Duration(seconds: 10)))
            .whereType<Order>()
            .toList();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _pool = pool;
        _searching = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty || _pool != null || _poolLoad != null) return;
    setState(() => _searching = true);
    _poolLoad = _loadPool();
  }

  @override
  Widget build(BuildContext context) {
    String? device;
    try {
      device = SegmentConfigService().device;
      // Labels not loaded yet come back as their key ("device._entity").
      if (device.contains('.')) device = null;
    } catch (_) {}
    return WhichOrderSheet(
      batch: widget.batch,
      orders: _orders ?? const [],
      loading: _orders == null,
      searchPool: [..._allOpen, ...?_pool],
      searching: _searching,
      onQueryChanged: _onQueryChanged,
      canCreate: _canCreate,
      deviceLabel: device,
    );
  }
}
