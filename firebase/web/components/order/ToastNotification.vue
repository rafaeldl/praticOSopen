<template>
  <Teleport to="body">
    <div
      v-if="visible"
      :class="[
        'fixed bottom-6 left-1/2 z-[3000] flex -translate-x-1/2 items-center gap-2.5 rounded-full border bg-[var(--bg-card)] px-6 py-3.5 shadow-lg transition-all duration-300',
        visible ? 'translate-y-0 opacity-100' : 'translate-y-24 opacity-0',
        type === 'success' ? 'border-status-approved' : 'border-status-canceled',
      ]"
    >
      <svg v-if="type === 'success'" class="h-5 w-5 text-status-approved" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <polyline points="20 6 9 17 4 12"/>
      </svg>
      <svg v-else class="h-5 w-5 text-status-canceled" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
      <span class="text-sm">{{ message }}</span>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
defineProps<{
  message: string
  type: 'success' | 'error'
  visible: boolean
}>()
</script>
