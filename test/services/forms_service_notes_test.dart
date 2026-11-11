import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/forms_service.dart';

OrderForm _form({Map<String, FormItemNote>? notes, String itemId = 'body'}) =>
    OrderForm(
      id: 'f1',
      formDefinitionId: 'd1',
      title: 'Entrada',
      status: FormStatus.inProgress,
      responses: [
        FormResponse(
          itemId: itemId,
          value: 'Com avaria',
          photoUrls: ['https://x/1.jpg', 'https://x/2.jpg'],
        ),
      ],
      notes: notes,
    );

FormItemNote _note() => FormItemNote(
  text: 'Amassado na porta',
  photos: [
    FormPhotoNote(url: 'https://x/1.jpg', text: 'Risco'),
    FormPhotoNote(url: 'https://x/2.jpg', text: 'Amassado'),
  ],
);

void main() {
  test('saving an answer never writes the notes', () {
    final form = _form(notes: {'body': _note()});
    for (final change in <FormAnswerChange>[
      const FormValueChange('body', 'Sem avaria'),
      const FormPhotosAdded('body', ['https://x/3.jpg']),
    ]) {
      final write = FormsService.answerWrite(form, change);
      expect(
        write.update.keys.where((k) => k.startsWith('notes')),
        isEmpty,
        reason: '$change',
      );
      expect(write.update.keys, containsAll(['responses', 'updatedAt']));
    }
  });

  test('the responses written carry no note', () {
    final write = FormsService.answerWrite(
      _form(notes: {'body': _note()}),
      const FormValueChange('body', 'Sem avaria'),
    );
    final response = (write.update['responses'] as List).single as Map;
    expect(response.keys, unorderedEquals(['itemId', 'value', 'photoUrls']));
  });

  test('a removed photo takes its note with it, in the same write', () {
    final write = FormsService.answerWrite(
      _form(notes: {'body': _note()}),
      const FormPhotoRemoved('body', 'https://x/1.jpg'),
    );
    final note = write.update['notes.body'] as Map<String, dynamic>;
    expect(note['text'], 'Amassado na porta');
    expect((note['photos'] as List).single['url'], 'https://x/2.jpg');
  });

  test('a note left empty by the removal is deleted', () {
    final write = FormsService.answerWrite(
      _form(
        notes: {
          'body': FormItemNote(
            photos: [FormPhotoNote(url: 'https://x/1.jpg', text: 'Risco')],
          ),
        },
      ),
      const FormPhotoRemoved('body', 'https://x/1.jpg'),
    );
    expect(write.update['notes.body'], FieldValue.delete());
  });

  test('a photo without note, or an id that is not a field name, writes no note', () {
    expect(
      FormsService.photoNoteRemoval(
        const FormPhotoRemoved('body', 'https://x/9.jpg'),
        _note(),
      ),
      isEmpty,
    );
    expect(
      FormsService.photoNoteRemoval(
        const FormPhotoRemoved('a.b', 'https://x/1.jpg'),
        _note(),
      ),
      isEmpty,
    );
    expect(
      FormsService.photoNoteRemoval(
        const FormPhotoRemoved('body', 'https://x/1.jpg'),
        null,
      ),
      isEmpty,
    );
  });
}
