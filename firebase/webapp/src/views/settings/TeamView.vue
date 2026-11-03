<script setup lang="ts">
// Equipe (team.list.load, team.view.*, team.invite.*): "N pessoas e M
// convites", the first waiting invite with the days left and "Reenviar
// convite", who is waiting (expired ones too, with "Convidar de novo": the app
// hides them), who is in the team (you first, never opened) and, on a big
// screen, what each role can do. Only owner and admin reach the route
// (manageUsers); members come from Firestore, invites and every change from
// the API.
import { computed, onMounted, ref, shallowRef } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import InviteForm from '@/components/settings/InviteForm.vue'
import InviteShare from '@/components/settings/InviteShare.vue'
import MemberDialog from '@/components/settings/MemberDialog.vue'
import PermissionTable from '@/components/settings/PermissionTable.vue'
import { locale, t } from '@/i18n'
import { cancelInvite, companyOwnerId, listInvites, listMembers } from '@/lib/settings/data'
import {
  daysLeft,
  displayRole,
  inviteExpiry,
  inviteName,
  ROLE_LABEL,
  ROLE_SHORT,
  sortMembers,
  type Member,
  type TeamInvite,
} from '@/lib/settings/model'
import { session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import '@/styles/settings.css'

const members = shallowRef<Member[] | null>(null)
const invites = shallowRef<TeamInvite[]>([])
const ownerId = ref<string | null>(null)
const failed = ref(false)
const inviting = ref<{ prefill: TeamInvite | null } | null>(null)
const sharing = ref<TeamInvite | null>(null)
const expired = ref<TeamInvite | null>(null)
const editing = ref<Member | null>(null)
const dropping = ref<TeamInvite | null>(null)
const now = ref(new Date())

const sorted = computed(() => sortMembers(members.value ?? [], session.uid, new Intl.Collator(locale.value, { sensitivity: 'base' })))
const summary = computed(() => {
  const people = t('teamPeopleCount', { count: members.value?.length ?? 0 })
  return invites.value.length ? t('teamSummary', { people, invites: t('teamInvitesCount', { count: invites.value.length }) }) : people
})
const waiting = computed(() => invites.value[0] ?? null)
const daysOf = (invite: TeamInvite) => daysLeft(inviteExpiry(invite), now.value)

function blockExpiry(invite: TeamInvite): string {
  const days = daysOf(invite)
  if (days === null) return ''
  if (days < 0) return t('teamInviteExpired')
  if (days === 0) return t('teamInviteExpiresToday')
  return t('teamInviteExpiresInDays', { count: days })
}

function rowExpiry(invite: TeamInvite): string {
  const days = daysOf(invite)
  if (days === null || days === 0) return t('teamInviteDueToday')
  if (days < 0) return t('teamInviteDueExpired')
  return t('teamInviteDueInDays', { count: days })
}

const memberName = (member: Member) => member.name || t('userWithoutName')
const roleText = (role: string) => (role === 'owner' ? t('owner') : t(ROLE_LABEL[displayRole(role)]))
const canOpen = (member: Member) => member.userId !== session.uid && member.userId !== ownerId.value && member.role !== 'owner'

async function load() {
  failed.value = false
  members.value = null
  try {
    const [list, pending, owner] = await Promise.all([listMembers(), listInvites(), companyOwnerId()])
    members.value = list
    invites.value = pending
    ownerId.value = owner
    now.value = new Date()
  } catch (error) {
    console.error('team: load failed', error)
    failed.value = true
  }
}

/** Waiting invite: the code to share. Expired: the code no longer works, so invite again. */
function openInvite(invite: TeamInvite) {
  if (daysOf(invite) === -1) expired.value = invite
  else sharing.value = invite
}

function created(invite: TeamInvite) {
  inviting.value = null
  sharing.value = invite
  void load()
}

function resend(invite: TeamInvite) {
  inviting.value = null
  sharing.value = invite
}

function inviteAgain() {
  const invite = expired.value
  expired.value = null
  inviting.value = { prefill: invite }
}

function cancelled() {
  sharing.value = null
  expired.value = null
  void load()
}

async function drop() {
  const invite = dropping.value
  dropping.value = null
  if (!invite) return
  try {
    await cancelInvite(invite.token)
    showToast(t('teamInviteCanceled'))
  } catch (error) {
    console.error('team: cancel invite failed', error)
    showToast(t('teamActionFailed'))
  }
  void load()
}

function changed() {
  editing.value = null
  void load()
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('teamTitle') }}</h1>
      <p v-if="members" class="page-sub" data-testid="team-summary">{{ summary }}</p>
    </div>
    <button v-if="members" type="button" class="btn btn--primary" data-testid="team-invite" @click="inviting = { prefill: null }">
      {{ members.length <= 1 && !invites.length ? t('teamInviteFirst') : t('teamInviteAnother') }}
    </button>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!members && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="members">
        <div v-if="waiting" class="set-block" :class="{ 'set-block--danger': daysOf(waiting) === -1 }" data-testid="team-waiting-block">
          <p class="set-h">{{ t('teamInviteWaitingLabel') }}</p>
          <p>{{ t('teamInviteWaitingText', { name: inviteName(waiting), expiry: blockExpiry(waiting) }).trim() }}</p>
          <p>
            <button type="button" class="link" data-testid="team-resend" @click="openInvite(waiting)">
              {{ daysOf(waiting) === -1 ? t('teamInviteAgain') : t('teamResendInvite') }}
            </button>
          </p>
        </div>

        <section v-if="invites.length" aria-labelledby="team-waiting" class="set-section">
          <h2 id="team-waiting" class="set-h">{{ t('teamWaitingSection') }}</h2>
          <ul class="set-list" data-testid="team-invites">
            <li v-for="invite in invites" :key="invite.token" :data-invite="invite.token">
              <button type="button" class="set-row" @click="openInvite(invite)">
                <span class="set-text">
                  <span class="who">{{ inviteName(invite) }}</span>
                  <span class="sub" :class="{ 'set-danger': daysOf(invite) === -1 }">{{ t('teamInviteSent', { expiry: rowExpiry(invite) }) }}</span>
                </span>
                <span class="set-end">{{ roleText(invite.role) }}</span>
              </button>
            </li>
          </ul>
        </section>

        <section aria-labelledby="team-members" class="set-section">
          <h2 id="team-members" class="set-h">{{ t('teamMembersSection') }}</h2>
          <ul class="set-list" data-testid="team-members">
            <li v-for="member in sorted" :key="member.userId" :data-member="member.userId">
              <button v-if="canOpen(member)" type="button" class="set-row" @click="editing = member">
                <span class="set-text">
                  <span class="who">{{ memberName(member) }}</span>
                  <span class="sub">{{ roleText(member.role) }} · {{ t(ROLE_SHORT[displayRole(member.role)]) }}</span>
                </span>
                <span class="set-end">{{ t('web.team.change') }}</span>
              </button>
              <div v-else class="set-row">
                <span class="set-text">
                  <span class="who">{{ member.userId === session.uid ? t('teamYou', { name: memberName(member) }) : memberName(member) }}</span>
                  <span class="sub">{{ roleText(member.role) }} · {{ t(ROLE_SHORT[displayRole(member.role)]) }}</span>
                </span>
              </div>
            </li>
          </ul>
        </section>

        <PermissionTable />
      </template>
    </div>
  </div>

  <InviteForm v-if="inviting" :pending="invites" :prefill="inviting.prefill" @created="created" @resend="resend" @close="inviting = null" />
  <InviteShare v-if="sharing" :invite="sharing" @cancelled="cancelled" @close="sharing = null" />
  <MemberDialog v-if="editing" :member="editing" :members="members ?? []" :owner-id="ownerId" @changed="changed" @close="editing = null" />
  <Layer v-if="expired" kind="dialog" :label="t('teamInviteExpiredQuestion', { name: inviteName(expired) })" @close="expired = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('teamInviteExpiredQuestion', { name: inviteName(expired) }) }}</h2>
      </div>
      <div class="layer-body" data-testid="invite-expired">
        <p>{{ t('teamInviteExpiredMessage') }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
        <button type="button" class="btn btn--ghost set-danger" data-testid="expired-cancel" @click="dropping = expired; expired = null">{{ t('teamCancelInvite') }}</button>
        <button type="button" class="btn btn--primary" data-autofocus data-testid="expired-again" @click="inviteAgain">{{ t('teamInviteAgain') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="dropping"
    :title="t('teamCancelInviteQuestion', { name: inviteName(dropping) })"
    :body="t('teamCancelInviteMessage')"
    :confirm="t('teamCancelInvite')"
    :keep="t('teamKeepInvite')"
    danger
    @confirm="drop"
    @close="dropping = null"
  />
</template>
