<script setup lang="ts">
// What each role can do (big screens), read from app-permissions.json through
// the generated contract: the same table the app, the rules and the API use.
// With "Valores e cobrança" off, the money permissions read "desligado".
import { t } from '@/i18n'
import { effectiveUseFinancial } from '@/lib/session'
import { ASSIGNABLE_ROLES, PERMISSION_GROUPS, PERMISSION_LABEL, permissionCell, ROLE_LABEL } from '@/lib/settings/model'

const cellText = { yes: 'web.perm.yes', no: 'web.perm.no', off: 'web.perm.off' } as const
</script>

<template>
  <section class="perm-wrap" aria-labelledby="perm-title" data-testid="permission-table">
    <h2 id="perm-title" class="set-h">{{ t('web.perm.title') }}</h2>
    <p class="set-lead">{{ t('web.perm.lead') }}</p>
    <table class="perm-table">
      <thead>
        <tr>
          <td></td>
          <th v-for="role in ASSIGNABLE_ROLES" :key="role" scope="col">{{ t(ROLE_LABEL[role]) }}</th>
        </tr>
      </thead>
      <tbody v-for="group in PERMISSION_GROUPS" :key="group.label">
        <tr>
          <th scope="rowgroup" :colspan="ASSIGNABLE_ROLES.length + 1">{{ t(group.label) }}</th>
        </tr>
        <tr v-for="permission in group.permissions" :key="permission">
          <th scope="row">{{ t(PERMISSION_LABEL[permission]) }}</th>
          <td v-for="role in ASSIGNABLE_ROLES" :key="role" :class="`perm-${permissionCell(role, permission, effectiveUseFinancial())}`">
            <span aria-hidden="true">{{ { yes: '✓', no: '–', off: '○' }[permissionCell(role, permission, effectiveUseFinancial())] }}</span>
            <span class="sr">{{ t(cellText[permissionCell(role, permission, effectiveUseFinancial())]) }}</span>
          </td>
        </tr>
      </tbody>
    </table>
    <p v-if="!effectiveUseFinancial()" class="role-note">{{ t('web.perm.offNote') }}</p>
  </section>
</template>
