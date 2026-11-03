// First access over Firebase. The company is created with the same batch as
// the app (UserStore.createCompanyForUser → AuthService.signup): users/{uid},
// companies/{id} and companies/{id}/memberships/{uid}, under the same rules
// (`createsOwnCompanyInBatch`). The segment's checklists and samples come from
// the server (POST /v1/app/onboarding/seed), the server's BootstrapService.
import { firestoreLite } from '../firebase'
import { waitForCompanyClaim } from '../invites'
import { api, refreshClaims, selectCompany, session } from '../session'
import { activeSegments, businessFields, termsFor, type BusinessInput, type OnboardingSegment } from './model'

const lite = () => Promise.all([firestoreLite(), import('firebase/firestore/lite')])

export async function listSegments(): Promise<OnboardingSegment[]> {
  const [db, { collection, getDocs, query, where }] = await lite()
  const snapshot = await getDocs(query(collection(db, 'segments'), where('active', '==', true)))
  return activeSegments(snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() })))
}

/** Phone masks of the company (`segments/global`, `company.phone`) for the country. */
export async function companyPhoneMasks(country: string): Promise<string[]> {
  const [db, { doc, getDoc }] = await lite()
  const snapshot = await getDoc(doc(db, 'segments', 'global'))
  const fields = (snapshot.data()?.customFields ?? []) as { key?: string; masksByCountry?: Record<string, string[]> }[]
  return fields.find((field) => field.key === 'company.phone')?.masksByCountry?.[country] ?? []
}

export interface CreateCompanyInput {
  business: BusinessInput
  /** The person's own name (blank business name falls back to it). */
  ownerName: string | null
  country: string
  localeTag: string
  /** Company saved by an attempt that failed later: completed, never created twice. */
  savedId: string | null
}

/** Creates the company (or completes the saved one) and returns its id. */
export async function saveCompany(input: CreateCompanyInput): Promise<string> {
  const uid = session.uid
  if (!uid) throw new Error('No signed-in user')
  const [db, { arrayUnion, collection, doc, getDoc, serverTimestamp, updateDoc, writeBatch }] = await lite()
  const userRef = doc(db, 'users', uid)
  const user = (await getDoc(userRef)).data() as { name?: string; email?: string } | undefined
  const userAggr = { id: uid, name: user?.name ?? session.name ?? null, email: user?.email ?? session.email ?? null }
  const now = new Date().toISOString()
  const fields = businessFields(input.business, input.ownerName)

  if (input.savedId) {
    await updateDoc(doc(db, 'companies', input.savedId), { ...fields, updatedAt: now, updatedBy: userAggr })
    return input.savedId
  }

  const companyRef = doc(collection(db, 'companies'))
  const id = companyRef.id
  const batch = writeBatch(db)
  // A web-only account may have no users/{uid} yet (the app creates it at sign-in).
  batch.set(
    userRef,
    {
      ...(user ? {} : { id: uid, name: userAggr.name, email: userAggr.email, createdAt: now, createdBy: userAggr }),
      updatedAt: now,
      updatedBy: userAggr,
      companies: arrayUnion({ company: { id, name: fields.name, country: input.country }, role: 'admin' }),
    },
    { merge: true },
  )
  batch.set(companyRef, {
    id,
    ...fields,
    country: input.country,
    termsOfService: termsFor(input.business.segment, input.localeTag),
    owner: userAggr,
    createdAt: now,
    createdBy: userAggr,
    updatedAt: now,
    updatedBy: userAggr,
  })
  batch.set(doc(db, 'companies', id, 'memberships', uid), { user: userAggr, role: 'admin', joinedAt: serverTimestamp() })
  await batch.commit()
  return id
}

export class ClaimTimeout extends Error {}

/**
 * The claim comes from a trigger on users/{uid}. Sample writes need it, so a
 * timeout is an error with "Tentar de novo" (the app goes on and fails: D9).
 */
export async function waitForClaim(companyId: string): Promise<void> {
  if (!(await waitForCompanyClaim(companyId, 20000, 500))) throw new ClaimTimeout()
}

export async function seedCompany(companyId: string, withSamples: boolean, localeTag: string): Promise<void> {
  await api('/v1/app/onboarding/seed', { method: 'POST', companyId, body: { withSamples, locale: localeTag } })
}

/** Into the new company: the session reads the token again and opens it. */
export async function enterCompany(companyId: string): Promise<void> {
  await refreshClaims()
  await selectCompany(companyId)
}
