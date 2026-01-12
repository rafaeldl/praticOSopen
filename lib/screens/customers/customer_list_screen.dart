import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';
import 'package:praticos/extensions/context_extensions.dart';

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
    final config = context.watch<SegmentConfigProvider>();
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    
    // Check if opened for selection (e.g. from OrderForm)
    final isSelectionMode = args != null && args!.containsKey('order');

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(config.customerPlural),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/customer_form').then((customer) {
                    if (isSelectionMode && customer != null) {
                      Navigator.pop(context, customer);
                    }
                  });
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: '${context.l10n.search} ${config.customer.toLowerCase()}',
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),
            
            // List (as Sliver)
            Observer(
              builder: (_) => _buildBody(isSelectionMode, config),
            ),
            
            // Bottom padding for safe area/scrolling
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isSelectionMode, SegmentConfigProvider config) {
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
              Text('${context.l10n.errorLoading} ${config.customerPlural.toLowerCase()}'),
              const SizedBox(height: 16),
              CupertinoButton(
                child: Text(config.label(LabelKeys.retryAgain)),
                onPressed: () => customerStore.retrieveCustomers(),
              )
            ],
          ),
        ),
      );
    }

    final rawData = customerStore.customerList!.data;

    if (rawData == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // Filter out null entries from the list
    final List<Customer> customerList = rawData.whereType<Customer>().toList();

    if (customerList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.person_2, size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
                const SizedBox(height: 16),
                Text(
                  '${context.l10n.no} ${config.customer.toLowerCase()} ${context.l10n.registered}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.tapPlusToAddYourFirst} ${config.customer.toLowerCase()}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
      return SliverFillRemaining(
        child: Center(
          child: Text(config.label(LabelKeys.noResultsFound)),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= filteredList.length) return null;
          final customer = filteredList[index];
          return _buildCustomerItem(customer, isSelectionMode, index == filteredList.length - 1, config);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildCustomerItem(Customer customer, bool isSelectionMode, bool isLast, SegmentConfigProvider config) {
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
          ).then((updatedCustomer) {
             // Optional: Handle update if needed
          });
          return false; // Don't dismiss from list
        } else {
          // Swipe Left -> Delete
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(config.label(LabelKeys.confirmDeletion)),
              content: Text('${context.l10n.doYouWantToRemoveThe} ${config.customer.toLowerCase()} "${customer.name}"?'),
              actions: [
                CupertinoDialogAction(
                  child: Text(config.label(LabelKeys.cancel)),
                  onPressed: () => Navigator.pop(context, false),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: Text(config.label(LabelKeys.remove)),
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
        child: InkWell(
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
                            customer.name ?? config.customer,
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
    );
  }

  String _formatPhone(String? phone) {
    if (phone == null) return '';
    return phone; 
  }
}
