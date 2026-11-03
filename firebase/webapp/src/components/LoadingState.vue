<script setup lang="ts">
import { t } from '@/i18n'

defineProps<{ label?: string }>()
</script>

<template>
  <div class="empty" role="status">
    <p>{{ label ?? t('web.loading') }}</p>
  </div>
</template>
