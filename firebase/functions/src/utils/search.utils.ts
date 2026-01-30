/**
 * Search Utilities
 *
 * Provides consistent keyword generation for full-text search
 * using Firestore's array-contains queries.
 */

/**
 * Removes accents from a string by normalizing unicode characters.
 *
 * @example
 * removeAccents("João") // Returns "joao"
 * removeAccents("Açúcar") // Returns "acucar"
 */
export function removeAccents(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

/**
 * Generates a list of keywords from a name string for search indexing.
 *
 * - Removes accents (João → joao)
 * - Removes special characters (keeps only letters and numbers)
 * - Splits by whitespace
 * - Filters empty strings
 *
 * @example
 * generateKeywords("João Da Silva&*-") // Returns ["joao", "da", "silva"]
 * generateKeywords("Maria José") // Returns ["maria", "jose"]
 * generateKeywords(null) // Returns []
 */
export function generateKeywords(name: string | null | undefined): string[] {
  if (!name) return [];

  // Remove accents and convert to lowercase
  let normalized = removeAccents(name).toLowerCase();

  // Remove special characters (keep only alphanumeric and spaces)
  normalized = normalized.replace(/[^a-z0-9\s]/g, '');

  // Split by whitespace and filter empty strings
  return normalized
    .split(/\s+/)
    .filter((w) => w.length > 0);
}
