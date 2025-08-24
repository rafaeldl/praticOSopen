import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class CustomerListScreen extends StatefulWidget {
  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  CustomerStore customerStore = CustomerStore();

  final PageController pageController = PageController();
  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('order')) {
      print('Customer List Screen: has order');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Clientes'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/customer_form')
                  .then((customer) => {
                        if (args != null && args!.containsKey('order'))
                          {Navigator.pop(context, customer)}
                      });
            },
          ),
        ],
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
              subtitle: Text(customer.phone!),
              trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () {
                if (args != null && args!.containsKey('order')) {
                  Navigator.pop(context, customer);
                } else {
                  Navigator.pushNamed(context, '/customer_form',
                      arguments: {'customer': customer});
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
}
