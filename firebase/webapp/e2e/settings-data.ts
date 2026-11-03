// Emulator documents and accounts read and written by the fatia 07 tests
// (equipe, empresa, plano, conta). Refuses to run outside the emulator.
import { getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'
import { PROJECT_ID } from './fixtures.mjs'

function app() {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Emulador ausente: os testes só rodam no emulador.')
  return getApps()[0] ?? initializeApp({ projectId: PROJECT_ID })
}

export async function readPath(path: string): Promise<Record<string, unknown> | undefined> {
  return (await getFirestore(app()).doc(path).get()).data()
}

export async function writePath(path: string, data: Record<string, unknown>, merge = true): Promise<void> {
  await getFirestore(app()).doc(path).set(data, { merge })
}

export async function listPath(path: string): Promise<Record<string, unknown>[]> {
  return (await getFirestore(app()).collection(path).get()).docs.map((doc) => ({ id: doc.id, ...doc.data() }))
}

export async function invitesOf(companyId: string): Promise<Record<string, unknown>[]> {
  const snapshot = await getFirestore(app()).collection('links/invites/tokens').where('company.id', '==', companyId).get()
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
}

export async function authUserExists(uid: string): Promise<boolean> {
  try {
    await getAuth(app()).getUser(uid)
    return true
  } catch {
    return false
  }
}
