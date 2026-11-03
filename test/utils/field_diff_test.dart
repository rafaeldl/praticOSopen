// Maps go out by path (`customData.key`), so a field the web wrote inside
// the same map stays.
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/field_diff.dart';

void main() {
  test('a changed or new key inside a map goes by path', () {
    final fields = changedFields(
      {
        'name': 'Troca',
        'customData': {'warranty': '90', 'brand': 'X'},
      },
      {
        'name': 'Troca',
        'customData': {'warranty': '180', 'brand': 'X', 'color': 'azul'},
      },
    );
    expect(fields, {'customData.warranty': '180', 'customData.color': 'azul'});
  });

  test('a key taken out of a map is deleted by path', () {
    final fields = changedFields(
      {
        'customData': {'warranty': '90', 'brand': 'X'},
      },
      {
        'customData': {'brand': 'X'},
      },
    );
    expect(fields, {'customData.warranty': const DeleteFieldOp()});
  });

  test('nested maps go down to the changed key', () {
    final fields = changedFields(
      {
        'a': {
          'b': {'c': 1, 'd': 2},
        },
      },
      {
        'a': {
          'b': {'c': 1, 'd': 3},
        },
      },
    );
    expect(fields, {'a.b.d': 3});
  });

  test('a map that appears or goes away is written whole', () {
    expect(
      changedFields(
        {'customData': null},
        {
          'customData': {'a': 1},
        },
      ),
      {
        'customData': {'a': 1},
      },
    );
    expect(
      changedFields(
        {
          'customData': {'a': 1},
        },
        {'customData': null},
      ),
      {'customData': null},
    );
  });

  test('a key that is not a plain name is written with its whole map', () {
    // "service.warranty" would be read as a path: the map goes whole.
    final fields = changedFields(
      {
        'customData': {'service.warranty': '90', 'brand': 'X'},
      },
      {
        'customData': {'service.warranty': '180', 'brand': 'X'},
      },
    );
    expect(fields, {
      'customData': {'service.warranty': '180', 'brand': 'X'},
    });
  });

  test('catalog: a segment field change goes by path', () {
    final fields = catalogChangedFields(
      {
        'name': 'Troca',
        'value': 100,
        'customData': {'warranty': '90', 'web': 'sim'},
      },
      {
        'name': 'Troca',
        'value': 100,
        'customData': {'warranty': '180', 'web': 'sim'},
      },
    );
    expect(fields, {'customData.warranty': '180'});
  });
}
