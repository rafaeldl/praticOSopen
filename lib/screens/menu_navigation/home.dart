import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order.dart';
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
    {'status': 'Todos', 'icon': Icons.select_all},
    {'status': 'Data entrega', 'field': 'due_date', 'icon': Icons.schedule},
    {
      'status': 'Aprovados',
      'field': 'approved',
      'icon': FontAwesomeIcons.thumbsUp,
    },
    {'status': 'Em andamento', 'field': 'progress', 'icon': Icons.sync},
    {'status': 'Orçamentos', 'field': 'quote', 'icon': Icons.assignment},
    {'status': 'Concluídos', 'field': 'done', 'icon': Icons.done},
    {'status': 'Cancelados', 'field': 'canceled', 'icon': Icons.cancel},
    {'status': 'A receber', 'field': 'unpaid', 'icon': Icons.money_off},
    {'status': 'Pago', 'field': 'paid', 'icon': Icons.monetization_on},
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

  // Método para carregar as ordens
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Ordens de Serviço'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.dashboard),
            onPressed: () {
              Navigator.pushNamed(context, '/financial_dashboard_simple');
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/order').then((_) {
                // Recarregar a lista ao retornar da tela de criação de OS
                print(
                  "Retornou da tela de criação de OS, recarregando lista...",
                );
                _loadOrders();
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4F8), // Greyish Blue Light
              Color(0xFFE1F5FE), // Light Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              // Botões de filtro
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Container(
                  height: 100.0,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildIconFilter(context, index);
                    },
                  ),
                ),
              ),

              Observer(
                builder: (_) {
                  // Sem filtro de cliente
                  if (orderStore.customerFilter == null) {
                    return SizedBox(height: 0.0);
                  }
                  return GestureDetector(
                    onTap: () {
                      orderStore.setCustomerFilter(null);
                      orderStore.loadOrdersInfinite(
                        filters[currentSelected]['field'],
                      );
                    },
                    child: Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.withOpacity(0.5))
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              orderStore.customerFilter?.name! ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.cancel, size: 18.0, color: Colors.red),
                          ],
                        ),
                      ),
                  );
                },
              ),

              Expanded(
                child: Observer(
                  builder: (_) {
                    if (orderStore.isLoading && orderStore.orders.isEmpty) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (orderStore.orders.isEmpty) {
                      return Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[400]),
                                SizedBox(height: 10),
                                Text(
                                  'Nenhuma ordem de serviço encontrada',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                    color: Colors.grey[600]
                                  ),
                                ),
                            ]
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      itemCount: orderStore.orders.length + (orderStore.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == orderStore.orders.length) {
                             return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                        }
                        Order? order = orderStore.orders[index];
                        return _buildOrderItem(order ?? Order(), orderStore);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconFilter(BuildContext context, int index) {
    bool isSelected = previousSelected == index;
    return GestureDetector(
      onTap: () {
        currentSelected = index;
        setState(() {
          previousSelected = index;
        });
        orderStore.loadOrdersInfinite(filters[index]['field']);
      },
      child: Container(
        width: 80,
        margin: EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25.0),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10.0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              filters[index]['icon'],
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              size: 28,
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                filters[index]['status'],
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Order order, OrderStore orderStore) {
    // Formatação da data da OS (createdAt)
    String formattedCreatedDate = '';
    if (order.createdAt != null) {
      formattedCreatedDate = DateFormat('dd/MM/yyyy').format(order.createdAt!);
    }

    // Status da OS
    String orderStatus = Order.statusMap[order.status] ?? 'Desconhecido';
    Color statusColor = Theme.of(context).primaryColor;

    // Cor baseada no status
    if (order.status == 'approved')
      statusColor = Colors.green;
    else if (order.status == 'quote')
      statusColor = Colors.orange;
    else if (order.status == 'progress')
      statusColor = Colors.blue;
    else if (order.status == 'done')
      statusColor = Colors.green.shade800;
    else if (order.status == 'canceled')
      statusColor = Colors.red;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/order',
          arguments: {'order': order},
        ).then((_) {
          _loadOrders();
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15.0,
              spreadRadius: 2.0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Row(
              children: <Widget>[
                // Imagem à esquerda - Foto de capa da OS
                Container(
                  width: 100,
                  height: double.infinity,
                  child: _buildOrderCoverPhoto(order),
                ),

                // Informações da OS
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 16, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Linha superior: Cliente e Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                order.customer?.name ?? 'Cliente',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.0,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10)
                                ),
                                child: Text(
                                    orderStatus.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor
                                    ),
                                ),
                            )
                          ],
                        ),

                        // Meio: Dispositivo e OS #
                         Row(
                          children: [
                              Text(
                                order.number != null ? "#${order.number}" : 'NOVA',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.0,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.device == null
                                      ? 'Veículo / Dispositivo'
                                      : "${order.device?.name}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[600],
                                    fontSize: 12.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                          ],
                         ),

                        // Linha inferior: Data e Valor
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                             Text(
                                formattedCreatedDate,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500]
                                ),
                             ),

                            Text(
                              _convertToCurrency(order.total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                color: Theme.of(context).primaryColor,
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
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total ?? 0.0);
  }

  /// Constrói a foto de capa da ordem de serviço
  Widget _buildOrderCoverPhoto(Order order) {
    final coverPhotoUrl = order.coverPhotoUrl;

    if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty) {
      return Image.network(
        coverPhotoUrl,
        alignment: Alignment.center,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200].withOpacity(0.5),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultOrderImage();
        },
      );
    }

    // Se não houver fotos, mostra imagem padrão
    return _buildDefaultOrderImage();
  }

  /// Constrói a imagem padrão quando não há foto
  Widget _buildDefaultOrderImage() {
    return Container(
      color: Colors.grey[200].withOpacity(0.5),
      child: Center(
        child: Icon(
            Icons.build_circle_outlined,
            size: 40,
            color: Colors.grey[400],
        ),
      ),
    );
  }
}
