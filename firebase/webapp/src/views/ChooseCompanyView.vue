<script setup lang="ts">
// More than one company: pick where to work, as the app's "Escolher conta".
import { useRoute, useRouter } from 'vue-router'
import AppLogo from '@/components/AppLogo.vue'
import { t, type MessageKey } from '@/i18n'
import { selectCompany, session } from '@/lib/session'

const route = useRoute()
const router = useRouter()

const ROLE_LABELS: Record<string, MessageKey> = {
  owner: 'roleAdmin',
  admin: 'roleAdmin',
  manager: 'roleManager',
  supervisor: 'roleSupervisor',
  consultant: 'roleConsultant',
  technician: 'roleTechnician',
}

async function choose(companyId: string) {
  await selectCompany(companyId)
  const next = route.query.next
  await router.replace(typeof next === 'string' && next.startsWith('/') && !next.startsWith('//') ? next : '/')
}
</script>

<template>
  <div class="entry">
    <aside class="entry-side"><AppLogo /></aside>
    <main class="entry-main">
      <div class="entry-box">
        <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.chooseCompany.title') }}</h1>
        <p class="muted">{{ t('web.chooseCompany.sub') }}</p>
        <div class="choose-list">
          <button v-for="company in session.companies" :key="company.id" type="button" class="choose-row" @click="choose(company.id)">
            <strong>{{ company.name || t('web.nav.unnamedCompany') }}</strong>
            <span v-if="ROLE_LABELS[company.role]" class="sub">{{ t(ROLE_LABELS[company.role] as MessageKey) }}</span>
          </button>
        </div>
      </div>
    </main>
  </div>
</template>
