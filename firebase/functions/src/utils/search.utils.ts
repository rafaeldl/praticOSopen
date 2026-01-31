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

/**
 * Generate keywords from phone number for search indexing.
 *
 * Includes last 4 digits, last 8 digits (without area code), and full number.
 *
 * @example
 * generatePhoneKeywords("+5548999887766") // Returns ["7766", "99887766", "5548999887766"]
 * generatePhoneKeywords("(48) 99988-7766") // Returns ["7766", "99887766", "48999887766"]
 * generatePhoneKeywords(null) // Returns []
 */
export function generatePhoneKeywords(phone: string | null | undefined): string[] {
  if (!phone) return [];

  // Remove non-digits
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 4) return [];

  const keywords: string[] = [];

  // Last 4 digits (common search pattern)
  keywords.push(digits.slice(-4));

  // Last 8 digits (number without area code in Brazil)
  if (digits.length >= 8) {
    keywords.push(digits.slice(-8));
  }

  // Full number without formatting
  keywords.push(digits);

  return keywords;
}

/**
 * Portuguese stopwords to filter out from search keywords.
 */
const STOPWORDS = new Set([
  'de', 'da', 'do', 'das', 'dos',
  'e', 'ou', 'em', 'no', 'na', 'nos', 'nas',
  'um', 'uma', 'uns', 'umas',
  'o', 'a', 'os', 'as',
  'para', 'por', 'com', 'sem',
]);

/**
 * Generate search keywords (individual words + full phrase, without stopwords).
 *
 * @example
 * generateSearchKeywords("Troca de Óleo")
 * // Returns: ["troca", "oleo", "troca oleo"]
 *
 * generateSearchKeywords("João da Silva")
 * // Returns: ["joao", "silva", "joao silva"]
 */
export function generateSearchKeywords(text: string | null | undefined): string[] {
  if (!text) return [];

  // Get all words normalized (with accents removed, lowercase)
  const allWords = generateKeywords(text);
  if (allWords.length === 0) return [];

  // Filter out stopwords
  const meaningfulWords = allWords.filter((w) => !STOPWORDS.has(w));
  if (meaningfulWords.length === 0) return allWords; // Fallback if all are stopwords

  const keywords: string[] = [...meaningfulWords];

  // Add full phrase (meaningful words joined)
  if (meaningfulWords.length > 1) {
    keywords.push(meaningfulWords.join(' '));
  }

  return keywords;
}

/**
 * Normalize search query (remove stopwords, join words).
 *
 * @example
 * normalizeSearchTerm("Troca de Óleo") // Returns: "troca oleo"
 * normalizeSearchTerm("oleo")          // Returns: "oleo"
 */
export function normalizeSearchTerm(query: string): string {
  const allWords = generateKeywords(query);
  const meaningfulWords = allWords.filter((w) => !STOPWORDS.has(w));
  return (meaningfulWords.length > 0 ? meaningfulWords : allWords).join(' ');
}
