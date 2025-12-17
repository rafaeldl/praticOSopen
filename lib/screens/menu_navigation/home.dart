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
      appBar: AppBar(
        title: Text('Ordens de Serviço'),
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
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: 30.0),
          children: <Widget>[
            // Botões de filtro
            Column(
              children: <Widget>[
                Container(
                  height: 95.0,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildIconFilter(context, index);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 25.0),
            Observer(
              builder: (_) {
                // Sem filtro
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
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            child: Text(
                              orderStore.customerFilter?.name! ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                                color: Colors.black,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          Icon(Icons.cancel, size: 18.0),
                        ],
                      ),
                      SizedBox(height: 20.0),
                    ],
                  ),
                );
              },
            ),
            Observer(
              builder: (_) {
                if (orderStore.isLoading && orderStore.orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (orderStore.orders.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                      child: Container(
                        child: Text(
                          'Nenhuma ordem de serviço encontrada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: orderStore.orders.length,
                      itemBuilder: (context, index) {
                        Order? order = orderStore.orders[index];
                        return _buildOrderItem(order ?? Order(), orderStore);
                      },
                    ),
                    if (orderStore.isLoading)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconFilter(BuildContext context, int index) {
    return Container(
      height: 90,
      width: 80,
      child: GestureDetector(
        onTap: () {
          currentSelected = index;
          setState(() {
            previousSelected = index;
          });
          orderStore.loadOrdersInfinite(filters[index]['field']);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Column(
            children: <Widget>[
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: previousSelected == index
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[200]!,
                      blurRadius: 6.0,
                      spreadRadius: 2.0,
                      offset: Offset(7.0, 7.0),
                    ),
                  ],
                ),
                child: Icon(
                  filters[index]['icon'],
                  color: previousSelected == index
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 2),
              Expanded(
                child: Text(
                  filters[index]['status'],
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    letterSpacing: -1.0,
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
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

    // Verificar se a entrega está atrasada
    bool isOverdue = false;
    if (order.dueDate != null) {
      // Comparar apenas as datas, ignorando a hora
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final dueDate = DateTime(
        order.dueDate!.year,
        order.dueDate!.month,
        order.dueDate!.day,
      );

      // Considera atrasado APENAS quando a data de entrega é ANTERIOR ao dia de hoje
      if ((dueDate.compareTo(today) < 0) &&
          order.status != 'done' &&
          order.status != 'canceled') {
        isOverdue = true;
      }
    }

    // Status de pagamento
    String payment = '';
    Color paymentColor = Colors.green;
    if (order.payment == 'paid') {
      payment = 'Pago';
      paymentColor = Colors.green;
    } else if (order.payment == 'unpaid') {
      payment = 'A receber';
      paymentColor = Colors.red.shade400;
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
        margin: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
        constraints: BoxConstraints(minHeight: 100.0),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: isOverdue ? Colors.red : Colors.grey[100]!,
            width: isOverdue ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isOverdue
                  ? Colors.red.withOpacity(0.2)
                  : Colors.grey[200]!,
              blurRadius: 6.0,
              spreadRadius: 2.0,
              offset: Offset(7.0, 7.0),
            ),
          ],
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          children: <Widget>[
            // Imagem à esquerda - Foto de capa da OS
            Container(
              width: 100,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: _buildOrderCoverPhoto(order),
              ),
            ),

            // Informações da OS
            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(13, 12, 13, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Linha superior: Cliente e Número
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Cliente e Veículo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                order.customer?.name ?? 'Cliente',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              SizedBox(height: 4),
                              Text(
                                order.device == null
                                    ? 'Veículo - Placa'
                                    : "${order.device?.name} - ${order.device?.serial}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                  fontSize: 13.0,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),

                        // Número da OS
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.number != null ? "#${order.number}" : 'NOVA',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Linha central: Datas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Data de criação
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Criação",
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2),
                            Padding(
                              padding: EdgeInsets.only(left: 18),
                              child: Text(
                                formattedCreatedDate,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Data de entrega - alinhada à direita
                        if (order.dueDate != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    size: 14,
                                    color: isOverdue
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isOverdue ? "Atrasada" : "Entrega",
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w500,
                                      color: isOverdue
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(order.dueDate!),
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isOverdue
                                        ? Colors.red
                                        : Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          SizedBox.shrink(),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Linha inferior: Status, Pagamento e Valor
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        // Status da OS
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Text(
                            orderStatus,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              fontSize: 12.0,
                            ),
                          ),
                        ),

                        // Valor e status de pagamento
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _convertToCurrency(order.total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                              ),
                            ),
                            Text(
                              payment,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
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
            ),
          ],
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total);
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
            color: Colors.grey[200],
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
      color: Colors.grey[200],
      child: Icon(
        Icons.build_circle,
        size: 50,
        color: Colors.grey[400],
      ),
    );
  }

  Color _getColorWithOpacity(Color color, double opacity) {
    return color.withValues(
      red: color.red.toDouble(),
      green: color.green.toDouble(),
      blue: color.blue.toDouble(),
      alpha: (opacity * 255).toDouble(),
    );
  }
}
