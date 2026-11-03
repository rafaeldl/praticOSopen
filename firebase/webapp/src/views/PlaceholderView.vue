<script setup lang="ts">
// Skeleton of a screen still to come. Keeps route, permission and title real.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import PageHead from '@/components/PageHead.vue'
import { t } from '@/i18n'

const route = useRoute()
const title = computed(() => (route.meta.title ? t(route.meta.title) : ''))
</script>

<template>
  <PageHead :title="title" />
  <div class="workspace">
    <EmptyState :title="t('web.placeholder.title')" :body="t('web.placeholder.body')" />
  </div>
</template>
