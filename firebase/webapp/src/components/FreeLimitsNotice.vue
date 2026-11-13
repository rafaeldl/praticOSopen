<script setup lang="ts">
// Início, before the limits start for the Free companies that exist
// (config/paidPlans.limitsStartAt, decision of 2026-11-13): the same words as
// the app's FreeLimitsBanner (lib/screens/widgets/free_limits_banner.dart).
// The server sends the same as push and e-mail. "Agora não" hides it for that date.
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { freeLimitsNotice } from '@/lib/plan-feature-gate'
import { currentPlanRows } from '@/lib/plan-limits'
import { readStorage, writeStorage } from '@/lib/storage'
import { session } from '@/lib/session'

const props = defineProps<{ country?: string | null }>()

const notice = computed(() => freeLimitsNotice())
const key = computed(() => (notice.value ? `free_limits_dismissed_${notice.value.startsAt.toISOString()}_${session.companyId}` : ''))
const dismissed = ref(new Set<string>())
const hidden = computed(() => !notice.value || dismissed.value.has(key.value) || readStorage(key.value) === '1')

function dismiss(): void {
  writeStorage(key.value, '1')
  dismissed.value = new Set([...dismissed.value, key.value])
}
</script>

<template>
  <section v-if="!hidden && notice" class="free-limits" data-testid="free-limits-notice" :aria-label="t('freeLimitsBannerLabel')">
    <h2 class="free-limits-title">{{ t('freeLimitsBannerLabel') }}</h2>
    <p>{{ t('freeLimitsBannerText', { date: formatDate(notice.startsAt, props.country), orders: currentPlanRows().free.ordersPerMonth }) }}</p>
    <div class="free-limits-actions">
      <RouterLink class="btn btn--primary" :to="{ name: 'plan' }" data-testid="free-limits-see-plans">{{ t('viewPlans') }}</RouterLink>
      <button type="button" class="link" data-testid="free-limits-later" @click="dismiss">{{ t('courtesyBannerLater') }}</button>
    </div>
  </section>
</template>

<style scoped>
.free-limits {
  display: flex;
  flex-direction: column;
  gap: var(--space-sm);
  margin: 0 0 var(--space-md);
  padding: var(--space-md);
  border: var(--rule);
  border-radius: var(--radius-card);
  background: var(--color-card);
}
.free-limits-title {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1.125rem;
}
.free-limits p {
  max-width: var(--measure);
}
.free-limits-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-md);
}
</style>
