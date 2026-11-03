<script setup lang="ts">
// Sua conta (account.*, profile.edit.*): photo, name, e-mail and "empresa ·
// papel"; edit the profile; switch company (with more than one, from the
// companies the token confirms, not the old names of the user document);
// join with an invite code; sign out (asks) and delete the account.
import { computed, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { Check } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import DeleteAccount from '@/components/settings/DeleteAccount.vue'
import ProfileForm from '@/components/settings/ProfileForm.vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { acceptInvite } from '@/lib/invites'
import { selectCompany, session, signOutEverywhere } from '@/lib/session'
import { loadProfile, lookupInvite, type InvitePreview, type Profile } from '@/lib/settings/data'
import { displayRole, normalizeInviteCode, ROLE_LABEL } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'
import '@/styles/settings.css'

const router = useRouter()
const profile = shallowRef<Profile | null>(null)
const failed = ref(false)
const dialog = ref<'profile' | 'switch' | 'code' | 'join' | 'leave' | 'delete' | null>(null)
const code = ref('')
const codeError = ref('')
const found = shallowRef<InvitePreview | null>(null)
const busy = ref(false)
const switchTo = ref(session.companyId ?? '')

const companyName = computed(() => session.company?.name || session.companies.find((item) => item.id === session.companyId)?.name || '')
const roleText = (role: string | null) => (!role ? '' : role === 'owner' ? t('owner') : t(ROLE_LABEL[displayRole(role)]))
const companyLine = computed(() => [companyName.value || (session.companyId ? t('companyNoName') : ''), roleText(session.role)].filter(Boolean).join(' · '))

async function load() {
  failed.value = false
  profile.value = null
  try {
    profile.value = await loadProfile()
  } catch (error) {
    console.error('account: profile failed', error)
    failed.value = true
  }
}

async function doSwitch() {
  const id = switchTo.value
  dialog.value = null
  if (!id || id === session.companyId) return
  try {
    await selectCompany(id)
    await router.push('/')
  } catch (error) {
    console.error('account: switch failed', error)
    showToast(t('web.error.generic'))
  }
}

function inviteError(error: unknown): string {
  const status = error instanceof ApiError ? error.status : 0
  const apiCode = error instanceof ApiError ? error.code : ''
  if (apiCode === 'EXPIRED') return t('inviteExpired')
  if (apiCode === 'ALREADY_MEMBER') return t('web.account.alreadyMember')
  if (apiCode === 'RATE_LIMIT_EXCEEDED' || status === 429) return t('emailLoginTooManyAttempts')
  if (apiCode === 'FORBIDDEN') return t('web.account.inviteNotForYou')
  if (apiCode === 'NETWORK') return t('networkError')
  if (status === 404 || status === 400) return t('web.account.inviteInvalid')
  return t('web.error.generic')
}

async function lookup() {
  codeError.value = ''
  if (!normalizeInviteCode(code.value)) {
    codeError.value = t('enterInviteCode')
    return
  }
  busy.value = true
  try {
    found.value = await lookupInvite(code.value)
    dialog.value = 'join'
  } catch (error) {
    codeError.value = inviteError(error)
  } finally {
    busy.value = false
  }
}

async function join() {
  const invite = found.value
  if (!invite || busy.value) return
  busy.value = true
  try {
    await acceptInvite({ token: invite.token, companyId: invite.company.id, companyName: invite.company.name, role: invite.role })
    dialog.value = null
    showToast(t('web.account.joined', { company: invite.company.name }))
    await router.push('/')
  } catch (error) {
    codeError.value = inviteError(error)
    dialog.value = 'code'
  } finally {
    busy.value = false
  }
}

function openCode() {
  code.value = ''
  codeError.value = ''
  dialog.value = 'code'
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('yourAccount') }}</h1>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!profile && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="profile">
        <ul class="set-list">
          <li>
            <button type="button" class="set-row" data-testid="account-profile" @click="dialog = 'profile'">
              <span class="set-avatar set-avatar--big">
                <img v-if="profile.photo" :src="profile.photo" :alt="t('web.account.photoAlt')" />
                <span v-else aria-hidden="true">{{ (profile.name || profile.email || '?').charAt(0).toUpperCase() }}</span>
              </span>
              <span class="set-text">
                <span class="who" data-testid="account-name">{{ profile.name || t('yourAccount') }}</span>
                <span class="sub">{{ profile.email }}</span>
                <span v-if="companyLine" class="sub" data-testid="account-company">{{ companyLine }}</span>
              </span>
              <span class="set-end">{{ t('web.account.edit') }}</span>
            </button>
          </li>
          <li v-if="session.companies.length > 1">
            <button type="button" class="set-row" data-testid="account-switch" @click="switchTo = session.companyId ?? ''; dialog = 'switch'">
              <span class="set-text"><span class="who">{{ t('switchCompany') }}</span></span>
              <span class="set-end">{{ companyName }}</span>
            </button>
          </li>
          <li>
            <button type="button" class="set-row" data-testid="account-code" @click="openCode">
              <span class="set-text"><span class="who">{{ t('joinWithInviteCode') }}</span></span>
            </button>
          </li>
        </ul>
        <div class="set-actions">
          <button type="button" class="btn" data-testid="account-sign-out" @click="dialog = 'leave'">{{ t('logout') }}</button>
          <button type="button" class="btn btn--ghost set-danger" data-testid="account-delete" @click="dialog = 'delete'">{{ t('deleteMyAccount') }}</button>
        </div>
      </template>
    </div>
  </div>

  <ProfileForm v-if="dialog === 'profile' && profile" :profile="profile" @saved="(next) => { profile = next; dialog = null }" @close="dialog = null" />
  <Layer v-if="dialog === 'switch'" kind="dialog" :label="t('selectCompany')" @close="dialog = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('selectCompany') }}</h2>
      </div>
      <div class="layer-body">
        <fieldset style="border: 0; margin: 0; padding: 0; min-width: 0">
          <legend class="sr">{{ t('selectCompany') }}</legend>
          <ul class="picker-list" data-testid="company-list">
            <li v-for="item in session.companies" :key="item.id">
              <label class="check-row">
                <input v-model="switchTo" type="radio" name="acc-company" :value="item.id" />
                <span>{{ item.name || t('companyNoName') }} <span class="sub">· {{ roleText(item.role) }}</span></span>
                <span v-if="item.id === session.companyId" class="sub"><Check :size="16" aria-hidden="true" /><span class="sr">{{ t('web.account.current') }}</span></span>
              </label>
            </li>
          </ul>
        </fieldset>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" :disabled="switchTo === session.companyId" data-testid="switch-confirm" @click="doSwitch">{{ t('switchCompany') }}</button>
      </div>
    </template>
  </Layer>
  <Layer v-if="dialog === 'code'" kind="dialog" :label="t('inviteCodeTitle')" @close="dialog = null">
    <template #default="{ close }">
      <form novalidate @submit.prevent="lookup">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('inviteCodeTitle') }}</h2>
        </div>
        <div class="layer-body">
          <label class="field-label" for="acc-code">{{ t('enterInviteCode') }}</label>
          <input id="acc-code" v-model="code" class="field" autocomplete="off" autocapitalize="characters" spellcheck="false" :placeholder="t('inviteCodePlaceholder')" :aria-invalid="!!codeError" data-autofocus />
          <p v-if="codeError" class="field-error" role="alert" data-testid="code-error">{{ codeError }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="busy" data-testid="code-submit">{{ t('continue_') }}</button>
        </div>
      </form>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="dialog === 'join' && found"
    :title="t('web.account.joinTitle', { company: found.company.name })"
    :body="t('web.account.joinBody', { role: roleText(found.role) })"
    :confirm="t('acceptInvite')"
    :keep="t('cancel')"
    @confirm="join"
    @close="dialog = null"
  />
  <ConfirmDialog v-if="dialog === 'leave'" :title="t('logoutConfirm')" :confirm="t('logout')" :keep="t('cancel')" @confirm="signOutEverywhere" @close="dialog = null" />
  <DeleteAccount v-if="dialog === 'delete'" @close="dialog = null" />
</template>
