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
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    orderStore = Provider.of<OrderStore>(context);
    navegationStore = Provider.of<BottomNavigationBarStore>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          'Clientes',
          style: theme.appBarTheme.titleTextStyle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de busca
            _buildSearchBar(theme),
            // Lista de clientes
            Expanded(
              child: Observer(
                builder: (_) => _buildCustomerList(customerStore, theme),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/customer_form');
        },
        backgroundColor: theme.primaryColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar cliente...',
            hintStyle: TextStyle(
              color: theme.disabledColor,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.disabledColor,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.disabledColor,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList(CustomerStore customerStore, ThemeData theme) {
    if (customerStore.customerList == null) {
      return _buildLoadingState(theme);
    }

    if (customerStore.customerList!.hasError) {
      return _buildErrorState(customerStore, theme);
    }

    List<Customer>? customerList = customerStore.customerList!.data;

    if (customerList == null || customerList.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Filtrar lista baseado na busca
    List<Customer> filteredList = customerList.where((customer) {
      if (_searchQuery.isEmpty) return true;
      return (customer.name?.toLowerCase().contains(_searchQuery) ?? false) ||
          (customer.phone?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    if (filteredList.isEmpty) {
      return _buildNoResultsState(theme);
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 88),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        Customer customer = filteredList[index];
        return _buildCustomerItem(customer, theme);
      },
    );
  }

  Widget _buildCustomerItem(Customer customer, ThemeData theme) {
    // Gerar iniciais para o avatar
    String initials = '';
    if (customer.name != null && customer.name!.isNotEmpty) {
      final parts = customer.name!.trim().split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        initials = parts[0][0].toUpperCase();
      }
    }

    return Dismissible(
      key: Key(customer.id!),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Swipe para esquerda = excluir (com confirmação)
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Confirmar exclusão'),
              content: Text('Deseja remover o cliente "${customer.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: Text('Remover'),
                ),
              ],
            ),
          ) ?? false;
        } else if (direction == DismissDirection.startToEnd) {
          // Swipe para direita = editar (não remove o item)
          Navigator.pushNamed(
            context,
            '/customer_form',
            arguments: {'customer': customer},
          );
          return false;
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          customerStore.deleteCustomer(customer);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente "${customer.name}" removido'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      background: Container(
        // Swipe para direita = editar (azul)
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Editar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        // Swipe para esquerda = excluir (vermelho)
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Excluir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.delete_rounded,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: InkWell(
          onTap: () {
            orderStore.setCustomerFilter(customer);
            navegationStore.setCurrentIndex(0);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar com iniciais
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Informações do cliente
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name ?? 'Cliente',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: theme.disabledColor,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatPhone(customer.phone),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Ícone de ação
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Sem telefone';
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(theme.primaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando clientes...',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CustomerStore customerStore, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Erro ao carregar clientes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => customerStore.retrieveCustomers(),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: theme.disabledColor,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Nenhum cliente cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Toque no + para adicionar',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: theme.disabledColor,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhum resultado encontrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tente uma busca diferente',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
