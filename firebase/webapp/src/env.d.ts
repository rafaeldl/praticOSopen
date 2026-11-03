/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** '1' connects every Firebase client to the local emulators. */
  readonly VITE_USE_EMULATORS?: string
  readonly VITE_FIREBASE_API_KEY?: string
  readonly VITE_FIREBASE_AUTH_DOMAIN?: string
  readonly VITE_FIREBASE_PROJECT_ID?: string
  readonly VITE_FIREBASE_STORAGE_BUCKET?: string
  readonly VITE_FIREBASE_APP_ID?: string
  readonly VITE_API_BASE_URL?: string
  readonly VITE_EMULATOR_AUTH_PORT?: string
  readonly VITE_EMULATOR_FIRESTORE_PORT?: string
  readonly VITE_EMULATOR_STORAGE_PORT?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<object, object, unknown>
  export default component
}
