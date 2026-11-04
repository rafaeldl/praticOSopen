<script setup lang="ts">
// "Convite para a equipe" (team.invite-share.*): the code, how long it lasts
// (from the server's expiresAt, never a number fixed here), copy as the main
// action, WhatsApp in a new tab, "Compartilhar convite" in the browser's own
// sheet where it has one (team.invite-share.share) and "Cancelar convite" with
// a confirmation. Every send goes through lib/share onShare.
import { computed, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { whatsappNumber } from '@/lib/phone'
import { cancelInvite } from '@/lib/settings/data'
import { inviteExpiry, inviteName, inviteWhatsAppUrl, validityDays, type TeamInvite } from '@/lib/settings/model'
import { session } from '@/lib/session'
import { canShareSheet, copyText, onShare, shareSheet } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{ invite: TeamInvite }>()
const emit = defineEmits<{ close: []; cancelled: [token: string] }>()

const confirming = ref(false)
const busy = ref(false)
const failed = ref('')
const days = computed(() => {
  const expiry = inviteExpiry(props.invite)
  return validityDays(props.invite.createdAt ? new Date(props.invite.createdAt) : new Date(), expiry?.toISOString())
})
const message = computed(() => t('inviteWhatsAppMessage', { code: props.invite.token }))
const whatsapp = computed(() => inviteWhatsAppUrl(message.value, whatsappNumber(props.invite.phone, session.company?.country)))

const CONTEXT = 'invite'
const hasSheet = canShareSheet()

async function copy() {
  if (!(await copyText(props.invite.token, CONTEXT))) {
    failed.value = t('web.team.copyFailed')
    return
  }
  showToast(t('inviteCodeCopied'))
  announce(t('inviteCodeCopied'))
}

async function share() {
  if ((await shareSheet({ text: message.value }, CONTEXT)) === 'failed') failed.value = t('web.share.sheetFailed')
}

async function cancel() {
  confirming.value = false
  busy.value = true
  failed.value = ''
  try {
    await cancelInvite(props.invite.token)
    showToast(t('teamInviteCanceled'))
    emit('cancelled', props.invite.token)
  } catch (error) {
    console.error('team: cancel invite failed', error)
    failed.value = t('teamActionFailed')
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <Layer kind="dialog" :label="t('inviteSheetTitle')" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('inviteSheetTitle') }}</h2>
        <p v-if="inviteName(invite)" class="sub">{{ inviteName(invite) }}</p>
      </div>
      <div class="layer-body" data-testid="invite-share">
        <p>{{ days ? t('inviteShareSentence', { days }) : t('web.team.shareSentence') }}</p>
        <p class="code-box" data-testid="invite-code">{{ invite.token }}</p>
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div class="set-actions">
          <button type="button" class="btn btn--primary" data-autofocus data-testid="invite-copy" @click="copy">{{ t('inviteCopyCode') }}</button>
          <a class="btn" :href="whatsapp" target="_blank" rel="noopener noreferrer" data-testid="invite-whatsapp" @click="onShare('whatsapp', CONTEXT)">{{ t('inviteSendWhatsApp') }}</a>
          <button v-if="hasSheet" type="button" class="btn" data-testid="invite-sheet" @click="share">{{ t('inviteShareButton') }}</button>
        </div>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost set-danger" :disabled="busy" data-testid="invite-cancel" @click="confirming = true">{{ t('teamCancelInvite') }}</button>
        <span class="spacer"></span>
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="confirming"
    :title="t('teamCancelInviteQuestion', { name: inviteName(invite) })"
    :body="t('teamCancelInviteMessage')"
    :confirm="t('teamCancelInvite')"
    :keep="t('teamKeepInvite')"
    danger
    @confirm="cancel"
    @close="confirming = false"
  />
</template>
