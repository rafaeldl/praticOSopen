import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/services/ai_form_photo_service.dart';
import 'package:praticos/services/ai_order_assist_service.dart';

FormItemDefinition _item(
  FormItemType type, {
  List<String>? options,
  String id = 'q',
}) =>
    FormItemDefinition(id: id, label: 'Pergunta', type: type, options: options);

AiFormPhotoPlan _plan(
  FormItemDefinition item,
  AiFormPhotoResult result, {
  Object? value,
  FormItemNote? note,
}) => planAiFormPhoto(
  item: item,
  response: FormResponse(itemId: item.id, value: value, photoUrls: ['u1']),
  note: note,
  photoUrl: 'u1',
  result: result,
);

void main() {
  group('aiAnswerValue', () {
    test('keeps the answer only in the shape the question saves', () {
      expect(aiAnswerValue(_item(FormItemType.boolean), true), true);
      expect(aiAnswerValue(_item(FormItemType.boolean), 'false'), false);
      expect(aiAnswerValue(_item(FormItemType.boolean), 'talvez'), isNull);

      final fuel = _item(FormItemType.select, options: ['Reserva', '1/4']);
      // The option as saved, whatever the case.
      expect(aiAnswerValue(fuel, 'reserva'), 'Reserva');
      expect(aiAnswerValue(fuel, 'Cheio'), isNull);

      final damage = _item(
        FormItemType.checklist,
        options: ['Porta', 'Para-choque'],
      );
      expect(aiAnswerValue(damage, ['porta', 'Teto', 'Porta']), ['Porta']);
      expect(aiAnswerValue(damage, ['Teto']), isNull);

      // A number is saved as typed text, like the person's answer.
      expect(aiAnswerValue(_item(FormItemType.number), 98000), '98000');
      expect(aiAnswerValue(_item(FormItemType.number), 98000.0), '98000');
      expect(aiAnswerValue(_item(FormItemType.number), 12.5), '12.5');
      expect(aiAnswerValue(_item(FormItemType.number), 'muito'), isNull);

      expect(aiAnswerValue(_item(FormItemType.text), ' SN 4C2X '), 'SN 4C2X');
      expect(aiAnswerValue(_item(FormItemType.photoOnly), 'x'), isNull);
    });
  });

  group('planAiFormPhoto', () {
    final fuel = _item(FormItemType.select, options: ['Reserva', '1/4']);

    test('fills the empty answer and the empty notes, marked as the AI', () {
      final plan = _plan(
        fuel,
        const AiFormPhotoResult(
          answer: '1/4',
          note: 'Ponteiro em um quarto',
          photoNote: 'Luz de óleo acesa',
          confident: true,
        ),
      );
      expect(plan.answer, '1/4');
      expect(plan.note!.text, 'Ponteiro em um quarto');
      expect(plan.note!.ai, isTrue);
      expect(plan.note!.photoText('u1'), 'Luz de óleo acesa');
      expect(plan.note!.photos.single.ai, isTrue);
      expect(plan.extra, isNull);
      expect(plan.filled, isTrue);
    });

    test('never replaces an answer: a different one is only told', () {
      final plan = _plan(
        fuel,
        const AiFormPhotoResult(answer: '1/4', confident: true),
        value: 'Reserva',
      );
      expect(plan.answer, isNull);
      expect(plan.answerSeen, '1/4');
      expect(plan.filled, isFalse);

      final same = _plan(
        fuel,
        const AiFormPhotoResult(answer: 'Reserva', confident: true),
        value: 'Reserva',
      );
      expect(same.isEmpty, isTrue);
    });

    test("never rewrites the person's note: offers what it saw", () {
      final note = FormItemNote(text: 'Risco na porta');
      final plan = _plan(
        _item(FormItemType.boolean),
        const AiFormPhotoResult(
          answer: true,
          note: 'Amassado no para-lama',
          confident: true,
        ),
        note: note,
      );
      expect(plan.answer, true);
      // Only the answer changes: the note is not rewritten.
      expect(plan.note, isNull);
      expect(plan.extra, 'Amassado no para-lama');

      // Already said: nothing to offer.
      final said = _plan(
        _item(FormItemType.boolean),
        const AiFormPhotoResult(note: 'risco na porta'),
        note: note,
      );
      expect(said.isEmpty, isTrue);
    });

    test('option notes only on multiple choice, only on known options', () {
      final damage = _item(
        FormItemType.checklist,
        options: ['Porta', 'Para-choque'],
      );
      final plan = _plan(
        damage,
        const AiFormPhotoResult(
          answer: ['Porta'],
          optionNotes: [
            (option: 'porta', text: 'amassado perto da maçaneta'),
            (option: 'Teto', text: 'não existe'),
          ],
          confident: true,
        ),
        note: FormItemNote(
          options: [FormOptionNote(option: 'Para-choque', text: 'risco')],
        ),
      );
      expect(plan.note!.optionText('Porta'), 'amassado perto da maçaneta');
      // The person's option note stays.
      expect(plan.note!.optionText('Para-choque'), 'risco');
      expect(plan.note!.options.length, 2);
    });

    test('a bad photo fills nothing', () {
      final plan = _plan(
        fuel,
        const AiFormPhotoResult(note: 'Escuro', photoIssue: AiPhotoIssue.dark),
      );
      expect(plan.issue, AiPhotoIssue.dark);
      expect(plan.filled, isFalse);
      expect(plan.note, isNull);
    });
  });

  test('appendToNote adds after what the person wrote', () {
    final note = appendToNote(
      FormItemNote(
        text: 'Risco na porta',
        photos: [FormPhotoNote(url: 'u1', text: 'x')],
      ),
      'Amassado no para-lama',
    );
    expect(note.text, 'Risco na porta. Amassado no para-lama');
    expect(note.ai, isFalse);
    expect(note.photos.single.url, 'u1');
    expect(appendToNote(null, 'Amassado').text, 'Amassado');
  });

  group('request and answer', () {
    test('the body has the question and no empty device fields', () {
      final body = aiFormPhotoBody(
        photo: AiPhoto(Uint8List.fromList([1, 2])),
        question: const AiFormQuestion(
          label: 'Quilometragem',
          type: FormItemType.photoOnly,
        ),
        deviceName: 'Fiat Uno 2015',
        locale: 'pt',
        lastReading: (value: 102000, unit: 'km'),
      );
      expect(body['photo'], {'mimeType': 'image/jpeg', 'data': 'AQI='});
      expect(body['question'], {
        'label': 'Quilometragem',
        'type': 'photo_only',
      });
      expect(body['device'], {'name': 'Fiat Uno 2015'});
      expect(body['lastReading'], {'value': 102000, 'unit': 'km'});
      expect(body.containsKey('segment'), isFalse);
    });

    test('reads the answer and maps the errors like the order', () {
      final result = parseAiFormPhotoResponse(
        200,
        jsonEncode({
          'success': true,
          'data': {
            'answer': '1/4',
            'note': 'Ponteiro em um quarto',
            'photoIssue': 'off_target',
            'confident': true,
            'usage': {'used': 3, 'limit': 150},
          },
        }),
      );
      expect(result.answer, '1/4');
      expect(result.photoIssue, AiPhotoIssue.offTarget);
      expect(result.used, 3);

      expect(
        () => parseAiFormPhotoResponse(
          429,
          jsonEncode({
            'success': false,
            'error': {'code': 'AI_QUOTA_EXCEEDED'},
          }),
        ),
        throwsA(
          isA<AiOrderAssistException>().having(
            (e) => e.error,
            'error',
            AiAssistError.quotaExceeded,
          ),
        ),
      );
      expect(
        () => parseAiFormPhotoResponse(500, 'oops'),
        throwsA(isA<AiOrderAssistException>()),
      );
    });
  });
}
