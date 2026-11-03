<script setup lang="ts">
// Status of an order in the customer and device history: dot + text, with the
// segment's status names (the app's customer screen ignores them, defect 15).
// Its own copy, so the list's StatusLabel stays inside the list's chunk.
import { statusText } from '@/lib/orders/text'
import type { OrderStatus } from '@/lib/orders/model'

defineProps<{ status: string }>()
const DOT: Record<string, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }
</script>

<template>
  <span class="status"><span class="dot" :class="`dot--${DOT[status] ?? 'neutral'}`" aria-hidden="true"></span><span>{{ statusText(status as OrderStatus) }}</span></span>
</template>
