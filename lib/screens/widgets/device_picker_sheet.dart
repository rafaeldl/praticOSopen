import 'package:flutter/cupertino.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/extensions/context_extensions.dart';

enum DevicePickerAction { specific, general, all, multiSpecific }

class DevicePickerResult {
  final DevicePickerAction action;
  final DeviceAggr? device;
  final List<String>? deviceIds;

  DevicePickerResult(this.action, [this.device]) : deviceIds = null;

  DevicePickerResult.multi(this.deviceIds)
      : action = DevicePickerAction.multiSpecific,
        device = null;
}

class DevicePickerSheet {
  static Future<DevicePickerResult?> show(
    BuildContext context,
    List<DeviceAggr> devices,
  ) async {
    return Navigator.push<DevicePickerResult>(
      context,
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => DeviceMultiPickerScreen(devices: devices),
      ),
    );
  }
}

class DeviceMultiPickerScreen extends StatefulWidget {
  final List<DeviceAggr> devices;

  const DeviceMultiPickerScreen({super.key, required this.devices});

  @override
  State<DeviceMultiPickerScreen> createState() =>
      _DeviceMultiPickerScreenState();
}

class _DeviceMultiPickerScreenState extends State<DeviceMultiPickerScreen> {
  bool _isGeneral = false;
  final Set<String> _selectedDeviceIds = {};

  bool get _allSelected =>
      widget.devices.isNotEmpty &&
      _selectedDeviceIds.length == widget.devices.length;

  bool get _hasSelection => _isGeneral || _selectedDeviceIds.isNotEmpty;

  void _toggleGeneral() {
    setState(() {
      _isGeneral = !_isGeneral;
      if (_isGeneral) _selectedDeviceIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedDeviceIds.clear();
      } else {
        _selectedDeviceIds
          ..clear()
          ..addAll(widget.devices.map((d) => d.id!));
        _isGeneral = false;
      }
    });
  }

  void _toggleDevice(DeviceAggr device) {
    if (device.id == null) return;
    setState(() {
      _isGeneral = false;
      if (_selectedDeviceIds.contains(device.id)) {
        _selectedDeviceIds.remove(device.id);
      } else {
        _selectedDeviceIds.add(device.id!);
      }
    });
  }

  void _confirm() {
    if (_isGeneral) {
      Navigator.pop(context, DevicePickerResult(DevicePickerAction.general));
      return;
    }

    if (_selectedDeviceIds.length == 1) {
      final device = widget.devices.firstWhere(
        (d) => d.id == _selectedDeviceIds.first,
      );
      Navigator.pop(
        context,
        DevicePickerResult(DevicePickerAction.specific, device),
      );
      return;
    }

    if (_allSelected) {
      Navigator.pop(context, DevicePickerResult(DevicePickerAction.all));
      return;
    }

    // 2+ but not all
    Navigator.pop(
      context,
      DevicePickerResult.multi(_selectedDeviceIds.toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        middle: Text(context.l10n.selectDeviceFor),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _hasSelection ? _confirm : null,
          child: Text(
            context.l10n.confirm,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _hasSelection
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            CupertinoListSection.insetGrouped(
              children: [
                // "Geral" option
                CupertinoListTile(
                  title: Text(context.l10n.generalNoDevice),
                  trailing: _isGeneral
                      ? Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoTheme.of(context).primaryColor,
                        )
                      : null,
                  onTap: _toggleGeneral,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                // "Select All" toggle
                CupertinoListTile(
                  title: Text(
                    context.l10n.selectAll,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  trailing: _allSelected
                      ? Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoTheme.of(context).primaryColor,
                        )
                      : null,
                  onTap: _toggleSelectAll,
                ),
                // Individual devices
                ...widget.devices.map((device) {
                  final displayName =
                      device.serial != null && device.serial!.trim().isNotEmpty
                          ? '${device.name} - ${device.serial}'
                          : device.name ?? '';
                  final isSelected = _selectedDeviceIds.contains(device.id);

                  return CupertinoListTile(
                    title: Text(displayName),
                    trailing: isSelected
                        ? Icon(
                            CupertinoIcons.checkmark,
                            color: CupertinoTheme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () => _toggleDevice(device),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
