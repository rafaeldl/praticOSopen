import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../global.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentSelected = 0;
  final ScrollController _scrollController = ScrollController();
  late OrderStore orderStore;
  bool _showFilters = true;
  double _lastOffset = 0;

  static const List<Map<String, dynamic>> filters = [
    {'status': 'Todos', 'icon': Icons.apps_rounded, 'field': null},
    {'status': 'Entrega', 'field': 'due_date', 'icon': Icons.schedule_outlined},
    {'status': 'Aprovados', 'field': 'approved', 'icon': Icons.thumb_up_outlined},
    {'status': 'Andamento', 'field': 'progress', 'icon': Icons.autorenew_rounded},
    {'status': 'Orçamentos', 'field': 'quote', 'icon': Icons.request_quote_outlined},
    {'status': 'Concluídos', 'field': 'done', 'icon': Icons.check_circle_outline},
    {'status': 'Cancelados', 'field': 'canceled', 'icon': Icons.cancel_outlined},
    {'status': 'A receber', 'field': 'unpaid', 'icon': Icons.account_balance_wallet_outlined},
    {'status': 'Pago', 'field': 'paid', 'icon': Icons.payments_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    orderStore = Provider.of<OrderStore>(context);

    if (Global.companyAggr?.id == null) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _loadOrders();
      });
    } else {
      _loadOrders();
    }
  }

  void _loadOrders() {
    // Salvar a posição atual do scroll
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    orderStore.loadOrdersInfinite(filters[currentSelected]['field']).then((_) {
      // Após o carregamento, ajustar o scroll para uma posição válida
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            // Se a posição anterior ainda for válida, tentar restaurá-la
            if (_scrollController.position.maxScrollExtent >= currentOffset && currentOffset > 0) {
              _scrollController.jumpTo(currentOffset);
            } else {
              // Caso contrário, resetar para o topo
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
    final offset = _scrollController.offset;

    // Detectar direção do scroll
    if (offset > _lastOffset && offset > 50) {
      if (_showFilters) setState(() => _showFilters = false);
    } else if (offset < _lastOffset) {
      if (!_showFilters) setState(() => _showFilters = true);
    }
    _lastOffset = offset;

    // Carregar mais itens
    if (offset >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreOrders();
    }
  }

  void _loadMoreOrders() {
    if (!orderStore.isLoading && orderStore.hasMoreOrders) {
      orderStore.loadMoreOrdersInfinite(filters[currentSelected]['field']);
    }
  }

  @override
  Widget build(BuildContext context) {
    FirebaseCrashlytics.instance.log("Abrindo home");
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ordens de Serviço',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.bar_chart_rounded,
              color: theme.primaryColor,
              size: 24,
            ),
            onPressed: () => Navigator.pushNamed(context, '/financial_dashboard_simple'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: theme.primaryColor,
                size: 26,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/order').then((_) => _loadOrders());
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros com animação suave
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: _showFilters ? 52 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showFilters ? 1 : 0,
              child: _buildFilterBar(theme, isDark),
            ),
          ),
          // Lista
          Expanded(child: _buildOrdersList(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Observer(
        builder: (_) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length + (orderStore.customerFilter != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (orderStore.customerFilter != null) {
                if (index == 0) return _buildCustomerChip(theme, isDark);
                return _buildFilterChip(index - 1, theme, isDark);
              }
              return _buildFilterChip(index, theme, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerChip(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        orderStore.setCustomerFilter(null);
        _loadOrders();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                orderStore.customerFilter?.name ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, ThemeData theme, bool isDark) {
    final isSelected = currentSelected == index;
    final backgroundColor = isSelected
        ? theme.primaryColor
        : (isDark ? AppTheme.backgroundDark : AppTheme.backgroundColor);
    final textColor = isSelected
        ? Colors.white
        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => currentSelected = index);
        orderStore.loadOrdersInfinite(filters[index]['field']);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
                  width: 0.5,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filters[index]['icon'] as IconData,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              filters[index]['status'] as String,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(ThemeData theme, bool isDark) {
    return Observer(
      builder: (_) {
        if (orderStore.isLoading && orderStore.orders.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primaryColor,
            ),
          );
        }

        if (orderStore.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.surfaceDark
                        : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    size: 40,
                    color: isDark
                        ? AppTheme.textTertiaryDark
                        : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma OS encontrada',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque em + para criar uma nova',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        // Verificar se o scroll está em uma posição válida
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.offset > _scrollController.position.maxScrollExtent) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        return RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await orderStore.loadOrdersInfinite(filters[currentSelected]['field']);
          },
          color: theme.primaryColor,
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceColor,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == orderStore.orders.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                );
              }
              return _buildOrderItem(
                orderStore.orders[index] ?? Order(),
                index,
                theme,
                isDark,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(Order order, int index, ThemeData theme, bool isDark) {
    final statusText = Order.statusMap[order.status] ?? '';
    final statusColor = AppTheme.getStatusColor(order.status);
    final isPaid = order.payment == 'paid';
    final showPaymentIcon = isPaid;
    final showUnpaidIcon = order.status == 'done' && order.payment == 'unpaid';

    // Verificar atraso
    bool isOverdue = false;
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      isOverdue = dueDate.isBefore(today) && order.status != 'done' && order.status != 'canceled';
    }

    // Linha secundária com #OS e dispositivo
    String secondaryLine = '#${order.number ?? '-'}';
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      final vehicleDesc = serial.isNotEmpty ? '$name • $serial' : name;
      if (vehicleDesc.isNotEmpty) {
        secondaryLine = '$vehicleDesc';
      }
    }

    return Material(
      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pushNamed(context, '/order', arguments: {'order': order})
              .then((_) => _loadOrders());
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail
                  _buildThumbnail(order, isDark),
                  const SizedBox(width: 12),
                  // Conteúdo principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: Nome do cliente + indicadores
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      order.customer?.name ?? 'Cliente',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.textPrimaryDark
                                            : AppTheme.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Indicadores inline
                                  if (isOverdue) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: AppTheme.errorColor,
                                    ),
                                  ],
                                  if (showPaymentIcon) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: AppTheme.successColor,
                                    ),
                                  ],
                                  if (showUnpaidIcon) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 14,
                                      color: AppTheme.warningColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            _buildStatusBadge(statusText, statusColor, order.status, isDark),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Linha 2: Info secundária + Valor
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                secondaryLine,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatCurrency(order.total),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Chevron
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: isDark
                        ? AppTheme.textTertiaryDark
                        : AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
            // Divisor estilo iOS (indentado)
            Padding(
              padding: const EdgeInsets.only(left: 76),
              child: Container(
                height: 0.5,
                color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color, String? status, bool isDark) {
    final isApproved = status == 'approved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved
            ? Colors.transparent
            : color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: isApproved
            ? Border.all(color: color, width: 1)
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildThumbnail(Order order, bool isDark) {
    final url = order.coverPhotoUrl;
    const double size = 48.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: isDark ? AppTheme.backgroundDark : AppTheme.backgroundColor,
        child: url != null && url.isNotEmpty
            ? CachedImage.thumbnail(
                imageUrl: url,
                size: size,
              )
            : Center(
                child: Icon(
                  Icons.build_outlined,
                  size: 22,
                  color: isDark
                      ? AppTheme.textTertiaryDark
                      : AppTheme.textTertiary,
                ),
              ),
      ),
    );
  }

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$').format(value ?? 0);
  }
}
