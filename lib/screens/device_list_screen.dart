import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class DeviceListScreen extends StatefulWidget {
  @override
  _DeviceListScreenState createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  DeviceStore store = DeviceStore();
  Map<String, dynamic>? args;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    store.retrieveDevices();
  }

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
        title: const Text('Veículos'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Buscar veículo...',
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
          Navigator.pushNamed(context, '/device_form').then((device) {
            if (isSelectionMode && device != null) {
              Navigator.pop(context, device);
            }
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (store.deviceList == null) {
      return _buildError();
    }

    if (store.deviceList!.hasError) {
      return _buildError();
    }

    List<Device>? deviceList = store.deviceList!.data;

    if (deviceList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (deviceList.isEmpty) {
      return _buildEmptyState();
    }

    // Filter list based on search query
    final filteredList = _searchQuery.isEmpty
        ? deviceList
        : deviceList.where((device) {
            final name = device.name?.toLowerCase() ?? '';
            final serial = device.serial?.toLowerCase() ?? '';
            final manufacturer = device.manufacturer?.toLowerCase() ?? '';
            return name.contains(_searchQuery) ||
                serial.contains(_searchQuery) ||
                manufacturer.contains(_searchQuery);
          }).toList();

    if (filteredList.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildDeviceList(filteredList);
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
            'Erro ao carregar veículos',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => store.retrieveDevices(),
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
            Icons.directions_car_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum veículo cadastrado',
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
            'Nenhum veículo encontrado',
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

  Widget _buildDeviceList(List<Device> list) {
    final isSelectionMode = args != null && args!.containsKey('order');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final device = list[index];
        return _buildDeviceCard(device, isSelectionMode);
      },
    );
  }

  Widget _buildDeviceCard(Device device, bool isSelectionMode) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(device.id!),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Edit
          Navigator.pushNamed(
            context,
            '/device_form',
            arguments: {'device': device},
          );
          return false;
        } else {
          // Swipe left - Delete
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmar exclusão'),
              content: Text('Deseja remover o veículo "${device.name}"?'),
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
          store.deleteDevice(device);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Veículo "${device.name}" removido'),
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
            child: Icon(
              Icons.directions_car_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            '${device.name ?? ''} ${device.serial ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(device.manufacturer ?? ''),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (isSelectionMode) {
              Navigator.pop(context, device);
            } else {
              Navigator.pushNamed(
                context,
                '/device_form',
                arguments: {'device': device},
              );
            }
          },
        ),
      ),
    );
  }
}
