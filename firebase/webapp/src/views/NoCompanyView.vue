<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import { t } from '@/i18n'
import { refreshClaims, session, signOutEverywhere } from '@/lib/session'

const router = useRouter()
const busy = ref(false)

// An invite accepted on the phone reaches the token only after a refresh.
async function check() {
  busy.value = true
  try {
    await refreshClaims()
  } finally {
    busy.value = false
  }
}

async function leave() {
  await signOutEverywhere()
  await router.replace({ name: 'login' })
}

watchEffect(() => {
  if (session.companyId) void router.replace('/')
})
</script>

<template>
  <div class="entry">
    <aside class="entry-side"><AppLogo /></aside>
    <main class="entry-main">
      <div class="entry-box">
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.noCompany.title') }}</h1>
        <p class="muted">{{ t('web.noCompany.body') }}</p>
        <button type="button" class="btn btn--primary btn--wide" :disabled="busy" @click="check">{{ t('web.noCompany.check') }}</button>
        <button type="button" class="btn btn--wide" @click="leave">{{ t('logout') }}</button>
      </div>
    </main>
  </div>
</template>
