import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell; 
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

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Clientes'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                   Navigator.pushNamed(context, '/customer_form');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Buscar cliente',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),
            _buildCustomerList(),
            // Bottom padding for tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // Need to handle the floating action button equivalent for Cupertino
  // Usually it's a trailing button in the Nav Bar.
  // I updated the build method to include the trailing add button logic properly.

  Widget _buildCustomerList() {
    return Observer(
      builder: (_) {
        if (customerStore.customerList == null) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (customerStore.customerList!.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: CupertinoColors.systemRed),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar clientes'),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    child: const Text('Tentar novamente'),
                    onPressed: () => customerStore.retrieveCustomers(),
                  )
                ],
              ),
            ),
          );
        }

        List<Customer>? customerList = customerStore.customerList!.data;
        return _buildCustomerListContent(customerList);
      },
    );
  }

  Widget _buildCustomerListContent(List<Customer>? customerList) {
    if (customerList == null || customerList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.person_2, size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
              const SizedBox(height: 16),
              Text(
                'Nenhum cliente cadastrado',
                style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ],
          ),
        ),
      );
    }

    // Filter list
    List<Customer> filteredList = customerList.where((customer) {
      if (_searchQuery.isEmpty) return true;
      return (customer.name?.toLowerCase().contains(_searchQuery) ?? false) ||
          (customer.phone?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    if (filteredList.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('Nenhum resultado encontrado'),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= filteredList.length) return null;
          return _buildCustomerItem(filteredList[index], index == filteredList.length - 1);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildCustomerItem(Customer customer, bool isLast) {
    // Generate initials
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
      background: Container(
        color: CupertinoColors.systemBlue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(CupertinoIcons.pencil, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right -> Edit
          Navigator.pushNamed(
            context,
            '/customer_form',
            arguments: {'customer': customer},
          );
          return false; // Don't dismiss
        } else {
          // Swipe Left -> Delete
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Confirmar exclusão'),
              content: Text('Deseja remover o cliente "${customer.name}"?'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context, false),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('Remover'),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ) ?? false;
        }
      },
      onDismissed: (_) {
        customerStore.deleteCustomer(customer);
      },
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              // Filter logic or Edit logic depending on context
              // In this Tab view, tapping usually filters orders for this customer
              orderStore.setCustomerFilter(customer);
              orderStore.loadOrdersInfinite(null); // Force reload with new filter
              navegationStore.setCurrentIndex(0); // Switch to Home tab
            },
            onLongPress: () {
               Navigator.pushNamed(
                context,
                '/customer_form',
                arguments: {'customer': customer},
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5.resolveFrom(context),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name ?? 'Cliente',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                            if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatPhone(customer.phone),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, size: 16, color: CupertinoColors.systemGrey3.resolveFrom(context)),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 72, // Avatar (44) + Padding (16+12)
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPhone(String? phone) {
    if (phone == null) return '';
    return phone; // Keep simple or use existing formatting logic
  }
}