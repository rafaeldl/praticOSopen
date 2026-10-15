/**
 * Finds the registered customer or vehicle the user meant, without AI.
 *
 * Voice and photos get names a little wrong ("Juliene" for Juliana, "GM Corsa"
 * for a Chevrolet Corsa, "ABC1C34" for ABC-1234), and Firestore only finds
 * exact words. These pure functions compare in memory: spelling distance
 * (Jaro-Winkler), Portuguese sound-alikes (Luis/Luiz, Thiago/Tiago), brand
 * nicknames and the Mercosul plate. The rule is the same for both:
 *
 * - **match**: one sure answer (same phone, same plate, same name, or a
 *   single very close name) is used right away;
 * - **alternatives**: close but not sure — the app asks "Qual Juliana?";
 * - nothing close: the app offers to register a new one.
 */
import { removeAccents } from '../../utils/search.utils';

/** At or above: the same name (sound-alike or one letter apart in a long name). */
export const SURE_SCORE = 0.97;
/** At or above: close enough to ask the user. */
export const CLOSE_SCORE = 0.8;
const MAX_ALTERNATIVES = 4;

const STOPWORDS = new Set(['da', 'de', 'do', 'das', 'dos', 'e']);

function words(text: string | undefined | null): string[] {
  return removeAccents((text ?? '').toLowerCase())
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((w) => w && !STOPWORDS.has(w));
}

/** Jaro-Winkler similarity, 0..1. Good for short names and typos at the end. */
export function jaroWinkler(a: string, b: string): number {
  if (a === b) return 1;
  if (!a || !b) return 0;
  const window = Math.max(0, Math.floor(Math.max(a.length, b.length) / 2) - 1);
  const aHit = new Array<boolean>(a.length).fill(false);
  const bHit = new Array<boolean>(b.length).fill(false);
  let matches = 0;
  for (let i = 0; i < a.length; i++) {
    for (let j = Math.max(0, i - window); j < Math.min(b.length, i + window + 1); j++) {
      if (bHit[j] || a[i] !== b[j]) continue;
      aHit[i] = bHit[j] = true;
      matches++;
      break;
    }
  }
  if (!matches) return 0;
  let k = 0;
  let transpositions = 0;
  for (let i = 0; i < a.length; i++) {
    if (!aHit[i]) continue;
    while (!bHit[k]) k++;
    if (a[i] !== b[k]) transpositions++;
    k++;
  }
  const jaro = (matches / a.length + matches / b.length + (matches - transpositions / 2) / matches) / 3;
  let prefix = 0;
  while (prefix < Math.min(4, a.length, b.length) && a[prefix] === b[prefix]) prefix++;
  return jaro + prefix * 0.1 * (1 - jaro);
}

/**
 * How a word sounds in Brazilian Portuguese, so spellings of the same name
 * meet: Luis/Luiz, Thiago/Tiago, Rafael/Raphael, Sousa/Souza, Wagner/Vagner,
 * Kelly/Keli, Gisele/Jisele.
 */
export function soundKey(word: string): string {
  let w = removeAccents(word.toLowerCase()).replace(/[^a-z]/g, '');
  w = w
    .replace(/ph/g, 'f')
    .replace(/th/g, 't')
    .replace(/sh|ch/g, 'x')
    .replace(/lh/g, 'li')
    .replace(/nh/g, 'ni')
    .replace(/qu(?=[ei])/g, 'k')
    .replace(/gu(?=[ei])/g, 'g')
    .replace(/q/g, 'k')
    .replace(/c(?=[ei])/g, 's')
    .replace(/c/g, 'k')
    .replace(/g(?=[ei])/g, 'j')
    .replace(/[zç]/g, 's')
    .replace(/y/g, 'i')
    .replace(/w/g, 'v')
    .replace(/h/g, '')
    .replace(/m(?=[^aeiou]|$)/g, 'n')
    .replace(/(.)\1+/g, '$1');
  return w;
}

function wordScore(spoken: string, registered: string): number {
  if (spoken === registered) return 1;
  // Numbers (years, versions) must be equal.
  if (/\d/.test(spoken) || /\d/.test(registered)) return 0;
  if (spoken.length > 2 && soundKey(spoken) === soundKey(registered)) return SURE_SCORE;
  return jaroWinkler(spoken, registered);
}

/**
 * How well the spoken name fits a registered one, 0..1: each spoken word
 * takes its best registered word, then the average. "Juliana" fits
 * "Juliana Souza" fully; "Juliene" fits Juliana at ~0.89.
 */
