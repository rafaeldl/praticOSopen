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

    // Mostrar ícone de pagamento sempre que a OS foi paga, independente do status
    final showPaymentIcon = isPaid;

    // Mostrar ícone "a receber" quando status for concluído e financeiro em aberto
    final showUnpaidIcon = order.status == 'done' && order.payment == 'unpaid';

    // Verificar atraso
    bool isOverdue = false;
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      isOverdue = dueDate.isBefore(today) && order.status != 'done' && order.status != 'canceled';
    }

    // Descrição do veículo com número da OS
    String deviceLine = '#${order.number ?? '-'}';
    if (order.device != null) {
      final name = order.device?.name ?? '';
      final serial = order.device?.serial ?? '';
      final vehicleDesc = serial.isNotEmpty ? '$name • $serial' : name;
      if (vehicleDesc.isNotEmpty) {
        deviceLine = '#${order.number ?? '-'} • $vehicleDesc';
      }
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  _buildThumbnail(order),
                  SizedBox(width: 12),
                  // Conteúdo principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: Nome + Ícones (atraso e pagamento) + Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Nome do cliente com ícones ao lado
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      order.customer?.name ?? 'Cliente',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Ícones de atraso, pagamento e a receber ao lado do nome
                                  if (isOverdue)
                                    Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.schedule,
                                        size: 16,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  if (showPaymentIcon)
                                    Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: AppTheme.successColor,
                                      ),
                                    ),
                                  if (showUnpaidIcon)
                                    Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            // Status badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: order.status == 'approved' 
                                    ? Colors.transparent 
                                    : statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: order.status == 'approved'
                                    ? Border.all(color: statusColor, width: 1)
                                    : null,
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        // Linha 2: #OS + Veículo + Valor total (canto inferior direito)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                deviceLine,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            // SizedBox(height: 20,),
                            // Valor total no canto inferior direito
                            Text(
                              _formatCurrency(order.total),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.5,
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
            // Divisor
            Padding(
              padding: EdgeInsets.only(left: 80),
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
    const double size = 52.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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
                  size: 26,
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
