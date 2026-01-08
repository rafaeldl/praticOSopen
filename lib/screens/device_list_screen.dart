import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/constants/label_keys.dart';

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
    final config = context.watch<SegmentConfigProvider>();
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final isSelectionMode = args != null && args!.containsKey('order');

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(config.devicePlural),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/device_form').then((device) {
                    if (isSelectionMode && device != null) {
                      Navigator.pop(context, device);
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
                  placeholder: 'Buscar ${config.device.toLowerCase()}',
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
    final config = context.read<SegmentConfigProvider>();

    if (store.deviceList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (store.deviceList!.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              Text('Erro ao carregar ${config.devicePlural.toLowerCase()}'),
              const SizedBox(height: 16),
              CupertinoButton(
                child: Text(config.label(LabelKeys.retryAgain)),
                onPressed: () => store.retrieveDevices(),
              )
            ],
          ),
        ),
      );
    }

    final rawData = store.deviceList!.data;

    if (rawData == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // Filter out null entries from the list
    final List<Device> deviceList = rawData.whereType<Device>().toList();

    if (deviceList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(config.deviceIcon, size: 64, color: CupertinoColors.systemGrey.resolveFrom(context)),
                const SizedBox(height: 16),
                Text(
                  'Nenhum ${config.device.toLowerCase()} cadastrado',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toque em + para adicionar seu primeiro ${config.device.toLowerCase()}.',
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
          final device = filteredList[index];
          return _buildDeviceItem(device, isSelectionMode, index == filteredList.length - 1, config);
        },
        childCount: filteredList.length,
      ),
    );
  }

  Widget _buildDeviceItem(Device device, bool isSelectionMode, bool isLast, SegmentConfigProvider config) {
    return Dismissible(
      key: Key(device.id!),
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
            '/device_form',
            arguments: {'device': device},
          ).then((_) {
             // Handle update if needed
          });
          return false;
        } else {
          // Swipe Left -> Delete
          return await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text(config.label(LabelKeys.confirmDeletion)),
              content: Text('Deseja remover o ${config.device.toLowerCase()} "${device.name}"?'),
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
        store.deleteDevice(device);
      },
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: InkWell(
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    _buildDeviceAvatar(device),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${device.name ?? ''} ${device.serial ?? ''}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          if (device.manufacturer != null && device.manufacturer!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              device.manufacturer!,
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
                  indent: 76, // Avatar (48) + Padding (16+12)
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceAvatar(Device device) {
    if (device.photo != null && device.photo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedImage(
          imageUrl: device.photo!,
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
      child: Icon(CupertinoIcons.car_detailed, color: CupertinoColors.systemGrey.resolveFrom(context)),
    );
  }
}