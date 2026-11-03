<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import { t, type MessageKey } from '@/i18n'
import { signInWithEmail } from '@/lib/session'

const route = useRoute()
const router = useRouter()
const email = ref('')
const password = ref('')
const busy = ref(false)
const error = ref<MessageKey | null>(null)

/** Only an internal path: `next` comes from the URL and could point elsewhere. */
function nextPath(): string {
  const next = route.query.next
  return typeof next === 'string' && next.startsWith('/') && !next.startsWith('//') ? next : '/'
}

async function submit() {
  busy.value = true
  error.value = null
  try {
    await signInWithEmail(email.value.trim(), password.value)
    await router.replace(nextPath())
  } catch (cause) {
    const code = (cause as { code?: string }).code ?? ''
    error.value = /wrong-password|invalid-credential|user-not-found|invalid-email/.test(code)
      ? 'web.login.invalid'
      : code === 'auth/too-many-requests'
        ? 'web.error.rateLimit'
        : code === 'auth/network-request-failed'
          ? 'web.error.network'
          : 'web.error.generic'
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <div class="entry">
    <aside class="entry-side">
      <AppLogo />
      <p class="entry-claim">{{ t('web.login.claim') }}</p>
    </aside>
    <main class="entry-main">
      <form class="entry-box" @submit.prevent="submit">
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.login.title') }}</h1>
        <p class="muted">{{ t('web.login.sub') }}</p>
        <div>
          <label class="field-label" for="login-email">{{ t('email') }}</label>
          <input id="login-email" v-model="email" class="field" type="email" autocomplete="username" required data-autofocus />
        </div>
        <div>
          <label class="field-label" for="login-password">{{ t('password') }}</label>
          <input id="login-password" v-model="password" class="field" type="password" autocomplete="current-password" required />
        </div>
        <p v-if="error" class="field-error" role="alert">{{ t(error) }}</p>
        <button class="btn btn--primary btn--wide" type="submit" :disabled="busy">{{ t('signIn') }}</button>
      </form>
    </main>
  </div>
</template>
