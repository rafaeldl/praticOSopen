<script setup lang="ts">
import { t } from '@/i18n'

defineProps<{ title?: string; body?: string; retry?: () => void }>()
</script>

<template>
  <div class="empty" role="alert">
    <h2>{{ title ?? t('web.error.title') }}</h2>
    <p>{{ body ?? t('web.error.generic') }}</p>
    <button v-if="retry" type="button" class="btn" @click="retry()">{{ t('web.tryAgain') }}</button>
  </div>
</template>
