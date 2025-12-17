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

  @override
  void initState() {
    super.initState();
    store.retrieveDevices();
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
      body: Observer(
        builder: (_) => _buildBody(),
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

    return _buildDeviceList(deviceList);
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
    return Dismissible(
      key: Key(device.id!),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
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
                child: const Text('Remover'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        store.deleteDevice(device);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veículo "${device.name}" removido'),
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
