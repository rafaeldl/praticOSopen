import 'package:flutter/cupertino.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/widgets/dynamic_field_builder.dart';

/// Keys of hardcoded fields already rendered in the order screens.
/// The segment may configure these fields (label, mask, validation)
/// but they must not appear as duplicate dynamic fields.
const orderBuiltInFieldKeys = {
  'service_order.status',
  'service_order.scheduledDate',
  'service_order.dueDate',
  'service_order.total',
  'service_order.payment',
  'service_order.address',
};

/// Segment field that holds what the customer asked for ("Observação").
/// The new order's "O que o cliente pediu" writes here when the segment has
/// it, so the same text is not asked twice.
const orderRequestFieldKey = 'service_order.observation';

/// The segment's request field, or null when the segment has none.
CustomField? orderRequestField(SegmentConfigProvider config) {
  for (final field in config.fieldsFor('service_order')) {
    if (field.key == orderRequestFieldKey) return field;
  }
  return null;
}

/// Segment custom fields of the order (`service_order.*`), grouped by
/// localized section name, without the built-in ones. [withoutRequest]
/// also hides the request field (the new order shows it as its own card).
Map<String, List<CustomField>> orderCustomFieldsFor(
  SegmentConfigProvider config, {
  bool withoutRequest = false,
}) =>
    config.fieldsGroupedBySectionLocalized(
      'service_order',
      exclude: {
        ...orderBuiltInFieldKeys,
        if (withoutRequest) orderRequestFieldKey,
      },
    );

/// Returns [data] with [field] set to [value] (removed when null). Also
/// drops the old full-key entry (migration) and returns null when nothing is
/// left, so empty maps are never saved. Shared by both order screens.
Map<String, dynamic>? applyCustomFieldValue(
  Map<String, dynamic>? data,
  CustomField field,
  dynamic value,
) {
  final next = <String, dynamic>{...?data};
  if (value == null) {
    next.remove(field.fieldName);
  } else {
    next[field.fieldName] = value;
  }
  next.remove(field.key); // migrate old key
  return next.isEmpty ? null : next;
}

/// Value of [field] in [data] (new key first, then the old full key).
dynamic customFieldValue(Map<String, dynamic>? data, CustomField field) =>
    data?[field.fieldName] ?? data?[field.key];

/// The segment's custom fields of the order, one section per group. How a
/// section looks (header, container) is up to [sectionBuilder].
class OrderCustomFieldSections extends StatelessWidget {
  const OrderCustomFieldSections({
    super.key,
    required this.grouped,
    required this.customData,
    required this.locale,
    required this.onChanged,
    required this.sectionBuilder,
  });

  final Map<String, List<CustomField>> grouped;
  final Map<String, dynamic>? customData;
  final String locale;

  /// Receives the new `customData` (null when empty) after an edit.
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final Widget Function(
    BuildContext context,
    String sectionName,
    List<Widget> rows,
  ) sectionBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in grouped.entries)
          sectionBuilder(
            context,
            entry.key,
            [
              for (final field in entry.value)
                DynamicFieldBuilder(
                  field: field,
                  value: customFieldValue(customData, field),
                  locale: locale,
                  onChanged: (value) =>
                      onChanged(applyCustomFieldValue(customData, field, value)),
                ),
            ],
          ),
      ],
    );
  }
}
