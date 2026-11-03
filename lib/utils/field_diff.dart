import 'package:collection/collection.dart';

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
    if (!_equality.equals(before[key], after[key])) result[key] = after[key];
  }
  return result;
}
