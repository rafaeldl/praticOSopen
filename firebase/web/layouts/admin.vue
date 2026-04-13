<template>
  <div class="min-h-screen bg-slate-950 text-slate-200" data-theme="dark">
    <!-- Mobile header -->
    <div class="lg:hidden flex items-center justify-between bg-slate-900 border-b border-slate-800 px-4 py-3">
      <div class="flex items-center gap-2">
        <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
          <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
          </svg>
        </div>
        <span class="text-white font-semibold">PraticOS</span>
      </div>
      <button @click="sidebarOpen = !sidebarOpen" class="text-slate-400 hover:text-white p-1">
        <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path v-if="!sidebarOpen" stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
          <path v-else stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>

    <div class="flex">
      <!-- Sidebar overlay (mobile) -->
      <div
        v-if="sidebarOpen"
        class="fixed inset-0 bg-black/50 z-40 lg:hidden"
        @click="sidebarOpen = false"
      />

      <!-- Sidebar -->
      <aside
        :class="[
          'fixed lg:sticky top-0 left-0 z-50 lg:z-auto h-screen w-64 bg-slate-900 border-r border-slate-800 flex flex-col transition-transform lg:translate-x-0',
          sidebarOpen ? 'translate-x-0' : '-translate-x-full',
        ]"
      >
        <!-- Logo -->
        <div class="hidden lg:flex items-center gap-3 px-6 py-5 border-b border-slate-800">
          <div class="w-9 h-9 bg-blue-600 rounded-xl flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          <div>
            <div class="text-white font-semibold text-sm">PraticOS</div>
            <div class="text-slate-500 text-xs">Admin Dashboard</div>
          </div>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 px-3 py-4 space-y-1">
          <NuxtLink
            to="/admin"
            :class="navLinkClass('/admin')"
            @click="sidebarOpen = false"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
            </svg>
            Overview
          </NuxtLink>
          <NuxtLink
            to="/admin/companies"
            :class="navLinkClass('/admin/companies')"
            @click="sidebarOpen = false"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 21h19.5M3.75 3v18m4.5-18v18m4.5-18v18m4.5-18v18M5.25 3h13.5M5.25 21h13.5M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15" />
            </svg>
            Empresas
          </NuxtLink>
        </nav>

        <!-- User info -->
        <div class="px-4 py-4 border-t border-slate-800">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 rounded-full bg-slate-700 flex items-center justify-center text-xs font-medium text-slate-300">
              {{ userInitial }}
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-sm text-slate-300 truncate">{{ user?.displayName || user?.email }}</div>
            </div>
            <button @click="signOut" class="text-slate-500 hover:text-slate-300 transition-colors" title="Sair">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
              </svg>
            </button>
          </div>
        </div>
      </aside>

      <!-- Main content -->
      <main class="flex-1 min-h-screen lg:min-h-0">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
const { user, signOut } = useAdminAuth()
const route = useRoute()
const sidebarOpen = ref(false)

const userInitial = computed(() => {
  const name = user.value?.displayName || user.value?.email || '?'
  return name.charAt(0).toUpperCase()
})

function navLinkClass(path: string) {
  const isActive = path === '/admin'
    ? route.path === '/admin'
    : route.path.startsWith(path)
  return [
    'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
    isActive
      ? 'bg-blue-600/10 text-blue-400'
      : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800',
  ]
}
</script>
