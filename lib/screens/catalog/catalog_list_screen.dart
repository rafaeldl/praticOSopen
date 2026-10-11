import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/catalog/catalog_item_form.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/order/order_item_search_screen.dart'
    show loadMostUsedItemKeys;
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/utils/order_items.dart' show catalogItemKey;
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/cached_image.dart';

/// Catalog of services and products.
///
/// - **Catalog mode** (from "Mais"): large title "Catálogo", a segmented
///   control "Serviços | Produtos" (only the kinds the user may view), search,
///   rows with price and chevron. Creating (floating button, opens a sheet),
///   editing and deleting require the `manage*` permission of the kind; with
///   only the view permission the rows are read-only.
/// - **Selection mode** (opened from the order with the `orderStore` route
///   argument, via `/service_list` or `/product_list`): a single kind, title
///   "Qual serviço?", no chevron and no deletion; tapping an item opens the
///   order item screen. "Criar serviço novo" needs `manage*`.
///
/// An item without a price (`value == null`) shows "sem valor".
class CatalogListScreen extends StatefulWidget {
  const CatalogListScreen({
    super.key,
    this.initialKind = CatalogKind.service,
    this.source,
    this.permissions,
    this.mostUsed,
  });

  final CatalogKind initialKind;

  /// Injected in tests; defaults to [FirestoreCatalogSource].
  final CatalogSource? source;

  /// Injected in tests; defaults to the current user's role.
  final CatalogPermissions? permissions;

  /// Injected in tests; defaults to [loadMostUsedItemKeys] (last ~50 orders).
  final Future<List<String>> Function()? mostUsed;

  @override
  State<CatalogListScreen> createState() => _CatalogListScreenState();
}

class _CatalogListScreenState extends State<CatalogListScreen> {
  late final CatalogSource _source = widget.source ?? FirestoreCatalogSource();
  late final CatalogPermissions _permissions =
      widget.permissions ?? CatalogPermissions.current();
  final TextEditingController _search = TextEditingController();

  late CatalogKind _kind = widget.initialKind;
  Object? _orderStore;
  bool _argsRead = false;

  final Map<CatalogKind, List<CatalogItem>?> _items = {};
  final Map<CatalogKind, bool> _errors = {};
  final Map<CatalogKind, StreamSubscription<List<CatalogItem>>> _subs = {};
  String _query = '';

  /// `service:<id>` / `product:<id>` of the items most used in recent orders.
  List<String> _mostUsedKeys = const [];

  bool get _selecting => _orderStore != null;

  /// Kinds shown in the segmented control (view permission).
  List<CatalogKind> get _kinds => [
        for (final k in CatalogKind.values)
          if (_permissions.canView(k)) k,
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _orderStore = args?['orderStore'];
    final kinds = _kinds;
    if (!_selecting && kinds.isNotEmpty && !kinds.contains(_kind)) {
      _kind = kinds.first;
    }
    _listen(_kind);
    // Counts in the segments need both lists (only the kinds the user may see).
    if (!_selecting) {
      for (final k in kinds) {
        if (k != _kind) _listen(k);
      }
    }
    (widget.mostUsed ?? loadMostUsedItemKeys)().then((keys) {
      if (mounted) setState(() => _mostUsedKeys = keys);
    }).catchError((_) {
      // "Mais usados" is a shortcut; the plain list still works without it.
    });
  }

  void _listen(CatalogKind kind) {
    _subs[kind]?.cancel();
    _items[kind] = null;
    _errors[kind] = false;
    _subs[kind] = _source.watch(kind).listen(
      (list) {
        if (mounted) setState(() => _items[kind] = list);
      },
      onError: (_) {
        if (mounted) setState(() => _errors[kind] = true);
      },
    );
  }

  void _selectKind(CatalogKind kind) {
    setState(() {
      _kind = kind;
      _search.clear();
      _query = '';
    });
    if (!_subs.containsKey(kind)) _listen(kind);
  }

  @override
  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  bool get _canManage => _permissions.canManage(_kind);

  Future<void> _create() async {
    final created = await AppSheet.show<CatalogItem>(
      context,
      (_) => CatalogItemForm(
        kind: _kind,
        source: _source,
        permissions: _permissions,
        asSheet: true,
      ),
    );
    if (created != null && mounted && _selecting) _open(created);
  }

