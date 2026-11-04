<script setup lang="ts">
// "Manutenções chegando" (home.maintenance.list/more/open/call/new-order/view-device):
// a reminder above the open lists. A failure only hides the section, as in the app.
import { computed, nextTick, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { formatDate, formatMonthYear, fromIsoDay, toIsoDay } from '@/lib/format'
import { canCreateOrders } from '@/lib/orders/model'
import { customerPhone, firstName, isLate, lastServices, loadMaintenances, SHOWN, type Maintenance } from '@/lib/orders/maintenance'
import { country, deviceLabel } from '@/lib/orders/text'
import { whatsappNumber } from '@/lib/phone'
import { whatsappUrl } from '@/lib/share'
import { LAYER_PARAM, queryValues } from '@/lib/route-layer'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { ui } from '@/lib/ui'

const route = useRoute()
const router = useRouter()
const items = shallowRef<Maintenance[]>([])
const all = ref(false)
const open = ref<Maintenance | null>(null)
const phone = ref<{ state: 'loading' } | { state: 'ready'; href: string | null; gone: boolean }>({ state: 'loading' })
const today = ref(toIsoDay(new Date()))
const canCreate = computed(() => canCreateOrders(session.role, can('createOrder')))
const shown = computed(() => (all.value ? items.value : items.value.slice(0, SHOWN)))
const hidden = computed(() => items.value.length - shown.value.length)
const date = (item: Maintenance) => formatDate(fromIsoDay(item.day), country())

function subtitle(item: Maintenance): string {
  return [item.customer?.name?.trim(), item.lastService ? t('maintenanceLastService', { service: item.lastService }) : '']
    .filter(Boolean)
    .join(' · ')
}

function message(item: Maintenance): string {
  const name = firstName(item.customer?.name)
  const when = formatMonthYear(fromIsoDay(item.day), country())
  return name ? t('maintenanceWhatsappMessage', { customer: name, device: item.name, date: when }) : t('maintenanceWhatsappMessageNoName', { device: item.name, date: when })
}

async function choose(item: Maintenance) {
  open.value = item
  phone.value = { state: 'loading' }
  const id = item.customer?.id
  if (!id) return
  try {
    const found = await customerPhone(id)
    if (open.value?.id !== item.id) return
    const number = found.kind === 'phone' ? whatsappNumber(found.phone, country()) : ''
    phone.value = { state: 'ready', href: number ? whatsappUrl(number, message(item)) : null, gone: found.kind === 'gone' }
  } catch (error) {
    console.warn('maintenance: phone not read', error)
    if (open.value?.id === item.id) phone.value = { state: 'ready', href: null, gone: false }
  }
}

/** Without a number nothing opens: the reason, never a dead link. */
function noPhone() {
  if (phone.value.state !== 'ready') return
  showToast(phone.value.gone ? t('web.maintenance.customerGone', { device: deviceLabel().toLocaleLowerCase() }) : t('maintenanceNoPhone'))
}

/** The sheet's history entry is gone before Nova OS adds its own. */
function layersGone(): Promise<void> {
  return new Promise((resolve) => {
    const count = () => queryValues(route.query, LAYER_PARAM).length
    const timer = setTimeout(() => done(), 1000)
    const stop = watch(count, (value) => value === 0 && done())
    function done() {
      clearTimeout(timer)
      stop()
      resolve()
    }
    if (!count()) done()
  })
}

/** "Abrir OS": Nova OS with the customer, the device and the last finished order's services. Nothing is saved before "Salvar". */
async function newOrder(item: Maintenance) {
  const items = await lastServices(item.id)
  open.value = null
  await nextTick()
  await layersGone()
  ui.newOrderSeed = {
    ...(item.customer?.id ? { customer: { id: item.customer.id, name: item.customer.name ?? '' } } : {}),
    device: { id: item.id, name: item.name, serial: item.serial },
    items,
  }
  ui.newOrder = true
}

/** Leaving Início closes the sheet with it. */
const viewDevice = (item: Maintenance) => void router.push({ path: '/devices', query: { device: item.id } })

onMounted(async () => {
  try {
    items.value = await loadMaintenances()
  } catch (error) {
    console.warn('maintenance: not loaded', error)
  }
})
</script>

<template>
  <section v-if="items.length" class="maint" :aria-labelledby="'maint-title'" data-testid="maintenances">
    <h2 id="maint-title" class="maint-title">{{ t('maintenanceComing') }}</h2>
    <ul class="maint-list">
      <li v-for="item in shown" :key="item.id">
        <button type="button" class="maint-row" @click="choose(item)">
          <span class="maint-main">
            <span class="who">{{ item.name }}</span>
            <span v-if="subtitle(item)" class="sub">{{ subtitle(item) }}</span>
          </span>
          <span class="num maint-day" :class="{ 'is-late': isLate(item.day, today) }" :data-testid="isLate(item.day, today) ? 'maintenance-late' : undefined">{{ date(item) }}</span>
        </button>
      </li>
    </ul>
    <button v-if="hidden > 0" type="button" class="link maint-more" @click="all = true">{{ t('maintenanceShowMore', { count: hidden }) }}</button>
  </section>

  <Layer v-if="open" kind="sheet" :label="open.name" @close="open = null">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ open.name }}</h2>
        <p class="sub">{{ [open.customer?.name?.trim(), date(open)].filter(Boolean).join(' · ') }}</p>
      </div>
      <div class="layer-body">
        <div class="opts maint-opts">
          <template v-if="open.customer?.id">
            <a v-if="phone.state === 'ready' && phone.href" class="btn btn--wide" :href="phone.href" target="_blank" rel="noopener" @click="close()">{{ t('maintenanceCallCustomer') }}</a>
            <button v-else type="button" class="btn btn--wide" :disabled="phone.state === 'loading'" @click="noPhone">{{ t('maintenanceCallCustomer') }}</button>
          </template>
          <button v-if="canCreate" type="button" class="btn btn--wide" @click="newOrder(open)">{{ t('maintenanceOpenOrder') }}</button>
          <button type="button" class="btn btn--wide" @click="viewDevice(open)">{{ t('maintenanceViewDevice', { device: deviceLabel() }) }}</button>
          <button type="button" class="btn btn--ghost btn--wide" @click="close()">{{ t('cancel') }}</button>
        </div>
      </div>
    </template>
  </Layer>
</template>

<style scoped>
.maint { margin: 0 0 0.75rem; }
.maint-title { font-size: 0.8125rem; font-weight: 600; color: var(--color-muted); text-transform: uppercase; letter-spacing: 0.04em; margin: 0 0 0.25rem; }
.maint-list { list-style: none; margin: 0; padding: 0; border-top: 1px solid var(--color-rule); }
.maint-row { display: flex; align-items: center; gap: 0.75rem; width: 100%; min-height: 2.75rem; padding: 0.5rem 0.25rem; border: 0; border-bottom: 1px solid var(--color-rule); background: transparent; color: var(--color-ink); text-align: left; cursor: pointer; }
.maint-row:hover { background: var(--color-paper-2); }
.maint-main { display: grid; gap: 0.1rem; min-width: 0; flex: 1; }
.maint-main .who { font-weight: 600; overflow-wrap: anywhere; }
.maint-day { flex: none; }
.maint-day.is-late { color: var(--color-danger-text); font-weight: 700; }
.maint-more { min-height: 2.75rem; }
.maint-opts { display: grid; gap: 0.5rem; }
</style>
