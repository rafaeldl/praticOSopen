<template>
  <div class="p-6 lg:p-8 max-w-7xl mx-auto">
    <!-- Header -->
    <div class="flex items-center justify-between mb-8">
      <div>
        <h1 class="text-xl font-semibold text-white">Empresas</h1>
        <p class="text-sm text-slate-500 mt-1">{{ filteredCompanies.length }} de {{ allCompanies.length }} empresas</p>
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
          placeholder="Buscar por nome ou email..."
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
              <th
                v-for="col in columns"
                :key="col.key"
                :class="[
                  'px-5 py-3 cursor-pointer select-none hover:text-slate-300 transition-colors',
                  col.align === 'right' ? 'text-right' : col.align === 'center' ? 'text-center' : '',
                ]"
                @click="toggleSort(col.key)"
              >
                <span class="inline-flex items-center gap-1">
                  {{ col.label }}
                  <svg v-if="sortBy === col.key" class="w-3 h-3 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                    <path v-if="sortDir === 'asc'" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L10 6.414l-3.293 3.293a1 1 0 01-1.414 0z" />
                    <path v-else d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L10 13.586l3.293-3.293a1 1 0 011.414 0z" />
                  </svg>
                  <svg v-else class="w-3 h-3 text-slate-700" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
                  </svg>
                </span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-800/50">
            <tr
              v-for="company in filteredCompanies"
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
              <td class="px-5 py-3.5 text-right text-slate-300">{{ company.totalOrders.toLocaleString('pt-BR') }}</td>
              <td class="px-5 py-3.5 text-right text-slate-300">{{ formatCurrency(company.revenue) }}</td>
              <td class="px-5 py-3.5 text-slate-400">{{ company.lastOrderDate ? formatDate(company.lastOrderDate) : '-' }}</td>
              <td class="px-5 py-3.5 text-center">
                <AdminStatusBadge :status="company.active ? 'active' : 'inactive'" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="filteredCompanies.length === 0" class="py-12 text-center text-slate-500 text-sm">
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
const sortBy = ref('totalOrders')
const sortDir = ref<'asc' | 'desc'>('desc')

const statusOptions = [
  { label: 'Todas', value: '' },
  { label: 'Ativas', value: 'active' },
  { label: 'Inativas', value: 'inactive' },
]

const columns = [
  { key: 'name', label: 'Empresa' },
  { key: 'segment', label: 'Segmento' },
  { key: 'country', label: 'Pais' },
  { key: 'membersCount', label: 'Membros', align: 'right' },
  { key: 'totalOrders', label: 'OS total', align: 'right' },
  { key: 'revenue', label: 'Receita', align: 'right' },
  { key: 'lastOrderDate', label: 'Ultima OS' },
  { key: 'active', label: 'Status', align: 'center' },
]

function toggleSort(key: string) {
  if (sortBy.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = key
    sortDir.value = ['name', 'segment', 'country', 'lastOrderDate'].includes(key) ? 'asc' : 'desc'
  }
}

// Fetch all data once, filter/sort client-side
const { data: response, loading, error, lastUpdated } = useAdminPolling(
  () => fetchAdmin<{ data: any[]; filters: any }>('/api/admin/companies'),
  60000, // poll every 60s since data is cached server-side
)

const allCompanies = computed(() => response.value?.data || [])
const filters = computed(() => response.value?.filters || { segments: [], countries: [] })

const filteredCompanies = computed(() => {
  let result = allCompanies.value

  // Search by name or email
  const q = search.value.toLowerCase().trim()
  if (q) {
    result = result.filter(
      (c: any) => c.name?.toLowerCase().includes(q) || c.ownerEmail?.toLowerCase().includes(q),
    )
  }

  // Filters
  if (segmentFilter.value) {
    result = result.filter((c: any) => c.segment === segmentFilter.value)
  }
  if (countryFilter.value) {
    result = result.filter((c: any) => c.country === countryFilter.value)
  }
  if (statusFilter.value === 'active') {
    result = result.filter((c: any) => c.active)
  } else if (statusFilter.value === 'inactive') {
    result = result.filter((c: any) => !c.active)
  }

  // Sort
  const key = sortBy.value
  const dir = sortDir.value === 'asc' ? 1 : -1
  result = [...result].sort((a: any, b: any) => {
    const va = a[key]
    const vb = b[key]
    if (va == null && vb == null) return 0
    if (va == null) return 1
    if (vb == null) return -1
    if (typeof va === 'string') return va.localeCompare(vb) * dir
    if (typeof va === 'boolean') return (va === vb ? 0 : va ? -1 : 1) * dir
    return (va - vb) * dir
  })

  return result
})

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
