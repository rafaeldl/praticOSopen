// One answer changes only its question, and inside it only the part touched
// (same as the web's applyChange in firebase/webapp/src/lib/forms/model.ts),
// so the app and the web on the same checklist never erase each other.
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/utils/form_answer_change.dart';

List<Map<String, dynamic>> _json(List<FormResponse> responses) =>
    [for (final r in responses) r.toJson()];

void main() {
  // What the server has: the web added a photo to "a" and answered "c".
  List<FormResponse> server() => [
    FormResponse(itemId: 'a', value: true, photoUrls: ['web/a.jpg']),
    FormResponse(itemId: 'c', value: 'Cheio'),
  ];

  test('a new value keeps the photos someone else added', () {
    final next = applyAnswerChange(server(), FormValueChange('a', false));
    expect(_json(next), [
      {'itemId': 'a', 'value': false, 'photoUrls': ['web/a.jpg']},
      {'itemId': 'c', 'value': 'Cheio', 'photoUrls': []},
    ]);
  });

  test('a new question is added; the others stay as they are', () {
    final next = applyAnswerChange(server(), FormValueChange('b', 'Reserva'));
    expect(next.map((r) => r.itemId), ['a', 'c', 'b']);
    expect(next.last.value, 'Reserva');
    expect(next.last.photoUrls, isEmpty);
    expect(next.first.photoUrls, ['web/a.jpg']);
  });

  test('a photo keeps the value and the photos already there', () {
    final next = applyAnswerChange(
      server(),
      FormPhotosAdded('a', ['app/a1.jpg', 'web/a.jpg']),
    );
    expect(next.first.value, isTrue);
    expect(next.first.photoUrls, ['web/a.jpg', 'app/a1.jpg']);
  });

  test('removing a photo takes only that one, of that question', () {
    final start = [
      FormResponse(itemId: 'a', value: true, photoUrls: ['p1', 'p2']),
      FormResponse(itemId: 'b', photoUrls: ['p1']),
    ];
    final next = applyAnswerChange(start, FormPhotoRemoved('a', 'p1'));
    expect(next.first.photoUrls, ['p2']);
    expect(next.first.value, isTrue);
    expect(next.last.photoUrls, ['p1']);
    // Nothing to remove from a question without an answer.
    expect(_json(applyAnswerChange(start, FormPhotoRemoved('z', 'p1'))),
        _json(start));
  });

  test('never changes the list it got', () {
    final start = server();
    applyAnswerChange(start, FormPhotosAdded('a', ['x']));
    expect(start.first.photoUrls, ['web/a.jpg']);
  });

  test('a question saved twice (old offline queue) becomes one', () {
    final start = [
      FormResponse(itemId: 'a', value: 'old'),
      FormResponse(itemId: 'b', value: 1),
      FormResponse(itemId: 'a', value: 'new', photoUrls: ['p']),
    ];
    final next = applyAnswerChange(start, FormValueChange('a', 'newer'));
    expect(_json(next), [
      {'itemId': 'b', 'value': 1, 'photoUrls': []},
      {'itemId': 'a', 'value': 'newer', 'photoUrls': ['p']},
    ]);
  });

  test('offline: swaps only that question, never the whole list', () {
    final before = FormResponse(itemId: 'a', value: true, photoUrls: ['p']);
    final write = queuedAnswerWrite(before, FormValueChange('a', false));
    expect(write.removed, before.toJson());
    expect(write.added, {'itemId': 'a', 'value': false, 'photoUrls': ['p']});

    final first = queuedAnswerWrite(null, FormValueChange('b', 'Reserva'));
    expect(first.removed, isNull);
    expect(first.added, {'itemId': 'b', 'value': 'Reserva', 'photoUrls': []});
  });
}