export function nameScore(spoken: string, registered: string): number {
  const said = words(spoken);
  const has = words(registered);
  if (!said.length || !has.length) return 0;
  const total = said.reduce((sum, w) => sum + Math.max(...has.map((r) => wordScore(w, r))), 0);
  return total / said.length;
}

export interface Ranked<T> {
  match: T | null;
  alternatives: T[];
}

/**
 * Sure match or close alternatives from scored entries. The best entry is
 * sure when it reaches [SURE_SCORE] and no other one does ("Julio" → Júlio,
 * with Juliana only listed); two equally sure ones are not (the app asks).
 */
function rank<T>(scored: { entry: T; score: number }[]): Ranked<T> {
  const close = scored.filter((s) => s.score >= CLOSE_SCORE).sort((a, b) => b.score - a.score);
  const [best, second] = close;
  const sure = best && best.score >= SURE_SCORE && !(second && second.score >= SURE_SCORE) ? best.entry : null;
  return {
    match: sure,
    alternatives: close
      .filter((s) => s.entry !== sure)
      .slice(0, MAX_ALTERNATIVES)
      .map((s) => s.entry),
  };
}

// ============================================================================
// Customers
// ============================================================================

export interface CustomerEntry {
  id: string;
  name: string;
  phone?: string;
}

/** Last 8 digits: the same number with or without area code, 9 or country code. */
export function phoneKey(phone: string | undefined | null): string | null {
  const digits = (phone ?? '').replace(/\D/g, '');
  return digits.length >= 8 ? digits.slice(-8) : null;
}

/**
 * Registered customer for a spoken name and/or phone. The phone wins: one
 * customer with that number is the match, whatever the name. Then the exact
 * name, then the closest names.
 */
export function matchCustomer<T extends CustomerEntry>(
  guess: { name?: string; phone?: string },
  customers: T[],
): Ranked<T> {
  const key = phoneKey(guess.phone);
  if (key) {
    const byPhone = customers.filter((c) => phoneKey(c.phone) === key);
    if (byPhone.length === 1) return { match: byPhone[0], alternatives: [] };
    if (byPhone.length > 1) return { match: null, alternatives: byPhone.slice(0, MAX_ALTERNATIVES) };
  }
  if (!guess.name) return { match: null, alternatives: [] };
  const target = words(guess.name).join(' ');
  const scored = customers.map((entry) => ({ entry, score: nameScore(guess.name!, entry.name) }));
  // The exact full name wins over others that also start with it.
  const exact = customers.filter((c) => words(c.name).join(' ') === target);
  if (exact.length === 1) {
    const rest = rank(scored.filter((s) => s.entry !== exact[0]));
    return { match: exact[0], alternatives: [...(rest.match ? [rest.match] : []), ...rest.alternatives].slice(0, MAX_ALTERNATIVES) };
  }
  return rank(scored);
}

// ============================================================================
// Vehicles and devices
// ============================================================================

/** Brand nicknames → one name. Only brands people shorten or spell many ways. */
const BRAND_ALIASES: Record<string, string> = {
  gm: 'chevrolet',
  chevrolet: 'chevrolet',
  chevy: 'chevrolet',
  vw: 'volkswagen',
  volks: 'volkswagen',
  volkswagen: 'volkswagen',
  wolks: 'volkswagen',
  mercedes: 'mercedes',
  benz: 'mercedes',
  mb: 'mercedes',
  fiat: 'fiat',
  ford: 'ford',
  toyota: 'toyota',
  honda: 'honda',
  hyundai: 'hyundai',
  hiunday: 'hyundai',
  hyunday: 'hyundai',
  renault: 'renault',
  nissan: 'nissan',
  peugeot: 'peugeot',
  citroen: 'citroen',
  jeep: 'jeep',
  mitsubishi: 'mitsubishi',
  kia: 'kia',
  bmw: 'bmw',
  audi: 'audi',
  chery: 'chery',
  caoa: 'chery',
  yamaha: 'yamaha',
  suzuki: 'suzuki',
  samsung: 'samsung',
  apple: 'apple',
  iphone: 'apple',
  motorola: 'motorola',
  moto: 'motorola',
  xiaomi: 'xiaomi',
  redmi: 'xiaomi',
  lg: 'lg',
  brastemp: 'brastemp',
  consul: 'consul',
  electrolux: 'electrolux',
};

/** Words that never tell one model from another. */
const DEVICE_NOISE = new Set(['carro', 'moto', 'veiculo', 'celular', 'aparelho']);

