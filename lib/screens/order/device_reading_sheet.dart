import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_spacing.dart';

/// What [DeviceReadingSheet] gives back: the typed reading, or null when the
/// field was emptied (removes it). Cancelling resolves the sheet to null.
typedef DeviceReadingEdit = ({int? value});

/// Asks the device's reading at this visit ("Quilometragem", "Horímetro"):
/// title and unit from the segment's reading field, digits only.
class DeviceReadingSheet extends StatefulWidget {
  const DeviceReadingSheet({
    super.key,
    required this.field,
    required this.locale,
    this.deviceName,
    this.initial,
  });

  final CustomField field;
  final String locale;

  /// Which device, when the order has more than one.
  final String? deviceName;
  final int? initial;

  static Future<DeviceReadingEdit?> show(
    BuildContext context, {
    required CustomField field,
    required String locale,
    String? deviceName,
    int? initial,
  }) {
    return AppSheet.show<DeviceReadingEdit>(
      context,
      (_) => DeviceReadingSheet(
        field: field,
        locale: locale,
        deviceName: deviceName,
        initial: initial,
      ),
    );
  }

  @override
  State<DeviceReadingSheet> createState() => _DeviceReadingSheetState();
}

class _DeviceReadingSheetState extends State<DeviceReadingSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.field.getLabel(widget.locale);
    final suffix = widget.field.suffix?.trim();
    final name = widget.deviceName?.trim();
    return AppSheet(
      title: label,
      actionLabel: context.l10n.save,
      onAction: () {
        final text = _controller.text.trim();
        Navigator.pop<DeviceReadingEdit>(context, (
          value: text.isEmpty ? null : int.tryParse(text),
        ));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.blockMargin,
          vertical: AppSpacing.lg,
        ),
        children: [
          AppFormField(
            key: const ValueKey('device_reading_input'),
            label: suffix == null || suffix.isEmpty ? label : '$label ($suffix)',
            hint: name == null || name.isEmpty ? null : name,
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            autofocus: true,
          ),
        ],
      ),
    );
  }
}
