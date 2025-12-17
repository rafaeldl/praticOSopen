import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../global.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int previousSelected = 0;
  int currentSelected = 0;
  final ScrollController _scrollController = ScrollController();
  late OrderStore orderStore;

  List filters = [
    {'status': 'Todos', 'icon': Icons.apps_rounded},
    {'status': 'Entrega', 'field': 'due_date', 'icon': Icons.schedule_rounded},
    {'status': 'Aprovados', 'field': 'approved', 'icon': Icons.thumb_up_rounded},
    {'status': 'Andamento', 'field': 'progress', 'icon': Icons.autorenew_rounded},
    {'status': 'Orçamentos', 'field': 'quote', 'icon': Icons.request_quote_rounded},
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
    print("Carregando ordens na tela Home...");
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
      appBar: _buildModernAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros compactos
            _buildFilterSection(),
            // Lista de OS
            Expanded(
              child: _buildOrdersList(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.surfaceColor,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordens de Serviço',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
          onPressed: () {
            Navigator.pushNamed(context, '/financial_dashboard_simple');
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {
              Navigator.pushNamed(context, '/order').then((_) {
                print("Retornou da tela de criação de OS, recarregando lista...");
                _loadOrders();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          // Filtros horizontais compactos
          Container(
            height: 48,
            margin: EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              itemBuilder: (context, index) => _buildFilterChip(index),
            ),
          ),
          // Indicador de filtro por cliente
          Observer(
            builder: (_) {
              if (orderStore.customerFilter == null) {
                return SizedBox.shrink();
              }
              return _buildCustomerFilterIndicator();
            },
          ),
          // Divisor sutil
          Container(
            height: 1,
            color: AppTheme.borderLight,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index) {
    final isSelected = previousSelected == index;

    return GestureDetector(
      onTap: () {
        currentSelected = index;
        setState(() {
          previousSelected = index;
        });
        orderStore.loadOrdersInfinite(filters[index]['field']);
      },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              width: 1,
            ),
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
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerFilterIndicator() {
    return GestureDetector(
      onTap: () {
        orderStore.setCustomerFilter(null);
        orderStore.loadOrdersInfinite(filters[currentSelected]['field']);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.infoLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                orderStore.customerFilter?.name ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.close_rounded,
              size: 18,
              color: AppTheme.primaryColor,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Carregando...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (orderStore.orders.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: 12),
          itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == orderStore.orders.length) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
              );
            }

            Order? order = orderStore.orders[index];
            return _buildCompactOrderItem(order ?? Order());
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
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppTheme.textTertiary,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Nenhuma OS encontrada',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Toque em + para criar uma nova ordem',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrderItem(Order order) {
    // Formatação da data
    String formattedCreatedDate = '';
    if (order.createdAt != null) {
      formattedCreatedDate = DateFormat('dd/MM/yy').format(order.createdAt!);
    }

    // Verificar se atrasada
    bool isOverdue = false;
    if (order.dueDate != null) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final dueDate = DateTime(order.dueDate!.year, order.dueDate!.month, order.dueDate!.day);
      if ((dueDate.compareTo(today) < 0) && order.status != 'done' && order.status != 'canceled') {
        isOverdue = true;
      }
    }

    // Status
    String orderStatus = Order.statusMap[order.status] ?? '';
    Color statusColor = AppTheme.getStatusColor(order.status);
    Color statusBgColor = AppTheme.getStatusBackgroundColor(order.status);

    // Pagamento
    String paymentText = order.payment == 'paid' ? 'Pago' : (order.payment == 'unpaid' ? 'A receber' : '');
    Color paymentColor = AppTheme.getPaymentColor(order.payment);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/order',
          arguments: {'order': order},
        ).then((_) => _loadOrders());
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppTheme.errorColor.withOpacity(0.5) : AppTheme.borderColor,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: isOverdue
              ? [
                  BoxShadow(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : AppTheme.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail compacto
              _buildCompactThumbnail(order),
              SizedBox(width: 12),
              // Informações principais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linha 1: Cliente + Número da OS
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customer?.name ?? 'Cliente',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.number != null ? '#${order.number}' : 'NOVA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Linha 2: Veículo/Dispositivo
                    Text(
                      order.device != null
                          ? '${order.device?.name ?? ''} ${order.device?.serial != null ? '• ${order.device?.serial}' : ''}'
                          : 'Sem veículo',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    SizedBox(height: 8),
                    // Linha 3: Status + Datas + Valor
                    Row(
                      children: [
                        // Parte esquerda flexível (status + data)
                        Expanded(
                          child: Row(
                            children: [
                              // Status badge
                              if (orderStatus.isNotEmpty)
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      orderStatus,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              if (orderStatus.isNotEmpty) SizedBox(width: 6),
                              // Data de criação
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: AppTheme.textTertiary,
                              ),
                              SizedBox(width: 2),
                              Text(
                                formattedCreatedDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              // Indicador de atrasada
                              if (isOverdue) ...[
                                SizedBox(width: 6),
                                Icon(
                                  Icons.warning_rounded,
                                  size: 11,
                                  color: AppTheme.errorColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        // Valor (fixo à direita)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _convertToCurrency(order.total),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (paymentText.isNotEmpty)
                              Text(
                                paymentText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: paymentColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactThumbnail(Order order) {
    final coverPhotoUrl = order.coverPhotoUrl;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverPhotoUrl != null && coverPhotoUrl.isNotEmpty
          ? Image.network(
              coverPhotoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.textTertiary),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
            )
          : _buildDefaultIcon(),
    );
  }

  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(
        Icons.build_circle_outlined,
        size: 28,
        color: AppTheme.textTertiary,
      ),
    );
  }

  String _convertToCurrency(double? total) {
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total ?? 0);
  }
}
