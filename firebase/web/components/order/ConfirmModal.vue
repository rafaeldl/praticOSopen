<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-[2000] flex items-center justify-center bg-black/80 p-5 backdrop-blur-sm transition-all duration-200"
      :class="isOpen ? 'opacity-100 visible' : 'opacity-0 invisible'"
      @click.self="$emit('cancel')"
    >
      <div
        class="w-full max-w-[400px] rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] p-8 transition-transform duration-300"
        :class="isOpen ? 'scale-100' : 'scale-90'"
      >
        <!-- Icon -->
        <div
          :class="[
            'mx-auto mb-5 flex h-16 w-16 items-center justify-center rounded-full',
            type === 'approve' ? 'bg-status-approved-bg text-status-approved' : 'bg-status-canceled-bg text-status-canceled',
          ]"
        >
          <svg v-if="type === 'approve'" class="h-8 w-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="20 6 9 17 4 12"/>
          </svg>
          <svg v-else class="h-8 w-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </div>

        <h3 class="mb-3 text-center text-xl font-semibold">{{ title }}</h3>
        <p class="mb-6 text-center text-[var(--text-secondary)]">{{ message }}</p>

        <!-- Input (for reject reason) -->
        <textarea
          v-if="showInput"
          v-model="inputValue"
          :placeholder="placeholder"
          rows="3"
          class="mb-6 w-full rounded-xl border border-[var(--border-color)] bg-[var(--bg-secondary)] p-3.5 font-body text-[0.9375rem] text-[var(--text-primary)] transition-all focus:border-brand-primary focus:outline-none placeholder:text-[var(--text-tertiary)]"
        />

        <div class="flex gap-3">
          <button class="btn btn-secondary flex-1" @click="$emit('cancel')">{{ t.cancel }}</button>
          <button
            :class="[
              'btn flex-1',
              type === 'approve'
                ? 'bg-gradient-to-br from-status-approved to-[#28a745] text-white shadow-[0_4px_20px_rgba(52,199,89,0.3)]'
                : 'border border-status-canceled bg-transparent text-status-canceled',
            ]"
            @click="$emit('confirm', inputValue)"
          >
            {{ t.confirm }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
defineProps<{
  isOpen: boolean
  type: 'approve' | 'reject'
  title: string
  message: string
  showInput?: boolean
  placeholder?: string
}>()

defineEmits<{
  confirm: [value: string]
  cancel: []
}>()

const { t } = useOrderI18n()
const inputValue = ref('')
</script>
