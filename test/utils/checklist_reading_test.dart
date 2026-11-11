import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/utils/checklist_reading.dart';

FormItemDefinition _km({String id = 'km', bool reading = true}) =>
    FormItemDefinition(
      id: id,
      label: 'Quilometragem Atual',
      type: FormItemType.number,
      reading: reading,
    );

void main() {
  group('checklistReadingDeviceId', () {
    test("the checklist's own device", () {
      expect(checklistReadingDeviceId('d2', ['d1', 'd2']), 'd2');
    });
    test("no device on the checklist: the order's only one", () {
      expect(checklistReadingDeviceId(null, ['d1']), 'd1');
      expect(checklistReadingDeviceId('', ['d1']), 'd1');
    });
    test('none, or several and none picked: no link', () {
      expect(checklistReadingDeviceId(null, []), isNull);
      expect(checklistReadingDeviceId(null, ['d1', 'd2']), isNull);
    });
  });

  group('lastVisitReading', () {
    test("the device's reading when the order has none or another", () {
      expect(lastVisitReading(device: 102000), 102000);
      expect(lastVisitReading(device: 102000, order: 99000), 102000);
    });
    test('unknown when the device got it from this visit, or has none', () {
      expect(lastVisitReading(device: 105000, order: 105000), isNull);
      expect(lastVisitReading(order: 105000), isNull);
    });
  });

  test('readingBelowLastVisit warns only below a known reading', () {
    expect(readingBelowLastVisit(98000, 102000), isTrue);
    expect(readingBelowLastVisit(102000, 102000), isFalse);
    expect(readingBelowLastVisit(110000, 102000), isFalse);
    expect(readingBelowLastVisit(5, null), isFalse);
  });

  group('unansweredReadingItems', () {
    OrderForm form({
      List<FormResponse> responses = const [],
      FormStatus status = FormStatus.pending,
    }) => OrderForm(
      id: 'f1',
      formDefinitionId: 'd1',
      title: 'Entrada',
      status: status,
      responses: responses,
      items: [
        _km(),
        _km(id: 'other', reading: false),
        FormItemDefinition(id: 'obs', label: 'Obs', type: FormItemType.text),
      ],
    );

    test('only the reading question, while empty', () {
      expect(unansweredReadingItems(form()).map((i) => i.id), ['km']);
      expect(
        unansweredReadingItems(
          form(responses: [FormResponse(itemId: 'km', value: ' ')]),
        ).map((i) => i.id),
        ['km'],
      );
      expect(
        unansweredReadingItems(
          form(responses: [FormResponse(itemId: 'km', value: '98000')]),
        ),
        isEmpty,
      );
    });

    test('never in a completed checklist', () {
      expect(
        unansweredReadingItems(form(status: FormStatus.completed)),
        isEmpty,
      );
    });
  });
}
