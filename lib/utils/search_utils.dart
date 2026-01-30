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