  Future<void> _edit(CatalogItem item) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => CatalogItemForm(
          kind: _kind,
          source: _source,
          permissions: _permissions,
          item: item,
        ),
      ),
    );
  }

  void _open(CatalogItem item) {
    if (_selecting) {
      Navigator.pushNamed(context, _kind.orderRoute, arguments: {
        _kind.argKey: item.origin,
        'orderStore': _orderStore,
      });
    } else if (_canManage) {
      _edit(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kinds = _kinds;
    final title = _selecting
        ? (_kind == CatalogKind.service
            ? l10n.pickServiceTitle
            : l10n.pickProductTitle)
        : l10n.catalogTitle;
    final showSegments = !_selecting && kinds.length > 1;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Stack(
        children: [
          CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(title),
                backgroundColor: AppColors.background.resolveFrom(context),
                border: null,
              ),
              if (!_selecting)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      0,
                      AppSpacing.pageMargin,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.catalogSubtitle,
                      key: const Key('catalogSubtitle'),
                      style: AppTypography.callout.copyWith(
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                    ),
                  ),
                ),
              if (showSegments)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.blockMargin,
                      AppSpacing.sm,
                      AppSpacing.blockMargin,
                      0,
                    ),
                    child: CupertinoSlidingSegmentedControl<CatalogKind>(
                      groupValue: _kind,
                      onValueChanged: (k) {
                        if (k != null) _selectKind(k);
                      },
                      children: {
                        for (final k in kinds)
                          k: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              _segmentLabel(k),
                              style: AppTypography.callout,
                            ),
                          ),
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.blockMargin,
                    vertical: AppSpacing.sm,
                  ),
                  child: CupertinoSearchTextField(
                    controller: _search,
                    placeholder: _kind == CatalogKind.service
                        ? l10n.searchService
                        : l10n.searchProduct,
                    backgroundColor: AppColors.secondaryFill.resolveFrom(context),
                    style: AppTypography.body.copyWith(
                      color: AppColors.text.resolveFrom(context),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              ..._buildBody(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          if (!_selecting && _canManage) _buildFloatingButton(),
        ],
      ),
    );
  }

  /// "Serviços (24)" once the count of that kind is known.
  String _segmentLabel(CatalogKind kind) {
    final l10n = context.l10n;
    final name = kind == CatalogKind.service ? l10n.services : l10n.products;
    final count = _items[kind]?.length;
    return count == null ? name : l10n.catalogKindWithCount(name, count);
  }

  Widget _buildFloatingButton() {
    final l10n = context.l10n;
    return Positioned(
      left: AppSpacing.blockMargin,
      right: AppSpacing.blockMargin,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.fromHeight(AppSizes.primaryButtonHeight),
            color: AppColors.accent.resolveFrom(context),
            borderRadius: BorderRadius.circular(AppRadii.button),
            onPressed: _create,
            child: Text(
              _kind == CatalogKind.service
                  ? l10n.catalogNewService
                  : l10n.catalogNewProduct,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.onAccent.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final l10n = context.l10n;
    if (_errors[_kind] == true) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: l10n.catalogLoadError,
            onRetry: () => setState(() => _listen(_kind)),
          ),
        ),
      ];
    }
    final all = _items[_kind];
    if (all == null) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: LoadingState()),
      ];
    }

    final query = _query.trim().toLowerCase();
    if (all.isEmpty && query.isEmpty) {
      final isService = _kind == CatalogKind.service;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            title: isService
                ? l10n.catalogEmptyServices
                : l10n.catalogEmptyProducts,
            message: isService
                ? l10n.catalogEmptyServicesHint
                : l10n.catalogEmptyProductsHint,
            actionLabel: _selecting && _canManage
                ? (isService ? l10n.catalogNewService : l10n.catalogNewProduct)
                : null,
            onAction: _selecting && _canManage ? _create : null,
          ),
        ),
      ];
    }

    final matches = query.isEmpty
        ? all
        : all
            .where((i) => (i.name ?? '').toLowerCase().contains(query))
            .toList();

    final slivers = <Widget>[];
    if (_selecting && _canManage) {
      slivers.add(
        SliverToBoxAdapter(
          child: AddRow(
            label: _kind == CatalogKind.service
                ? l10n.catalogNewService
                : l10n.catalogNewProduct,
            onTap: _create,
          ),
        ),
      );
    }
    if (matches.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(title: l10n.catalogNoMatch(_query.trim())),
        ),
      );
      return slivers;
    }

    final showPrices = _permissions.canViewPrices;
    final format = FormatService()..setLocale(l10n.localeName);
    final tappable = _selecting || _canManage;

    Widget row(CatalogItem item, String keyPrefix) {
      return AppListRow(
        key: ValueKey('$keyPrefix${item.id ?? item.name}'),
        leading: _avatar(item),
        title: item.name ?? '',
        trailing: showPrices
            ? (item.value == null
                ? l10n.catalogNoPrice
                : format.formatCurrency(item.value!))
            : null,
        showChevron: !_selecting && _canManage,
        onTap: tappable ? () => _open(item) : null,
      );
    }

    // "Mais usados" on top, only without a search.
    final byKey = {
      for (final i in all)
        if (i.id != null) catalogItemKey(_kind.name, i.id!): i,
    };
    final mostUsed = query.isEmpty
        ? _mostUsedKeys.map((k) => byKey[k]).whereType<CatalogItem>().toList()
        : const <CatalogItem>[];
    if (mostUsed.isNotEmpty) {
      slivers.add(
        SliverList(
          delegate: SliverChildListDelegate([
            SectionLabel(l10n.orderMostUsed),
            for (final item in mostUsed) row(item, 'used-'),
            SectionLabel(l10n.orderAllItems),
          ]),
        ),
      );
    }

    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => row(matches[index], ''),
          childCount: matches.length,
        ),
      ),
    );
    if (!_selecting && query.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.lg,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.catalogTip,
              key: const Key('catalogTip'),
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _avatar(CatalogItem item) {
    final hasPhoto = item.photo != null && item.photo!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: SizedBox(
        width: 40,
        height: 40,
        child: hasPhoto
            ? CachedImage(
                imageUrl: item.photo!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              )
            : ColoredBox(
                color: AppColors.secondaryFill.resolveFrom(context),
                child: Icon(
                  _kind == CatalogKind.service
                      ? CupertinoIcons.wrench
                      : CupertinoIcons.cube_box,
                  size: 20,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
      ),
    );
  }
}
