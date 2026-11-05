/// The device's reading: what a meter on it says at each visit (a vehicle's
/// odometer in km, a machine's hour meter in h, a printer's page counter…).
///
/// The segment says which device field is the reading (`reading: true` in
/// `segments/{id}.customFields`), with its name and unit (`labels`,
/// `suffix`). A segment without one (electronics, phones) has no reading
/// and nothing about it shows. The last value lives in the device field
/// itself (`device.customData[fieldName]`, the field that already existed),
/// and each order keeps the value of that visit in `Order.deviceReadings`,
/// by device id. See `docs/DEVICE_READING.md`.
library;

import 'package:praticos/models/custom_field.dart';
import 'package:praticos/services/format_service.dart';

/// Device fields that were readings before the `reading` flag existed: a
/// segment saved without the flag still gets the reading on screen.
const legacyReadingKeys = ['device.mileage', 'device.operatingHours'];

/// The segment's reading field among [deviceFields], or null when the
/// segment has none.
CustomField? readingFieldOf(Iterable<CustomField> deviceFields) {
  final numbers = deviceFields
      .where((f) => f.isField && f.type == 'number' && f.namespace == 'device')
      .toList();
  for (final f in numbers) {
    if (f.reading) return f;
  }
  for (final key in legacyReadingKeys) {
    for (final f in numbers) {
      if (f.key == key) return f;
    }
  }
  return null;
}

/// A reading as stored, or null for anything that is not a whole number of
/// zero or more (meters count up from zero; typed dots and commas are
/// thousand separators: "98.000" is 98000).
int? parseReading(Object? value) {
  if (value is num) {
    return value >= 0 && value == value.truncate() ? value.toInt() : null;
  }
  final digits = '${value ?? ''}'.trim().replaceAll(RegExp(r'[.,\s]'), '');
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
  return int.tryParse(digits);
}

/// "98.000 km", "1.250 h", "3.400" (field without a unit). Null when
/// [value] is not a reading.
String? formatReading(CustomField field, Object? value, FormatService format) {
  final number = parseReading(value);
  if (number == null) return null;
  final suffix = field.suffix?.trim();
  final text = format.formatDecimal(number);
  return suffix == null || suffix.isEmpty ? text : '$text $suffix';
}

/// The device's reading, read from its `customData` by field name (and by
/// the full key, as some old devices have it).
int? deviceReading(Map<String, dynamic>? customData, CustomField field) =>
    parseReading(customData?[field.fieldName] ?? customData?[field.key]);

/// Whether a visit's reading [next] becomes the device's last reading: when
/// the device has none, or it does not go back. Meters only go up, so a
/// smaller value is an older visit edited later (or a typo), and the device
/// keeps the bigger one; the device form still edits it by hand.
bool readingAdvances(int? current, int next) => current == null || next >= current;
