/// A checklist question linked to the device's reading
/// (`FormItemDefinition.reading`, e.g. "Quilometragem Atual" in the vehicle
/// check-in): its answer is the order's reading of the checklist's device,
/// so the order does not ask it again, and an order that already has the
/// reading answers it. See `docs/DEVICE_READING.md`.
library;

import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';

/// What the checklist screen needs to link its reading question to the
/// order. Null (no link) when the segment has no reading or the checklist
/// has no device: the question is then a plain number question.
class ChecklistReadingLink {
  const ChecklistReadingLink({
    required this.deviceId,
    required this.field,
    required this.orderReading,
    required this.onReading,
    this.lastVisit,
  });

  /// The checklist's device.
  final String deviceId;

  /// The segment's reading field (name and unit: "Quilometragem", "km").
  final CustomField field;

  /// The order's reading of [deviceId] now, if any.
  final int? Function() orderReading;

  /// Saves an answer as the order's reading (and the device's last
  /// reading), the same path as "+ Quilometragem" on the order.
  final void Function(int value) onReading;

  /// The device's reading at its last visit, to warn when the answer is
  /// smaller. Null or resolving to null: no warning.
  final Future<int?>? lastVisit;
}

/// The device a checklist's reading belongs to: the checklist's own device,
/// or the order's only device when the checklist has none (one device is
/// never asked). Null with no device, or several and none picked.
String? checklistReadingDeviceId(
  String? formDeviceId,
  List<String> orderDeviceIds,
) {
  if (formDeviceId != null && formDeviceId.isNotEmpty) return formDeviceId;
  return orderDeviceIds.length == 1 ? orderDeviceIds.single : null;
}

/// The device's reading at its last visit, from the device's last reading
/// ([device], `customData`) and this order's ([order]): when they are the
/// same, the device got it from this visit, so the last one is unknown.
int? lastVisitReading({int? device, int? order}) {
  if (device == null) return null;
  if (order != null && device == order) return null;
  return device;
}

/// Whether [value] is smaller than the last visit's reading: worth a "Está
/// certo?", never a block (a new hour meter, a typo in the last visit).
bool readingBelowLastVisit(int value, int? lastVisit) =>
    lastVisit != null && value < lastVisit;

/// Reading questions of [form] still without an answer, which an order that
/// already has the reading answers when the checklist opens. None for a
/// completed checklist.
List<FormItemDefinition> unansweredReadingItems(OrderForm form) {
  if (form.status == FormStatus.completed) return const [];
  return [
    for (final item in form.items)
      if (item.isReading && !_hasValue(form.getResponse(item.id)?.value)) item,
  ];
}

bool _hasValue(Object? value) =>
    value != null && (value is! String || value.trim().isNotEmpty);
