<script setup lang="ts">
import EmptyState from '@/components/EmptyState.vue'
import PageHead from '@/components/PageHead.vue'
import { t } from '@/i18n'
</script>

<template>
  <PageHead :title="t('web.notFound.title')" />
  <div class="workspace">
    <EmptyState :title="t('web.notFound.heading')" :body="t('web.notFound.body')">
      <RouterLink class="btn" to="/">{{ t('home') }}</RouterLink>
    </EmptyState>
  </div>
</template>
