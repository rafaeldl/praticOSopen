// Initials of the company on the profile button (home.profile.initials), as
// _ProfileButton.initials in lib/screens/menu_navigation/home_content.dart:
// first letters of the first and last words, skipping connectors
// ("Oficina do Zé" → "OZ"). Empty without a name (the button shows a person).
const CONNECTORS = new Set(['da', 'de', 'do', 'das', 'dos', 'e', '&', 'y'])

export function initials(name: string | null | undefined): string {
  const words = (name ?? '')
    .trim()
    .split(/\s+/)
    .filter((word) => word && !CONNECTORS.has(word.toLowerCase()))
  if (!words.length) return ''
  const first = [...(words[0] as string)][0] as string
  if (words.length === 1) return first.toUpperCase()
  return (first + ([...(words[words.length - 1] as string)][0] as string)).toUpperCase()
}
