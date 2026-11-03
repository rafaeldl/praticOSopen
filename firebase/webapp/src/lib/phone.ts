// Phone rules of the app (lib/utils/customer_utils.dart whatsappNumber and
// phoneMatchKey, lib/utils/phone_format.dart formatPhone), checked by the
// contract cases in docs/web-app/contract-cases/phone.json.
//
// The app uses a full phone library; here only what the cases fix: Brazil in
// full (DDD 55, old 8-digit mobiles), North America and the country code of
// the other countries the segments know. Anything else keeps the digits.

/** Country calling codes of the company countries (company.country). */
const CALLING: Record<string, string> = {
  BR: '55', US: '1', CA: '1', PT: '351', ES: '34', MX: '52', AR: '54', CL: '56', CO: '57', PE: '51',
  UY: '598', PY: '595', BO: '591', EC: '593', VE: '58', GB: '44', FR: '33', DE: '49', IT: '39',
}
/** National lengths taken as valid when the number has no "+". */
const NATIONAL: Record<string, number[]> = { PT: [9], ES: [9], MX: [10], AR: [10], CL: [9], CO: [10], PE: [9], UY: [8], PY: [9], GB: [10], FR: [9], DE: [10, 11], IT: [9, 10] }

const countryOf = (country: string | null | undefined) => {
  const code = (country ?? 'BR').toUpperCase()
  return CALLING[code] ? code : 'BR'
}

/** The wa.me number: with "+" keeps its country; without, the company's (Brazil by default). */
export function whatsappNumber(phone: string | null | undefined, country?: string | null): string {
  const raw = phone ?? ''
  const digits = raw.replace(/\D/g, '')
  if (!digits) return ''
  if (raw.replace(/[^\d+]/g, '').startsWith('+')) return digits
  const code = countryOf(country)
  const national = digits.replace(/^0+/, '')
  if (code === 'BR') return national.length === 10 || national.length === 11 ? `55${national}` : digits
  if (code === 'US' || code === 'CA') {
    if (digits.length === 10) return `1${digits}`
    return digits
  }
  return (NATIONAL[code] ?? []).includes(national.length) ? `${CALLING[code]}${national}` : digits
}

/** Key to compare two phones: the wa.me number and, in Brazil, without the ninth digit. */
export function phoneMatchKey(phone: string | null | undefined, country?: string | null): string {
  const number = whatsappNumber(phone, country)
  if (number.length === 13 && number.startsWith('55') && number[4] === '9') return number.slice(0, 4) + number.slice(5)
  return number
}

/** Valid Brazilian national number: landline (2-5 after the DDD) or mobile (9). */
function brazilianNational(number: string): string | null {
  if (!number.startsWith('55')) return null
  const nsn = number.slice(2)
  if (nsn.length === 10 && /^[1-9]{2}[2-5]/.test(nsn)) return nsn
  if (nsn.length === 11 && /^[1-9]{2}9/.test(nsn)) return nsn
  return null
}

/**
 * Phone as people read it: "+5548984087801" → "(48) 98408-7801". A number of
 * another country, or that is not a valid phone, keeps the text as saved.
 */
export function formatPhone(phone: string | null | undefined, country?: string | null): string {
  const text = (phone ?? '').trim()
  if (!text) return ''
  if (countryOf(country) !== 'BR' && !text.startsWith('+55')) return text
  const nsn = brazilianNational(whatsappNumber(text, country))
  if (!nsn) return text
  const cut = nsn.length - 4
  return `(${nsn.slice(0, 2)}) ${nsn.slice(2, cut)}-${nsn.slice(cut)}`
}

/** For a tel: link: digits and "+" only (customer.detail.call). */
export function dialable(phone: string | null | undefined): string {
  return (phone ?? '').replace(/[^\d+]/g, '')
}
