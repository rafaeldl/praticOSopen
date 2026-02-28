<template>
  <div class="py-10 text-center text-sm text-[var(--text-tertiary)]">
    {{ t.poweredBy }} <a href="https://praticos.web.app" target="_blank" class="text-brand-primary hover:underline">PraticOS</a>
  </div>
</template>

<script setup lang="ts">
const { t } = useOrderI18n()
</script>
