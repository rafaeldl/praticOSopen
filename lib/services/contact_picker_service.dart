import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:praticos/utils/vcard.dart';

/// Opens the system contact picker, which gives the app only the contact the
/// person chooses. No contacts permission is declared or requested.
///
/// iOS (`CNContactPickerViewController`, `ios/Runner/AppDelegate.swift`)
/// returns name, every phone and e-mail. Android (`ACTION_PICK`,
/// `MainActivity.kt`) asks for one number in the system list and returns that
/// number and the name: without `READ_CONTACTS` it cannot read the rest.
class ContactPickerService {
  static const MethodChannel _channel =
      MethodChannel('br.com.rafsoft.praticos/contacts');

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// The chosen contact, or null when closed without choosing.
  Future<ContactCard?> pick() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('pick');
      return result == null ? null : contactFromPicker(result);
    } on PlatformException catch (e) {
      debugPrint('ContactPicker: $e');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('ContactPicker: $e');
      return null;
    }
  }
}

/// Builds the card from the map sent by the native side.
ContactCard contactFromPicker(Map<String, Object?> map) {
  String? text(Object? value) {
    final s = (value as String? ?? '').trim();
    return s.isEmpty ? null : s;
  }

  final seen = <String>{};
  return ContactCard(
    name: text(map['name']),
    phones: [
      for (final phone in (map['phones'] as List<Object?>? ?? const []))
        if (text(phone) != null &&
            seen.add(text(phone)!.replaceAll(RegExp(r'\D'), '')))
          text(phone)!,
    ],
    email: text(map['email']),
  );
}
