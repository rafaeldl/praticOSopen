<script setup lang="ts">
// Signed in, on the access list, without a company: the app's gate (AuthWrapper).
// Pending invites first; without any, the first access (/start). A failure to
// read the invites never sends an invited person to create a company (fatia 01, 72).
import { defineAsyncComponent, ref, watchEffect } from 'vue'
import { useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import InvitesList from '@/components/InvitesList.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { refreshClaims, session, signOutEverywhere } from '@/lib/session'

const InviteCodeFlow = defineAsyncComponent(() => import('@/components/InviteCodeFlow.vue'))

const router = useRouter()
const codeOpen = ref(false)
const busy = ref(false)
const invites = ref<'loading' | 'some' | 'failed'>('loading')
const attempt = ref(0)

// An invite accepted on the phone reaches the token only after a refresh.
async function check() {
  busy.value = true
  try {
    await refreshClaims()
  } finally {
    busy.value = false
  }
}

function onLoaded(count: number) {
  if (count) invites.value = 'some'
  else if (invites.value === 'loading') void router.replace({ name: 'onboarding' })
}

function retry() {
  invites.value = 'loading'
  attempt.value++
}

// The account could not be read (auth.gate.retry): read it again, never the first access.
async function retryAccount() {
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
        <template v-if="session.failed">
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.error.title') }}</h1>
          <p class="field-error" role="alert">{{ t('web.error.generic') }}</p>
          <button type="button" class="btn btn--primary btn--wide" :disabled="busy" data-testid="account-retry" @click="retryAccount">{{ t('web.tryAgain') }}</button>
        </template>
        <template v-else-if="invites === 'failed'">
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.error.title') }}</h1>
          <p class="field-error" role="alert">{{ t('inviteLoadError') }}</p>
          <button type="button" class="btn btn--primary btn--wide" @click="retry">{{ t('web.tryAgain') }}</button>
        </template>
        <template v-else>
          <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.noCompany.title') }}</h1>
          <LoadingState v-if="invites === 'loading'" />
          <p v-else class="muted">{{ t('web.noCompany.body') }}</p>
        </template>
        <InvitesList v-if="!session.failed" :key="attempt" @loaded="onLoaded" @failed="invites = 'failed'" @accepted="() => router.replace('/')" />
        <template v-if="invites === 'some'">
          <button type="button" class="btn btn--wide" data-testid="start-without-invite" @click="router.push({ name: 'onboarding' })">
            {{ t('inviteCreateOwnCompany') }}
          </button>
          <button type="button" class="btn btn--wide" data-testid="other-code" @click="codeOpen = true">{{ t('inviteHaveAnotherCode') }}</button>
          <button type="button" class="btn btn--wide" :disabled="busy" @click="check">{{ t('web.noCompany.check') }}</button>
        </template>
        <button type="button" class="btn btn--wide" @click="leave">{{ t('logout') }}</button>
      </div>
    </main>
  </div>
  <InviteCodeFlow v-if="codeOpen" @close="codeOpen = false" />
</template>
