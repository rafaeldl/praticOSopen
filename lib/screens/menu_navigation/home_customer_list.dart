import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:provider/provider.dart';

class HomeCustomerList extends StatefulWidget {
  @override
  _HomeCustomerListState createState() => _HomeCustomerListState();
}

class _HomeCustomerListState extends State<HomeCustomerList> {
  CustomerStore customerStore = CustomerStore();
  late OrderStore orderStore;
  late BottomNavigationBarStore navegationStore;

  @override
  Widget build(BuildContext context) {
    orderStore = Provider.of<OrderStore>(context);
    navegationStore = Provider.of<BottomNavigationBarStore>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Clientes'),
      ),
      body: SafeArea(
        child: Container(
          child: Observer(
            builder: (_) {
              return _buildCustomerList(customerStore);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList(CustomerStore customerStore) {
    if (customerStore.customerList == null) {
      return Center(
        child: ElevatedButton(
          onPressed: customerStore.retrieveCustomers(),
          child: Text('Error'),
        ),
      );
    }

    if (customerStore.customerList!.hasError) {
      return Center(
        child: ElevatedButton(
          onPressed: customerStore.retrieveCustomers(),
          child: Text('Error'),
        ),
      );
    }

    List<Customer>? customerList = customerStore.customerList!.data;

    if (customerList == null || customerList.isEmpty) {
      return Center(
        child: Text(
          'Não há clientes cadastrados',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    List<Customer> list = customerStore.customerList!.data;

    return Container(
      padding: EdgeInsets.all(0.0),
      margin: EdgeInsets.all(20.0),
      child: ListView.separated(
        itemCount: list.length,
        itemBuilder: (context, index) {
          Customer customer = list[index];

          return Dismissible(
            direction: DismissDirection.endToStart,
            key: Key(customer.id!),
            onDismissed: (direction) {
              customerStore.deleteCustomer(customer);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Cliente ${customer.name} removido")));
            },
            background: Container(color: Colors.red, child: Icon(Icons.cancel)),
            child: ListTile(
              title: Text(customer.name!),
              subtitle: Text(customer.phone ?? 'Contato: N/A'),
              onTap: () {
                // Navigator.pushNamed(context, '/customer_os_list');
                // OrderStore _store = OrderStore();
                // Global.orderStore.setCustomerFilter(customer);
                orderStore.setCustomerFilter(customer);
                navegationStore.setCurrentIndex(0);
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
}
