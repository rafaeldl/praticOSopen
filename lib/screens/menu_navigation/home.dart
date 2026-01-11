import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider;
// Keeping Material for specific color references if needed, but UI tree will be Cupertino.

import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:provider/provider.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

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

  List<Map<String, dynamic>> _getFilters(SegmentConfigProvider config) {
    final canViewPrices = _authService.hasPermission(PermissionType.viewPrices);

    final baseFilters = [
      {'status': 'Todos', 'icon': CupertinoIcons.square_grid_2x2, 'field': null},
      {'status': 'Entrega', 'field': 'due_date', 'icon': CupertinoIcons.clock},
      {'status': config.getStatus('approved'), 'field': 'approved', 'icon': CupertinoIcons.hand_thumbsup},
      {'status': config.getStatus('progress'), 'field': 'progress', 'icon': CupertinoIcons.arrow_2_circlepath},
      {'status': config.getStatus('quote'), 'field': 'quote', 'icon': CupertinoIcons.doc_text},
      {'status': config.getStatus('done'), 'field': 'done', 'icon': CupertinoIcons.check_mark_circled},
      {'status': config.getStatus('canceled'), 'field': 'canceled', 'icon': CupertinoIcons.xmark_circle},
    ];

    // Apenas adicionar filtros financeiros se usuário tem permissão
    if (canViewPrices) {
      baseFilters.addAll([
        {'status': 'A receber', 'field': 'unpaid', 'icon': CupertinoIcons.money_dollar},
        {'status': 'Pago', 'field': 'paid', 'icon': CupertinoIcons.money_dollar_circle},
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
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildNavigationBar(context, config),
            _buildActiveFilterHeader(config),
            _buildSearchField(config),
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
                                 const Text('Carregar mais'),
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
            Semantics(
              identifier: 'filter_button',
              button: true,
              label: config.label(LabelKeys.filter),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(
                  currentSelected == 0
                      ? CupertinoIcons.line_horizontal_3_decrease_circle
                      : CupertinoIcons.line_horizontal_3_decrease_circle_fill,
                ),
                onPressed: () => _showFilterOptions(context, config),
              ),
            ),
            if (_authService.hasPermission(PermissionType.viewFinancialReports))
              Semantics(
                identifier: 'dashboard_button',
                button: true,
                label: 'Painel Financeiro',
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

  void _showFilterOptions(BuildContext context, SegmentConfigProvider config) {
    final filters = _getFilters(config);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('${config.label(LabelKeys.filter)} por Status'),
        actions: filters.asMap().entries.map((entry) {
          final index = entry.key;
          final filter = entry.value;
          final isSelected = currentSelected == index;
          
          return CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(CupertinoIcons.checkmark, size: 16),
                  const SizedBox(width: 8),
                ],
                Text(
                  filter['status'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(context);
              if (currentSelected != index) {
                HapticFeedback.selectionClick();
                setState(() => currentSelected = index);
                orderStore.loadOrdersInfinite(filters[index]['field']);
              }
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(config.label(LabelKeys.cancel)),
          onPressed: () => Navigator.pop(context),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Buscar ${config.serviceOrderPlural}',
          onChanged: (value) {
            setState(() => _searchQuery = value.toLowerCase());
          },
        ),
      ),
    );
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
                    'Nenhuma ${config.serviceOrder} encontrada',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque em + para criar uma nova',
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
                      'Nenhum resultado encontrado',
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
                        'Há mais ordens para carregar. Role para baixo ou toque no botão para buscar nas próximas páginas.',
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
                                const Text('Carregar mais'),
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
                'Nenhum resultado encontrado',
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

    // Build services line: First service (+N more)
    String servicesText = '';
    final services = order.services ?? [];
    if (services.isNotEmpty) {
      final firstService = services.first.service?.name ?? services.first.description ?? '';
      if (firstService.isNotEmpty) {
        servicesText = firstService;
        if (services.length > 1) {
          servicesText += ' +${services.length - 1}';
        }
      }
    }

    // Build device line: Device name • Serial (only if device has data)
    String? deviceText;
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      if (name.isNotEmpty || serial.isNotEmpty) {
        final parts = <String>[];
        if (name.isNotEmpty) parts.add(name);
        if (serial.isNotEmpty) parts.add(serial);
        deviceText = parts.join(' • ');
      }
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        Navigator.of(context, rootNavigator: true)
            .pushNamed('/order', arguments: {'order': order})
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail with status dot overlay
                  _buildThumbnail(order, statusColor, config),
                  const SizedBox(width: 12),

                  // Main content (3 lines)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line 1: Customer name + Due date
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customer?.name ?? config.customer,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label.resolveFrom(context),
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (order.dueDate != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd/MM').format(order.dueDate!),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Line 2: Services + Price
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                servicesText.isNotEmpty ? servicesText : '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_authService.hasPermission(PermissionType.viewPrices)) ...[
                              const SizedBox(width: 8),
                              Text(
                                _formatCurrency(order.total),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Line 3: Device info + Indicators (overdue, paid)
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (config.showDeviceInOrderList && deviceText != null)
                              Expanded(
                                child: Text(
                                  deviceText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              const Spacer(),
                            // Indicators at the end
                            if (_isOverdue(order)) ...[
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.clock_fill,
                                size: 14,
                                color: CupertinoColors.systemRed,
                              ),
                            ],
                            if (_authService.hasPermission(PermissionType.viewPrices) && order.payment == 'paid') ...[
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.money_dollar_circle_fill,
                                size: 14,
                                color: CupertinoColors.systemGreen,
                              ),
                            ],
                          ],
                        ),
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
    );
  }

  Widget _buildThumbnail(Order order, Color statusColor, SegmentConfigProvider config) {
    const double size = 48;
    const double dotSize = 14;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Thumbnail image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: order.coverPhotoUrl != null
                ? CachedImage(
                    imageUrl: order.coverPhotoUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: size,
                    height: size,
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    child: Icon(
                      config.deviceIcon,
                      size: 24,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
          ),
          // Status dot at bottom-right corner
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  width: 2,
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

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$', decimalDigits: 2).format(value ?? 0);
  }
}