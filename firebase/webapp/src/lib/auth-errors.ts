import type { MessageKey } from '@/generated/message-keys'

/** Same texts as the app's EmailLoginScreen, never Firebase's own message. */
export function emailErrorKey(code: string): MessageKey {
  if (/wrong-password|invalid-credential|user-not-found|invalid-login-credentials/.test(code)) return 'emailLoginWrongCredentials'
  if (code === 'auth/invalid-email') return 'emailLoginEmailInvalid'
  if (code === 'auth/too-many-requests') return 'emailLoginTooManyAttempts'
  if (code === 'auth/network-request-failed') return 'emailLoginNoInternet'
  return 'emailLoginGenericError'
}
