<script setup lang="ts">
// Same doors as the app (lib/screens/login.dart): Google, Apple and "Já tenho
// conta com e-mail" (password, with "Esqueceu a senha?"). New accounts come
// from Google or Apple, as in the app.
import { onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import Layer from '@/components/Layer.vue'
import { t, type MessageKey } from '@/i18n'
import { emailErrorKey, isSignupBlocked, resetEmailErrorKey } from '@/lib/auth-errors'
import { sendPasswordReset, session, signInWithEmail, signInWithProvider, type ProviderKind } from '@/lib/session'
import { showToast } from '@/lib/toast'

const route = useRoute()
const router = useRouter()
const showEmail = ref(false)
const email = ref('')
const password = ref('')
const passwordShown = ref(false)
const busy = ref(false)
const error = ref<MessageKey | null>(null)
const resetOpen = ref(false)
const resetEmail = ref('')
const resetError = ref<MessageKey | null>(null)

const PROVIDER_ERRORS: Record<ProviderKind, MessageKey> = {
  google: 'errorSignInGoogleFriendly',
  apple: 'errorSignInAppleFriendly',
}

/** Only an internal path: `next` comes from the URL and could point elsewhere. */
function nextPath(): string {
  const next = route.query.next
  return typeof next === 'string' && next.startsWith('/') && !next.startsWith('//') ? next : '/'
}

async function enter() {
  await router.replace(nextPath())
}

async function withProvider(kind: ProviderKind) {
  busy.value = true
  error.value = null
  try {
    const result = await signInWithProvider(kind)
    if (result === 'done') await enter()
  } catch (cause) {
    console.warn('login: provider failed', cause)
    error.value = isSignupBlocked(cause) ? 'web.login.signupBlocked' : PROVIDER_ERRORS[kind]
  } finally {
    busy.value = false
  }
}

async function submitEmail() {
  const emailProblem = resetEmailErrorKey(email.value)
  if (emailProblem) {
    error.value = emailProblem
    return
  }
  if (!password.value) {
    error.value = 'emailLoginPasswordRequired'
    return
  }
  busy.value = true
  error.value = null
  try {
    await signInWithEmail(email.value.trim(), password.value)
    await enter()
  } catch (cause) {
    error.value = emailErrorKey((cause as { code?: string }).code ?? '')
  } finally {
    busy.value = false
  }
}

function openReset() {
  resetEmail.value = email.value
  resetError.value = null
  resetOpen.value = true
}

async function sendReset(close: () => void) {
  resetError.value = resetEmailErrorKey(resetEmail.value)
  if (resetError.value) return
  try {
    await sendPasswordReset(resetEmail.value.trim())
    close()
    showToast(`${t('emailSent')}. ${t('checkInboxResetPassword')}`)
  } catch {
    resetError.value = 'resetPasswordError'
  }
}

onMounted(() => {
  const failed = session.signInError as ProviderKind | null
  if (failed && PROVIDER_ERRORS[failed]) error.value = PROVIDER_ERRORS[failed]
  session.signInError = null
})
</script>

<template>
  <div class="entry">
    <aside class="entry-side">
      <AppLogo />
      <p class="entry-claim">{{ t('web.login.claim') }}</p>
    </aside>
    <main class="entry-main">
      <div class="entry-box">
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.login.title') }}</h1>
        <p class="muted">{{ t('web.login.sub') }}</p>
        <p v-if="error" class="field-error" role="alert">{{ t(error) }}</p>
        <div class="entry-btns">
          <button type="button" class="btn btn--primary btn--wide" :disabled="busy" @click="withProvider('google')">
            {{ t('continueWithGoogle') }}
          </button>
          <button type="button" class="btn btn--wide btn--apple" :disabled="busy" @click="withProvider('apple')">
            {{ t('continueWithApple') }}
          </button>
          <button v-if="!showEmail" type="button" class="link entry-link" @click="showEmail = true">
            {{ t('loginWithEmailLink') }}
          </button>
        </div>
        <form v-if="showEmail" class="entry-mail" novalidate @submit.prevent="submitEmail">
          <div>
            <label class="field-label" for="login-email">{{ t('email') }}</label>
            <input
              id="login-email"
              v-model="email"
              class="field"
              type="email"
              autocomplete="username"
              :placeholder="t('emailPlaceholder')"
              autofocus
            />
          </div>
          <div>
            <label class="field-label" for="login-password">{{ t('password') }}</label>
            <div class="entry-password">
              <input id="login-password" v-model="password" class="field" :type="passwordShown ? 'text' : 'password'" autocomplete="current-password" />
              <button
                type="button"
                class="link entry-reveal"
                :aria-pressed="passwordShown"
                aria-controls="login-password"
                data-testid="toggle-password"
                @click="passwordShown = !passwordShown"
              >
                {{ passwordShown ? t('hidePassword') : t('showPassword') }}
              </button>
            </div>
          </div>
          <button class="btn btn--wide" type="submit" :disabled="busy">{{ busy ? t('emailLoginSigningIn') : t('signIn') }}</button>
          <button type="button" class="link entry-link" @click="openReset">{{ t('forgotPasswordQuestion') }}</button>
          <p class="sub" data-testid="new-account-hint">{{ t('emailLoginNewAccountHint') }}</p>
        </form>
        <p class="sub entry-terms">
          {{ t('byContinuingYouAgree') }}
          <a class="link" href="/privacy.html" target="_blank" rel="noopener">{{ t('privacyPolicy') }}</a>.
        </p>
      </div>
    </main>
  </div>

  <Layer v-if="resetOpen" v-slot="{ close }" :label="t('resetPasswordTitle')" @close="resetOpen = false">
    <form class="layer-body" novalidate @submit.prevent="sendReset(close)">
      <h2 class="layer-title">{{ t('resetPasswordTitle') }}</h2>
      <p class="muted">{{ t('resetPasswordMessage') }}</p>
      <div>
        <label class="field-label" for="reset-email">{{ t('email') }}</label>
        <input id="reset-email" v-model="resetEmail" class="field" type="email" autocomplete="email" :aria-invalid="!!resetError" aria-describedby="reset-error" data-autofocus />
      </div>
      <p v-if="resetError" id="reset-error" class="field-error" role="alert">{{ t(resetError) }}</p>
      <div class="layer-foot layer-foot--inline">
        <button type="button" class="btn" @click="close">{{ t('cancel') }}</button>
        <button type="submit" class="btn btn--primary">{{ t('send') }}</button>
      </div>
    </form>
  </Layer>
</template>
