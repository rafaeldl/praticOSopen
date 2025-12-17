import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/theme/app_theme.dart';
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
      // Rolando para cima - esconder filtros
      if (_showFilters) setState(() => _showFilters = false);
    } else if (offset < _lastOffset) {
      // Rolando para baixo - mostrar filtros
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Ordens de Serviço',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/financial_dashboard_simple'),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
            height: _showFilters ? 40 : 0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 150),
              opacity: _showFilters ? 1 : 0,
              child: _buildFilterBar(),
            ),
          ),
          // Lista
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 40,
      color: AppTheme.surfaceColor,
      child: Observer(
        builder: (_) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        margin: EdgeInsets.only(right: 6),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 13, color: Colors.white),
            SizedBox(width: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 70),
              child: Text(
                orderStore.customerFilter?.name ?? '',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.close, size: 13, color: Colors.white70),
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
        margin: EdgeInsets.only(right: 6),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filters[index]['icon'], size: 13, color: isSelected ? Colors.white : AppTheme.textSecondary),
            SizedBox(width: 4),
            Text(
              filters[index]['status'],
              style: TextStyle(
                fontSize: 11,
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
                Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textTertiary),
                SizedBox(height: 12),
                Text('Nenhuma OS encontrada', style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(12, 4, 12, 20),
          itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == orderStore.orders.length) {
              return Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            return _buildOrderItem(orderStore.orders[index] ?? Order());
          },
        );
      },
    );
  }

  Widget _buildOrderItem(Order order) {
    // Status e cores
    final statusText = Order.statusMap[order.status] ?? '';
    final statusColor = AppTheme.getStatusColor(order.status);
    final isPaid = order.payment == 'paid';

    // Verificar atraso
    bool isOverdue = false;
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      isOverdue = dueDate.isBefore(today) && order.status != 'done' && order.status != 'canceled';
    }

    const double itemHeight = 76.0;

    // Descrição do veículo
    String vehicleDesc = '';
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      vehicleDesc = serial.isNotEmpty ? '$name • $serial' : name;
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/order', arguments: {'order': order}).then((_) => _loadOrders());
      },
      child: Container(
        height: itemHeight,
        margin: EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOverdue ? AppTheme.errorColor.withOpacity(0.5) : AppTheme.borderColor,
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Foto - altura total do item
            _buildThumbnail(order, itemHeight),
            // Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Linha 1: Nome + Número
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customer?.name ?? 'Cliente',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '#${order.number ?? '-'}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                    // Linha 2: Veículo
                    Text(
                      vehicleDesc.isNotEmpty ? vehicleDesc : 'Sem veículo',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    // Linha 3: Status + Valor
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ),
                        if (isOverdue) ...[
                          SizedBox(width: 4),
                          Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.errorColor),
                        ],
                        Spacer(),
                        Text(
                          _formatCurrency(order.total),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        SizedBox(width: 6),
                        Text(
                          isPaid ? 'Pago' : 'A receber',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPaid ? AppTheme.successColor : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Order order, double height) {
    final url = order.coverPhotoUrl;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(9),
        bottomLeft: Radius.circular(9),
      ),
      child: Container(
        width: height,
        height: height,
        color: AppTheme.backgroundColor,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
                errorBuilder: (_, __, ___) => _defaultIcon(),
              )
            : _defaultIcon(),
      ),
    );
  }

  Widget _defaultIcon() {
    return Center(child: Icon(Icons.build_circle_outlined, size: 28, color: AppTheme.textTertiary));
  }

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$').format(value ?? 0);
  }
}
