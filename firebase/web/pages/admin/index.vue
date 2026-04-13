<template>
  <div class="p-6 lg:p-8 max-w-7xl mx-auto">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div>
        <h1 class="text-xl font-semibold text-white">Overview</h1>
        <p class="text-sm text-slate-500 mt-1">Visao geral do uso do PraticOS</p>
      </div>
      <div class="flex items-center gap-3">
        <!-- Period selector -->
        <div class="flex items-center bg-slate-900 border border-slate-800 rounded-lg overflow-hidden">
          <button
            v-for="opt in periodOptions"
            :key="opt.value"
            :class="[
              'px-3 py-2 text-xs font-medium transition-colors',
              selectedPeriod === opt.value ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-slate-200',
            ]"
            @click="changePeriod(opt.value)"
          >
            {{ opt.label }}
          </button>
        </div>
        <div v-if="lastUpdated" class="text-xs text-slate-600 hidden sm:block">
          {{ timeAgo(lastUpdated) }}
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading && !data" class="flex items-center justify-center py-32">
      <div class="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
    </div>

    <!-- Error -->
    <div v-else-if="error && !data" class="bg-red-950/50 border border-red-900 rounded-xl p-6 text-center">
      <p class="text-red-400">{{ error }}</p>
      <button @click="refresh" class="mt-3 text-sm text-blue-400 hover:text-blue-300">Tentar novamente</button>
    </div>

    <template v-else-if="data">
      <!-- Loading overlay when changing period -->
      <div v-if="refreshing" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 backdrop-blur-sm">
        <div class="flex flex-col items-center gap-3">
          <div class="w-10 h-10 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
          <span class="text-sm text-slate-300">Carregando {{ periodLabel }}...</span>
        </div>
      </div>

      <!-- Debug info (temporary) -->
      <div v-if="data._debug" class="bg-slate-900/50 border border-slate-700 rounded-lg p-3 mb-4 text-xs text-slate-400">
        {{ data._debug.ordersLoaded }} OS carregadas | {{ data._debug.ordersWithDate }} com data | {{ data._debug.ordersWithoutDate }} sem data |
        De {{ data._debug.newestDate ? formatDate(data._debug.newestDate) : '-' }} a {{ data._debug.oldestDate ? formatDate(data._debug.oldestDate) : '-' }}
      </div>

      <!-- KPI Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-8">
        <AdminKpiCard title="Empresas" :value="data.totalCompanies" :subtitle="`${data.newCompaniesInPeriod} novas no periodo`" />
        <AdminKpiCard :title="`Ativas (${periodLabel})`" :value="data.activeCompanies" />
        <AdminKpiCard :title="`OS (${periodLabel})`" :value="data.ordersPeriod" :subtitle="`${data.realTotalOrders} total`" />
        <AdminKpiCard :title="`Receita (${periodLabel})`" :value="data.revenuePeriod" format="currency" />
        <AdminKpiCard :title="`Ticket medio (${periodLabel})`" :value="data.averageTicket" format="currency" />
        <AdminKpiCard title="Retencao" :value="data.retentionRate" format="percent" />
      </div>

      <!-- Charts row -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <div class="lg:col-span-2">
          <AdminLineChart
            :title="`OS criadas por dia (${periodLabel})`"
            :labels="data.ordersOverTime.map((d: any) => formatDateLabel(d.date))"
            :data="data.ordersOverTime.map((d: any) => d.count)"
          />
        </div>
        <AdminDoughnutChart
          :title="`OS por status (${periodLabel})`"
          :labels="statusLabels"
          :data="statusValues"
          :colors="statusColors"
        />
      </div>

      <!-- Bar chart + Churn alerts -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <AdminBarChart
          title="Novas empresas por mes"
          :labels="data.newCompaniesPerMonth.map((d: any) => formatMonthLabel(d.month))"
          :data="data.newCompaniesPerMonth.map((d: any) => d.count)"
          color="#8B5CF6"
        />

        <!-- Churn Risk -->
        <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
          <h3 class="text-sm font-medium text-slate-300 mb-4 flex items-center gap-2">
            <svg class="w-4 h-4 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
            Risco de churn
            <span class="text-slate-500 font-normal">(sem OS no periodo)</span>
          </h3>
          <div v-if="data.churnRisk.length === 0" class="text-slate-500 text-sm py-4 text-center">
            Nenhuma empresa em risco
          </div>
          <div v-else class="space-y-2 max-h-52 overflow-y-auto">
            <div
              v-for="company in data.churnRisk.slice(0, 10)"
              :key="company.id"
              class="flex items-center justify-between py-2 px-3 rounded-lg hover:bg-slate-800/50 cursor-pointer"
              @click="navigateTo(`/admin/companies/${company.id}`)"
            >
              <div>
                <div class="text-sm text-slate-200">{{ company.name }}</div>
                <div class="text-xs text-slate-500">{{ company.segment }}</div>
              </div>
              <div class="text-xs text-amber-400 font-medium">
                {{ company.daysSinceLastOrder }}d inativo
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Top Companies Table -->
      <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
        <h3 class="text-sm font-medium text-slate-300 mb-4">Top 10 empresas no periodo</h3>
        <div v-if="data.topCompanies.length === 0" class="text-slate-500 text-sm py-8 text-center">
          Nenhuma empresa com OS neste periodo
        </div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs text-slate-500 uppercase tracking-wider">
                <th class="pb-3 pr-4">Empresa</th>
                <th class="pb-3 pr-4">Segmento</th>
                <th class="pb-3 pr-4 text-right">OS (periodo)</th>
                <th class="pb-3 pr-4 text-right">OS (total)</th>
                <th class="pb-3 pr-4 text-right">Receita (periodo)</th>
                <th class="pb-3 text-right">Ultima atividade</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800">
              <tr
                v-for="company in data.topCompanies"
                :key="company.id"
                class="hover:bg-slate-800/30 cursor-pointer transition-colors"
                @click="navigateTo(`/admin/companies/${company.id}`)"
              >
                <td class="py-3 pr-4">
                  <div class="text-slate-200 font-medium">{{ company.name }}</div>
                </td>
                <td class="py-3 pr-4 text-slate-400">{{ company.segment || '-' }}</td>
                <td class="py-3 pr-4 text-right text-slate-300">{{ company.orders }}</td>
                <td class="py-3 pr-4 text-right text-slate-500">{{ company.realOrders }}</td>
                <td class="py-3 pr-4 text-right text-slate-300">{{ formatCurrency(company.revenue) }}</td>
                <td class="py-3 text-right text-slate-500">{{ company.lastActivity ? formatDate(company.lastActivity) : '-' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: ['admin-auth'] })

