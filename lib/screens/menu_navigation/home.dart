import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:flutter/material.dart';
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

  List filters = [
    {'status': 'Todos', 'icon': Icons.apps_rounded, 'field': null},
    {'status': 'Entrega', 'field': 'due_date', 'icon': Icons.schedule_rounded},
    {'status': 'Aprovados', 'field': 'approved', 'icon': Icons.thumb_up_alt_rounded},
    {'status': 'Andamento', 'field': 'progress', 'icon': Icons.sync_rounded},
    {'status': 'Orçamentos', 'field': 'quote', 'icon': Icons.description_rounded},
    {'status': 'Concluídos', 'field': 'done', 'icon': Icons.check_circle_rounded},
    {'status': 'Cancelados', 'field': 'canceled', 'icon': Icons.cancel_rounded},
    {'status': 'A receber', 'field': 'unpaid', 'icon': Icons.payments_outlined},
    {'status': 'Pago', 'field': 'paid', 'icon': Icons.paid_rounded},
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
    orderStore.loadOrdersInfinite(filters[currentSelected]['field']);
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Ordens de Serviço',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: AppTheme.textSecondary, size: 26),
            onPressed: () => Navigator.pushNamed(context, '/financial_dashboard_simple'),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/order').then((_) => _loadOrders());
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros animados
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            height: _showFilters ? 48 : 0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 150),
              opacity: _showFilters ? 1 : 0,
              child: _buildFilterBar(),
            ),
          ),
          // Divisor sutil
          Container(height: 1, color: AppTheme.borderLight),
          // Lista
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 48,
      color: Colors.white,
      child: Observer(
        builder: (_) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length + (orderStore.customerFilter != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (orderStore.customerFilter != null) {
                if (index == 0) return _buildCustomerChip();
                return _buildFilterChip(index - 1);
              }
              return _buildFilterChip(index);
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerChip() {
    return GestureDetector(
      onTap: () {
        orderStore.setCustomerFilter(null);
        _loadOrders();
      },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 80),
              child: Text(
                orderStore.customerFilter?.name ?? '',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.close, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index) {
    final isSelected = currentSelected == index;

    return GestureDetector(
      onTap: () {
        setState(() => currentSelected = index);
        orderStore.loadOrdersInfinite(filters[index]['field']);
      },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filters[index]['icon'],
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            SizedBox(width: 6),
            Text(
              filters[index]['status'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return Observer(
      builder: (_) {
        if (orderStore.isLoading && orderStore.orders.isEmpty) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (orderStore.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 56, color: AppTheme.textTertiary),
                SizedBox(height: 16),
                Text(
                  'Nenhuma OS encontrada',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == orderStore.orders.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _buildOrderItem(orderStore.orders[index] ?? Order(), index);
          },
        );
      },
    );
  }

  Widget _buildOrderItem(Order order, int index) {
    final statusText = Order.statusMap[order.status] ?? '';
    final statusColor = AppTheme.getStatusColor(order.status);
    final isPaid = order.payment == 'paid';

    // Não mostrar ícone de pagamento em orçamento e cancelado
    final showPaymentIcon = order.status != 'quote' && order.status != 'canceled';

    // Verificar atraso
    bool isOverdue = false;
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      isOverdue = dueDate.isBefore(today) && order.status != 'done' && order.status != 'canceled';
    }

    // Descrição do veículo
    String vehicleDesc = '';
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      vehicleDesc = serial.isNotEmpty ? '$name • $serial' : name;
    }

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/order', arguments: {'order': order}).then((_) => _loadOrders());
      },
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Thumbnail circular
                  _buildThumbnail(order),
                  SizedBox(width: 14),
                  // Conteúdo principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: Nome + Número
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customer?.name ?? 'Cliente',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '#${order.number ?? '-'}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        // Linha 2: Veículo
                        Text(
                          vehicleDesc.isNotEmpty ? vehicleDesc : 'Sem veículo',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: 8),
                        // Linha 3: Status + Ícones + Valor
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Ícones de status (atrasado + pagamento)
                            if (isOverdue)
                              Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.schedule,
                                  size: 18,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            if (showPaymentIcon)
                              Icon(
                                isPaid ? Icons.check_circle : Icons.circle_outlined,
                                size: 18,
                                color: isPaid ? AppTheme.successColor : AppTheme.textTertiary,
                              ),
                            Spacer(),
                            // Valor
                            Text(
                              _formatCurrency(order.total),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Divisor - apenas se não for o último item
            Padding(
              padding: EdgeInsets.only(left: 86),
              child: Container(
                height: 1,
                color: AppTheme.borderLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Order order) {
    final url = order.coverPhotoUrl;
    const double size = 56.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.backgroundColor,
        child: url != null && url.isNotEmpty
            ? CachedImage.thumbnail(
                imageUrl: url,
                size: size,
              )
            : Center(
                child: Icon(
                  Icons.build_circle_outlined,
                  size: 28,
                  color: AppTheme.textTertiary,
                ),
              ),
      ),
    );
  }

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$').format(value ?? 0);
  }
}
