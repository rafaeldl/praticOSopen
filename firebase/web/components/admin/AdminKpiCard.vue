<template>
  <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
    <div class="flex items-center justify-between mb-3">
      <span class="text-slate-400 text-xs font-medium uppercase tracking-wider">{{ title }}</span>
      <div v-if="trend" :class="['text-xs font-medium', trend > 0 ? 'text-emerald-400' : 'text-red-400']">
        {{ trend > 0 ? '+' : '' }}{{ trend }}%
      </div>
    </div>
    <div class="text-2xl font-semibold text-white tracking-tight">{{ formattedValue }}</div>
    <div v-if="subtitle" class="text-slate-500 text-xs mt-1">{{ subtitle }}</div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  title: string
  value: number | string
  subtitle?: string
  trend?: number
  format?: 'number' | 'currency' | 'percent'
}>()

const formattedValue = computed(() => {
  if (typeof props.value === 'string') return props.value
  if (props.format === 'currency') {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(props.value)
  }
  if (props.format === 'percent') return `${props.value}%`
  return new Intl.NumberFormat('pt-BR').format(props.value)
})
</script>
