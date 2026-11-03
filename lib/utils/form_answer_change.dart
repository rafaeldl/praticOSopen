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
/// erase each other. A question that is in the list twice is read and edited
/// on its first entry, as the web, the bot and older apps read it; the other
/// entries stay. Never changes [responses].
List<FormResponse> applyAnswerChange(
  List<FormResponse> responses,
  FormAnswerChange change,
) {
  final id = change.itemId;
  final index = responses.indexWhere((r) => r.itemId == id);
  final changed = applyToResponse(index < 0 ? null : responses[index], change);
  final result = [for (final r in responses) _copy(r)];
  if (changed == null) return result;
  if (index < 0) {
    result.add(changed);
  } else {
    result[index] = changed;
  }
  return result;
}

/// The offline write of [change] (transactions need the server): take out
/// every response to that question the screen knows ([known]) and put in the
/// new one, built on the first, with `arrayRemove` and `arrayUnion`. Only
/// that question is touched; the list and the status are never written
/// whole.
///
/// What is left: if the web changed that question while the app was
/// offline, the server has a response the app does not know. It stays, the
/// new one goes after it, and everyone (reading the first) keeps seeing the
/// web's until the question is answered again online.
({List<Map<String, dynamic>> removed, Map<String, dynamic> added})
queuedAnswerWrite(List<FormResponse> known, FormAnswerChange change) {
  final mine = [
    for (final r in known)
      if (r.itemId == change.itemId) r,
  ];
  final after =
      applyToResponse(mine.isEmpty ? null : mine.first, change) ??
      FormResponse(itemId: change.itemId, photoUrls: []);
  return (removed: [for (final r in mine) r.toJson()], added: after.toJson());
}