const { fetchAdmin } = useAdminApi()

const periodOptions = [
  { label: 'Hoje', value: 'today' },
  { label: '7d', value: '7d' },
  { label: '30d', value: '30d' },
  { label: '90d', value: '90d' },
  { label: '6m', value: '6m' },
  { label: '1 ano', value: '1y' },
  { label: 'Tudo', value: 'all' },
]

const selectedPeriod = ref('today')
const refreshing = ref(false)

const periodLabel = computed(() => {
  return periodOptions.find((o) => o.value === selectedPeriod.value)?.label || '30d'
})

const { data, loading, error, lastUpdated, refresh } = useAdminPolling(
  () => fetchAdmin<{ data: any }>(`/api/admin/overview?period=${selectedPeriod.value}`).then((r) => r.data),
  30000,
)

async function changePeriod(period: string) {
  if (period === selectedPeriod.value) return
  selectedPeriod.value = period
  refreshing.value = true
  try {
    await refresh()
  } finally {
    refreshing.value = false
  }
}

const statusMap: Record<string, { label: string; color: string }> = {
  quote: { label: 'Orcamento', color: '#3B82F6' },
  approved: { label: 'Aprovado', color: '#10B981' },
  progress: { label: 'Em Andamento', color: '#F59E0B' },
  done: { label: 'Concluido', color: '#059669' },
  canceled: { label: 'Cancelado', color: '#EF4444' },
}

const statusLabels = computed(() => {
  if (!data.value?.ordersByStatus) return []
  return Object.keys(data.value.ordersByStatus).map((k) => statusMap[k]?.label || k)
})
const statusValues = computed(() => {
  if (!data.value?.ordersByStatus) return []
  return Object.values(data.value.ordersByStatus) as number[]
})
const statusColors = computed(() => {
  if (!data.value?.ordersByStatus) return []
  return Object.keys(data.value.ordersByStatus).map((k) => statusMap[k]?.color || '#64748B')
})

function formatDateLabel(dateStr: string) {
  const [, m, d] = dateStr.split('-')
  return `${d}/${m}`
}

function formatMonthLabel(monthStr: string) {
  const [, m] = monthStr.split('-')
  const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
  return months[parseInt(m) - 1] || m
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('pt-BR')
}

function timeAgo(date: Date) {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000)
  if (seconds < 60) return 'agora'
  return `${Math.floor(seconds / 60)}min atras`
}
</script>
