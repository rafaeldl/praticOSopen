import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';

class CustomerOsList extends StatefulWidget {
  @override
  _CustomerOsListState createState() => _CustomerOsListState();
}

class _CustomerOsListState extends State<CustomerOsList> {
  CustomerStore customerStore = CustomerStore();
  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(config.serviceOrderPlural),
      ),
      body: SafeArea(
        child: Container(
          child: Observer(
            builder: (_) {
              return _buildCustomerOsList(customerStore, config);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerOsList(CustomerStore customerStore, SegmentConfigProvider config) {
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

    final rawData = customerStore.customerList!.data;

    if (rawData == null || rawData.isEmpty) {
      return Center(
        child: Text(
          'Nenhum ${config.customer.toLowerCase()} cadastrado',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    // Filter out null entries from the list
    final List<Customer> list = rawData.whereType<Customer>().toList();

    return Container(
      padding: const EdgeInsets.all(0.0),
      margin: const EdgeInsets.all(20.0),
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
                  SnackBar(content: Text("${config.customer} ${customer.name} removido")));
            },
            background: Container(color: Colors.red, child: const Icon(Icons.cancel)),
            child: ListTile(
              title: Text(customer.name!),
              subtitle: Text(customer.phone!),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () {
                print('on tap');
              },
            ),
          );
        },
        separatorBuilder: (context, index) {
          return const Divider();
        },
      ),
    );
  }
}
