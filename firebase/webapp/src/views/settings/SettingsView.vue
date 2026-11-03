<script setup lang="ts">
// Configurações (settings.view, settings.more-view): the account first, then
// only the rows the role can open, the preferences of this browser and the
// invites received. Rows wait for the role (the session is loaded before any
// screen), so a role never sees a shorter list by accident.
import { computed, ref } from 'vue'
import { ChevronRight } from '@lucide/vue'
import InvitesList from '@/components/InvitesList.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import PageHead from '@/components/PageHead.vue'
import { t } from '@/i18n'
import { prefs } from '@/lib/prefs'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session, signOutEverywhere } from '@/lib/session'
import { displayRole, ROLE_LABEL } from '@/lib/settings/model'
import '@/styles/settings.css'

interface Row {
  to: string
  title: string
  sub?: string
  testid: string
}

const leaving = ref(false)
const companyName = computed(() => session.company?.name || session.companies.find((item) => item.id === session.companyId)?.name || '')
const roleText = computed(() => (session.role ? t(session.role === 'owner' ? 'owner' : ROLE_LABEL[displayRole(session.role)]) : ''))
const accountSub = computed(() => [session.email ?? '', [companyName.value, roleText.value].filter(Boolean).join(' · ')].filter((line) => !!line))
// As the app: with Contratos on, or for who can turn it on.
const showsContracts = computed(() => !!session.companyId && (session.company?.useContracts === true || can('manageCompany')))
const devicesPlural = computed(() => segmentLabels()['device._entity_plural'])

const companyRows = computed<Row[]>(() => {
  if (!session.companyId) return []
  const rows: Row[] = []
  if (can('manageCompany')) rows.push({ to: '/settings/company', title: t('web.company.title'), sub: t('web.settings.companySub'), testid: 'settings-company' })
  if (can('manageUsers')) rows.push({ to: '/team', title: t('teamTitle'), sub: t('web.settings.teamSub'), testid: 'settings-team' })
  rows.push({ to: '/settings/plan', title: t('planTitle'), sub: t('web.settings.planSub'), testid: 'settings-plan' })
  if (can('manageUsers')) rows.push({ to: '/settings/integrations', title: t('integrations'), sub: t('web.settings.integrationsSub'), testid: 'settings-integrations' })
  return rows
})

const registerRows = computed<Row[]>(() => {
  if (!session.companyId) return []
  const rows: Row[] = []
  if (can('viewCustomers')) rows.push({ to: '/customers', title: t('customers'), testid: 'settings-customers' })
  if (can('viewServices') || can('viewProducts'))
    rows.push({ to: can('viewServices') ? '/catalog' : '/catalog?kind=product', title: t('web.nav.catalog'), sub: resolveLabel('product._entity_plural', segmentLabels(), t, 'Products'), testid: 'settings-catalog' })
  // Same rule as Avançado in the app: the devices list only with device control on.
  if (session.company?.useDeviceManagement && can('viewDevices') && devicesPlural.value) rows.push({ to: '/devices', title: devicesPlural.value, testid: 'settings-devices' })
  return rows
})

async function leave() {
  leaving.value = false
  await signOutEverywhere()
}

// The app shows "PraticOS {version} ({build})"; the web shows its own build (settings.more-view).
const WEB_VERSION = __WEB_VERSION__
</script>

