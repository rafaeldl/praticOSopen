// Utility functions for search functionality
//
// Provides consistent keyword generation for full-text search
// using Firestore's array-contains queries.

/// Removes accents from a string by normalizing unicode characters.
///
/// Example:
/// ```dart
/// removeAccents("João") // Returns "joao"
/// removeAccents("Açúcar") // Returns "acucar"
/// ```
String removeAccents(String text) {
  const accents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ';
  const withoutAccents = 'aaaaaaaceeeeiiiidnoooooouuuuyy';

  String result = text.toLowerCase();
  for (int i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], withoutAccents[i]);
  }
  return result;
}

/// Generates a list of keywords from a name string for search indexing.
///
/// - Removes accents (João → joao)
/// - Removes special characters (keeps only letters and numbers)
/// - Splits by whitespace
/// - Filters empty strings
///
/// Example:
/// ```dart
/// generateKeywords("João Da Silva&*-") // Returns ["joao", "da", "silva"]
/// generateKeywords("Maria José") // Returns ["maria", "jose"]
/// generateKeywords(null) // Returns []
/// ```
List<String> generateKeywords(String? name) {
  if (name == null || name.isEmpty) return [];

  // Remove accents
  String normalized = removeAccents(name);

  // Remove special characters (keep only alphanumeric and spaces)
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), '');

  // Split by whitespace and filter empty strings
  return normalized
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}

/// Portuguese stopwords left out of search keywords (same list as the
/// server's search.utils.ts).
const _stopwords = {
  'de', 'da', 'do', 'das', 'dos',
  'e', 'ou', 'em', 'no', 'na', 'nos', 'nas',
  'um', 'uma', 'uns', 'umas',
  'o', 'a', 'os', 'as',
  'para', 'por', 'com', 'sem',
};

/// Words without stopwords plus the full phrase (same as the server's
/// generateSearchKeywords).
///
/// ```dart
/// generateSearchKeywords("João da Silva") // ["joao", "silva", "joao silva"]
/// ```
List<String> generateSearchKeywords(String? text) {
  final all = generateKeywords(text);
  if (all.isEmpty) return [];
  final meaningful = all.where((w) => !_stopwords.contains(w)).toList();
  if (meaningful.isEmpty) return all;
  return [...meaningful, if (meaningful.length > 1) meaningful.join(' ')];
}

/// Last 4 digits, last 8 digits and the full number (same as the server's
/// generatePhoneKeywords).
///
/// ```dart
/// generatePhoneKeywords("(48) 99988-7766") // ["7766", "99887766", "48999887766"]
/// ```
List<String> generatePhoneKeywords(String? phone) {
  if (phone == null) return [];
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return [];
  return [
    digits.substring(digits.length - 4),
    if (digits.length >= 8) digits.substring(digits.length - 8),
    digits,
  ];
}

/// Customer keywords: name and phone, as the server writes them
/// (customer.service.ts), so the bot and the API find app-made customers
/// by phone too.
List<String> customerKeywords(String? name, String? phone) => [
      ...generateSearchKeywords(name),
      ...generatePhoneKeywords(phone),
    ];

/// Vehicle (device) keywords: name, serial and brand, each with
/// [generateSearchKeywords], as the server writes them (device.service.ts)
/// and the web, so the bot and the API find a vehicle by plate after it is
/// edited in the app.
///
/// ```dart
/// deviceKeywords("Gol", "ABC-1D23", "VW") // ["gol", "abc1d23", "vw"]
/// ```
List<String> deviceKeywords(
  String? name,
  String? serial,
  String? manufacturer,
) => [
  ...generateSearchKeywords(name),
  ...generateSearchKeywords(serial),
  ...generateSearchKeywords(manufacturer),
];
