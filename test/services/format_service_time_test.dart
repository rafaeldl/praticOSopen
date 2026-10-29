import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/services/format_service.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => FormatService().setLocale('pt-BR'));

  // The server writes payment times in UTC ('…Z', e.g. the Asaas webhook);
  // the app writes local time. Both must show the phone's local time.
  test('a UTC time is shown in local time', () {
    final utc = DateTime.parse('2026-10-29T20:37:51.486Z');
    final local = utc.toLocal();
    final format = FormatService();

    expect(format.formatDateTime(utc), format.formatDateTime(local));
    expect(format.formatTime(utc), format.formatTime(local));
  });

  test('a local time is shown as is', () {
    final local = DateTime(2026, 10, 29, 17, 39);
    expect(FormatService().formatDateTime(local), '29/10/2026 17:39');
    expect(FormatService().formatTime(local), '17:39');
  });
}
