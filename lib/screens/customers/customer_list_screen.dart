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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final isSelectionMode = args != null && args!.containsKey('order');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar cliente...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: _searchQuery.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    ]
                  : null,
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          // List
          Expanded(
            child: Observer(
              builder: (_) => _buildBody(),
            ),
          ),
        ],
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

    // Filter list based on search query
    final filteredList = _searchQuery.isEmpty
        ? customerList
        : customerList.where((customer) {
            final name = customer.name?.toLowerCase() ?? '';
            final phone = customer.phone?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || phone.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildCustomerList(filteredList);
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

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum cliente encontrado',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente buscar por outro termo',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(customer.id!),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Edit
          Navigator.pushNamed(
            context,
            '/customer_form',
            arguments: {'customer': customer},
          );
          return false;
        } else {
          // Swipe left - Delete
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
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  ),
                  child: const Text('Remover'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          customerStore.deleteCustomer(customer);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente "${customer.name}" removido'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Editar',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Excluir',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.delete_outline,
              color: colorScheme.onErrorContainer,
              size: 28,
            ),
          ],
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
