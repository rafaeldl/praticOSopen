<template>
  <div class="min-h-screen bg-slate-950 flex items-center justify-center px-4">
    <div class="w-full max-w-sm">
      <div class="text-center mb-10">
        <div class="inline-flex items-center gap-3 mb-2">
          <div class="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <span class="text-white text-2xl font-semibold tracking-tight">PraticOS</span>
        </div>
        <p class="text-slate-400 text-sm">Admin Dashboard</p>
      </div>

      <div class="bg-slate-900/50 border border-slate-800 rounded-2xl p-8">
        <p v-if="error" class="text-red-400 text-sm text-center mb-4 bg-red-950/50 border border-red-900 rounded-lg p-3">
          {{ error }}
        </p>

        <button
          @click="handleSignIn"
          :disabled="signingIn"
          class="w-full flex items-center justify-center gap-3 bg-white hover:bg-gray-50 text-gray-800 font-medium py-3 px-4 rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <svg v-if="!signingIn" class="w-5 h-5" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
          <svg v-else class="w-5 h-5 animate-spin text-gray-500" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          {{ signingIn ? 'Entrando...' : 'Entrar com Google' }}
        </button>
      </div>

      <p class="text-center text-slate-600 text-xs mt-6">Acesso restrito a administradores</p>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })

const { signIn, isAuthenticated } = useAdminAuth()
const signingIn = ref(false)
const error = ref('')

watch(isAuthenticated, (val) => {
  if (val) navigateTo('/admin')
}, { immediate: true })

async function handleSignIn() {
  signingIn.value = true
  error.value = ''
  try {
    await signIn()
    navigateTo('/admin')
  } catch (e: any) {
    if (e.code === 'auth/popup-closed-by-user') return
    error.value = 'Falha ao entrar. Tente novamente.'
  } finally {
    signingIn.value = false
  }
}
</script>
