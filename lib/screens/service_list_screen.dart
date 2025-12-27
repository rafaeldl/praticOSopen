import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

class ServiceListScreen extends StatefulWidget {
  @override
  _ServiceListScreenState createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  ServiceStore serviceStore = ServiceStore();
  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
        elevation: 0,
      ),
      body: Observer(
        builder: (_) => _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/service_form');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (serviceStore.serviceList == null) {
      return _buildError();
    }

    if (serviceStore.serviceList!.hasError) {
      return _buildError();
    }

    List<Service>? serviceList = serviceStore.serviceList!.value;

    if (serviceList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (serviceList.isEmpty) {
      return _buildEmptyState();
    }

    return _buildServiceList(serviceList);
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
            'Erro ao carregar serviços',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => serviceStore.retrieveServices(),
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
            Icons.build_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum serviço cadastrado',
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

  Widget _buildServiceList(List<Service> list) {
    final isSelectionMode = args != null && args!.containsKey('orderStore');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final service = list[index];
        return _buildServiceCard(service, isSelectionMode);
      },
    );
  }

  Widget _buildServiceCard(Service service, bool isSelectionMode) {
    return Dismissible(
      key: Key(service.id!),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja remover o serviço "${service.name}"?'),
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
        serviceStore.deleteService(service);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Serviço "${service.name}" removido'),
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
          leading: _buildServiceAvatar(service),
          title: Text(
            service.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _convertToCurrency(service.value),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
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
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildServiceAvatar(Service service) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.build_outlined,
        color: colorScheme.onPrimaryContainer,
      ),
    );

    if (service.photo == null || service.photo!.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: CachedImage(
        imageUrl: service.photo!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorWidget: fallback,
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    NumberFormat numberFormat =
        NumberFormat.currency(locale: 'pt-BR', symbol: 'R\$ ');
    return numberFormat.format(total);
  }
}
