import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/order_items.dart';
import 'package:praticos/utils/search_utils.dart';

/// What the user picked in "O que vai na OS?".
class OrderItemPick {
  const OrderItemPick(this.kind, this.item);

  final CatalogKind kind;
  final CatalogItem item;
}

/// Keys (`service:<id>` / `product:<id>`) of the items most used in the last
/// ~50 orders of the company.
Future<List<String>> loadMostUsedItemKeys() async {
  final companyId = Global.companyAggr?.id;
  if (companyId == null) return const [];
  final list = await TenantOrderRepository().getQueryList(
    companyId,
    orderBy: [OrderBy('createdAt', descending: true)],
    limit: 50,
  );
  return mostUsedItemKeys(list.whereType<Order>().toList());
}

/// "O que vai na OS?": one search over services and products.
///
/// - Each row says "serviço" or "produto" and shows the price (only with the
///   view-prices permission; no price shows "sem valor").
/// - Tapping a row pops with an [OrderItemPick]: the order adds it right away.
/// - When nothing has exactly the typed name, the first row is
///   "Criar “X” e pôr na OS" (only with `manageServices`/`manageProducts`).
///   It saves the item with the name only (price left blank) and adds it.
/// - Without a query, "Mais usados" (derived from the last ~50 orders) comes
///   first, then everything by name.
class OrderItemSearchScreen extends StatefulWidget {
  const OrderItemSearchScreen({
    super.key,
    this.source,
    this.permissions,
    this.mostUsed,
  });

  /// Injected in tests; defaults to [FirestoreCatalogSource].
  final CatalogSource? source;

  /// Injected in tests; defaults to the current user's role.
  final CatalogPermissions? permissions;

  /// Injected in tests; defaults to [loadMostUsedItemKeys].
  final Future<List<String>> Function()? mostUsed;

  @override
  State<OrderItemSearchScreen> createState() => _OrderItemSearchScreenState();
}

class _Entry {
  const _Entry(this.kind, this.item);

  final CatalogKind kind;
  final CatalogItem item;

  String get key => catalogItemKey(kind.name, item.id ?? '');
  String get folded => removeAccents(item.name ?? '').toLowerCase();
}

class _OrderItemSearchScreenState extends State<OrderItemSearchScreen> {
  late final CatalogSource _source = widget.source ?? FirestoreCatalogSource();
  late final CatalogPermissions _permissions =
      widget.permissions ?? CatalogPermissions.current();
  final TextEditingController _search = TextEditingController();

  final Map<CatalogKind, List<CatalogItem>?> _items = {};
  final List<StreamSubscription<List<CatalogItem>>> _subs = [];
  bool _hasError = false;
  bool _creating = false;
  String _query = '';
  List<String> _mostUsed = const [];

  List<CatalogKind> get _kinds => [
        for (final k in CatalogKind.values)
          if (_permissions.canView(k)) k,
      ];

  /// Kind created by "Criar “X” e pôr na OS": service first.
  CatalogKind? get _createKind {
    for (final k in CatalogKind.values) {
      if (_permissions.canManage(k)) return k;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _listen();
    (widget.mostUsed ?? loadMostUsedItemKeys)().then((keys) {
      if (mounted) setState(() => _mostUsed = keys);
    }).catchError((_) {});
  }

  void _listen() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    setState(() {
      _hasError = false;
      _items.clear();
    });
    for (final kind in _kinds) {
      _subs.add(_source.watch(kind).listen(
        (list) {
          if (mounted) setState(() => _items[kind] = list);
        },
        onError: (_) {
          if (mounted) setState(() => _hasError = true);
        },
      ));
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  bool get _loading => _kinds.any((k) => _items[k] == null);

  List<_Entry> get _entries {
    final all = <_Entry>[
      for (final kind in _kinds)
        for (final item in _items[kind] ?? const <CatalogItem>[])
          _Entry(kind, item),
    ];
    all.sort((a, b) => a.folded.compareTo(b.folded));
    return all;
  }

  void _pick(_Entry entry) {
    Navigator.pop(context, OrderItemPick(entry.kind, entry.item));
  }

  Future<void> _create(String name) async {
    final kind = _createKind;
    if (kind == null || _creating) return;
    setState(() => _creating = true);
    final item = CatalogItem(name: name);
    try {
      await _source.save(kind, item);
      if (!mounted) return;
      Navigator.pop(context, OrderItemPick(kind, item));
    } catch (_) {
      if (!mounted) return;
      setState(() => _creating = false);
      final l10n = context.l10n;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(l10n.orderCreateItemError),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(l10n.orderWhatGoesTitle),
            backgroundColor: AppColors.background.resolveFrom(context),
            border: null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.blockMargin,
                vertical: AppSpacing.sm,
              ),
              child: CupertinoSearchTextField(
                controller: _search,
                autofocus: true,
                placeholder: l10n.orderItemSearchPlaceholder,
                backgroundColor: AppColors.secondaryFill.resolveFrom(context),
                style: AppTypography.body.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          ..._buildBody(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildBody() {
    final l10n = context.l10n;
    if (_hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(onRetry: _listen),
        ),
      ];
    }
    if (_loading) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }

    final query = _query.trim();
    final folded = removeAccents(query).toLowerCase();
    final entries = _entries;
    final matches = query.isEmpty
        ? entries
        : entries.where((e) => e.folded.contains(folded)).toList();
    final exact = matches.any((e) => e.folded == folded);
    final canCreate = query.isNotEmpty && !exact && _createKind != null;

    final children = <Widget>[];
    if (canCreate) {
      children.add(
        AddRow(
          label: l10n.orderCreateAndAdd(query),
          onTap: () => _create(query),
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin, 0, AppSpacing.pageMargin, AppSpacing.md,
          ),
          child: Text(
            l10n.orderCreateItemHint,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      );
    }

    if (entries.isEmpty && query.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: l10n.orderCatalogEmpty),
        ),
      ];
    }

    if (matches.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: Text(
            l10n.catalogNoMatch(query),
            textAlign: TextAlign.center,
            style: AppTypography.callout.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ),
      );
    } else if (query.isEmpty) {
      final byKey = {for (final e in entries) e.key: e};
      final mostUsed =
          _mostUsed.map((k) => byKey[k]).whereType<_Entry>().toList();
      if (mostUsed.isNotEmpty) {
        children.add(SectionLabel(l10n.orderMostUsed));
        children.addAll(mostUsed.map(_row));
        children.add(SectionLabel(l10n.orderAllItems));
      }
      children.addAll(entries.map(_row));
    } else {
      children.addAll(matches.map(_row));
    }

    return [SliverList(delegate: SliverChildListDelegate(children))];
  }

  Widget _row(_Entry entry) {
    final l10n = context.l10n;
    final item = entry.item;
    final kindLabel = entry.kind == CatalogKind.service
        ? l10n.orderItemKindService
        : l10n.orderItemKindProduct;
    String? price;
    if (_permissions.canViewPrices) {
      price = item.value == null
          ? l10n.catalogNoPrice
          : (FormatService()..setLocale(l10n.localeName))
              .formatCurrency(item.value!);
    }
    return AppListRow(
      title: item.name ?? '',
      subtitle: kindLabel,
      trailing: price,
      showChevron: false,
      onTap: _creating ? null : () => _pick(entry),
    );
  }
}
