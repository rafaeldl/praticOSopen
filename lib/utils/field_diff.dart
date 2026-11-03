import 'package:collection/collection.dart';
import 'package:praticos/utils/order_field_diff.dart' show DeleteFieldOp;

export 'package:praticos/utils/order_field_diff.dart' show DeleteFieldOp;

const _equality = DeepCollectionEquality();

/// Top-level fields of [after] that differ from [before] (deep comparison of
/// the JSON values), for a partial `update` of a document. Only [only] are
/// looked at when given (otherwise every key of both); [ignore] never goes
/// out. A field that [after] no longer has goes out as null.
///
/// Saving only what the person changed keeps what someone else wrote
/// meanwhile (the web, another phone) instead of putting back the copy the
/// screen loaded.
Map<String, dynamic> changedFields(
  Map<String, dynamic> before,
  Map<String, dynamic> after, {
  Iterable<String>? only,
  Set<String> ignore = const {},
}) {
  final keys = only?.toSet() ?? {...before.keys, ...after.keys};
  final result = <String, dynamic>{};
  for (final key in keys) {
    if (ignore.contains(key)) continue;
    _diff(result, key, before[key], after[key], after.containsKey(key));
  }
  return result;
}

/// A key Firestore takes as one path segment without quoting.
final _plainKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Adds to [out] what changed from [before] to [after] at [path]. Two maps
/// go key by key (`customData.warranty`), so a key someone else wrote in the
/// same map stays; a key taken out is a [DeleteFieldOp]. A map with a key
/// that is not a plain name (it would be read as a path) goes whole.
void _diff(
  Map<String, dynamic> out,
  String path,
  Object? before,
  Object? after,
  bool present,
) {
  if (_equality.equals(before, after)) return;
  if (before is Map && after is Map) {
    final keys = {...before.keys, ...after.keys};
    if (keys.every((k) => k is String && _plainKey.hasMatch(k))) {
      for (final key in keys.cast<String>()) {
        _diff(out, '$path.$key', before[key], after[key], after.containsKey(key));
      }
      return;
    }
  }
  final nested = path.contains('.');
  out[path] = nested && !present ? const DeleteFieldOp() : after;
}

/// Fields the catalog form edits (service and product).
const catalogEditedFields = ['name', 'value', 'photo', 'customData'];

/// What saving an edited catalog item writes: the edited fields that differ
/// from [previous] (the item as it was read) and, with a new name, the
/// search keywords. Never the price when only the name changed, so a price
/// the web changed meanwhile stays.
Map<String, dynamic> catalogChangedFields(
  Map<String, dynamic> previous,
  Map<String, dynamic> after,
) {
  final fields = changedFields(previous, after, only: catalogEditedFields);
  if (fields.containsKey('name')) fields['keywords'] = after['keywords'];
  return fields;
}
