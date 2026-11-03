<script setup lang="ts">
import { X } from '@lucide/vue'
import { t } from '@/i18n'
import { currentToast, dismissToast, undoToast } from '@/lib/toast'
</script>

<template>
  <!-- The live region exists before any message, or screen readers skip it. -->
  <div role="status" aria-live="polite">
    <div v-if="currentToast" :key="currentToast.id" class="toast">
      <span>{{ currentToast.message }}</span>
      <button v-if="currentToast.undo" type="button" class="link" @click="undoToast">{{ t('orderAssistantUndo') }}</button>
      <button type="button" class="icon-btn toast-x" :aria-label="t('close')" @click="dismissToast">
        <X :size="16" aria-hidden="true" />
      </button>
    </div>
  </div>
</template>