/** Brand (by nickname) and the model words, without brand and years. */
export function splitDevice(name?: string, manufacturer?: string): { brand: string | null; model: string[] } {
  let brand: string | null = null;
  for (const w of words(manufacturer)) brand ??= BRAND_ALIASES[w] ?? null;
  const model: string[] = [];
  for (const w of words(name)) {
    const alias = BRAND_ALIASES[w];
    // "iPhone 12" keeps "iphone" as model too; other brand words are dropped.
    if (alias) {
      brand ??= alias;
      if (w !== 'iphone') continue;
    }
    if (/^(19|20)\d\d$/.test(w) || DEVICE_NOISE.has(w)) continue;
    model.push(w);
  }
  if (!brand && manufacturer) brand = words(manufacturer)[0] ?? null;
  return { brand, model };
}

/**
 * "GM Corsa" against a registered "Corsa" from Chevrolet: same brand, same
 * model. Both ways, so "Corsa" fits "Corsa" better than "Corsa Classic"
 * (a person is called by the first name; a model is not).
 */
export function deviceScore(
  guess: { name?: string; manufacturer?: string },
  device: { name: string; manufacturer?: string },
): number {
  const said = splitDevice(guess.name, guess.manufacturer);
  const has = splitDevice(device.name, device.manufacturer);
  if (said.brand && has.brand && said.brand !== has.brand) return 0;
  if (!said.model.length || !has.model.length) return 0;
  const a = said.model.join(' ');
  const b = has.model.join(' ');
  return (nameScore(a, b) + nameScore(b, a)) / 2;
}

const LETTER_FOR_DIGIT: Record<string, string> = { '0': 'O', '1': 'I', '2': 'Z', '4': 'A', '5': 'S', '6': 'G', '8': 'B' };
const DIGIT_FOR_LETTER: Record<string, string> = { O: '0', Q: '0', D: '0', I: '1', L: '1', Z: '2', S: '5', G: '6', B: '8' };

/**
 * One key for the same Brazilian plate however it was read or registered:
 * ABC-1234, abc 1234, Mercosul ABC1C34 (C = 2), and photo slips like 0/O in
 * the letter part or B/8 in the number part. Not a plate → just the letters
 * and digits (serial numbers).
 */
export function plateKey(serial: string | undefined | null): string | null {
  const raw = (serial ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (!raw) return null;
  if (raw.length !== 7) return raw;
  const chars = raw.split('');
  for (const i of [0, 1, 2]) chars[i] = LETTER_FOR_DIGIT[chars[i]] ?? chars[i];
  for (const i of [3, 5, 6]) chars[i] = DIGIT_FOR_LETTER[chars[i]] ?? chars[i];
  // Mercosul: the 5th character is a letter A..J for the digit 0..9.
  if (/[A-J]/.test(chars[4])) chars[4] = String(chars[4].charCodeAt(0) - 65);
  else chars[4] = DIGIT_FOR_LETTER[chars[4]] ?? chars[4];
  const key = chars.join('');
  return /^[A-Z]{3}\d{4}$/.test(key) ? key : raw;
}

/** Ways a plate may be stored, to look it up when the fleet is too big to load. */
export function plateLookups(serial: string): string[] {
  const key = plateKey(serial);
  const out = new Set([serial.trim(), serial.trim().toUpperCase()]);
  if (key) {
    out.add(key);
    if (/^[A-Z]{3}\d{4}$/.test(key)) {
      out.add(`${key.slice(0, 3)}-${key.slice(3)}`);
      out.add(`${key.slice(0, 4)}${String.fromCharCode(65 + Number(key[4]))}${key.slice(5)}`);
    }
  }
  return [...out].filter(Boolean);
}

export interface DeviceEntry {
  id: string;
  name: string;
  serial?: string;
  manufacturer?: string;
}

/**
 * Registered vehicle for a spoken/read plate and name. The plate wins; a
 * plate that is not registered never picks a vehicle by name (it is a new
 * one), it only lists the close names. Without a plate: the closest name.
 */
export function matchDevice<T extends DeviceEntry>(
  guess: { name?: string; serial?: string; manufacturer?: string },
  devices: T[],
): Ranked<T> {
  const key = plateKey(guess.serial);
  if (key) {
    const byPlate = devices.filter((d) => plateKey(d.serial) === key);
    if (byPlate.length === 1) return { match: byPlate[0], alternatives: [] };
    if (byPlate.length > 1) return { match: null, alternatives: byPlate.slice(0, MAX_ALTERNATIVES) };
  }
  if (!guess.name) return { match: null, alternatives: [] };
  const ranked = rank(devices.map((entry) => ({ entry, score: deviceScore(guess, entry) })));
  if (!key || !ranked.match) return ranked;
  return { match: null, alternatives: [ranked.match, ...ranked.alternatives].slice(0, MAX_ALTERNATIVES) };
}
