// users/{uid} on the first sign-in and the account's language, as the app
// (UserStore.createUserIfNotExist, LocaleStore): auth.session.user-bootstrap
// and reminders.language.
import { firestoreLite } from './firebase'
import { prefs, type LanguagePref } from './prefs'
import { readStorage, writeStorage } from './storage'

/** Set once the person picks a language here or the account's one was applied. */
const CHOSEN_KEY = 'praticos.languageChosen'

/** The account's preferredLanguage (any BCP 47 tag) to one of the three languages, as LocaleStore. */
export function languageOf(tag: string | null | undefined): Exclude<LanguagePref, 'system'> | null {
  if (!tag) return null
  const language = tag.split(/[-_]/)[0]?.toLowerCase()
  if (language === 'pt') return 'pt'
  if (language === 'es') return 'es'
  return 'en'
}

/** What the web writes back, the app's codes. */
export function preferredLanguageTag(language: LanguagePref): string | null {
  return language === 'pt' ? 'pt-BR' : language === 'en' ? 'en-US' : language === 'es' ? 'es-ES' : null
}

/**
 * The account's language wins only while nobody picked one in this browser
 * (the app: "only override if the user hasn't manually set a locale").
 */
export function applyAccountLanguage(tag: string | null | undefined): void {
  const language = languageOf(tag)
  if (!language || readStorage(CHOSEN_KEY) || prefs.language !== 'system') return
  prefs.language = language
  writeStorage(CHOSEN_KEY, '1')
}

/** The person picked a language: kept here and on the account, without waiting (an error only goes to the log). */
export function chooseLanguage(uid: string | null, language: LanguagePref): void {
  writeStorage(CHOSEN_KEY, '1')
  const tag = preferredLanguageTag(language)
  if (!uid || !tag) return
  void (async () => {
    const [db, { doc, updateDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
    await updateDoc(doc(db, 'users', uid), { preferredLanguage: tag })
  })().catch((error) => console.warn('profile: language not saved on the account', error))
}

export interface NewUser {
  uid: string
  name: string | null
  email: string | null
}

/** The document the app creates at the first sign-in: no company, the browser's language. */
export function newUserDoc(user: NewUser, browserLanguage: string, now: string): Record<string, unknown> {
  const aggr = { id: user.uid, name: user.name }
  return {
    id: user.uid,
    name: user.name,
    email: user.email,
    companies: [],
    preferredLanguage: browserLanguage || null,
    createdAt: now,
    createdBy: aggr,
    updatedAt: now,
    updatedBy: aggr,
  }
}

/**
 * Creates users/{uid} when it does not exist yet, inside a transaction: an
 * invite accepted at the same moment (which writes `companies`) is never undone.
 */
export async function ensureUserDoc(user: NewUser): Promise<void> {
  const [db, { doc, runTransaction }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const ref = doc(db, 'users', user.uid)
  await runTransaction(db, async (tx) => {
    if ((await tx.get(ref)).exists()) return
    tx.set(ref, newUserDoc(user, navigator.language, new Date().toISOString()))
  })
}
