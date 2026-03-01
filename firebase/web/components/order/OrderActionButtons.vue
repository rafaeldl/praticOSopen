<template>
  <div class="card-stagger card-v2 flex flex-col gap-3 sm:flex-row rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <button
      class="btn flex-1 bg-gradient-to-br from-[#16A34A] to-[#15803D] text-white shadow-[0_4px_20px_rgba(22,163,74,0.25)] transition-all hover:-translate-y-0.5 hover:shadow-[0_8px_30px_rgba(22,163,74,0.35)]"
      @click="$emit('approve')"
    >
      <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="20 6 9 17 4 12"/>
      </svg>
      {{ t.approve }}
    </button>
    <button
      class="btn flex-1 border border-[#EF4444] bg-transparent text-[#EF4444] transition-all hover:bg-[#FEF2F2]"
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
