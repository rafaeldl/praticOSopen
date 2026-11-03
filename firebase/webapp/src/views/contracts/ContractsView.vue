<script setup lang="ts">
// Contratos (contract.list.*, contract.off.*, contract.title.label): the orders
// that repeat. Ativos (on and paused) and Encerrados, the customer, how often,
// the device and the next order planned. A row opens its order beside the list;
// "Ajustar" opens the schedule (only who edits that order). "Novo contrato"
// opens Nova OS with Repetir on, only with canCreateOrder (the app's "+" did
// not check, defect 36). With Contratos off: what it is for, and "Usar
// contratos" for who manages the company.
//
// Read by field mask (lib/contracts/data.ts), so no value of the orders
// reaches the browser; consultant and technician see only theirs, like the app.
// The web never creates the orders: the app or the server job do.
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import ContractEditor from '@/components/contracts/ContractEditor.vue'
import { loadOrderTexts, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { loadContracts, turnOnContracts, type ContractOrder } from '@/lib/contracts/data'
import { byNext, isTemplate, stateOf, type Contract } from '@/lib/contracts/model'
import { contractsTitle, repeatText, stateText } from '@/lib/contracts/text'
import { toIsoDay } from '@/lib/format'
import { onOrderEvent } from '@/lib/orders/bus'
import { accessOf, canCreateOrders, type Order } from '@/lib/orders/model'
import { orderShort } from '@/lib/orders/text'
import { useRoutePanel } from '@/lib/route-layer'
import { can, effectiveUseFinancial, reloadCompany, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import '@/styles/contracts.css'

const OrderDetail = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderDetail.vue'), loadOrderTexts()]).then(([m]) => m))

type Tab = 'active' | 'ended'
interface Row {
  order: ContractOrder
  contract: Contract
  customer: string
}

const panel = useRoutePanel('order')
const rows = shallowRef<Row[] | null>(null)
const failed = ref(false)
const tab = ref<Tab>('active')
const editing = shallowRef<ContractOrder | null>(null)
const turningOn = ref(false)
const turnOnError = ref('')
const today = toIsoDay(new Date())

const title = computed(() => contractsTitle())
const contractsOn = computed(() => (session.company as { useContracts?: boolean } | null)?.useContracts === true)
const manages = computed(() => can('manageCompany'))
const canCreate = computed(() => contractsOn.value && canCreateOrders(session.role, can('createOrder')))
const state = computed(() => (failed.value ? 'failed' : rows.value === null ? 'loading' : 'ready'))
const visible = computed(() => (rows.value ?? []).filter((row) => (stateOf(row.contract) === 'ended') === (tab.value === 'ended')))

/** Who may change the schedule of this order: who edits its main fields (technician only in quote, consultant only theirs). */
function canEdit(order: ContractOrder): boolean {
  const stub = { status: order.status, createdBy: order.createdBy, showsMoney: false } as unknown as Order
  return accessOf(stub, session.role, session.uid, effectiveUseFinancial()).canEditMainFields
}

function deviceOf(order: ContractOrder): string {
  return order.devices.map((device) => device.name).filter(Boolean).join(', ')
}

async function load() {
  failed.value = false
  try {
    const list = await loadContracts()
    rows.value = list
      .filter((order) => isTemplate(order.isContract, order.contract))
      .map((order) => ({ order, contract: order.contract as Contract, customer: order.customer?.name ?? '' }))
      .sort(byNext)
  } catch (error) {
    console.error('contracts: list failed', error)
    failed.value = true
  }
}

function newContract() {
  ui.newOrderSeed = { repeat: true }
  ui.newOrder = true
}

async function turnOn() {
  if (turningOn.value) return
  turningOn.value = true
  turnOnError.value = ''
  try {
    await turnOnContracts()
    await reloadCompany()
    const message = t('web.contracts.turnedOn')
    showToast(message)
    announce(message)
    void load()
  } catch (error) {
    turnOnError.value = t(errorMessageKey(error))
  } finally {
    turningOn.value = false
  }
}

function onSaved() {
  editing.value = null
  void load()
}

// Read again when coming back to the window and when an order is created or changed here.
const onFocus = () => {
  if (contractsOn.value && !editing.value) void load()
}
let stopBus: (() => void) | undefined
onMounted(() => {
  if (contractsOn.value) void load()
  window.addEventListener('focus', onFocus)
  stopBus = onOrderEvent(() => {
    if (contractsOn.value) void load()
  })
})
onBeforeUnmount(() => {
  window.removeEventListener('focus', onFocus)
  stopBus?.()
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p v-if="contractsOn" class="page-sub">{{ t('contractsSubtitle', { order: orderShort() }) }}</p>
    </div>
    <button v-if="canCreate" type="button" class="btn btn--primary" data-testid="contract-new" @click="newContract">{{ t('contractNew') }}</button>
  </header>

  <div class="workspace" :class="{ 'has-panel': !!panel.value.value }">
    <div class="list-pane contracts-page">
      <div v-if="!contractsOn" class="contracts-off" data-testid="contracts-off">
        <h2>{{ t('contractsOffQuestion') }}</h2>
        <p>{{ t('contractsOffMessage', { order: orderShort() }) }}</p>
        <template v-if="manages">
          <p v-if="turnOnError" class="field-error" role="alert">{{ turnOnError }}</p>
          <button type="button" class="btn btn--primary" data-testid="contracts-turn-on" :aria-disabled="turningOn" @click="turnOn">{{ t('contractsOffAction') }}</button>
        </template>
        <p v-else class="sub" data-testid="contracts-off-others">{{ t('web.contracts.offOthers') }}</p>
      </div>

      <template v-else>
        <div class="tabs contracts-tabs" role="group" :aria-label="title">
          <button type="button" :aria-pressed="tab === 'active'" data-testid="contracts-tab-active" @click="tab = 'active'">
            {{ t('contractsTabActive') }}
          </button>
          <button type="button" :aria-pressed="tab === 'ended'" data-testid="contracts-tab-ended" @click="tab = 'ended'">
            {{ t('contractsTabEnded') }}
          </button>
        </div>

        <LoadingState v-if="state === 'loading'" />
        <ErrorState v-else-if="state === 'failed'" :body="t('web.contracts.loadFailed')" :retry="load" />
        <EmptyState v-else-if="!visible.length" :title="tab === 'active' ? t('noContracts') : t('contractsEmptyEnded')" data-testid="contracts-empty">
          <template v-if="tab === 'active' && canCreate">
            <p>{{ t('web.contracts.emptyAdd', { order: orderShort() }) }}</p>
            <button type="button" class="btn btn--primary" @click="newContract">{{ t('contractNew') }}</button>
          </template>
        </EmptyState>
        <ul v-else class="contracts-list" data-testid="contracts-list">
          <li v-for="row in visible" :key="row.order.id" class="contracts-row" :data-contract="row.order.id">
            <button type="button" class="row-btn contracts-row-main" :aria-current="panel.value.value === row.order.id ? 'true' : undefined" @click="panel.open(row.order.id)">
              <span class="who">{{ row.customer || t('noName') }}</span>
              <span class="sub">{{ [repeatText(row.contract), deviceOf(row.order)].filter(Boolean).join(' · ') }}<template v-if="row.order.number"> · {{ orderShort() }} {{ row.order.number }}</template></span>
              <span class="contract-state" :class="`contract-state--${stateText(row.contract, today).tone}`">
                <span v-if="stateOf(row.contract) === 'paused'" class="dot dot--hollow" aria-hidden="true"></span>
                {{ stateText(row.contract, today).text }}
              </span>
            </button>
            <button
              v-if="stateOf(row.contract) !== 'ended' && canEdit(row.order)"
              type="button"
              class="btn"
              :aria-label="t('web.contracts.adjustNamed', { name: row.customer || t('noName') })"
              @click="editing = row.order"
            >
              {{ t('web.contracts.adjust') }}
            </button>
          </li>
        </ul>
        <p v-if="state === 'ready' && visible.length" class="sub contracts-foot">{{ t('web.contracts.webNeverCreates', { order: orderShort(), title }) }}</p>
      </template>
    </div>
    <aside v-if="panel.value.value" class="panel" :aria-label="t('web.orders.panel')">
      <OrderDetail :key="panel.value.value" :order-id="panel.value.value" @close="panel.close()" />
    </aside>
  </div>

  <ContractEditor v-if="editing" :key="editing.id" :order="editing" @saved="onSaved" @close="editing = null" />
</template>
