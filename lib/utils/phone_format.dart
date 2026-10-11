import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:praticos/global.dart';

/// Phone for display, e.g. "+5548984087801" -> "(48) 98408-7801" (BR).
///
/// Numbers from the company's country (or [country], an ISO 3166-1 alpha-2
/// code) show in the national format; foreign numbers keep the country code.
/// Returns the raw text when it cannot be parsed or is not valid.
String formatPhone(String? raw, {String? country}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '';
  try {
    final code = (country ?? Global.companyAggr?.country ?? 'BR').toUpperCase();
    final iso = IsoCode.values.where((c) => c.name == code).firstOrNull ??
        IsoCode.BR;
    final digits = text.replaceAll(RegExp(r'[^\d+]'), '');
    final phone = digits.startsWith('+')
        ? PhoneNumber.parse(digits)
        : PhoneNumber.parse(digits, destinationCountry: iso);
    if (!phone.isValid()) return text;
    if (phone.isoCode != iso) return '+${phone.countryCode} ${phone.formatNsn()}';
    return _national(phone, iso);
  } catch (_) {
    return text;
  }
}

String _national(PhoneNumber phone, IsoCode iso) {
  final nsn = phone.nsn;
  if (iso == IsoCode.BR && (nsn.length == 10 || nsn.length == 11)) {
    final area = nsn.substring(0, 2);
    final rest = nsn.substring(2);
    final split = rest.length - 4;
    return '($area) ${rest.substring(0, split)}-${rest.substring(split)}';
  }
  return phone.formatNsn();
}
