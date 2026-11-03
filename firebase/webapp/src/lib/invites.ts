// Invites the signed-in person received, same flow as the app (InviteStore):
// list by verified e-mail from Firestore, accept through the API, wait for the
// token to carry the new company, reject by updating the invite.
import { firestoreClient } from './firebase'
import { api, refreshClaims, selectCompany, session } from './session'
import { authClient } from './firebase'

export interface Invite {
  token: string
  companyId: string
  companyName: string
  role: string
  invitedBy?: string
  expiresAt?: string
}

interface InviteDoc {
  company?: { id?: string; name?: string }
  role?: string
  invitedBy?: { name?: string }
  expiresAt?: unknown
}

function expiryOf(value: unknown): Date | null {
  if (!value) return null
  if (typeof value === 'string') return new Date(value)
  const timestamp = value as { toDate?: () => Date }
  return typeof timestamp.toDate === 'function' ? timestamp.toDate() : null
}

export function toInvite(token: string, data: InviteDoc, now = new Date()): Invite | null {
  const companyId = data.company?.id
  if (!companyId) return null
  const expires = expiryOf(data.expiresAt)
  if (expires && expires < now) return null
  return {
    token,
    companyId,
    companyName: data.company?.name ?? '',
    role: data.role ?? '',
    invitedBy: data.invitedBy?.name,
    expiresAt: expires?.toISOString(),
  }
}

export async function listPendingInvites(): Promise<Invite[]> {
  const email = session.email?.trim().toLowerCase()
  if (!email) return []
  const [db, { collection, getDocs, query, where }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  const snapshot = await getDocs(
    query(collection(db, 'links', 'invites', 'tokens'), where('email', '==', email), where('status', '==', 'pending')),
  )
  return snapshot.docs
    .map((doc) => toInvite(doc.id, doc.data() as InviteDoc))
    .filter((invite): invite is Invite => !!invite)
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

/** The claim is written by a trigger after the API answers: poll the token for it. */
async function waitForCompanyClaim(companyId: string, timeoutMs = 20000): Promise<boolean> {
  const auth = await authClient()
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    const token = await auth.currentUser?.getIdTokenResult(true)
    const roles = (token?.claims.roles ?? {}) as Record<string, string>
    if (roles[companyId]) return true
    await sleep(1000)
  }
  return false
}

export async function acceptInvite(invite: Invite): Promise<void> {
  await api(`/v1/app/invites/${encodeURIComponent(invite.token)}/accept`, { method: 'POST' })
  await waitForCompanyClaim(invite.companyId)
  await refreshClaims()
  await selectCompany(invite.companyId)
}

export async function rejectInvite(invite: Invite): Promise<void> {
  const [db, { doc, updateDoc }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  await updateDoc(doc(db, 'links', 'invites', 'tokens', invite.token), { status: 'rejected' })
}
