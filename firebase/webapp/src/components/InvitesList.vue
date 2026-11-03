<script setup lang="ts">
// Pending invites with Aceitar / Recusar, as in the app's PendingInvitesScreen.
import { onMounted, ref } from 'vue'
import { t, type MessageKey } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { acceptInvite, listPendingInvites, rejectInvite, type Invite } from '@/lib/invites'
import { showToast } from '@/lib/toast'

const emit = defineEmits<{ accepted: [companyId: string] }>()
const invites = ref<Invite[]>([])
const loaded = ref(false)
const busy = ref<string | null>(null)
const error = ref<MessageKey | null>(null)

const ROLE_LABELS: Record<string, MessageKey> = {
  admin: 'roleAdmin',
  manager: 'roleManager',
  supervisor: 'roleSupervisor',
  consultant: 'roleConsultant',
  technician: 'roleTechnician',
}

async function load() {
  try {
    invites.value = await listPendingInvites()
  } catch (cause) {
    console.warn('invites: list failed', cause)
    invites.value = []
  } finally {
    loaded.value = true
  }
}

async function accept(invite: Invite) {
  busy.value = invite.token
  error.value = null
  try {
    await acceptInvite(invite)
    emit('accepted', invite.companyId)
  } catch (cause) {
    error.value = errorMessageKey(cause)
  } finally {
    busy.value = null
  }
}

async function reject(invite: Invite) {
  busy.value = invite.token
  try {
    await rejectInvite(invite)
    invites.value = invites.value.filter((item) => item.token !== invite.token)
    showToast(t('web.invites.rejected'))
  } catch (cause) {
    error.value = errorMessageKey(cause)
  } finally {
    busy.value = null
  }
}

onMounted(load)
</script>

<template>
  <section v-if="loaded && invites.length" class="invites" :aria-label="t('pendingInvites')">
    <h2 class="invites-title">{{ t('pendingInvites') }}</h2>
    <p v-if="error" class="field-error" role="alert">{{ t(error) }}</p>
    <div v-for="invite in invites" :key="invite.token" class="invite">
      <div>
        <strong class="who">{{ invite.companyName }}</strong>
        <p class="sub">
          <span v-if="ROLE_LABELS[invite.role]">{{ t(ROLE_LABELS[invite.role] as MessageKey) }}</span>
          <span v-if="invite.invitedBy"> · {{ t('invitedBy', { name: invite.invitedBy }) }}</span>
        </p>
      </div>
      <div class="invite-actions">
        <button type="button" class="btn btn--primary" :disabled="busy !== null" @click="accept(invite)">{{ t('acceptInvite') }}</button>
        <button type="button" class="btn" :disabled="busy !== null" @click="reject(invite)">{{ t('rejectInvite') }}</button>
      </div>
    </div>
  </section>
</template>
