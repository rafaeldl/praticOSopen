<script setup lang="ts">
// Confirmation that says the consequence. The default button is never the destructive one.
import Layer from '@/components/Layer.vue'

defineProps<{ title: string; body?: string; confirm: string; keep: string; danger?: boolean }>()
const emit = defineEmits<{ confirm: []; close: [] }>()
</script>

<template>
  <Layer kind="dialog" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div v-if="body" class="layer-body">
        <p>{{ body }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" data-autofocus @click="close()">{{ keep }}</button>
        <button type="button" class="btn" :class="danger ? 'btn--danger' : 'btn--primary'" @click="emit('confirm')">{{ confirm }}</button>
      </div>
    </template>
  </Layer>
</template>
