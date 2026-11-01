import 'dart:convert';

/// A person from the device's contacts: picked in the system picker or read
/// from a shared `.vcf`. Only a draft for the customer form, never saved as is.
class ContactCard {
  const ContactCard({this.name, this.phones = const [], this.email});

  final String? name;

  /// In the order they appear in the contact, without repeats.
  final List<String> phones;
  final String? email;

  bool get isEmpty => (name ?? '').isEmpty && phones.isEmpty;
}

/// Contacts in the text of a `.vcf`, in file order. Cards with neither name
/// nor phone are skipped, so an invalid file gives an empty list.
///
/// Reads what phones export: vCard 2.1, 3.0 and 4.0, folded lines, group
/// prefixes (`item1.TEL`) and quoted-printable (Android, for accents).
List<ContactCard> parseVCards(String text) {
  final cards = <ContactCard>[];
  List<String>? lines;
  for (final line in _unfold(text)) {
    final upper = line.trim().toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      lines = [];
    } else if (upper == 'END:VCARD') {
      final card = lines == null ? null : _parseCard(lines);
      if (card != null && !card.isEmpty) cards.add(card);
      lines = null;
    } else {
      lines?.add(line);
    }
  }
  return cards;
}

/// Joins the lines continued with a leading space or tab (RFC 6350) and the
/// quoted-printable soft breaks (a line ending in "=").
List<String> _unfold(String text) {
  final result = <String>[];
  for (final line in const LineSplitter().convert(text)) {
    if (result.isEmpty) {
      result.add(line);
    } else if (line.startsWith(' ') || line.startsWith('\t')) {
      result.last += line.substring(1);
    } else if (_isQuotedPrintable(result.last) && result.last.endsWith('=')) {
      result.last = result.last.substring(0, result.last.length - 1) + line;
    } else {
      result.add(line);
    }
  }
  return result;
}

bool _isQuotedPrintable(String line) {
  final colon = line.indexOf(':');
  return colon > 0 &&
      line.substring(0, colon).toUpperCase().contains('QUOTED-PRINTABLE');
}

ContactCard? _parseCard(List<String> lines) {
  String? formatted;
  String? structured;
  String? organization;
  String? email;
  final phones = <String>[];
  final seenPhones = <String>{};

  for (final line in lines) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final params = line.substring(0, colon).split(';');
    // "item1.TEL" -> "TEL".
    final key = params.first.split('.').last.toUpperCase();
    final raw = line.substring(colon + 1);
    final value = _isQuotedPrintable(line) ? _decodeQuotedPrintable(raw) : raw;
    switch (key) {
      case 'FN':
        formatted = _unescape(value).trim();
      case 'N':
        structured = _nameFromParts(value);
      case 'ORG':
        organization = _unescape(value.split(';').first).trim();
      case 'TEL':
        final phone = _unescape(value).replaceFirst(RegExp('^tel:'), '').trim();
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty && seenPhones.add(digits)) phones.add(phone);
      case 'EMAIL':
        final address = _unescape(value).trim();
        if (address.isNotEmpty) email ??= address;
    }
  }

  final name = [formatted, structured, organization]
      .firstWhere((n) => (n ?? '').isNotEmpty, orElse: () => null);
  return ContactCard(name: name, phones: phones, email: email);
}

/// "Silva;Maria;Clara;;" (family;given;middle;prefix;suffix) -> "Maria Clara
/// Silva".
String _nameFromParts(String value) {
  final parts = value.split(';').map((p) => _unescape(p).trim()).toList();
  String at(int i) => i < parts.length ? parts[i] : '';
  return [at(3), at(1), at(2), at(0), at(4)]
      .where((p) => p.isNotEmpty)
      .join(' ');
}

String _unescape(String value) => value.replaceAllMapped(
      RegExp(r'\\(.)'),
      (m) => m[1]!.toLowerCase() == 'n' ? ' ' : m[1]!,
    );

String _decodeQuotedPrintable(String value) {
  final bytes = <int>[];
  final input = utf8.encode(value);
  for (var i = 0; i < input.length; i++) {
    final hex = input[i] == 0x3D && i + 2 < input.length
        ? int.tryParse(String.fromCharCodes(input, i + 1, i + 3), radix: 16)
        : null;
    if (hex == null) {
      bytes.add(input[i]);
    } else {
      bytes.add(hex);
      i += 2;
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}
