<script setup lang="ts">
// "Convidar pessoa" (team.form.invite, team.invite-form.*, team.form.duplicate,
// team.invite.reinvite). Everything goes through POST /v1/app/invites, which
// checks the role of who invites and of the invite. Plan limits are not checked
// there nor here: like the app, the browser applies none (lib/plan-limits.ts);
// TeamView shows the seats count. Unlike the app, the old invite is only
// cancelled after the new one exists, so nobody is left without an invite. The
// WhatsApp follows the phone mask of the company country.
import { computed, reactive, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import RoleChoice from '@/components/settings/RoleChoice.vue'
import { t, type MessageKey } from '@/i18n'
import { ApiError } from '@/lib/api'
import { applyMask, fieldMasks, segmentField } from '@/lib/segment-fields'
import { session } from '@/lib/session'
import { cancelInvite, createInvite } from '@/lib/settings/data'
import { findDuplicateInvite, inviteBody, inviteProblems, isExpired, ROLE_DESCRIPTION, type AssignableRole, type InviteInput, type TeamInvite } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'
import '@/styles/orders.css'

const props = defineProps<{ pending: TeamInvite[]; prefill?: TeamInvite | null }>()
const emit = defineEmits<{
  close: []
  created: [invite: TeamInvite]
  resend: [invite: TeamInvite]
}>()

const prefillRole = (role: string | undefined): AssignableRole =>
  (['admin', 'supervisor', 'manager', 'consultant', 'technician'] as string[]).includes(role ?? '') ? (role as AssignableRole) : 'technician'

const form = reactive<InviteInput>({
  name: props.prefill?.name ?? '',
  email: props.prefill?.email ?? '',
  phone: props.prefill?.phone ?? '',
  role: prefillRole(props.prefill?.role),
})
const initial = JSON.stringify(form)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const tried = ref(false)
const saving = ref(false)
const failed = ref('')
const duplicate = ref<TeamInvite | null>(null)
let allowClose = false

const problems = computed(() => inviteProblems(form))
const phoneMasks = computed(() => fieldMasks(segmentField('customer.phone'), session.company?.country ?? null))
if (form.phone) form.phone = applyMask(form.phone, phoneMasks.value)

function onPhone(event: Event) {
  const input = event.target as HTMLInputElement
  form.phone = applyMask(input.value, phoneMasks.value)
  if (input.value !== form.phone) input.value = form.phone
}
const canSave = computed(() => !!(form.email.trim() || form.phone.trim()))
const dirty = computed(() => JSON.stringify(form) !== initial)
const problemText: Record<string, MessageKey> = { contact: 'inviteSaveNeedsContact', email: 'invalidEmail', phone: 'invalidPhone' }

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.team.discardTitle')}\n${t('web.team.discardBody')}`)
}

function errorText(error: unknown): string {
  if (error instanceof ApiError && (error.code === 'FORBIDDEN' || error.status === 403)) return t('teamActionNotAllowed')
  return t('inviteGenericError')
}

/** New invite first; the one it replaces is cancelled only after. */
async function create(replacing: TeamInvite | null) {
  saving.value = true
  failed.value = ''
  try {
    const created = await createInvite(inviteBody(form))
    const body = inviteBody(form)
    if (replacing) {
      try {
        await cancelInvite(replacing.token)
      } catch (error) {
        console.warn('team: old invite not cancelled', error)
        showToast(t('web.team.oldInviteKept'))
      }
    }
    allowClose = true
    emit('created', { token: created.token, expiresAt: created.expiresAt, createdAt: new Date().toISOString(), name: body.name, email: body.email, phone: body.phone, role: body.role })
  } catch (error) {
    console.error('team: invite failed', error)
    failed.value = errorText(error)
  } finally {
    saving.value = false
  }
}

async function save() {
  tried.value = true
  if (problems.value.length || saving.value) return
  const others = props.pending.filter((invite) => invite.token !== props.prefill?.token)
  const found = findDuplicateInvite(others, form)
  if (found && !isExpired(found, new Date())) {
    duplicate.value = found
    return
  }
  // Re-inviting (or an expired twin) replaces the old invite once the new one exists.
  await create(props.prefill ?? found)
}

async function replaceDuplicate() {
  const old = duplicate.value
  duplicate.value = null
  await create(old)
}

function resendDuplicate() {
  const old = duplicate.value
  duplicate.value = null
  if (!old) return
  allowClose = true
  emit('resend', old)
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
    event.preventDefault()
    void save()
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('invitePerson')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="invite-form" novalidate @submit.prevent="save()" @keydown="onKeydown">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('invitePerson') }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div>
          <label class="field-label" for="inv-name">{{ t('inviteWhoLabel') }}</label>
          <input id="inv-name" v-model="form.name" class="field" autocomplete="off" :placeholder="t('inviteWhoPlaceholder')" data-autofocus />
        </div>
        <div>
          <label class="field-label" for="inv-email">{{ t('inviteEmailLabel') }}</label>
          <input
            id="inv-email"
            v-model="form.email"
            class="field"
            type="email"
            autocomplete="off"
            :aria-invalid="tried && problems.includes('email')"
            aria-describedby="inv-email-hint"
          />
          <p id="inv-email-hint" class="sub field-hint">{{ t('inviteEmailHint') }}</p>
          <p v-if="tried && problems.includes('email')" class="field-error">{{ t('invalidEmail') }}</p>
        </div>
        <div>
          <label class="field-label" for="inv-phone">{{ t('inviteWhatsAppLabel') }}</label>
          <input
            id="inv-phone"
            :value="form.phone"
            @input="onPhone"
            class="field"
            type="tel"
            inputmode="tel"
            autocomplete="off"
            :aria-invalid="tried && problems.includes('phone')"
            aria-describedby="inv-phone-hint"
          />
          <p id="inv-phone-hint" class="sub field-hint">{{ t('userWillReceiveInviteByWhatsAppHint') }}</p>
          <p v-if="tried && problems.includes('phone')" class="field-error">{{ t('invalidPhone') }}</p>
        </div>
        <div>
          <RoleChoice v-model="form.role" :legend="t('inviteRoleLabel')" name="inv-role" />
          <p class="role-note" data-testid="invite-role-note">{{ t(ROLE_DESCRIPTION[form.role]) }}</p>
        </div>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ tried && problems.length ? t(problemText[problems[0]!]!) : !canSave ? t('inviteSaveNeedsContact') : '' }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !canSave }" :disabled="saving" data-testid="send-invite">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.team.sending') : t('web.team.createInvite') }}
        </button>
      </div>
    </form>
  </Layer>
  <Layer v-if="duplicate" kind="dialog" :label="t('duplicateInviteTitle')" @close="duplicate = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('duplicateInviteTitle') }}</h2>
      </div>
      <div class="layer-body">
        <p>{{ t('duplicateInviteMessage') }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" data-autofocus @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn" data-testid="duplicate-replace" @click="replaceDuplicate">{{ t('cancelAndCreateNew') }}</button>
        <button type="button" class="btn btn--primary" data-testid="duplicate-resend" @click="resendDuplicate">{{ t('resendExistingInvite') }}</button>
      </div>
    </template>
  </Layer>
</template>
