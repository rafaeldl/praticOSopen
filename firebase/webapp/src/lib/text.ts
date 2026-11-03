const normalize = (text: string) =>
  text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()

/** Every typed word starts some word of the text, ignoring accents and case. */
export function matchesWords(text: string, query: string): boolean {
  const words = normalize(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean)
  return normalize(query)
    .split(/\s+/)
    .filter(Boolean)
    .every((part) => words.some((word) => word.startsWith(part)))
}
