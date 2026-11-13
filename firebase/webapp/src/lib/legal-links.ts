// The site's Terms of Use and Privacy Policy, in the language the web is
// showing (firebase/hosting: terms.html, terms-en.html, terms-es.html; same for privacy).
import type { Locale } from '@/i18n'

export type LegalPage = 'terms' | 'privacy'

export function legalUrl(page: LegalPage, lang: Locale): string {
  return lang === 'pt' ? `/${page}.html` : `/${page}-${lang}.html`
}

/** The policy's "Cookies e estatísticas de uso" section (its title, slugified by the site). */
const COOKIES_ANCHOR: Record<Locale, string> = {
  pt: 'cookies-e-estatisticas-de-uso',
  en: 'cookies-and-usage-statistics',
  es: 'cookies-y-estadisticas-de-uso',
}

export function cookiesPolicyUrl(lang: Locale): string {
  return `${legalUrl('privacy', lang)}#${COOKIES_ANCHOR[lang]}`
}
