import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_form.dart';

void main() {
  Map<String, dynamic> doc() => {
    'id': 'f1',
    'formDefinitionId': 'd1',
    'title': 'Entrada',
    'status': 'in_progress',
    'items': <dynamic>[],
    'responses': [
      {
        'itemId': 'body',
        'value': ['Porta'],
        'photoUrls': ['https://x/1.jpg'],
      },
    ],
    'notes': {
      'body': {
        'text': 'Amassado na porta traseira esquerda',
        'ai': true,
        'options': [
          {'option': 'Porta', 'text': 'perto da maçaneta', 'ai': false},
        ],
        'photos': [
          {'url': 'https://x/1.jpg', 'text': 'Risco', 'ai': true},
        ],
      },
    },
    'aiFilled': ['fuel'],
  };

  test('notes and aiFilled go to json and back', () {
    final form = OrderForm.fromJson(doc());
    final note = form.noteOf('body')!;
    expect(note.text, 'Amassado na porta traseira esquerda');
    expect(note.ai, isTrue);
    expect(note.optionText('Porta'), 'perto da maçaneta');
    expect(note.photoText('https://x/1.jpg'), 'Risco');
    expect(form.aiFilled, ['fuel']);

    final again = OrderForm.fromJson(form.toJson());
    expect(again.toJson()['notes'], doc()['notes']);
    expect(again.aiFilled, ['fuel']);
  });

  test('notes stay out of responses', () {
    final json = OrderForm.fromJson(doc()).toJson();
    final response = (json['responses'] as List).single as Map;
    expect(response.keys, unorderedEquals(['itemId', 'value', 'photoUrls']));
  });

  test('a checklist without notes (older apps, the web) reads empty', () {
    final form = OrderForm.fromJson(
      doc()
        ..remove('notes')
        ..remove('aiFilled'),
    );
    expect(form.notes, isEmpty);
    expect(form.aiFilled, isEmpty);
  });

  test('a bad note is left out, the checklist still reads', () {
    final form = OrderForm.fromJson(
      doc()..['notes'] = {
        'body': 'not a note',
        'fuel': {'text': 3},
        'km': {'text': 'Painel ok'},
      },
    );
    expect(form.notes.keys, ['km']);
  });

  test('withoutPhoto takes out only that photo note; isEmpty', () {
    final note = OrderForm.fromJson(doc()).noteOf('body')!;
    final after = note.withoutPhoto('https://x/1.jpg');
    expect(after.photos, isEmpty);
    expect(after.text, note.text);
    expect(after.options.single.option, 'Porta');
    expect(after.isEmpty, isFalse);
    expect(FormItemNote(text: '  ').isEmpty, isTrue);
    expect(
      FormItemNote(
        photos: [FormPhotoNote(url: 'u', text: 'x')],
      ).withoutPhoto('u').isEmpty,
      isTrue,
    );
  });
}
