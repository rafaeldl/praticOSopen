<script setup lang="ts">
// "Qual é o código do convite?" (the app's AcceptInviteScreen): the code as
// typed (trim, upper case, INV_ in front), Enter looks it up, the invite says
// the company and the role, "Aceitar" joins and "Buscar outro código" goes
// back to the field; joining goes to Início with the new company. Used by Sua conta and by the first access, with or
// without a company (the server accepts both, invite-self.routes.ts).
import { computed, nextTick, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { acceptInvite, inviteErrorKey } from '@/lib/invites'
import { lookupInvite, type InvitePreview } from '@/lib/settings/data'
import { displayRole, normalizeInviteCode, ROLE_LABEL } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'

const emit = defineEmits<{ close: [] }>()
const router = useRouter()

const step = ref<'code' | 'join'>('code')
const code = ref('')
const codeError = ref('')
const found = shallowRef<InvitePreview | null>(null)
const busy = ref(false)

const codeField = ref<HTMLInputElement | null>(null)
const againButton = ref<HTMLButtonElement | null>(null)
const label = computed(() => (step.value === 'join' && found.value ? t('web.account.joinTitle', { company: found.value.company.name }) : t('inviteCodeTitle')))

const roleText = (role: string) => (role === 'owner' ? t('owner') : t(ROLE_LABEL[displayRole(role)]))

async function lookup() {
  codeError.value = ''
  if (!normalizeInviteCode(code.value)) {
    codeError.value = t('enterInviteCode')
    return
  }
  busy.value = true
  try {
    found.value = await lookupInvite(code.value)
    step.value = 'join'
    void nextTick(() => againButton.value?.focus())
  } catch (error) {
    codeError.value = t(inviteErrorKey(error))
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
    // Joining switches the company, which re-creates the screen that opened this
    // (RouterView keyed by company): the flow goes to Início by itself.
    showToast(t('web.account.joined', { company: invite.company.name }))
    await router.push('/')
  } catch (error) {
    codeError.value = t(inviteErrorKey(error))
    step.value = 'code'
    void nextTick(() => codeField.value?.focus())
  } finally {
    busy.value = false
  }
}

function searchAgain() {
  found.value = null
  code.value = ''
  codeError.value = ''
  step.value = 'code'
  void nextTick(() => codeField.value?.focus())
}
</script>

<template>
  <!-- One layer for both steps: swapping layers would race their history entries. -->
  <Layer kind="dialog" :label="label" @close="emit('close')">
    <template #default="{ close }">
      <form v-if="step === 'code' || !found" novalidate @submit.prevent="lookup">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('inviteCodeTitle') }}</h2>
        </div>
        <div class="layer-body">
          <label class="field-label" for="invite-code">{{ t('enterInviteCode') }}</label>
          <input
            id="invite-code"
            ref="codeField"
            v-model="code"
            class="field invite-code-field"
            autocomplete="off"
            autocapitalize="characters"
            spellcheck="false"
            :placeholder="t('inviteCodePlaceholder')"
            :aria-invalid="!!codeError"
            aria-describedby="invite-code-error"
            data-autofocus
          />
          <p v-if="codeError" id="invite-code-error" class="field-error" role="alert" data-testid="code-error">{{ codeError }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="busy" data-testid="code-submit">{{ t('continue_') }}</button>
        </div>
      </form>
      <template v-else>
        <div class="layer-head">
          <h2 class="layer-title">{{ t('web.account.joinTitle', { company: found.company.name }) }}</h2>
        </div>
        <div class="layer-body">
          <p>{{ t('web.account.joinBody', { role: roleText(found.role) }) }}</p>
          <p v-if="found.invitedBy" class="sub">{{ t('invitedBy', { name: found.invitedBy }) }}</p>
        </div>
        <div class="layer-foot">
          <button ref="againButton" type="button" class="btn" data-testid="code-search-again" @click="searchAgain">{{ t('searchAnotherCode') }}</button>
          <button type="button" class="btn btn--primary" :disabled="busy" data-testid="code-join" @click="join">
            {{ busy ? t('web.invites.joining') : t('acceptInvite') }}
          </button>
        </div>
      </template>
    </template>
  </Layer>
</template>

<style scoped>
.invite-code-field { font-family: var(--font-mono); text-align: center; letter-spacing: 0.08em; text-transform: uppercase; }
</style>
