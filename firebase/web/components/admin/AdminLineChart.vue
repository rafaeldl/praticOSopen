<template>
  <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
    <h3 class="text-sm font-medium text-slate-300 mb-4">{{ title }}</h3>
    <div class="h-64">
      <Line v-if="chartData" :data="chartData" :options="chartOptions" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { Line } from 'vue-chartjs'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Tooltip,
  Filler,
} from 'chart.js'

ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Tooltip, Filler)

const props = defineProps<{
  title: string
  labels: string[]
  data: number[]
  color?: string
}>()

const chartData = computed(() => ({
  labels: props.labels,
  datasets: [
    {
      data: props.data,
      borderColor: props.color || '#3B82F6',
      backgroundColor: (props.color || '#3B82F6') + '15',
      borderWidth: 2,
      pointRadius: 0,
      pointHoverRadius: 4,
      pointHoverBackgroundColor: props.color || '#3B82F6',
      tension: 0.3,
      fill: true,
    },
  ],
}))

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
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
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: '#475569', font: { size: 10 }, maxTicksLimit: 8 },
      border: { display: false },
    },
    y: {
      grid: { color: '#1E293B' },
      ticks: { color: '#475569', font: { size: 10 } },
      border: { display: false },
      beginAtZero: true,
    },
  },
}
</script>
