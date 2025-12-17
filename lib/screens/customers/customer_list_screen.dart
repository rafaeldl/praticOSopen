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
  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final isSelectionMode = args != null && args!.containsKey('order');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        elevation: 0,
      ),
      body: Observer(
        builder: (_) => _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/customer_form').then((customer) {
            if (isSelectionMode && customer != null) {
              Navigator.pop(context, customer);
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (customerStore.customerList == null) {
      return _buildError();
    }

    if (customerStore.customerList!.hasError) {
      return _buildError();
    }

    List<Customer>? customerList = customerStore.customerList!.data;

    if (customerList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (customerList.isEmpty) {
      return _buildEmptyState();
    }

    return _buildCustomerList(customerList);
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar clientes',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => customerStore.retrieveCustomers(),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum cliente cadastrado',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no + para adicionar',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(List<Customer> list) {
    final isSelectionMode = args != null && args!.containsKey('order');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final customer = list[index];
        return _buildCustomerCard(customer, isSelectionMode);
      },
    );
  }

  Widget _buildCustomerCard(Customer customer, bool isSelectionMode) {
    return Dismissible(
      key: Key(customer.id!),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja remover o cliente "${customer.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remover'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        customerStore.deleteCustomer(customer);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente "${customer.name}" removido'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onError,
          size: 28,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              customer.name != null && customer.name!.isNotEmpty
                  ? customer.name![0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            customer.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: customer.phone != null && customer.phone!.isNotEmpty
              ? Text(_formatPhone(customer.phone!))
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (isSelectionMode) {
              Navigator.pop(context, customer);
            } else {
              Navigator.pushNamed(
                context,
                '/customer_form',
                arguments: {'customer': customer},
              );
            }
          },
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }
}
