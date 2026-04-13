<template>
  <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
    <h3 class="text-sm font-medium text-slate-300 mb-4">{{ title }}</h3>
    <div class="flex items-center gap-6">
      <div class="w-40 h-40 flex-shrink-0">
        <Doughnut v-if="chartData" :data="chartData" :options="chartOptions" />
      </div>
      <div class="space-y-2">
        <div v-for="(item, i) in legendItems" :key="i" class="flex items-center gap-2">
          <span class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ backgroundColor: item.color }" />
          <span class="text-xs text-slate-400">{{ item.label }}</span>
          <span class="text-xs font-medium text-slate-200 ml-auto pl-3">{{ item.value }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Doughnut } from 'vue-chartjs'
import { Chart as ChartJS, ArcElement, Tooltip } from 'chart.js'

ChartJS.register(ArcElement, Tooltip)

const props = defineProps<{
  title: string
  labels: string[]
  data: number[]
  colors: string[]
}>()

const chartData = computed(() => ({
  labels: props.labels,
  datasets: [
    {
      data: props.data,
      backgroundColor: props.colors,
      borderWidth: 0,
      hoverOffset: 4,
    },
  ],
}))

const chartOptions = {
  responsive: true,
  maintainAspectRatio: true,
  cutout: '65%',
  plugins: {
    legend: { display: false },
    tooltip: {
      backgroundColor: '#1E293B',
      titleColor: '#94A3B8',
      bodyColor: '#F1F5F9',
      borderColor: '#334155',
      borderWidth: 1,
      padding: 10,
      cornerRadius: 8,
    },
  },
}

const legendItems = computed(() =>
  props.labels.map((label, i) => ({
    label,
    value: props.data[i],
    color: props.colors[i],
  })),
)
</script>