<template>
  <PageHead :title="t('settings')" :sub="session.email ?? undefined" />
  <div class="workspace">
    <div class="list-pane set-page">
      <section aria-labelledby="set-account" class="set-section">
        <h2 id="set-account" class="set-h">{{ t('yourAccount') }}</h2>
        <ul class="set-list">
          <li>
            <RouterLink class="set-row" to="/settings/account" data-testid="settings-account">
              <span class="set-avatar" aria-hidden="true">{{ (session.name || session.email || '?').trim().charAt(0).toUpperCase() }}</span>
              <span class="set-text">
                <span class="who">{{ session.name || t('yourAccount') }}</span>
                <span v-for="line in accountSub" :key="line" class="sub">{{ line }}</span>
              </span>
              <ChevronRight :size="18" aria-hidden="true" />
            </RouterLink>
          </li>
        </ul>
      </section>

      <section v-if="companyRows.length" aria-labelledby="set-company" class="set-section">
        <h2 id="set-company" class="set-h">{{ companyName || t('web.nav.company') }}</h2>
        <ul class="set-list">
          <li v-for="row in companyRows" :key="row.to">
            <RouterLink class="set-row" :to="row.to" :data-testid="row.testid">
              <span class="set-text">
                <span class="who">{{ row.title }}</span>
                <span v-if="row.sub" class="sub">{{ row.sub }}</span>
              </span>
              <ChevronRight :size="18" aria-hidden="true" />
            </RouterLink>
          </li>
        </ul>
      </section>

      <section v-if="registerRows.length || can('manageForms') || showsContracts" aria-labelledby="set-registers" class="set-section">
        <h2 id="set-registers" class="set-h">{{ t('web.settings.registers') }}</h2>
        <ul class="set-list">
          <li v-for="row in registerRows" :key="row.to">
            <RouterLink class="set-row" :to="row.to" :data-testid="row.testid">
              <span class="set-text">
                <span class="who">{{ row.title }}</span>
                <span v-if="row.sub" class="sub">{{ row.sub }}</span>
              </span>
              <ChevronRight :size="18" aria-hidden="true" />
            </RouterLink>
          </li>
          <li v-if="showsContracts">
            <RouterLink class="set-row" to="/contracts" data-testid="settings-contracts">
              <span class="set-text"><span class="who">{{ t('contracts') }}</span></span>
              <ChevronRight :size="18" aria-hidden="true" />
            </RouterLink>
          </li>
          <li v-if="can('manageForms')">
            <RouterLink class="set-row" to="/checklists" data-testid="settings-checklists">
              <span class="set-text"><span class="who">{{ t('checklistsTitle') }}</span></span>
              <ChevronRight :size="18" aria-hidden="true" />
            </RouterLink>
          </li>
        </ul>
      </section>

      <section aria-labelledby="set-browser" class="set-section">
        <h2 id="set-browser" class="set-h">{{ t('web.settings.thisBrowser') }}</h2>
        <div class="settings-form">
          <div>
            <label class="field-label" for="pref-language">{{ t('language') }}</label>
            <select id="pref-language" v-model="prefs.language" class="field">
              <option value="system">{{ t('web.settings.languageSystem') }}</option>
              <option value="pt">Português</option>
              <option value="en">English</option>
              <option value="es">Español</option>
            </select>
          </div>
          <div>
            <label class="field-label" for="pref-theme">{{ t('theme') }}</label>
            <select id="pref-theme" v-model="prefs.theme" class="field">
              <option value="system">{{ t('web.settings.themeSystem') }}</option>
              <option value="light">{{ t('web.settings.themeLight') }}</option>
              <option value="dark">{{ t('web.settings.themeDark') }}</option>
            </select>
          </div>
          <label class="check-row hide-phone">
            <input v-model="prefs.singleKeyShortcuts" class="check" type="checkbox" />
            <span>{{ t('web.settings.singleKeys') }}</span>
          </label>
        </div>
      </section>

      <InvitesList />

      <div class="set-section">
        <button type="button" class="btn" data-testid="settings-sign-out" @click="leaving = true">{{ t('logout') }}</button>
      </div>
      <p class="sub set-version" data-testid="settings-version">{{ t('web.settings.version', { version: WEB_VERSION }) }}</p>
    </div>
  </div>
  <ConfirmDialog v-if="leaving" :title="t('logoutConfirm')" :confirm="t('logout')" :keep="t('cancel')" @confirm="leave" @close="leaving = false" />
</template>
