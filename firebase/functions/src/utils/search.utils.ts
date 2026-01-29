/**
 * Search Utilities
 *
 * Provides consistent keyword generation for full-text search
 * using Firestore's array-contains queries.
 */

/**
 * Generates a list of keywords from a name string for search indexing.
 *
 * Splits the name by whitespace, normalizes to lowercase, and filters empty strings.
 * Used for creating searchable keywords that work with array-contains queries.
 *
 * @example
 * generateKeywords("João Silva") // Returns ["joão", "silva"]
 * generateKeywords("Maria") // Returns ["maria"]
 * generateKeywords(null) // Returns []
 */
export function generateKeywords(name: string | null | undefined): string[] {
  if (!name) return [];
  return name
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 0);
}
