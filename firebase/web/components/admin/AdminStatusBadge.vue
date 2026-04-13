<template>
  <span :class="['inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium', colorClass]">
    <span class="w-1.5 h-1.5 rounded-full" :class="dotClass" />
    {{ label }}
  </span>
</template>

<script setup lang="ts">
const props = defineProps<{
  status: string
}>()

const statusConfig: Record<string, { label: string; bg: string; text: string; dot: string }> = {
  quote: { label: 'Orçamento', bg: 'bg-blue-500/10', text: 'text-blue-400', dot: 'bg-blue-400' },
  approved: { label: 'Aprovado', bg: 'bg-emerald-500/10', text: 'text-emerald-400', dot: 'bg-emerald-400' },
  progress: { label: 'Em Andamento', bg: 'bg-amber-500/10', text: 'text-amber-400', dot: 'bg-amber-400' },
  done: { label: 'Concluído', bg: 'bg-emerald-500/10', text: 'text-emerald-400', dot: 'bg-emerald-400' },
  canceled: { label: 'Cancelado', bg: 'bg-red-500/10', text: 'text-red-400', dot: 'bg-red-400' },
  active: { label: 'Ativo', bg: 'bg-emerald-500/10', text: 'text-emerald-400', dot: 'bg-emerald-400' },
  inactive: { label: 'Inativo', bg: 'bg-slate-500/10', text: 'text-slate-400', dot: 'bg-slate-400' },
}

const config = computed(() => statusConfig[props.status] || statusConfig.inactive)
const colorClass = computed(() => `${config.value.bg} ${config.value.text}`)
const dotClass = computed(() => config.value.dot)
const label = computed(() => config.value.label)
</script>
