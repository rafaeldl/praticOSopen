import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/utils/order_field_diff.dart' show DeleteFieldOp;

/// [fields] (from `changedFields`) ready for `update`: a [DeleteFieldOp]
/// becomes `FieldValue.delete()`; paths like `customData.warranty` stay as
/// they are, so only that key of the map changes.
Map<String, dynamic> firestoreFieldsOf(Map<String, dynamic> fields) => {
  for (final entry in fields.entries)
    entry.key: entry.value is DeleteFieldOp
        ? FieldValue.delete()
        : entry.value,
};
