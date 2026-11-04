import type { MessageKey } from '@/generated/message-keys'

/** Same texts as the app's EmailLoginScreen, never Firebase's own message. */
export function emailErrorKey(code: string): MessageKey {
  if (/wrong-password|invalid-credential|user-not-found|invalid-login-credentials/.test(code)) return 'emailLoginWrongCredentials'
  if (code === 'auth/invalid-email') return 'emailLoginEmailInvalid'
  if (code === 'auth/too-many-requests') return 'emailLoginTooManyAttempts'
  if (code === 'auth/network-request-failed') return 'emailLoginNoInternet'
  return 'emailLoginGenericError'
}

/**
 * The server refused a new account (blockSuspiciousSignups) or sign-ups are
 * off: the SDK calls it auth/internal-error with the function's answer in the
 * message, or auth/admin-restricted-operation. The app shows the provider's
 * generic sentence (auth.signup.blocked: "Não copiar"); the web says so.
 */
export function isSignupBlocked(error: unknown): boolean {
  const { code = '', message = '' } = (error ?? {}) as { code?: string; message?: string }
  if (code === 'auth/admin-restricted-operation') return true
  return code === 'auth/internal-error' && /BLOCKING_FUNCTION|Cloud Function|PERMISSION_DENIED|permission-denied/i.test(message)
}

/** Reset link: the app's dialog does nothing with an empty or odd address; the web says what is missing. */
export function resetEmailErrorKey(email: string): MessageKey | null {
  const value = email.trim()
  if (!value) return 'emailLoginEmailRequired'
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'emailLoginEmailInvalid'
  return null
}
