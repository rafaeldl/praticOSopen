<script setup lang="ts">
// Clientes and the devices of the segment ("Veículos", "Aparelhos") side by side, as two links.
import { t } from '@/i18n'
import { resolveLabel, segmentLabels } from '@/lib/segments'

defineProps<{ current: 'customers' | 'devices' }>()
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
</script>

<template>
  <nav class="tabs dir-tabs" :aria-label="t('web.customers.directory')">
    <RouterLink to="/customers" :aria-current="current === 'customers' ? 'page' : undefined" data-testid="customers-tab">{{ label('customer._entity_plural') }}</RouterLink>
    <RouterLink to="/devices" :aria-current="current === 'devices' ? 'page' : undefined" data-testid="devices-tab">{{ label('device._entity_plural') }}</RouterLink>
  </nav>
</template>
