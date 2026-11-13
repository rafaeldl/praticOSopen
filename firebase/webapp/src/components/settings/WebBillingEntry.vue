<script setup lang="ts">
// The way from Plano to buying on the web (docs/WEB_CHECKOUT.md). Shows
// nothing while config/webCheckout is off or for whoever cannot buy (the
// server answers 403). Store subscribers are told to change the plan in the app.
import { onMounted, ref } from 'vue'
import { ChevronRight } from '@lucide/vue'
import { t } from '@/i18n'
import { billingEntry, loadBilling, type BillingEntry } from '@/lib/settings/billing'

const emit = defineEmits<{ shown: [entry: BillingEntry] }>()
const entry = ref<BillingEntry>('hidden')

onMounted(async () => {
  try {
    entry.value = billingEntry(await loadBilling())
  } catch {
    entry.value = 'hidden'
  }
  emit('shown', entry.value)
})
</script>

<template>
  <p v-if="entry === 'store'" class="role-note" data-testid="plan-billing-store">{{ t('web.billing.storeNote') }}</p>
  <section v-else-if="entry !== 'hidden'" class="set-section" data-testid="plan-billing">
    <RouterLink v-if="entry === 'buy'" to="/settings/plan/subscribe" class="btn btn--primary" data-testid="plan-billing-buy">{{ t('web.billing.choosePlan') }}</RouterLink>
    <ul v-else class="set-list">
      <li>
        <RouterLink to="/settings/plan/subscribe" class="set-row" data-testid="plan-billing-subscription">
          <span class="set-text"><span class="who">{{ t('web.billing.yourSubscription') }}</span></span>
          <ChevronRight :size="18" aria-hidden="true" />
        </RouterLink>
      </li>
    </ul>
  </section>
</template>
