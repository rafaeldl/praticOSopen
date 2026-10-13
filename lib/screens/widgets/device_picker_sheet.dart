import 'package:flutter/cupertino.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/segment_config_service.dart';

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

/// "Em quais veículos?": which vehicles of the order an item goes to.
///
/// Multiple choice on [PickerScaffold]: tapping marks / unmarks (✓), "Geral"
/// (no vehicle) and "Selecionar tudo" stay on top, and the round ✓ in the top
/// bar (gray until something is marked) confirms. Back cancels (null).
class DevicePickerSheet {
  static Future<DevicePickerResult?> show(
    BuildContext context,
    List<DeviceAggr> devices, {
    String? subtitle,
  }) async {
    return Navigator.push<DevicePickerResult>(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            DeviceMultiPickerScreen(devices: devices, subtitle: subtitle),
      ),
    );
  }
}

class DeviceMultiPickerScreen extends StatefulWidget {
  final List<DeviceAggr> devices;

  /// Under the question, e.g. the item ("Alinhamento · R$ 150 cada").
  final String? subtitle;

  const DeviceMultiPickerScreen({
    super.key,
    required this.devices,
    this.subtitle,
  });

  @override
  State<DeviceMultiPickerScreen> createState() =>
      _DeviceMultiPickerScreenState();
}

const _general = '\u0000general';
const _all = '\u0000all';

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

  void _onTap(String key) {
    if (key == _general) {
      _toggleGeneral();
    } else if (key == _all) {
      _toggleSelectAll();
    } else {
      _toggleDevice(widget.devices.firstWhere((d) => d.id == key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = widget.devices.where((d) => d.id != null).toList();
    return PickerScaffold<String>(
      title: l10n.pickerDevicesTitle(
        SegmentConfigService().devicePlural.toLowerCase(),
      ),
      subtitle: widget.subtitle,
      itemCount: devices.length,
      multiple: true,
      onConfirm: _hasSelection ? _confirm : null,
      onSelect: _onTap,
      sections: (query) => [
        if (query.isEmpty)
          PickerSection(
            items: [
              PickerItem(
                key: const ValueKey('device_picker_general'),
                value: _general,
                title: l10n.generalNoDevice,
                selected: _isGeneral,
              ),
              if (devices.length > 1)
                PickerItem(
                  key: const ValueKey('device_picker_all'),
                  value: _all,
                  title: l10n.selectAll,
                  selected: _allSelected,
                ),
            ],
          ),
        PickerSection(
          items: [
            for (final d in devices)
              if (pickerMatches(d.name, query) || pickerMatches(d.serial, query))
                PickerItem(
                  key: ValueKey('device_picker_${d.id}'),
                  value: d.id!,
                  title: d.name ?? '',
                  subtitle: (d.serial?.trim().isNotEmpty ?? false)
                      ? d.serial
                      : null,
                  selected: _selectedDeviceIds.contains(d.id),
                ),
          ],
        ),
      ],
    );
  }
}
