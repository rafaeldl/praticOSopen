<script setup lang="ts">
// "Recurso do plano Pro" (#724): the same words as the app's
// showPlanFeatureNotice (lib/widgets/plan_feature_notice.dart). Owner and
// admin get the way to the Plan screen; everyone else is told to ask the owner.
// Inline (the TV screen) or inside PlanFeatureDialog.
import { computed } from 'vue'
import { t } from '@/i18n'
import { canChangePlan } from '@/lib/plan-feature-gate'
import { PLAN_FEATURE_NAME, requiredPlanFor, type PlanFeature } from '@/lib/plan-features'
import { PLAN_NAME, type PlanId } from '@/lib/plan-limits'

const props = withDefaults(defineProps<{ feature: PlanFeature; requiredPlan?: PlanId | null; role?: string | null; headingLevel?: 'h1' | 'h2' }>(), {
  requiredPlan: null,
  role: undefined,
  headingLevel: 'h2',
})
defineEmits<{ navigate: [] }>()

const plan = computed(() => PLAN_NAME[props.requiredPlan ?? requiredPlanFor(props.feature) ?? 'business'])
const owner = computed(() => canChangePlan(props.role))
const body = computed(() => `${t(PLAN_FEATURE_NAME[props.feature])}. ${owner.value ? t('planFeatureBody', { plan: plan.value }) : t('planFeatureAskOwner', { plan: plan.value })}`)
</script>

<template>
  <div class="plan-notice" data-testid="plan-feature-notice" :data-feature="feature">
    <component :is="headingLevel" class="plan-notice-title">{{ t('planFeatureTitle', { plan }) }}</component>
    <p>{{ body }}</p>
    <RouterLink v-if="owner" class="link" :to="{ name: 'plan' }" data-testid="plan-feature-see-plan" @click="$emit('navigate')">{{ t('web.planFeature.seePlan') }}</RouterLink>
  </div>
</template>
