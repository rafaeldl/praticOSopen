// Firebase clients, created once and loaded on demand. The login screen needs
// only Auth, so Firestore and Storage stay out of the first download.
import type { FirebaseApp, FirebaseOptions } from 'firebase/app'
import type { Auth } from 'firebase/auth'
import type { Firestore } from 'firebase/firestore'
import type { Firestore as LiteFirestore } from 'firebase/firestore/lite'
import type { FirebaseStorage } from 'firebase/storage'

const env = import.meta.env
// Read import.meta.env.VITE_USE_EMULATORS inline at each use: Vite replaces it
// with a literal, so the emulator branches disappear from the production bundle.
export const usesEmulators = import.meta.env.VITE_USE_EMULATORS === '1'
const EMULATOR_HOST = '127.0.0.1'

function options(): FirebaseOptions {
  const projectId = env.VITE_FIREBASE_PROJECT_ID
  if (!projectId) throw new Error('VITE_FIREBASE_PROJECT_ID is missing')
  // A typo here must never point local tooling at a real project.
  if (import.meta.env.VITE_USE_EMULATORS === '1' && !projectId.startsWith('demo-')) {
    throw new Error('Emulator mode only runs on a demo- project')
  }
  return {
    apiKey: env.VITE_FIREBASE_API_KEY,
    authDomain: env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId,
    storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
    appId: env.VITE_FIREBASE_APP_ID,
    messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    // Only read by lib/analytics-client.ts, after consent.
    ...(env.VITE_FIREBASE_MEASUREMENT_ID ? { measurementId: env.VITE_FIREBASE_MEASUREMENT_ID } : {}),
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
    if (import.meta.env.VITE_USE_EMULATORS === '1') {
      connectAuthEmulator(client, `http://${EMULATOR_HOST}:${env.VITE_EMULATOR_AUTH_PORT ?? 9099}`, {
        disableWarnings: true,
      })
    }
    return client
  })()
  return auth
}

let lite: Promise<LiteFirestore> | undefined
/**
 * One-shot reads (session documents, list pages, segment labels) through the
 * REST build of Firestore: about a quarter of the size and no channel to open,
 * so the list paints before the full client below downloads. Never cached on disk.
 */
export function firestoreLite(): Promise<LiteFirestore> {
  lite ??= (async () => {
    const [instance, { getFirestore, connectFirestoreEmulator }] = await Promise.all([firebaseApp(), import('firebase/firestore/lite')])
    const client = getFirestore(instance)
    if (import.meta.env.VITE_USE_EMULATORS === '1') connectFirestoreEmulator(client, EMULATOR_HOST, Number(env.VITE_EMULATOR_FIRESTORE_PORT ?? 8080))
    return client
  })()
  return lite
}

/**
 * False while the cache may still hold another account's data (a deletion
 * failed): the full client then keeps its cache in memory only.
 */
export const cacheState = { trusted: true }

let firestore: Promise<Firestore> | undefined
/** Full client: live updates (onSnapshot) and writes. Loaded after the first paint. */
export function firestoreClient(): Promise<Firestore> {
  firestore ??= (async () => {
    const [instance, { initializeFirestore, memoryLocalCache, persistentLocalCache, persistentMultipleTabManager, connectFirestoreEmulator }] =
      await Promise.all([firebaseApp(), import('firebase/firestore')])
    // Persistent cache keeps the open order across tabs. The computer is shared,
    // so signing out erases it (clearFirestoreCache); while another account's copy
    // could not be erased, this client stays in memory and never reads the disk.
    const client = initializeFirestore(instance, {
      localCache: cacheState.trusted ? persistentLocalCache({ tabManager: persistentMultipleTabManager() }) : memoryLocalCache(),
    })
    if (import.meta.env.VITE_USE_EMULATORS === '1') connectFirestoreEmulator(client, EMULATOR_HOST, Number(env.VITE_EMULATOR_FIRESTORE_PORT ?? 8080))
    return client
  })()
  return firestore
}

/**
 * Erases this browser's copy of the data. Throws when it could not, so the
 * caller can try again on the next load. The next firestoreClient() call
 * builds a new, empty instance.
 */
export async function clearFirestoreCache(): Promise<void> {
  const [client, { terminate, clearIndexedDbPersistence }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  firestore = undefined
  await terminate(client)
  await clearIndexedDbPersistence(client)
}

let storage: Promise<FirebaseStorage> | undefined
export function storageClient(): Promise<FirebaseStorage> {
  storage ??= (async () => {
    const [instance, { getStorage, connectStorageEmulator }] = await Promise.all([
      firebaseApp(),
      import('firebase/storage'),
    ])
    const client = getStorage(instance)
    if (import.meta.env.VITE_USE_EMULATORS === '1') connectStorageEmulator(client, EMULATOR_HOST, Number(env.VITE_EMULATOR_STORAGE_PORT ?? 9199))
    return client
  })()
  return storage
}
