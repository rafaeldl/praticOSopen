// Firebase clients, created once and loaded on demand. The login screen needs
// only Auth, so Firestore and Storage stay out of the first download.
import type { FirebaseApp, FirebaseOptions } from 'firebase/app'
import type { Auth } from 'firebase/auth'
import type { Firestore } from 'firebase/firestore'
import type { FirebaseStorage } from 'firebase/storage'

const env = import.meta.env
export const usesEmulators = env.VITE_USE_EMULATORS === '1'
const EMULATOR_HOST = '127.0.0.1'

function options(): FirebaseOptions {
  const projectId = env.VITE_FIREBASE_PROJECT_ID
  if (!projectId) throw new Error('VITE_FIREBASE_PROJECT_ID is missing')
  // A typo here must never point local tooling at a real project.
  if (usesEmulators && !projectId.startsWith('demo-')) {
    throw new Error('Emulator mode only runs on a demo- project')
  }
  return {
    apiKey: env.VITE_FIREBASE_API_KEY,
    authDomain: env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId,
    storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
    appId: env.VITE_FIREBASE_APP_ID,
  }
}

let app: Promise<FirebaseApp> | undefined
export function firebaseApp(): Promise<FirebaseApp> {
  app ??= import('firebase/app').then(({ initializeApp }) => initializeApp(options()))
  return app
}

let auth: Promise<Auth> | undefined
export function authClient(): Promise<Auth> {
  auth ??= (async () => {
    const [instance, { initializeAuth, browserLocalPersistence, connectAuthEmulator }] = await Promise.all([
      firebaseApp(),
      import('firebase/auth'),
    ])
    // initializeAuth without a popup resolver keeps the sign-in widgets out of the bundle.
    const client = initializeAuth(instance, { persistence: browserLocalPersistence })
    if (usesEmulators) {
      connectAuthEmulator(client, `http://${EMULATOR_HOST}:${env.VITE_EMULATOR_AUTH_PORT ?? 9099}`, {
        disableWarnings: true,
      })
    }
    return client
  })()
  return auth
}

let firestore: Promise<Firestore> | undefined
export function firestoreClient(): Promise<Firestore> {
  firestore ??= (async () => {
    const [instance, { getFirestore, connectFirestoreEmulator }] = await Promise.all([
      firebaseApp(),
      import('firebase/firestore'),
    ])
    // No persistent cache: the workshop computer is shared (WEB_APP_DESIGN, Sair).
    const client = getFirestore(instance)
    if (usesEmulators) connectFirestoreEmulator(client, EMULATOR_HOST, Number(env.VITE_EMULATOR_FIRESTORE_PORT ?? 8080))
    return client
  })()
  return firestore
}

let storage: Promise<FirebaseStorage> | undefined
export function storageClient(): Promise<FirebaseStorage> {
  storage ??= (async () => {
    const [instance, { getStorage, connectStorageEmulator }] = await Promise.all([
      firebaseApp(),
      import('firebase/storage'),
    ])
    const client = getStorage(instance)
    if (usesEmulators) connectStorageEmulator(client, EMULATOR_HOST, Number(env.VITE_EMULATOR_STORAGE_PORT ?? 9199))
    return client
  })()
  return storage
}
