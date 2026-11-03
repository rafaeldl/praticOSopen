import 'package:praticos/models/order_form.dart';

/// One change to a checklist answer, applied to the responses read inside
/// the transaction (FormsService.saveAnswer). Same kinds as the web's
/// `AnswerChange` (firebase/webapp/src/lib/forms/model.ts).
sealed class FormAnswerChange {
  const FormAnswerChange(this.itemId);

  /// The question answered.
  final String itemId;
}

/// A new value: the photos of the question stay.
class FormValueChange extends FormAnswerChange {
  const FormValueChange(super.itemId, this.value);

  final dynamic value;
}

/// Photos added to the question: the value and the photos already there
/// stay.
class FormPhotosAdded extends FormAnswerChange {
  const FormPhotosAdded(super.itemId, this.urls);

  final List<String> urls;
}

/// One photo taken out of the question.
class FormPhotoRemoved extends FormAnswerChange {
  const FormPhotoRemoved(super.itemId, this.url);

  final String url;
}

FormResponse _copy(FormResponse r) => FormResponse(
  itemId: r.itemId,
  value: r.value,
  photoUrls: List.of(r.photoUrls),
);

/// [response] with [change] applied ([response] null: no answer yet). Never
/// changes [response].
FormResponse? applyToResponse(FormResponse? response, FormAnswerChange change) {
  if (response == null && change is FormPhotoRemoved) return null;
  final next = response == null
      ? FormResponse(itemId: change.itemId, photoUrls: [])
      : _copy(response);
  switch (change) {
    case FormValueChange(:final value):
      next.value = value;
    case FormPhotosAdded(:final urls):
      next.photoUrls = [
        ...next.photoUrls,
        for (final url in urls)
          if (!next.photoUrls.contains(url)) url,
      ];
    case FormPhotoRemoved(:final url):
      next.photoUrls = next.photoUrls.where((u) => u != url).toList();
  }
  return next;
}

/// The responses after [change]: only that question changes, and inside it
/// only the part touched (a value keeps the photos someone else added, a
/// photo keeps the value), so the app and the web on the same checklist never
/// erase each other. A question that is in the list twice (written by an old
/// offline queue) becomes one, the last. Never changes [responses].
List<FormResponse> applyAnswerChange(
  List<FormResponse> responses,
  FormAnswerChange change,
) {
  final id = change.itemId;
  final current = responses.lastWhereOrNull((r) => r.itemId == id);
  final changed = applyToResponse(current, change);
  final duplicated = responses.where((r) => r.itemId == id).length > 1;
  final result = <FormResponse>[];
  for (final r in responses) {
    if (r.itemId != id) {
      result.add(_copy(r));
    } else if (identical(r, current) && changed != null && !duplicated) {
      result.add(changed);
    }
  }
  // A new question, or one that was duplicated, goes to the end.
  if (changed != null && (current == null || duplicated)) result.add(changed);
  return result;
}

/// The offline write of [change] (transactions need the server): take out
/// the response the screen had ([before], what the server also had) and put
/// in the new one, with `arrayRemove` and `arrayUnion`. Only that question
/// is touched; the list and the status are never written whole. If the
/// server's response for the question changed meanwhile, both stay in the
/// list until the next answer to it ([applyAnswerChange] keeps the last).
({Map<String, dynamic>? removed, Map<String, dynamic> added}) queuedAnswerWrite(
  FormResponse? before,
  FormAnswerChange change,
) {
  final after =
      applyToResponse(before, change) ??
      FormResponse(itemId: change.itemId, photoUrls: []);
  return (removed: before?.toJson(), added: after.toJson());
}

extension<T> on Iterable<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    T? found;
    for (final e in this) {
      if (test(e)) found = e;
    }
    return found;
  }
}
