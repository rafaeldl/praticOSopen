<template>
  <div class="my-8 flex flex-col gap-3 sm:flex-row animate-fade-in-up">
    <button
      class="btn flex-1 bg-gradient-to-br from-status-approved to-[#28a745] text-white shadow-[0_4px_20px_rgba(52,199,89,0.3)] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(52,199,89,0.4)]"
      @click="$emit('approve')"
    >
      <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="20 6 9 17 4 12"/>
      </svg>
      {{ t.approve }}
    </button>
    <button
      class="btn flex-1 border border-status-canceled bg-transparent text-status-canceled transition-all hover:bg-status-canceled-bg"
      @click="$emit('reject')"
    >
      {{ t.reject }}
    </button>
  </div>
</template>

<script setup lang="ts">
defineEmits<{
  approve: []
  reject: []
}>()

const { t } = useOrderI18n()
</script>
