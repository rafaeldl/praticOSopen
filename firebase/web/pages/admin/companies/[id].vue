<template>
  <div class="p-6 lg:p-8 max-w-7xl mx-auto">
    <!-- Back link -->
    <button @click="navigateTo('/admin/companies')" class="flex items-center gap-1.5 text-sm text-slate-400 hover:text-slate-200 mb-6 transition-colors">
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
      </svg>
      Voltar
    </button>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-32">
      <div class="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="bg-red-950/50 border border-red-900 rounded-xl p-6 text-center">
      <p class="text-red-400">{{ error }}</p>
    </div>

    <template v-else-if="data">
      <!-- Company Header -->
      <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-6 mb-8">
        <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
          <div>
            <h1 class="text-xl font-semibold text-white">{{ data.company.name }}</h1>
            <div class="flex flex-wrap items-center gap-3 mt-2 text-sm text-slate-400">
              <span v-if="data.company.segment" class="flex items-center gap-1.5">
                <span class="w-1.5 h-1.5 rounded-full bg-blue-400" />
                {{ data.company.segment }}
              </span>
              <span v-if="data.company.country">{{ data.company.country }}</span>
              <span v-if="data.company.ownerName">Owner: {{ data.company.ownerName }}</span>
              <span v-if="data.company.createdAt">Desde {{ formatDate(data.company.createdAt) }}</span>
            </div>
          </div>
          <div class="flex flex-wrap gap-2">
            <span
              v-for="(enabled, feature) in data.company.features"
              :key="feature"
              :class="[
                'px-2.5 py-1 rounded-md text-xs font-medium',
                enabled ? 'bg-blue-500/10 text-blue-400' : 'bg-slate-800 text-slate-500',
              ]"
            >
              {{ featureLabels[feature as string] || feature }}
            </span>
          </div>
        </div>
      </div>

      <!-- KPI Cards -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <AdminKpiCard title="Total OS" :value="data.stats.totalOrders" />
        <AdminKpiCard title="OS ativas" :value="data.stats.activeOrders" />
        <AdminKpiCard title="Receita" :value="data.stats.revenue" format="currency" />
        <AdminKpiCard title="Ticket medio" :value="data.stats.avgTicket" format="currency" />
      </div>

      <!-- Charts -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
        <div class="lg:col-span-2">
          <AdminBarChart
            title="OS por mes (12 meses)"
            :labels="data.ordersByMonth.map((d: any) => formatMonthLabel(d.month))"
            :data="data.ordersByMonth.map((d: any) => d.count)"
          />
        </div>
        <AdminDoughnutChart
          title="Distribuicao de status"
          :labels="Object.keys(data.statusDistribution).map((k: string) => statusLabels[k] || k)"
          :data="Object.values(data.statusDistribution) as number[]"
          :colors="Object.keys(data.statusDistribution).map((k: string) => statusColors[k] || '#64748B')"
        />
      </div>

      <!-- Feature Usage -->
      <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5 mb-8">
        <h3 class="text-sm font-medium text-slate-300 mb-4">Uso de features</h3>
        <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
          <div v-for="(pct, feature) in data.featureUsage" :key="feature" class="text-center">
            <div class="text-2xl font-semibold text-white">{{ pct }}%</div>
            <div class="text-xs text-slate-400 mt-1">{{ featureUsageLabels[feature as string] || feature }}</div>
            <div class="w-full bg-slate-800 rounded-full h-1.5 mt-2">
              <div class="bg-blue-500 h-1.5 rounded-full transition-all" :style="{ width: `${pct}%` }" />
            </div>
          </div>
        </div>
      </div>

      <!-- Members -->
      <div v-if="data.company.members.length > 0" class="bg-slate-900/50 border border-slate-800 rounded-xl p-5 mb-8">
        <h3 class="text-sm font-medium text-slate-300 mb-4">Membros ({{ data.company.membersCount }})</h3>
        <div class="flex flex-wrap gap-3">
          <div
            v-for="member in data.company.members"
            :key="member.email"
            class="flex items-center gap-2 bg-slate-800/50 rounded-lg px-3 py-2"
          >
            <div class="w-7 h-7 rounded-full bg-slate-700 flex items-center justify-center text-xs font-medium text-slate-300">
              {{ (member.name || member.email || '?').charAt(0).toUpperCase() }}
            </div>
            <div>
              <div class="text-xs text-slate-200">{{ member.name || member.email }}</div>
              <div class="text-xs text-slate-500">{{ member.role || 'member' }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Orders -->
      <div class="bg-slate-900/50 border border-slate-800 rounded-xl p-5">
        <h3 class="text-sm font-medium text-slate-300 mb-4">OS recentes</h3>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs text-slate-500 uppercase tracking-wider">
                <th class="pb-3 pr-4">#</th>
                <th class="pb-3 pr-4">Cliente</th>
                <th class="pb-3 pr-4">Status</th>
                <th class="pb-3 pr-4 text-right">Valor</th>
                <th class="pb-3 text-right">Data</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/50">
              <tr v-for="order in data.recentOrders" :key="order.id">
                <td class="py-2.5 pr-4 text-slate-400">{{ order.number || '-' }}</td>
                <td class="py-2.5 pr-4 text-slate-200">{{ order.customerName || '-' }}</td>
                <td class="py-2.5 pr-4">
                  <AdminStatusBadge :status="order.status" />
                </td>
                <td class="py-2.5 pr-4 text-right text-slate-300">{{ formatCurrency(order.total) }}</td>
                <td class="py-2.5 text-right text-slate-500">{{ order.createdAt ? formatDate(order.createdAt) : '-' }}</td>
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

const route = useRoute()
const { fetchAdmin } = useAdminApi()

const { data, loading, error } = useAdminPolling(
  () => fetchAdmin<{ data: any }>(`/api/admin/companies/${route.params.id}`).then((r) => r.data),
  30000,
)

const statusLabels: Record<string, string> = {
  quote: 'Orcamento',
  approved: 'Aprovado',
  progress: 'Em Andamento',
  done: 'Concluido',
  canceled: 'Cancelado',
}

const statusColors: Record<string, string> = {
  quote: '#3B82F6',
  approved: '#10B981',
  progress: '#F59E0B',
  done: '#059669',
  canceled: '#EF4444',
}

const featureLabels: Record<string, string> = {
  fieldService: 'Field Service',
  scheduling: 'Agendamento',
  deviceManagement: 'Dispositivos',
  contracts: 'Contratos',
}

const featureUsageLabels: Record<string, string> = {
  photos: 'Fotos',
  shareLinks: 'Share Links',
  documents: 'Documentos',
  devices: 'Dispositivos',
  contracts: 'Contratos',
  ratings: 'Avaliacoes',
}

function formatCurrency(value: number) {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString('pt-BR')
}

function formatMonthLabel(monthStr: string) {
  const [, m] = monthStr.split('-')
  const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
  return months[parseInt(m) - 1] || m
}
</script>
