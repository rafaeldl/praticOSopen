<script setup lang="ts">
// Side navigation on computers, tabs on phones. Same entries, filtered by permission.
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { Menu, Plus, Search, Settings } from '@lucide/vue'
import AppLogo from '@/components/AppLogo.vue'
import { loadOrderTexts, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { can, canAny, reloadCompany, selectCompany, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { registerShortcut, shortcutLabel } from '@/lib/shortcuts'
import { registerCommand } from '@/lib/commands'
import { ui } from '@/lib/ui'
import { NAV } from '@/navigation'
import { canCreateOrders } from '@/lib/orders/model'

// Opened by a key or a tap, never on the first paint: out of the first download.
const CommandPalette = defineAsyncComponent(() => import('@/components/CommandPalette.vue'))
const ShortcutsDialog = defineAsyncComponent(() => import('@/components/ShortcutsDialog.vue'))
const Layer = defineAsyncComponent(() => import('@/components/Layer.vue'))
const NewOrderDrawer = defineAsyncComponent(() =>
  Promise.all([import('@/components/orders/NewOrderDrawer.vue'), loadOrderTexts()]).then(([m]) => m),
)

const route = useRoute()
// Nova OS from anywhere: N, the palette and the + of the phone bar (technician does not create: canCreateOrder).
const canCreate = computed(() => canCreateOrders(session.role, can('createOrder')))
const openNewOrder = () => {
  if (canCreate.value) ui.newOrder = true
}
const removeNewOrderKeys = [
  registerShortcut({ keys: 'n', label: 'web.shortcuts.newOrder', run: openNewOrder }),
  registerCommand({ id: 'new-order', label: 'newOrderButton', icon: Plus, keys: 'N', run: openNewOrder }),
]
onBeforeUnmount(() => removeNewOrderKeys.forEach((remove) => remove()))
const moreOpen = ref(false)
const online = ref(navigator.onLine)

const entries = computed(() => NAV.filter((entry) => canAny(entry.access.anyOf)))
const tabs = computed(() => entries.value.filter((entry) => entry.tab))
const moreEntries = computed(() => entries.value.filter((entry) => !entry.tab))
const isCurrent = (path: string) => (path === '/' ? route.path === '/' : route.path.startsWith(path))
const moreIsCurrent = computed(() => !tabs.value.some((tab) => isCurrent(tab.path)))
const companyName = computed(() =>
  companyLabel(session.company?.name || session.companies.find((c) => c.id === session.companyId)?.name || ''),
)

function onCompanyChange(event: Event) {
  selectCompany((event.target as HTMLSelectElement).value).catch((error) => showToast(t(errorMessageKey(error))))
}

const companyLabel = (name: string) => name || t('web.nav.unnamedCompany')

const setOnline = () => (online.value = true)
const setOffline = () => (online.value = false)
onMounted(() => {
  window.addEventListener('online', setOnline)
  window.addEventListener('offline', setOffline)
})
onBeforeUnmount(() => {
  window.removeEventListener('online', setOnline)
  window.removeEventListener('offline', setOffline)
})
</script>

<template>
  <div class="shell">
    <aside class="side" :aria-label="t('web.nav.label')">
      <div>
        <AppLogo />
        <div v-if="session.companies.length < 2" class="company">{{ companyName }}</div>
        <div v-else class="company-pick">
          <label class="sr" for="company-pick">{{ t('web.nav.company') }}</label>
          <select id="company-pick" class="company-select" :value="session.companyId ?? ''" @change="onCompanyChange">
            <option v-for="company in session.companies" :key="company.id" :value="company.id">{{ companyLabel(company.name) }}</option>
          </select>
        </div>
      </div>
      <button type="button" class="side-search" @click="ui.palette = true">
        <Search :size="16" aria-hidden="true" /><span>{{ t('search') }}</span><kbd>{{ shortcutLabel('mod+k') }}</kbd>
      </button>
      <nav :aria-label="t('web.nav.main')">
        <RouterLink
          v-for="entry in entries"
          :key="entry.name"
          class="nav-item"
          :to="entry.path"
          :aria-label="t(entry.label)"
          :aria-current="isCurrent(entry.path) ? 'page' : undefined"
        >
          <component :is="entry.icon" :size="18" aria-hidden="true" /><span>{{ t(entry.label) }}</span>
        </RouterLink>
      </nav>
      <div class="side-foot">
        <RouterLink
          class="nav-item"
          to="/settings"
          :aria-label="t('settings')"
          :aria-current="isCurrent('/settings') ? 'page' : undefined"
        >
          <Settings :size="18" aria-hidden="true" /><span>{{ t('settings') }}</span>
        </RouterLink>
      </div>
    </aside>

    <header class="topbar">
      <AppLogo />
      <span class="spacer"></span>
      <button type="button" class="topbar-btn" :aria-label="t('search')" @click="ui.palette = true">
        <Search :size="21" aria-hidden="true" />
      </button>
      <button v-if="canCreate" type="button" class="topbar-btn topbar-add" @click="openNewOrder">
        <Plus :size="18" aria-hidden="true" />{{ t('newOrderButton') }}
      </button>
    </header>

    <main class="main">
      <p v-if="!online" class="offline" role="status">{{ t('web.offline') }}</p>
      <p v-if="session.companyFailed" class="offline" role="alert">
        {{ t('web.companyFailed') }}
        <button type="button" class="link" @click="reloadCompany">{{ t('web.tryAgain') }}</button>
      </p>
      <RouterView :key="session.companyId ?? ''" />
    </main>

    <nav class="tabbar" :aria-label="t('web.nav.tabs')">
      <RouterLink
        v-for="tab in tabs"
        :key="tab.name"
        :to="tab.path"
        :aria-current="isCurrent(tab.path) ? 'page' : undefined"
      >
        <component :is="tab.icon" :size="22" aria-hidden="true" /><span>{{ t(tab.tabLabel ?? tab.label) }}</span>
      </RouterLink>
      <button type="button" :aria-current="moreIsCurrent ? 'page' : undefined" @click="moreOpen = true">
        <Menu :size="22" aria-hidden="true" /><span>{{ t('more') }}</span>
      </button>
    </nav>
  </div>

  <Layer v-if="moreOpen" kind="sheet" :label="t('more')" @close="moreOpen = false">
    <div class="more">
      <p class="more-co">{{ companyName }}</p>
      <RouterLink v-for="entry in moreEntries" :key="entry.name" class="more-row" :to="entry.path" replace>
        <component :is="entry.icon" :size="20" aria-hidden="true" />{{ t(entry.label) }}
      </RouterLink>
      <RouterLink class="more-row" to="/settings" replace>
        <Settings :size="20" aria-hidden="true" />{{ t('settings') }}
      </RouterLink>
    </div>
  </Layer>
  <NewOrderDrawer v-if="ui.newOrder && canCreate" />
  <CommandPalette v-if="ui.palette" />
  <ShortcutsDialog v-if="ui.shortcuts" />
</template>
