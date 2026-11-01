import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/contact_picker_service.dart';

void main() {
  test('builds the card from the iOS map', () {
    final card = contactFromPicker({
      'name': ' Ana Ribeiro ',
      'phones': ['+55 48 98408-7801', '(48) 3222-3344', '55 (48) 98408 7801', ''],
      'email': 'ana@example.com',
    });
    expect(card.name, 'Ana Ribeiro');
    expect(card.phones, ['+55 48 98408-7801', '(48) 3222-3344']);
    expect(card.email, 'ana@example.com');
  });

  test('empty values become null', () {
    final card = contactFromPicker({'name': '', 'phones': [], 'email': null});
    expect(card.name, isNull);
    expect(card.phones, isEmpty);
    expect(card.email, isNull);
    expect(card.isEmpty, isTrue);
  });

  test('builds the card from the Android map, without e-mail', () {
    final card = contactFromPicker({
      'name': 'Bia',
      'phones': ['48 98408-7801'],
    });
    expect(card.phones, ['48 98408-7801']);
    expect(card.email, isNull);
  });

  group('no access to the whole address book', () {
    String read(String path) => File(path).readAsStringSync();

    test('Android declares no contacts permission', () {
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        isNot(contains('_CONTACTS')),
      );
    });

    test('native sides use the system pickers on the same channel', () {
      const channel = 'br.com.rafsoft.praticos/contacts';
      final ios = read('ios/Runner/AppDelegate.swift');
      expect(ios, contains(channel));
      expect(ios, contains('CNContactPickerViewController'));
      expect(ios, isNot(contains('CNContactStore')));

      final android = read(
        'android/app/src/main/kotlin/br/com/rafsoft/praticos/MainActivity.kt',
      );
      expect(android, contains(channel));
      expect(android, contains('ACTION_PICK'));
    });
  });
}
