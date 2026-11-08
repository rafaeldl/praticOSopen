<script setup lang="ts">
// Dot + text, never a colored badge. The dot always shows the status; a problem
// comes as text next to it, never in its place: "● Pintura · Atrasada 2 dias"
// (danger, bold), "● Aprovada · Parada" (dark amber, bold). docs/DESIGN_TOKENS.md.
// `text` replaces the status name (a stage name, "Situação · entrega 15/10").
// The default slot goes after everything (the agenda's " · 1042").
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
const problem = computed(() => (late.value ? { kind: 'late', text: late.value } : props.held ? { kind: 'held', text: t('web.status.held') } : null))
const label = computed(() => props.text || (meta.value ? resolveLabel(meta.value.label, segmentLabels(), (key: MessageKey) => t(key)) : props.status))
</script>

<template>
  <span class="status">
    <span class="dot" :class="`dot--${meta?.dot ?? 'neutral'}`" aria-hidden="true"></span>
    <span
      >{{ label }}<template v-if="problem"> · <strong class="status-problem" :class="`status-problem--${problem.kind}`">{{ problem.text }}</strong></template
      ><slot
    /></span>
  </span>
</template>
