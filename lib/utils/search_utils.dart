/// Utility functions for search functionality
///
/// Provides consistent keyword generation for full-text search
/// using Firestore's array-contains queries.

/// Generates a list of keywords from a name string for search indexing.
///
/// Splits the name by whitespace, normalizes to lowercase, and filters empty strings.
/// Used for creating searchable keywords that work with array-contains queries.
///
/// Example:
/// ```dart
/// generateKeywords("João Silva") // Returns ["joão", "silva"]
/// generateKeywords("Maria") // Returns ["maria"]
/// generateKeywords(null) // Returns []
/// ```
List<String> generateKeywords(String? name) {
  if (name == null || name.isEmpty) return [];
  return name
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
