import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider;
// Keeping Material for specific color references if needed, but UI tree will be Cupertino.

import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';

import '../../global.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentSelected = 0;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final AuthorizationService _authService = AuthorizationService.instance;
  late OrderStore orderStore;
  bool _showFilterChips = false;

  List<Map<String, dynamic>> _getFilters(SegmentConfigProvider config) {
    final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);

    final l10n = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'pt'
        ? _PtLabels()
        : (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'es' ? _EsLabels() : _EnLabels());

    final baseFilters = [
      {'status': l10n.all, 'icon': CupertinoIcons.square_grid_2x2, 'field': null},
      {'status': l10n.unread, 'icon': CupertinoIcons.bubble_left_fill, 'field': 'unread'},
      {'status': l10n.delivery, 'field': 'due_date', 'icon': CupertinoIcons.clock},
      {'status': config.getStatus('approved'), 'field': 'approved', 'icon': CupertinoIcons.hand_thumbsup},
      {'status': config.getStatus('progress'), 'field': 'progress', 'icon': CupertinoIcons.arrow_2_circlepath},
      {'status': config.getStatus('quote'), 'field': 'quote', 'icon': CupertinoIcons.doc_text},
      {'status': config.getStatus('done'), 'field': 'done', 'icon': CupertinoIcons.check_mark_circled},
      {'status': config.getStatus('canceled'), 'field': 'canceled', 'icon': CupertinoIcons.xmark_circle},
    ];

    // Apenas adicionar filtros financeiros se usuário tem permissão
    if (canViewPrices) {
      baseFilters.addAll([
        {'status': l10n.toReceive, 'field': 'unpaid', 'icon': CupertinoIcons.money_dollar},
        {'status': l10n.paid, 'field': 'paid', 'icon': CupertinoIcons.money_dollar_circle},
      ]);
    }

    return baseFilters;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    orderStore = Provider.of<OrderStore>(context);
    final config = Provider.of<SegmentConfigProvider>(context, listen: false);

    if (Global.companyAggr?.id == null) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _loadOrders(_getFilters(config));
      });
    } else {
      _loadOrders(_getFilters(config));
    }
  }

  void _loadOrders(List<Map<String, dynamic>> filters) {
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    orderStore.loadOrdersInfinite(filters[currentSelected]['field']).then((_) {
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            if (_scrollController.position.maxScrollExtent >= currentOffset && currentOffset > 0) {
              _scrollController.jumpTo(currentOffset);
            } else {
              _scrollController.jumpTo(0);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final config = Provider.of<SegmentConfigProvider>(context, listen: false);
    final filters = _getFilters(config);
    final offset = _scrollController.offset;
    // Simple logic to just load more
    if (offset >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreOrders(filters);
    }
  }

  void _loadMoreOrders(List<Map<String, dynamic>> filters) {
    if (!orderStore.isLoading && orderStore.hasMoreOrders) {
      orderStore.loadMoreOrdersInfinite(filters[currentSelected]['field']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    FirebaseCrashlytics.instance.log("Abrindo home (Cupertino)");
    // Ensuring default text style is available
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Show filter chips when user overscrolls at top (pulls down)
            if (notification is OverscrollNotification) {
              if (notification.overscroll < 0 && !_showFilterChips) {
                setState(() => _showFilterChips = true);
              }
            }
            // Also show when scrolled to top
            if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels <= 0 && !_showFilterChips) {
                setState(() => _showFilterChips = true);
              }
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildNavigationBar(context, config),
              _buildActiveFilterHeader(config),
              _buildSearchField(config),
              _buildFilterChips(config),
              _buildOrdersList(config),
            SliverToBoxAdapter(
               child: Observer(builder: (_) {
                 if (orderStore.isLoading && orderStore.orders.isNotEmpty) {
                   return const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Center(child: CupertinoActivityIndicator()),
                   );
                 }

                 // Mostrar botão "Carregar mais" quando há mais dados disponíveis
                 if (orderStore.hasMoreOrders && orderStore.orders.isNotEmpty) {
                   return Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Center(
                       child: Column(
                         children: [
                           CupertinoButton(
                             onPressed: () {
                               final filters = _getFilters(config);
                               _loadMoreOrders(filters);
                             },
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Icon(
                                   CupertinoIcons.arrow_down_circle,
                                   size: 20,
                                   color: CupertinoColors.activeBlue,
                                 ),
                                 const SizedBox(width: 8),
                                 Text(context.l10n.seeMore),
                               ],
                             ),
                           ),
                           const SizedBox(height: 80), // Extra padding for TabBar
                         ],
                       ),
                     ),
                   );
                 }

                 return const SizedBox(height: 100); // Bottom padding to clear TabBar
               }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context, SegmentConfigProvider config) {
    return CupertinoSliverNavigationBar(
      largeTitle: Semantics(
        identifier: 'home_title',
        child: Text(config.serviceOrderPlural),
      ),
      trailing: Observer(
        builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_authService.hasPermission(PermissionType.viewFinancialReports))
              Semantics(
                identifier: 'dashboard_button',
                button: true,
                label: context.l10n.dashboard,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.chart_bar_alt_fill),
                  onPressed: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed('/financial_dashboard_simple'),
                ),
              ),
            Semantics(
              identifier: 'add_order_button',
              button: true,
              label: config.label(LabelKeys.createServiceOrder),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context, rootNavigator: true).pushNamed('/order').then((_) {
                    final configInner = Provider.of<SegmentConfigProvider>(context, listen: false);
                    _loadOrders(_getFilters(configInner));
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterHeader(SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        if (orderStore.customerFilter == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.resolveFrom(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.person_fill, size: 14, color: CupertinoColors.activeBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${config.customer}: ${orderStore.customerFilter!.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.activeBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      orderStore.setCustomerFilter(null);
                      final configInner = Provider.of<SegmentConfigProvider>(context, listen: false);
                      _loadOrders(_getFilters(configInner));
                    }, minimumSize: Size(0, 0),
                    child: Text(
                      config.label(LabelKeys.cancel), // Or "Limpar" if we had it. Cancel is close enough for prototype.
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(SegmentConfigProvider config) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: '${context.l10n.search} ${config.serviceOrderPlural}',
          onChanged: (value) {
            setState(() => _searchQuery = value.toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips(SegmentConfigProvider config) {
    final filters = _getFilters(config);

    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: _showFilterChips ? 36 : 0,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        margin: EdgeInsets.only(
          top: _showFilterChips ? 12 : 0,
          bottom: 8,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showFilterChips ? 1.0 : 0.0,
          child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = currentSelected == index;
            final chipColor = _getFilterChipColor(filter['field']);

            return GestureDetector(
              onTap: () {
                if (currentSelected != index) {
                  HapticFeedback.selectionClick();
                  setState(() => currentSelected = index);
                  orderStore.loadOrdersInfinite(filter['field']);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 14 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor
                      : CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? CupertinoColors.white
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: isSelected
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                filter['status'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
          ),
        ),
      ),
    );
  }

  Color _getFilterChipColor(String? field) {
    switch (field) {
      case 'unread':
        return CupertinoColors.systemRed;
      case 'approved':
        return CupertinoColors.systemBlue;
      case 'progress':
        return CupertinoColors.systemPurple;
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      case 'due_date':
        return CupertinoColors.systemTeal;
      case 'unpaid':
        return CupertinoColors.systemOrange;
      case 'paid':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.activeBlue;
    }
  }

  Widget _buildOrdersList(SegmentConfigProvider config) {
    return Observer(
      builder: (_) {
        if (orderStore.isLoading && orderStore.orders.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        // Apply search filter
        final filteredList = _searchQuery.isEmpty
            ? orderStore.orders
            : orderStore.orders.where((order) {
                if (order == null) return false;
                final orderNumber = order.number?.toString().toLowerCase() ?? '';
                final customerName = order.customer?.name?.toLowerCase() ?? '';
                final deviceName = order.device?.name?.toLowerCase() ?? '';
                final deviceSerial = order.device?.serial?.toLowerCase() ?? '';
                return orderNumber.contains(_searchQuery) ||
                    customerName.contains(_searchQuery) ||
                    deviceName.contains(_searchQuery) ||
                    deviceSerial.contains(_searchQuery);
              }).toList();

        if (orderStore.orders.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.doc_text_search,
                    size: 48,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.noOrders,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.noData,
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (filteredList.isEmpty) {
          // Se não encontrou resultados mas há mais ordens para carregar
          if (orderStore.hasMoreOrders && _searchQuery.isNotEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.search,
                      size: 48,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noResults,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        context.l10n.seeMore,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CupertinoButton(
                      onPressed: orderStore.isLoading
                          ? null
                          : () {
                              final filters = _getFilters(config);
                              _loadMoreOrders(filters);
                            },
                      child: orderStore.isLoading
                          ? const CupertinoActivityIndicator()
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_down_circle,
                                  size: 20,
                                  color: CupertinoColors.activeBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.seeMore),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Se não há mais dados para carregar
          return SliverFillRemaining(
            child: Center(
              child: Text(
                context.l10n.noResults,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= filteredList.length) return null;
              final order = filteredList[index];
              if (order == null) return null;
              return _buildOrderItem(order, index, index == filteredList.length - 1, config);
            },
            childCount: filteredList.length,
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(Order order, int index, bool isLast, SegmentConfigProvider config) {
    final statusColor = _getCupertinoStatusColor(order.status);
    final userId = Global.userAggr?.id ?? '';
    final hasUnread = order.hasUnread(userId);
    final unreadCount = order.getUnreadCount(userId);
    final isOverdue = _isOverdue(order);

    // Format last activity time
    String timeText = '';
    if (order.lastActivity?.createdAt != null) {
      timeText = _formatActivityTime(order.lastActivity!.createdAt!);
    } else if (order.updatedAt != null) {
      timeText = _formatActivityTime(order.updatedAt!);
    }

    // Last activity preview
    final activityIcon = order.lastActivity?.icon ?? '';
    final activityPreview = order.lastActivity?.preview ?? '';
    final isPublicActivity = order.lastActivity?.visibility == 'customer';

    // Build info line: #123 • Device • Serial
    final infoParts = <String>[];
    if (order.number != null) infoParts.add('#${order.number}');
    if (order.device?.name != null && order.device!.name!.isNotEmpty) {
      infoParts.add(order.device!.name!);
    }
    if (order.device?.serial != null && order.device!.serial!.isNotEmpty) {
      infoParts.add(order.device!.serial!);
    }
    final infoText = infoParts.join(' • ');

    // Payment status
    final isPaid = _authService.hasPermission(PermissionType.viewPrices) && order.payment == 'paid';

    return Semantics(
      identifier: 'order_card_${order.id ?? index}',
      button: true,
      label: order.customer?.name ?? config.customer,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.of(context, rootNavigator: true)
              .pushNamed('/timeline', arguments: {'order': order})
              .then((_) {
            final configInner = Provider.of<SegmentConfigProvider>(context, listen: false);
            _loadOrders(_getFilters(configInner));
          });
        },
        child: Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Thumbnail with badges
                    _buildThumbnail(order, statusColor, config, unreadCount),
                    const SizedBox(width: 12),

                    // Main content (2 lines - WhatsApp style)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Line 1: Customer name + time
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.customer?.name ?? config.customer,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                    color: CupertinoColors.label.resolveFrom(context),
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: hasUnread
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Line 2: Last activity preview
                          Row(
                            children: [
                              // Activity icon
                              if (activityIcon.isNotEmpty) ...[
                                Text(
                                  activityIcon,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                              ],
                              // Activity text
                              Expanded(
                                child: Text(
                                  activityPreview.isNotEmpty ? activityPreview : '-',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                    color: isPublicActivity
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Unread indicator
                              if (hasUnread) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.activeBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Line 3: #123 • Device • Serial + indicators
                          if (infoText.isNotEmpty || isOverdue || isPaid) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                // Info text
                                Expanded(
                                  child: Text(
                                    infoText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Indicators
                                if (isOverdue) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    CupertinoIcons.clock_fill,
                                    size: 14,
                                    color: CupertinoColors.systemRed,
                                  ),
                                ],
                                if (isPaid) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    size: 14,
                                    color: CupertinoColors.systemGreen,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 76, // 16 padding + 48 thumbnail + 12 spacing
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatActivityTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      // Today: show time
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == yesterday) {
      // Yesterday
      return context.l10n.yesterday;
    } else if (now.difference(date).inDays < 7) {
      // This week: show day name
      const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return days[date.weekday - 1];
    } else {
      // Older: show date
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildThumbnail(Order order, Color statusColor, SegmentConfigProvider config, int unreadCount) {
    const double size = 48;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Thumbnail image with status color border
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: order.coverPhotoUrl != null
                  ? CachedImage(
                      imageUrl: order.coverPhotoUrl!,
                      width: size - 6,
                      height: size - 6,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      child: Icon(
                        config.deviceIcon,
                        size: 22,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                    ),
            ),
          ),
          // Unread count badge at top-right
          if (unreadCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    width: 2,
                  ),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCupertinoStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return CupertinoColors.systemBlue;
      case 'done':
        return CupertinoColors.systemGreen;
      case 'canceled':
        return CupertinoColors.systemRed;
      case 'quote':
        return CupertinoColors.systemOrange;
      case 'progress':
        return CupertinoColors.systemPurple;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  bool _isOverdue(Order order) {
    if (order.dueDate == null) return false;
    if (order.status == 'done' || order.status == 'canceled') return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);

    return dueDay.isBefore(today);
  }
}

// Helper classes for filter labels (used outside BuildContext)
abstract class _FilterLabels {
  String get all;
  String get unread;
  String get delivery;
  String get toReceive;
  String get paid;
}

class _PtLabels implements _FilterLabels {
  @override String get all => 'Todos';
  @override String get unread => 'Não lidas';
  @override String get delivery => 'Entrega';
  @override String get toReceive => 'A receber';
  @override String get paid => 'Pago';
}

class _EnLabels implements _FilterLabels {
  @override String get all => 'All';
  @override String get unread => 'Unread';
  @override String get delivery => 'Delivery';
  @override String get toReceive => 'Receivable';
  @override String get paid => 'Paid';
}

class _EsLabels implements _FilterLabels {
  @override String get all => 'Todos';
  @override String get unread => 'No leídos';
  @override String get delivery => 'Entrega';
  @override String get toReceive => 'Por cobrar';
  @override String get paid => 'Pagado';
}