import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
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

/// "O que vai ser feito?": one picker ([PickerScaffold]) over services and
/// products. The search is always shown: typing creates.
///
/// - Each row says "serviço" or "produto" and shows the price (only with the
///   view-prices permission; no price shows "sem valor").
/// - Tapping a row pops with an [OrderItemPick]: the order adds it right away.
/// - "+ Novo serviço ou peça" on top focuses the search; when nothing has
///   exactly the typed name, the first row is "Cadastrar “X”" (only with
///   `manageServices`/`manageProducts`).
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

  final Map<CatalogKind, List<CatalogItem>?> _items = {};
  final List<StreamSubscription<List<CatalogItem>>> _subs = [];
  bool _hasError = false;
  bool _creating = false;
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
    (widget.mostUsed ?? loadMostUsedItemKeys)()
        .then((keys) {
          if (mounted) setState(() => _mostUsed = keys);
        })
        .catchError((_) {});
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
      _subs.add(
        _source
            .watch(kind)
            .listen(
              (list) {
                if (mounted) setState(() => _items[kind] = list);
              },
              onError: (_) {
                if (mounted) setState(() => _hasError = true);
              },
            ),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
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
    final entries = _loading ? const <_Entry>[] : _entries;
    return PickerScaffold<_Entry>(
      title: l10n.pickerItemTitle,
      itemCount: entries.length,
      searchPlaceholder: l10n.orderItemSearchPlaceholder,
      // Typing is how a new item is created here, so the search is always
      // there (as in the prototype), whatever the size of the catalog.
      alwaysShowSearch: true,
      autofocusSearch: true,
      loading: _loading && !_hasError,
      hasError: _hasError,
      onRetry: _listen,
      enabled: !_creating,
      addLabel: _createKind == null ? null : l10n.pickerNewItem,
      onCreate: _createKind == null ? null : _create,
      // TODO: switch to the default "Cadastrar “x”" once
      // test/screens/order/order_screen_v2_test.dart stops asserting this.
      createLabel: l10n.orderCreateAndAdd,
      noMatchText: l10n.pickerNoItemWith,
      emptyTitle: l10n.orderCatalogEmpty,
      onSelect: _pick,
      sections: (query) => _sections(entries, query),
    );
  }

  List<PickerSection<_Entry>> _sections(List<_Entry> entries, String query) {
    final l10n = context.l10n;
    if (query.isNotEmpty) {
      final folded = removeAccents(query).toLowerCase();
      return [
        PickerSection(
          items: [
            for (final e in entries)
              if (e.folded.contains(folded)) _item(e),
          ],
        ),
      ];
    }
    final byKey = {for (final e in entries) e.key: e};
    final mostUsed = _mostUsed.map((k) => byKey[k]).whereType<_Entry>();
    return [
      if (mostUsed.isNotEmpty)
        PickerSection(
          label: l10n.orderMostUsed,
          items: mostUsed.map(_item).toList(),
        ),
      PickerSection(
        label: mostUsed.isEmpty ? null : l10n.orderAllItems,
        items: entries.map(_item).toList(),
      ),
    ];
  }

  PickerItem<_Entry> _item(_Entry entry) {
    final l10n = context.l10n;
    final item = entry.item;
    final kindLabel = entry.kind == CatalogKind.service
        ? l10n.orderItemKindService
        : l10n.orderItemKindProduct;
    String? price;
    if (_permissions.canViewPrices) {
      price = item.value == null
          ? l10n.catalogNoPrice
          : (FormatService()..setLocale(l10n.localeName)).formatCurrency(
              item.value!,
            );
    }
    return PickerItem(
      value: entry,
      title: item.name ?? '',
      subtitle: kindLabel,
      trailing: price,
    );
  }
}
