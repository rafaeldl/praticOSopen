<script setup lang="ts">
import { useRouter } from 'vue-router'
import InvitesList from '@/components/InvitesList.vue'
import PageHead from '@/components/PageHead.vue'
import { t } from '@/i18n'
import { prefs } from '@/lib/prefs'
import { can, session, signOutEverywhere } from '@/lib/session'

const router = useRouter()

async function leave() {
  await signOutEverywhere()
  await router.replace({ name: 'login' })
}
</script>

<template>
  <PageHead :title="t('settings')" :sub="session.email ?? undefined" />
  <div class="workspace settings">
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
      <RouterLink v-if="can('manageForms')" class="btn" to="/checklists" data-testid="settings-checklists">{{ t('checklistsTitle') }}</RouterLink>
      <InvitesList />
      <button type="button" class="btn" @click="leave">{{ t('logout') }}</button>
    </div>
  </div>
</template>
