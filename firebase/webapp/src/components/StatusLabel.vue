<script setup lang="ts">
// Dot + text, never a colored badge. Late is a problem: danger and bold.
import { computed } from 'vue'
import { t, type MessageKey } from '@/i18n'
import { resolveLabel, segmentLabels } from '@/lib/segments'

export type OrderStatus = 'quote' | 'approved' | 'progress' | 'done' | 'canceled'

const props = defineProps<{ status: OrderStatus | string; lateDays?: number; held?: boolean }>()

const STATUS: Record<OrderStatus, { label: string; dot: string }> = {
  quote: { label: 'status.quote', dot: 'neutral' },
  approved: { label: 'status.approved', dot: 'accent' },
  progress: { label: 'status.in_progress', dot: 'warning' },
  done: { label: 'status.completed', dot: 'success' },
  canceled: { label: 'status.cancelled', dot: 'hollow' },
}

const meta = computed(() => STATUS[props.status as OrderStatus])
const late = computed(() => props.lateDays ?? 0)
const dot = computed(() => (late.value ? 'danger' : props.held ? 'held' : (meta.value?.dot ?? 'neutral')))
const text = computed(() => {
  if (late.value) return t('web.status.late', { count: late.value })
  if (props.held) return t('web.status.held')
  return meta.value ? resolveLabel(meta.value.label, segmentLabels(), (key: MessageKey) => t(key)) : props.status
})
</script>

<template>
  <span class="status" :class="{ 'status--late': late }">
    <span class="dot" :class="`dot--${dot}`" aria-hidden="true"></span>
    <span>{{ text }}</span>
  </span>
</template>
