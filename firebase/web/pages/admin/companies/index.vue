<template>
  <div class="p-6 lg:p-8 max-w-7xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-xl font-semibold text-white">Empresas</h1>
        <p class="text-sm text-slate-500 mt-1">{{ filteredCount }} empresas encontradas</p>
      </div>
      <div v-if="lastUpdated" class="text-xs text-slate-600">
        Atualizado {{ timeAgo(lastUpdated) }}
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-wrap gap-3 mb-6">
      <div class="relative flex-1 min-w-[200px] max-w-sm">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          v-model="search"
          type="text"
          placeholder="Buscar por nome..."
          class="w-full bg-slate-900 border border-slate-800 rounded-lg pl-10 pr-4 py-2.5 text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500"
        />
      </div>

      <select
        v-model="segmentFilter"
        class="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2.5 text-sm text-slate-300 focus:outline-none focus:border-blue-500"
      >
        <option value="">Todos segmentos</option>
        <option v-for="s in filters.segments" :key="s" :value="s">{{ s }}</option>
      </select>

      <select
        v-model="countryFilter"
        class="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2.5 text-sm text-slate-300 focus:outline-none focus:border-blue-500"
      >
        <option value="">Todos paises</option>
        <option v-for="c in filters.countries" :key="c" :value="c">{{ c }}</option>
      </select>

      <div class="flex items-center bg-slate-900 border border-slate-800 rounded-lg overflow-hidden">
        <button
          v-for="opt in statusOptions"
          :key="opt.value"
          :class="[
            'px-3 py-2.5 text-xs font-medium transition-colors',
            statusFilter === opt.value ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-slate-200',
          ]"
          @click="statusFilter = opt.value"
        >
          {{ opt.label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-32">
      <div class="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="bg-red-950/50 border border-red-900 rounded-xl p-6 text-center">
      <p class="text-red-400">{{ error }}</p>
    </div>

    <!-- Table -->
    <div v-else class="bg-slate-900/50 border border-slate-800 rounded-xl overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-xs text-slate-500 uppercase tracking-wider border-b border-slate-800">
              <th class="px-5 py-3">Empresa</th>
              <th class="px-5 py-3">Segmento</th>
              <th class="px-5 py-3">Pais</th>
              <th class="px-5 py-3 text-right">Membros</th>
              <th class="px-5 py-3 text-right">OS total</th>
              <th class="px-5 py-3 text-right">Receita</th>
              <th class="px-5 py-3">Ultima OS</th>
              <th class="px-5 py-3 text-center">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/50">
            <tr
              v-for="company in companies"
              :key="company.id"
              class="hover:bg-slate-800/30 cursor-pointer transition-colors"
              @click="navigateTo(`/admin/companies/${company.id}`)"
            >
              <td class="px-5 py-3.5">
                <div class="text-slate-200 font-medium">{{ company.name }}</div>
                <div v-if="company.ownerEmail" class="text-xs text-slate-500 mt-0.5">{{ company.ownerEmail }}</div>
              </td>
              <td class="px-5 py-3.5 text-slate-400">{{ company.segment || '-' }}</td>
              <td class="px-5 py-3.5 text-slate-400">{{ company.country || '-' }}</td>
              <td class="px-5 py-3.5 text-right text-slate-300">{{ company.membersCount }}</td>
              <td class="px-5 py-3.5 text-right text-slate-300">{{ company.totalOrders }}</td>
              <td class="px-5 py-3.5 text-right text-slate-300">{{ formatCurrency(company.revenue) }}</td>
              <td class="px-5 py-3.5 text-slate-400">{{ company.lastOrderDate ? formatDate(company.lastOrderDate) : '-' }}</td>
              <td class="px-5 py-3.5 text-center">
                <AdminStatusBadge :status="company.active ? 'active' : 'inactive'" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="companies.length === 0" class="py-12 text-center text-slate-500 text-sm">
        Nenhuma empresa encontrada
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: ['admin-auth'] })

const { fetchAdmin } = useAdminApi()
const search = ref('')
const segmentFilter = ref('')
const countryFilter = ref('')
const statusFilter = ref('')

const statusOptions = [
  { label: 'Todas', value: '' },
  { label: 'Ativas', value: 'active' },
  { label: 'Inativas', value: 'inactive' },
]

const queryParams = computed(() => {
  const params = new URLSearchParams()
  if (search.value) params.set('search', search.value)
  if (segmentFilter.value) params.set('segment', segmentFilter.value)
  if (countryFilter.value) params.set('country', countryFilter.value)
  if (statusFilter.value) params.set('status', statusFilter.value)
  return params.toString()
})

const { data: response, loading, error, lastUpdated } = useAdminPolling(
  () => fetchAdmin<{ data: any[]; filters: any }>(`/api/admin/companies?${queryParams.value}`),
  30000,
)

const companies = computed(() => response.value?.data || [])
const filters = computed(() => response.value?.filters || { segments: [], countries: [] })
const filteredCount = computed(() => companies.value.length)

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
