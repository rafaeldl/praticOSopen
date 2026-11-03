<script setup lang="ts">
// "Apagar minha conta" (account.delete, account.deletion.*): the warning, then
// a strong confirmation (type your e-mail), then DELETE /v1/app/account on the
// accountApi function. When the server asks for a recent sign-in, the same
// re-authentication as the app (password for an e-mail account, Google or
// Apple otherwise), then the final confirmation again. Every error has its
// own sentence; nothing technical reaches the screen.
import { computed, nextTick, ref, watch } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { deleteAccount, reauthenticate, reauthKind, type ReauthKind } from '@/lib/settings/data'
import { session, signOutEverywhere } from '@/lib/session'

const emit = defineEmits<{ close: [] }>()

type Step = 'warn' | 'confirm' | 'reauth'
const step = ref<Step>('warn')
const typed = ref('')
const password = ref('')
const busy = ref(false)
const failed = ref('')
const kind = ref<ReauthKind | null>(null)
const email = computed(() => session.email ?? '')
const matches = computed(() => typed.value.trim().toLowerCase() === email.value.toLowerCase() && !!email.value)

const TIMEOUT_MS = 120_000
const box = ref<HTMLElement | null>(null)

// Each step replaces the focused button: focus moves to the new step's field, so Esc and Tab stay in the dialog.
watch(step, async () => {
  await nextTick()
  const target = box.value?.closest('.layer-box')?.querySelector<HTMLElement>('[data-autofocus], button:not([disabled])')
  target?.focus()
})

function deleteError(error: unknown): string {
  if ((error as Error)?.name === 'AbortError') return t('accountDeletionTakingLong')
  if (!(error instanceof ApiError)) return t('couldNotDeleteAccount')
  if (error.code === 'COMPANY_HAS_MEMBERS') return t('web.account.deleteHasMembers')
  if (error.code === 'OWNERSHIP_MISMATCH') return t('web.account.deleteOwnership')
  if (error.code === 'NETWORK') return t('networkError')
  if (error.status === 429) return t('emailLoginTooManyAttempts')
  return `${t('couldNotDeleteAccount')} ${t('web.tryAgain')}.`
}

function reauthError(error: unknown): string {
  const code = (error as { code?: string })?.code ?? ''
  if (code === 'auth/wrong-password' || code === 'auth/invalid-credential' || code === 'auth/invalid-login-credentials') return t('emailLoginWrongCredentials')
  if (code === 'auth/too-many-requests') return t('emailLoginTooManyAttempts')
  if (code === 'auth/network-request-failed') return t('networkError')
  return t('couldNotReauthenticate')
}

async function remove() {
  if (!matches.value || busy.value) return
  busy.value = true
  failed.value = ''
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  try {
    await deleteAccount({ signal: controller.signal })
  } catch (error) {
    clearTimeout(timer)
    busy.value = false
    if (error instanceof ApiError && error.code === 'REQUIRES_RECENT_LOGIN') {
      kind.value = await reauthKind()
      password.value = ''
      step.value = 'reauth'
      return
    }
    console.error('account: delete failed', error instanceof ApiError ? error.code : (error as Error)?.name)
    failed.value = deleteError(error)
    return
  }
  clearTimeout(timer)
  // Nothing of the account may stay in this browser: sign out and start over.
  try {
    await signOutEverywhere()
  } catch {
    location.assign(`${import.meta.env.BASE_URL}login`)
  }
}

async function signInAgain() {
  if (!kind.value || busy.value) return
  if (kind.value === 'password' && !password.value) {
    failed.value = t('emailLoginPasswordRequired')
    return
  }
  busy.value = true
  failed.value = ''
  try {
    await reauthenticate(kind.value, password.value)
    // As the app: after signing in again, the final confirmation once more.
    typed.value = ''
    step.value = 'confirm'
  } catch (error) {
    const code = (error as { code?: string })?.code
    if (code !== 'auth/popup-closed-by-user' && code !== 'auth/cancelled-popup-request') failed.value = reauthError(error)
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <Layer kind="dialog" :label="t('deleteMyAccount')" @close="emit('close')">
    <template #default="{ close }">
      <span ref="box" hidden></span>
      <template v-if="step === 'warn'">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('deleteMyAccount') }}</h2>
        </div>
        <div class="layer-body" data-testid="delete-warn">
          <p style="white-space: pre-line">{{ t('deleteAccountWarning') }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" data-autofocus @click="close()">{{ t('cancel') }}</button>
          <button type="button" class="btn btn--danger" data-testid="delete-continue" @click="step = 'confirm'">{{ t('continue_') }}</button>
        </div>
      </template>
      <form v-else-if="step === 'confirm'" novalidate @submit.prevent="remove">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('finalConfirmation') }}</h2>
        </div>
        <div class="layer-body" data-testid="delete-confirm">
          <p style="white-space: pre-line">{{ t('lastChanceCancel') }}</p>
          <div>
            <label class="field-label" for="del-email">{{ t('web.account.deleteTypeEmail', { email }) }}</label>
            <input id="del-email" v-model="typed" class="field" type="email" autocomplete="off" spellcheck="false" data-autofocus />
          </div>
          <p v-if="busy" role="status">{{ t('web.account.deleting') }}</p>
          <p v-if="failed" class="field-error" role="alert" data-testid="delete-error">{{ failed }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" :disabled="busy" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--danger" :disabled="!matches || busy" data-testid="delete-final">{{ t('permanentlyDelete') }}</button>
        </div>
      </form>
      <form v-else novalidate @submit.prevent="signInAgain">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('reauthenticationRequired') }}</h2>
        </div>
        <div class="layer-body" data-testid="delete-reauth">
          <p>{{ t('pleaseSignInAgainToDelete') }}</p>
          <div v-if="kind === 'password'">
            <label class="field-label" for="del-password">{{ t('password') }}</label>
            <input id="del-password" v-model="password" class="field" type="password" autocomplete="current-password" data-autofocus />
          </div>
          <p v-else-if="!kind" class="field-error">{{ t('couldNotReauthenticate') }}</p>
          <p v-if="failed" class="field-error" role="alert" data-testid="reauth-error">{{ failed }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" :disabled="busy" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="busy || !kind" data-testid="reauth-submit">{{ t('signInAgain') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
