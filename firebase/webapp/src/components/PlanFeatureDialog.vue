<script setup lang="ts">
// The plan notice as a dialog, opened by ensurePlanFeature / handlePlanFeatureError
// (lib/plan-feature-gate.ts). Mounted once in the shell.
import { computed } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import PlanFeatureNotice from '@/components/PlanFeatureNotice.vue'
import { PLAN_FEATURE_NAME } from '@/lib/plan-features'
import { canChangePlan, planNotice } from '@/lib/plan-feature-gate'

const open = computed(() => planNotice.open)
const close = () => (planNotice.open = null)
</script>

<template>
  <Layer v-if="open" kind="dialog" :label="t(PLAN_FEATURE_NAME[open.feature])" @close="close">
    <div class="layer-body">
      <PlanFeatureNotice :feature="open.feature" :required-plan="open.requiredPlan" @navigate="close" />
    </div>
    <div class="layer-foot">
      <button type="button" class="btn" data-autofocus data-testid="plan-feature-close" @click="close">{{ canChangePlan() ? t('notNow') : t('ok') }}</button>
    </div>
  </Layer>
</template>
