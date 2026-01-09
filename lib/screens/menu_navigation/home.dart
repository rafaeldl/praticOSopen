import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider, InkWell;
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
            _buildOrdersList(config),
            SliverToBoxAdapter(
               child: Observer(builder: (_) {
                 if (orderStore.isLoading && orderStore.orders.isNotEmpty) {
                   return const Padding(
                     padding: EdgeInsets.all(16.0),
                     child: Center(child: CupertinoActivityIndicator()),
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
            color: CupertinoColors.systemGroupedBackground,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.person_fill, size: 14, color: CupertinoColors.activeBlue.resolveFrom(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${config.customer}: ${orderStore.customerFilter!.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
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

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= orderStore.orders.length) return null;
              final order = orderStore.orders[index];
              if (order == null) return null;
              return _buildOrderItem(order, index, index == orderStore.orders.length - 1, config);
            },
            childCount: orderStore.orders.length,
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(Order order, int index, bool isLast, SegmentConfigProvider config) {
    final statusColor = _getCupertinoStatusColor(order.status);
    
    // Date Formatting (Mail style: "Yesterday", "Friday", or "dd/MM/yy")
    if (order.createdAt != null) {
      final now = DateTime.now();
      final diff = now.difference(order.createdAt!);
      if (diff.inDays == 0) {
      } else if (diff.inDays == 1) {
      } else if (diff.inDays < 7) {
// Day name
      } else {
      }
    }

    String subtitle = '#${order.number ?? '-'}';
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      
      if (name.isNotEmpty) {
        subtitle += ' • $name';
      }
      // Assuming serial serves as the license plate/identifier
      if (serial.isNotEmpty) {
        subtitle += ' • $serial';
      }
    }

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Material(
        type: MaterialType.transparency,
                            child: InkWell(
                            onTap: () {
                               Navigator.of(context, rootNavigator: true).pushNamed('/order', arguments: {'order': order})
                                   .then((_) {
                                     final configInner = Provider.of<SegmentConfigProvider>(context, listen: false);
                                     _loadOrders(_getFilters(configInner));
                                   });
                            },                  child: Column(            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Compact padding
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Thumbnail (Left side again)
                    _buildThumbnail(order),
                    const SizedBox(width: 12),
                    
                    // Main Content
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Line 1: Customer (Left) --- Value & Dot (Right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Apenas mostrar valor se usuário tem permissão
                                  if (_authService.hasPermission(PermissionType.viewPrices)) ...[
                                    Text(
                                      _formatCurrency(order.total),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: order.payment == 'paid' ? CupertinoColors.label.resolveFrom(context) : CupertinoColors.secondaryLabel.resolveFrom(context),
                                        fontWeight: order.payment == 'paid' ? FontWeight.bold : FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Status Dot (Now on the right)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 12,
                                color: CupertinoColors.tertiaryLabel.resolveFrom(context)
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          
                          // Line 2: #OS • Vehicle • Plate
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  indent: 76, // Adjusted indent for thumbnail (52 size + padding)
                  color: CupertinoColors.separator, 
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Order order) {
    final url = order.coverPhotoUrl;
    const double size = 52.0; // Slightly larger for iOS feel

    return ClipRRect(
      borderRadius: BorderRadius.circular(12), // Smoother corners
      child: Container(
        width: size,
        height: size,
        color: CupertinoColors.systemGroupedBackground,
        child: url != null && url.isNotEmpty
            ? CachedImage.thumbnail(
                imageUrl: url,
                size: size,
              )
            : Center(
                child: Icon(
                  CupertinoIcons.wrench,
                  size: 24,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
              ),
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

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$').format(value ?? 0);
  }
}