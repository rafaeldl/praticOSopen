// First access: Ramo → [Especialidades] → Para o cliente → Início, the same
// rules as lib/services/onboarding_service.dart (OnboardingSegment,
// OnboardingBusiness, applyBusiness). Pure, tested in tests/onboarding.test.ts.

export interface OnboardingSubspecialty {
  id: string
  names: Record<string, string>
  icon: string | null
}

export interface OnboardingSegment {
  id: string
  name: string
  nameI18n: Record<string, string>
  icon: string | null
  subspecialties: OnboardingSubspecialty[]
  /** Segment defaults applied to the new company (`fieldService`, `useFinancial`). */
  fieldServiceDefault: boolean
  useFinancialDefault: boolean
  termsOfServiceI18n: Record<string, string>
}

function stringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object') return {}
  return Object.fromEntries(Object.entries(value as Record<string, unknown>).filter((entry): entry is [string, string] => typeof entry[1] === 'string'))
}

/** OnboardingSegment.fromMap. */
export function toSegment(id: string, data: Record<string, unknown>): OnboardingSegment {
  const subs = Array.isArray(data.subspecialties) ? data.subspecialties : []
  return {
    id,
    name: typeof data.name === 'string' ? data.name : id,
    nameI18n: stringMap(data.nameI18n),
    icon: typeof data.icon === 'string' ? data.icon : null,
    subspecialties: subs
      .filter((sub): sub is Record<string, unknown> => !!sub && typeof sub === 'object' && typeof (sub as { id?: unknown }).id === 'string')
      .map((sub) => ({
        id: sub.id as string,
        // A map of names (seed_segments.js); a plain name is pt-BR, with nameI18n when there is one.
        names: typeof sub.name === 'string' ? { 'pt-BR': sub.name, ...stringMap(sub.nameI18n) } : stringMap(sub.name),
        icon: typeof sub.icon === 'string' ? sub.icon : null,
      })),
    fieldServiceDefault: typeof data.fieldService === 'boolean' ? data.fieldService : true,
    useFinancialDefault: typeof data.useFinancial === 'boolean' ? data.useFinancial : true,
    termsOfServiceI18n: stringMap(data.defaultTermsOfService),
  }
}

/** Only `active == true`, ordered by name (firestoreOnboardingSegments). */
export function activeSegments(docs: { id: string; data: Record<string, unknown> }[]): OnboardingSegment[] {
  return docs
    .filter((doc) => doc.data.active === true)
    .map((doc) => toSegment(doc.id, doc.data))
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0))
}

/** Locale tag of segments and samples: pt-BR, es-ES, the rest en-US (localeTagFor). */
export function localeTag(language: string): 'pt-BR' | 'en-US' | 'es-ES' {
  const code = language.toLowerCase().split(/[-_]/)[0]
  return code === 'pt' ? 'pt-BR' : code === 'es' ? 'es-ES' : 'en-US'
}

/** `_pick`: full tag, then the language, then en-US. */
export function pickName(values: Record<string, string>, tag: string): string | null {
  if (!Object.keys(values).length) return null
  if (values[tag]) return values[tag] as string
  const language = tag.split('-')[0] as string
  const match = Object.entries(values).find(([key]) => key.startsWith(language))
  return match ? match[1] : (values['en-US'] ?? null)
}

export const segmentName = (segment: OnboardingSegment, tag: string) => pickName(segment.nameI18n, tag) ?? segment.name
export const subspecialtyName = (sub: OnboardingSubspecialty, tag: string) =>
  pickName(sub.names, tag) ?? Object.values(sub.names)[0] ?? sub.id

/** Default terms of service of the segment in the language, else pt-BR. */
export const termsFor = (segment: OnboardingSegment, tag: string) => segment.termsOfServiceI18n[tag] ?? segment.termsOfServiceI18n['pt-BR'] ?? null

/**
 * Country written on the new company. The app does not write it (defect D8);
 * the web takes the browser's region, else the one of the language.
 */
export function countryFor(languages: readonly string[], language: string): string {
  for (const tag of languages) {
    const region = tag.split(/[-_]/)[1]
    if (region && /^[a-z]{2}$/i.test(region)) return region.toUpperCase()
  }
  return language === 'en' ? 'US' : language === 'es' ? 'ES' : 'BR'
}

export interface BusinessInput {
  segment: OnboardingSegment
  /** Picked specialties, in the segment's order. Empty means none picked. */
  subspecialties: string[]
  name: string
  phone: string
  useFinancial: boolean
}

/** The name on the order: what was typed, else the person's own name (ownerName). */
export function businessName(typed: string, ownerName: string | null | undefined): string {
  return typed.trim() || ownerName?.trim() || ''
}

/** Blank name is only an error when the account has no name to fall back to. */
export const nameMissing = (typed: string, ownerName: string | null | undefined) => !businessName(typed, ownerName)

/**
 * Fields the first access writes on the company (applyBusiness): scheduling
 * on, field service from the segment, no specialty is null, a blank phone
 * keeps the one already there (on a retry).
 */
export function businessFields(input: BusinessInput, ownerName: string | null | undefined): Record<string, unknown> {
  const phone = input.phone.trim()
  return {
    name: businessName(input.name, ownerName),
    ...(phone ? { phone } : {}),
    segment: input.segment.id,
    subspecialties: input.subspecialties.length ? [...input.subspecialties] : null,
    fieldService: input.segment.fieldServiceDefault,
    useScheduling: true,
    useFinancial: input.useFinancial,
  }
}

/**
 * auth.gate.resume-company: a company that exists without a segment (a first
 * access stopped in the app, or an old one) opens the first access with its
 * name and phone and completes the same company. Only who may change the
 * company (owner, admin): the app sends any member there and the save is
 * refused by the rules (not copied).
 */
export function resumesCompany(state: { companyId: string | null; company: { segment?: unknown } | null; role: string | null }): boolean {
  const segment = state.company?.segment
  return !!state.companyId && !!state.company && !(typeof segment === 'string' && segment.trim()) && (state.role === 'owner' || state.role === 'admin')
}

/** Specialties picked, kept in the segment's order. */
export function orderedPick(segment: OnboardingSegment, picked: ReadonlySet<string>): string[] {
  return segment.subspecialties.filter((sub) => picked.has(sub.id)).map((sub) => sub.id)
}
