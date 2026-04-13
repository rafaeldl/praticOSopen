import { signInWithPopup, GoogleAuthProvider, onIdTokenChanged, type User } from 'firebase/auth'

export function useAdminAuth() {
  const { $firebaseAuth } = useNuxtApp()
  const user = useState<User | null>('admin-user', () => null)
  const token = useState<string | null>('admin-token', () => null)
  const loading = useState('admin-auth-loading', () => true)
  const tokenCookie = useCookie('admin-token', { maxAge: 3600 })

  const isAuthenticated = computed(() => !!token.value)

  if (import.meta.client) {
    onIdTokenChanged($firebaseAuth, async (firebaseUser) => {
      if (firebaseUser) {
        user.value = firebaseUser
        const idToken = await firebaseUser.getIdToken()
        token.value = idToken
        tokenCookie.value = idToken
      } else {
        user.value = null
        token.value = null
        tokenCookie.value = null
      }
      loading.value = false
    })
  }

  async function signIn() {
    const provider = new GoogleAuthProvider()
    try {
      const result = await signInWithPopup($firebaseAuth, provider)
      const idToken = await result.user.getIdToken()
      token.value = idToken
      tokenCookie.value = idToken
      user.value = result.user
      return result.user
    } catch (error) {
      console.error('Sign-in failed:', error)
      throw error
    }
  }

  async function signOut() {
    await $firebaseAuth.signOut()
    user.value = null
    token.value = null
    tokenCookie.value = null
    navigateTo('/admin/login')
  }

  return { user, token, isAuthenticated, loading, signIn, signOut }
}
