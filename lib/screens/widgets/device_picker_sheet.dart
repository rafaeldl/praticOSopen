import 'package:flutter/cupertino.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/extensions/context_extensions.dart';

enum DevicePickerAction { specific, general, all }

class DevicePickerResult {
  final DevicePickerAction action;
  final DeviceAggr? device;

  DevicePickerResult(this.action, [this.device]);
}

class DevicePickerSheet {
  static Future<DevicePickerResult?> show(
    BuildContext context,
    List<DeviceAggr> devices,
  ) async {
    return showCupertinoModalPopup<DevicePickerResult>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.selectDeviceFor),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              ctx,
              DevicePickerResult(DevicePickerAction.general),
            ),
            child: Text(context.l10n.generalNoDevice),
          ),
          ...devices.map(
            (d) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(
                ctx,
                DevicePickerResult(DevicePickerAction.specific, d),
              ),
              child: Text(
                d.serial != null && d.serial!.trim().isNotEmpty
                    ? '${d.name} - ${d.serial}'
                    : d.name ?? '',
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              ctx,
              DevicePickerResult(DevicePickerAction.all),
            ),
            child: Text(
              context.l10n.duplicateForAll,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }
}
