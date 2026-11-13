<script setup lang="ts">
// "O que {nome} pode fazer?" (team.member.role, team.member.remove): the roles
// with their sentence and "Tirar da equipe". Both ask before doing anything.
// The server keeps the owner and the last administrator; the screen checks the
// same before asking, and still shows the server's answer.
import { computed, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import RoleChoice from '@/components/settings/RoleChoice.vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { changeRole, removeMember } from '@/lib/settings/data'
import { handlePlanFeatureError } from '@/lib/plan-feature-gate'
import { displayRole, leavesNoAdmin, ROLE_LABEL, type AssignableRole, type Member } from '@/lib/settings/model'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{ member: Member; members: Member[]; ownerId: string | null }>()
const emit = defineEmits<{ close: []; changed: [] }>()

const role = ref<AssignableRole>(displayRole(props.member.role))
const asking = ref<'role' | 'remove' | null>(null)
const busy = ref(false)
const failed = ref('')
const unchanged = computed(() => role.value === displayRole(props.member.role))

function serverText(error: unknown, removing: boolean): string {
  const code = error instanceof ApiError ? error.code : ''
  if (code === 'OWNER_PROTECTED') return t('cannotChangeOwner')
  if (code === 'LAST_ADMIN') return removing ? t('cannotRemoveOnlyAdmin') : t('cannotChangeOnlyAdminRole')
  if (code === 'FORBIDDEN' || code === 'INSUFFICIENT_PERMISSIONS') return t('teamActionNotAllowed')
  return t('teamActionFailed')
}

function ask(kind: 'role' | 'remove') {
  failed.value = ''
  if (props.member.userId === props.ownerId) {
    failed.value = t('cannotChangeOwner')
    return
  }
  if (leavesNoAdmin(props.members, props.ownerId, props.member.userId, kind === 'remove' ? null : role.value)) {
    failed.value = kind === 'remove' ? t('cannotRemoveOnlyAdmin') : t('cannotChangeOnlyAdminRole')
    return
  }
  asking.value = kind
}

async function run(kind: 'role' | 'remove') {
  asking.value = null
  busy.value = true
  try {
    if (kind === 'role') await changeRole(props.member.userId, role.value)
    else await removeMember(props.member.userId)
    const message = kind === 'role' ? t('teamRoleChanged') : t('teamMemberRemoved', { name: props.member.name })
    showToast(message)
    announce(message)
    emit('changed')
  } catch (error) {
    console.error('team: change failed', error)
    if (handlePlanFeatureError(error)) return
    failed.value = serverText(error, kind === 'remove')
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <Layer kind="dialog" :label="t('teamMemberRoleQuestion', { name: member.name })" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('teamMemberRoleQuestion', { name: member.name }) }}</h2>
      </div>
      <div class="layer-body" data-testid="member-dialog">
        <p v-if="failed" class="field-error" role="alert" data-testid="member-error">{{ failed }}</p>
        <RoleChoice v-model="role" :legend="t('inviteRoleLabel')" name="member-role" :keep="displayRole(member.role)" />
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost set-danger" :disabled="busy" data-testid="member-remove" @click="ask('remove')">{{ t('teamRemoveMember') }}</button>
        <span class="spacer"></span>
        <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" :disabled="busy || unchanged" data-testid="member-save" @click="ask('role')">{{ t('web.team.saveRole') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="asking === 'role'"
    :title="t('web.team.changeRoleTitle', { name: member.name, role: t(ROLE_LABEL[role]) })"
    :body="t('web.team.changeRoleBody')"
    :confirm="t('web.team.saveRole')"
    :keep="t('cancel')"
    @confirm="run('role')"
    @close="asking = null"
  />
  <ConfirmDialog
    v-if="asking === 'remove'"
    :title="t('teamRemoveMemberQuestion', { name: member.name })"
    :body="t('teamRemoveMemberMessage')"
    :confirm="t('teamRemoveMember')"
    :keep="t('cancel')"
    danger
    @confirm="run('remove')"
    @close="asking = null"
  />
</template>
