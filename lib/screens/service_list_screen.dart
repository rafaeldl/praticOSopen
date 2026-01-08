import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/widgets/cached_image.dart';

class ServiceListScreen extends StatefulWidget {
  @override
  _ServiceListScreenState createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  ServiceStore serviceStore = ServiceStore();
  Map<String, dynamic>? args;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    serviceStore.retrieveServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final isSelectionMode = args != null && args!.containsKey('orderStore');

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Serviços'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/service_form').then((_) => serviceStore.retrieveServices());
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: 'Buscar serviço',
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
            ),
            
            // List (as Sliver)
            Observer(
              builder: (_) => _buildBody(isSelectionMode),
            ),
            
            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isSelectionMode) {
    if (serviceStore.serviceList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (serviceStore.serviceList!.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              const Text('Erro ao carregar serviços'),
              const SizedBox(height: 16),
              CupertinoButton(
                child: const Text('Tentar novamente'),
                onPressed: () => serviceStore.retrieveServices(),
              )
            ],
          ),
        ),
      );
    }

    List<Service?>? serviceList = serviceStore.serviceList!.value;

    if (serviceList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (serviceList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.wrench, size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
                const SizedBox(height: 16),
                Text(
                  'Nenhum serviço cadastrado',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toque em + para adicionar seu primeiro serviço.',
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
        ? serviceList.whereType<Service>().toList()
        : serviceList.whereType<Service>().where((service) {
            final name = service.name?.toLowerCase() ?? '';
            return name.contains(_searchQuery);
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
          final service = filteredList[index];
          return _buildServiceItem(service, isSelectionMode, index == filteredList.length - 1);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildServiceItem(Service service, bool isSelectionMode, bool isLast) {
    return Dismissible(
      key: Key(service.id!),
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
            '/service_form',
            arguments: {'service': service},
          ).then((_) => serviceStore.retrieveServices());
          return false;
        } else {
          // Swipe Left -> Delete
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Confirmar exclusão'),
              content: Text('Deseja remover o serviço "${service.name}"?'),
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
        serviceStore.deleteService(service);
      },
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: InkWell(
          onTap: () {
            if (isSelectionMode) {
              Navigator.pushNamed(context, '/order_service', arguments: {
                'service': service,
                'orderStore': args!['orderStore']
              });
            } else {
              Navigator.pushNamed(
                context,
                '/service_form',
                arguments: {'service': service},
              ).then((_) => serviceStore.retrieveServices());
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    _buildServiceAvatar(service),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name ?? '',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _convertToCurrency(service.value),
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.activeBlue.resolveFrom(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                  indent: 76, // Avatar (48) + Padding (16+12)
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceAvatar(Service service) {
    if (service.photo != null && service.photo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedImage(
          imageUrl: service.photo!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.wrench, color: CupertinoColors.systemGrey.resolveFrom(context)),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$');
    return numberFormat.format(total);
  }
}