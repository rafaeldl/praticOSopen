<script setup lang="ts">
// The five roles as a radio list, each with its short sentence (team.invite-form.role).
// Plan (#724): on a plan without `teamRoles` only owner/admin are offered; the
// other roles show "Plano Pro" and the notice. The role a member already has
// (`keep`) stays selectable: nobody loses what they have.
import { computed, watch } from 'vue'
import { t } from '@/i18n'
import PlanFeatureNotice from '@/components/PlanFeatureNotice.vue'
import { usePlanFeature } from '@/lib/plan-feature-gate'
import { featureForRole } from '@/lib/plan-features'
import { PLAN_NAME } from '@/lib/plan-limits'
import { ASSIGNABLE_ROLES, ROLE_LABEL, ROLE_SHORT, type AssignableRole } from '@/lib/settings/model'

const props = defineProps<{ legend: string; name: string; keep?: string | null }>()
const model = defineModel<AssignableRole>({ required: true })

const teamRoles = usePlanFeature('teamRoles')
const locked = (role: string): boolean => !teamRoles.value.allowed && featureForRole(role) !== null && role !== props.keep
const anyLocked = computed(() => ASSIGNABLE_ROLES.some(locked))
const badge = computed(() => t('planFeatureBadge', { plan: PLAN_NAME[teamRoles.value.requiredPlan ?? 'pro'] }))

// A new invite starts on a role the plan has.
watch(
  () => locked(model.value),
  (isLocked) => {
    if (isLocked) model.value = 'admin'
  },
  { immediate: true },
)
</script>

<template>
  <fieldset class="choice-set" style="border: 0; margin: 0; padding: 0; min-width: 0">
    <legend class="field-label">{{ legend }}</legend>
    <ul class="role-list">
      <li v-for="role in ASSIGNABLE_ROLES" :key="role">
        <label class="role-opt" :class="{ 'is-locked': locked(role) }">
          <input v-model="model" type="radio" :name="name" :value="role" :disabled="locked(role)" :data-testid="`role-${role}`" />
          <span>
            <strong>{{ t(ROLE_LABEL[role]) }}</strong>
            <span class="sub">{{ t(ROLE_SHORT[role]) }}</span>
            <span v-if="locked(role)" class="plan-badge" data-testid="role-plan-badge">{{ badge }}</span>
          </span>
        </label>
      </li>
    </ul>
    <PlanFeatureNotice v-if="anyLocked" class="role-plan-notice" feature="teamRoles" :required-plan="teamRoles.requiredPlan" />
  </fieldset>
</template>
