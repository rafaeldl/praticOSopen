<script setup lang="ts">
// The five roles as a radio list, each with its short sentence (team.invite-form.role).
import { t } from '@/i18n'
import { ASSIGNABLE_ROLES, ROLE_LABEL, ROLE_SHORT, type AssignableRole } from '@/lib/settings/model'

defineProps<{ legend: string; name: string }>()
const model = defineModel<AssignableRole>({ required: true })
</script>

<template>
  <fieldset class="choice-set" style="border: 0; margin: 0; padding: 0; min-width: 0">
    <legend class="field-label">{{ legend }}</legend>
    <ul class="role-list">
      <li v-for="role in ASSIGNABLE_ROLES" :key="role">
        <label class="role-opt">
          <input v-model="model" type="radio" :name="name" :value="role" />
          <span>
            <strong>{{ t(ROLE_LABEL[role]) }}</strong>
            <span class="sub">{{ t(ROLE_SHORT[role]) }}</span>
          </span>
        </label>
      </li>
    </ul>
  </fieldset>
</template>
