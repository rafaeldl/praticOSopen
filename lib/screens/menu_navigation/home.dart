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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
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
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // AppBar fixa
            SliverAppBar(
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.surfaceColor,
              title: Text(
                'Ordens de Serviço',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.bar_chart_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pushNamed(context, '/financial_dashboard_simple'),
                ),
                IconButton(
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
                SizedBox(width: 8),
              ],
            ),
            // Filtros que somem ao rolar
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: AppTheme.surfaceColor,
              toolbarHeight: 44,
              flexibleSpace: _buildFilterBar(),
            ),
          ];
        },
        body: _buildOrdersList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderLight, width: 1)),
      ),
      child: Observer(
        builder: (_) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length + (orderStore.customerFilter != null ? 1 : 0),
            itemBuilder: (context, index) {
              // Primeiro item: filtro de cliente (se existir)
              if (orderStore.customerFilter != null) {
                if (index == 0) {
                  return _buildCustomerFilterChip();
                }
                return _buildFilterChip(index - 1);
              }
              return _buildFilterChip(index);
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerFilterChip() {
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
            Icon(Icons.person_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 80),
              child: Text(
                orderStore.customerFilter?.name ?? '',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 14, color: Colors.white70),
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
          color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filters[index]['icon'],
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            SizedBox(width: 4),
            Text(
              filters[index]['status'],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          );
        }

        if (orderStore.orders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 20),
          itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == orderStore.orders.length) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return _buildOrderItem(orderStore.orders[index] ?? Order());
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 56, color: AppTheme.textTertiary),
          SizedBox(height: 16),
          Text(
            'Nenhuma OS encontrada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 4),
          Text(
            'Toque em + para criar',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Order order) {
    // Dados formatados
    final createdDate = order.createdAt != null ? DateFormat('dd/MM').format(order.createdAt!) : '';

    // Verificar atraso
    bool isOverdue = false;
    String dueDateText = '';
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      isOverdue = dueDate.isBefore(today) && order.status != 'done' && order.status != 'canceled';
      dueDateText = DateFormat('dd/MM').format(order.dueDate!);
    }

    // Status e pagamento
    final statusText = Order.statusMap[order.status] ?? '';
    final statusColor = AppTheme.getStatusColor(order.status);
    final isPaid = order.payment == 'paid';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/order', arguments: {'order': order}).then((_) => _loadOrders());
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppTheme.errorColor.withOpacity(0.4) : AppTheme.borderColor,
            width: isOverdue ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Foto - ocupa altura total
            _buildThumbnail(order),
            // Informações
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linha 1: Cliente + Número
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customer?.name ?? 'Cliente',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '#${order.number ?? 'NOVA'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    // Linha 2: Veículo
                    Text(
                      order.device != null
                          ? '${order.device?.name ?? ''} • ${order.device?.serial ?? ''}'
                          : 'Sem veículo',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    // Linha 3: Status + Data + Valor
                    Row(
                      children: [
                        // Status
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        // Data
                        if (isOverdue)
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.errorColor),
                              SizedBox(width: 2),
                              Text(
                                dueDateText,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.errorColor),
                              ),
                            ],
                          )
                        else
                          Text(
                            createdDate,
                            style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                          ),
                        Spacer(),
                        // Valor
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatCurrency(order.total),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (order.payment != null)
                              Text(
                                isPaid ? 'Pago' : 'A receber',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isPaid ? AppTheme.successColor : AppTheme.errorColor,
                                ),
                              ),
                          ],
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

  Widget _buildThumbnail(Order order) {
    final url = order.coverPhotoUrl;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(11),
        bottomLeft: Radius.circular(11),
      ),
      child: Container(
        width: 80,
        height: 80,
        color: AppTheme.backgroundColor,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => _defaultIcon(),
              )
            : _defaultIcon(),
      ),
    );
  }

  Widget _defaultIcon() {
    return Center(
      child: Icon(Icons.build_circle_outlined, size: 32, color: AppTheme.textTertiary),
    );
  }

  String _formatCurrency(double? value) {
    return NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$').format(value ?? 0);
  }
}
