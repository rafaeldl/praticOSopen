<script setup lang="ts">
// "Comece por aqui": only when the company never created an order (home.empty.first-run).
import { t } from '@/i18n'
import { deviceLabel } from '@/lib/orders/text'
import { ui } from '@/lib/ui'

defineProps<{ canCreate: boolean }>()
</script>

<template>
  <div class="empty first-run" data-testid="first-run">
    <h2>{{ t('firstOrderLabel') }}</h2>
    <p>{{ t('web.orders.firstRunBody') }}</p>
    <ol class="how">
      <li>{{ t('howItWorksStep1') }} <span class="muted">{{ t('howItWorksStep1DetailDevice', { device: deviceLabel().toLocaleLowerCase() }) }}</span></li>
      <li>{{ t('howItWorksStep2') }} <span class="muted">{{ t('howItWorksStep2Detail') }}</span></li>
      <li>{{ t('howItWorksStep3') }} <span class="muted">{{ t('howItWorksStep3Detail') }}</span></li>
    </ol>
    <button v-if="canCreate" type="button" class="btn btn--primary" @click="ui.newOrder = true">{{ t('newOrderButton') }}</button>
  </div>
</template>
