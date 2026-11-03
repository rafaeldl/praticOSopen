<script setup lang="ts">
// The web app is open only to allowed accounts. Plain message, a way to try
// again and a way out; the phone app keeps working.
import { ref, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import { t } from '@/i18n'
import { refreshClaims, sendVerificationEmail, session, signOutEverywhere } from '@/lib/session'
import { showToast } from '@/lib/toast'

const router = useRouter()
const busy = ref(false)

async function resend() {
  busy.value = true
  try {
    await sendVerificationEmail()
    showToast(t('web.notAllowed.sent'))
  } catch {
    showToast(t('web.error.generic'))
  } finally {
    busy.value = false
  }
}

async function retry() {
  busy.value = true
  try {
    await refreshClaims()
  } finally {
    busy.value = false
  }
}

watchEffect(() => {
  if (session.webAccess === 'allowed') void router.replace('/')
})
</script>

<template>
  <div class="entry">
    <aside class="entry-side"><AppLogo /></aside>
    <main class="entry-main">
      <div class="entry-box">
        <template v-if="session.webAccess === 'error'">
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.error.title') }}</h1>
          <p class="field-error" role="alert">{{ t('web.error.network') }}</p>
        </template>
        <template v-else-if="!session.emailVerified">
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.notAllowed.verifyTitle') }}</h1>
          <p class="muted">{{ t('web.notAllowed.verifyBody') }}</p>
          <button type="button" class="btn btn--primary btn--wide" :disabled="busy" @click="resend">{{ t('web.notAllowed.resend') }}</button>
        </template>
        <template v-else>
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.notAllowed.title') }}</h1>
          <p class="muted">{{ t('web.notAllowed.body') }}</p>
        </template>
        <p class="sub">{{ session.email }}</p>
        <button type="button" class="btn btn--wide" :disabled="busy" @click="retry">{{ t('web.tryAgain') }}</button>
        <button type="button" class="btn btn--wide" @click="signOutEverywhere">{{ t('logout') }}</button>
      </div>
    </main>
  </div>
</template>
