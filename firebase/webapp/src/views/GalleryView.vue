<script setup lang="ts">
// Base components in one place, for E2E, axe and design review. Emulator builds only.
import { ref } from 'vue'
import Combobox, { type ComboboxGroup } from '@/components/Combobox.vue'
import DateField from '@/components/DateField.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import PageHead from '@/components/PageHead.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { api, session } from '@/lib/session'
import { matchesWords } from '@/lib/text'
import { showToast } from '@/lib/toast'

const dialog = ref(false)
const drawer = ref(false)
const sheet = ref(false)
const typed = ref('')
const money = ref<number | null>(90)
const day = ref<string | null>('2026-11-02')
const picked = ref<string | null>(null)
const apiResult = ref('')

const OPTIONS = ['Alfa', 'Bravo', 'Charlie', 'Delta'].map((label) => ({ id: label.toLowerCase(), label }))
const groups = (query: string): ComboboxGroup[] => [
  { title: t('web.gallery.options'), items: OPTIONS.filter((item) => matchesWords(item.label, query)) },
]

// Drawer with unsaved text asks before closing, Voltar included.
const confirmDiscard = () => !typed.value || window.confirm(t('web.gallery.discard'))

function toastWithUndo() {
  const before = money.value
  money.value = 0
  showToast(t('web.gallery.changed'), { undo: () => (money.value = before) })
}

async function callApi() {
  try {
    await api('/v1/app/orders/does-not-exist')
    apiResult.value = 'ok'
  } catch (error) {
    apiResult.value = t(errorMessageKey(error))
  }
}
</script>

<template>
  <PageHead :title="t('web.gallery.title')" />
  <div class="workspace gallery">
    <section class="gallery-sec">
      <MoneyInput id="g-money" v-model="money" :label="t('web.gallery.price')" :country="session.company?.country" />
      <p class="sub" data-testid="money-value">{{ money }}</p>
      <DateField id="g-date" v-model="day" :label="t('date')" :country="session.company?.country" />
      <Combobox id="g-combo" :label="t('web.gallery.choose')" :groups="groups" :selected-id="picked" @pick="(item) => (picked = item.id)" />
      <p class="sub" data-testid="combo-value">{{ picked }}</p>
    </section>
    <section class="gallery-sec">
      <div class="gallery-row">
        <StatusLabel status="quote" /><StatusLabel status="approved" /><StatusLabel status="progress" />
        <StatusLabel status="done" /><StatusLabel status="canceled" /><StatusLabel status="progress" :late-days="2" />
      </div>
      <div class="gallery-row">
        <button type="button" class="btn btn--primary" @click="toastWithUndo">{{ t('web.gallery.toast') }}</button>
        <button type="button" class="btn" @click="dialog = true">{{ t('web.gallery.dialog') }}</button>
        <button type="button" class="btn" @click="drawer = true">{{ t('web.gallery.drawer') }}</button>
        <button type="button" class="btn" @click="sheet = true">{{ t('web.gallery.sheet') }}</button>
        <button type="button" class="btn" @click="callApi">{{ t('web.gallery.api') }}</button>
        <RouterLink class="btn" to="/orders?order=order-1">{{ t('web.gallery.openOrder') }}</RouterLink>
      </div>
      <p class="sub" data-testid="api-result">{{ apiResult }}</p>
      <EmptyState :title="t('web.gallery.emptyTitle')" :body="t('web.gallery.emptyBody')" />
      <LoadingState />
      <ErrorState :retry="() => {}" />
    </section>
  </div>

  <Layer v-if="dialog" v-slot="{ close }" :label="t('web.gallery.dialog')" @close="dialog = false">
    <div class="layer-head"><h2 class="layer-title">{{ t('web.gallery.dialog') }}</h2></div>
    <div class="layer-body"><p>{{ t('web.gallery.emptyBody') }}</p></div>
    <div class="layer-foot">
      <button type="button" class="btn" @click="close">{{ t('cancel') }}</button>
      <button type="button" class="btn btn--primary" data-autofocus @click="close">{{ t('confirm') }}</button>
    </div>
  </Layer>
  <Layer v-if="drawer" v-slot="{ close }" kind="drawer" :label="t('web.gallery.drawer')" :guard="confirmDiscard" @close="drawer = false">
    <div class="layer-head"><h2 class="layer-title">{{ t('web.gallery.drawer') }}</h2></div>
    <div class="layer-body">
      <label class="field-label" for="g-note">{{ t('notes') }}</label>
      <textarea id="g-note" v-model="typed" class="field" data-autofocus></textarea>
    </div>
    <div class="layer-foot">
      <button type="button" class="btn" @click="close">{{ t('cancel') }}</button>
      <button type="button" class="btn" @click="dialog = true">{{ t('web.gallery.dialog') }}</button>
    </div>
  </Layer>
  <Layer v-if="sheet" kind="sheet" :label="t('web.gallery.sheet')" @close="sheet = false">
    <div class="layer-body"><p>{{ t('web.gallery.emptyBody') }}</p></div>
  </Layer>
</template>
