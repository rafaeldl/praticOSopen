import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/form_definition.dart';

void main() {
  test('reading comes from the template and goes back only when true', () {
    final item = FormItemDefinition.fromJson({
      'id': 'km_atual',
      'label': 'Quilometragem Atual',
      'type': 'number',
      'required': true,
      'allowPhotos': true,
      'reading': true,
    });
    expect(item.reading, isTrue);
    expect(item.isReading, isTrue);
    expect(item.toJson()['reading'], isTrue);

    final plain = FormItemDefinition.fromJson({
      'id': 'obs',
      'label': 'Obs',
      'type': 'text',
      'required': false,
      'allowPhotos': false,
    });
    expect(plain.reading, isFalse);
    expect(plain.toJson().containsKey('reading'), isFalse);
  });

  test('only a number question is a reading', () {
    final text = FormItemDefinition(
      id: 'serie',
      label: 'Série',
      type: FormItemType.text,
      reading: true,
    );
    expect(text.isReading, isFalse);
  });
}
