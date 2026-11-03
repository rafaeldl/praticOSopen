<script setup lang="ts">
// Dot + text, never a colored badge. Late is a problem: danger and bold.
// `text` replaces the status name (the list's "Situação · entrega 15/10").
import { computed } from 'vue'
import { t, type MessageKey } from '@/i18n'
import { resolveLabel, segmentLabels } from '@/lib/segments'

export type OrderStatus = 'quote' | 'approved' | 'progress' | 'done' | 'canceled'

const props = defineProps<{ status: OrderStatus | string; lateDays?: number; lateText?: string | null; held?: boolean; text?: string }>()

const STATUS: Record<OrderStatus, { label: string; dot: string }> = {
  quote: { label: 'status.quote', dot: 'neutral' },
  approved: { label: 'status.approved', dot: 'accent' },
  progress: { label: 'status.in_progress', dot: 'warning' },
  done: { label: 'status.completed', dot: 'success' },
  canceled: { label: 'status.cancelled', dot: 'hollow' },
}

const meta = computed(() => STATUS[props.status as OrderStatus])
const late = computed(() => props.lateText || (props.lateDays ? t('web.status.late', { count: props.lateDays }) : ''))
const dot = computed(() => (late.value ? 'danger' : props.held ? 'held' : (meta.value?.dot ?? 'neutral')))
const label = computed(() => {
  if (late.value) return late.value
  if (props.text) return props.text
  if (props.held) return t('web.status.held')
  return meta.value ? resolveLabel(meta.value.label, segmentLabels(), (key: MessageKey) => t(key)) : props.status
})
</script>

<template>
  <span class="status" :class="{ 'status--late': late }">
    <span class="dot" :class="`dot--${dot}`" aria-hidden="true"></span>
    <span>{{ label }}</span>
  </span>
</template>
