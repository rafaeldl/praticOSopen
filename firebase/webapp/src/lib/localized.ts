// Names stored by locale in `segments/*` (segment, subspecialty). The data comes
// in three shapes: a plain text (pt-BR), a map { "pt-BR": …, "en-US": … } or that
// map saved as a JSON string. Same rule as OnboardingSubspecialty.fromMap in the
// app: `name` gives the base, `nameI18n` adds the other languages and wins.

const FULL: Record<string, string> = { pt: 'pt-BR', en: 'en-US', es: 'es-ES' }

function onlyStrings(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).filter((entry): entry is [string, string] => typeof entry[1] === 'string' && entry[1] !== ''))
}

/** Map by locale from any of the stored shapes; a plain text is pt-BR. */
export function localizedMap(value: unknown): Record<string, string> {
  if (typeof value === 'string') {
    const text = value.trim()
    if (text.startsWith('{')) {
      try {
        const parsed = onlyStrings(JSON.parse(text))
        if (Object.keys(parsed).length) return parsed
      } catch {
        // Not JSON: a name that starts with "{" is still a name.
      }
    }
    return text ? { 'pt-BR': value } : {}
  }
  return onlyStrings(value)
}

/** `name` plus `nameI18n` (which wins), as the app reads them. */
export function localizedNames(name: unknown, nameI18n?: unknown): Record<string, string> {
  return { ...localizedMap(name), ...localizedMap(nameI18n) }
}

/** Exact locale, the full locale of the language, any of the language, pt-BR, then the first one. */
export function pickLocalized(names: Record<string, string>, locale: string): string | null {
  const language = (locale.split(/[-_]/)[0] ?? '').toLowerCase()
  return (
    names[locale] ??
    names[FULL[language] ?? ''] ??
    Object.entries(names).find(([key]) => key.toLowerCase().split(/[-_]/)[0] === language)?.[1] ??
    names['pt-BR'] ??
    Object.values(names)[0] ??
    null
  )
}

/** The text to show: never an object or JSON, falling back to `fallback` (the id). */
export function localizedText(value: unknown, locale: string, fallback = ''): string {
  return pickLocalized(localizedMap(value), locale) ?? fallback
}
