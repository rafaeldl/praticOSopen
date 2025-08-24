import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

class ServiceListScreen extends StatefulWidget {
  @override
  _ServiceListScreenState createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  ServiceStore serviceStore = ServiceStore();

  final PageController pageController = PageController();
  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('orderStore')) {
      print('orderStore');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Serviços'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/service_form');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          child: Observer(
            builder: (_) {
              return _buildServiceList(serviceStore);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildServiceList(ServiceStore serviceStore) {
    if (serviceStore.serviceList == null) {
      return Center(
        child: ElevatedButton(
          onPressed: serviceStore.retrieveServices(),
          child: Text('Error'),
        ),
      );
    }

    if (serviceStore.serviceList!.hasError) {
      return Center(
        child: ElevatedButton(
          onPressed: serviceStore.retrieveServices(),
          child: Text('Error'),
        ),
      );
    }

    List<Service>? list = serviceStore.serviceList!.value;
    if (list == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      padding: EdgeInsets.all(0.0),
      margin: EdgeInsets.all(20.0),
      child: ListView.separated(
        itemCount: list.length,
        itemBuilder: (context, index) {
          Service service = list[index];

          return Dismissible(
            direction: DismissDirection.endToStart,
            background: Container(
                color: Colors.red,
                child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Icon(Icons.delete, size: 30),
                    ))),
            key: Key(service.id!),
            onDismissed: (direction) {
              serviceStore.deleteService(service);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Serviço ${service.name} removido")));
            },
            child: ListTile(
              title: Text(service.name == null ? '' : service.name!),
              subtitle: Text(_convertToCurrency(service.value)),
              trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () {
                if (args != null && args!.containsKey('orderStore')) {
                  Navigator.pushNamed(context, '/order_service', arguments: {
                    'service': service,
                    'orderStore': args!['orderStore']
                  });
                } else {
                  Navigator.pushNamed(context, '/service_form',
                      arguments: {'service': service});
                }
              },
            ),
          );
        },
        separatorBuilder: (context, index) {
          return Divider();
        },
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$');
    return numberFormat.format(total);
  }
}
