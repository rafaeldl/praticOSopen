<script setup lang="ts">
// The contract on the order's screen (order.contract.card, .children,
// .open-parent, .enable): how it repeats and the next order planned, with
// "Ajustar"; the orders it created; on a created order, the one it came from.
// Without a contract, "Repetir esta OS" for who edits the order, only with
// Contratos on. Read by field mask (lib/contracts/data.ts): no money.
import { computed, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import ContractEditor from './ContractEditor.vue'
import { t } from '@/i18n'
import { loadContractOrder, loadGenerated, type ContractOrder } from '@/lib/contracts/data'
import { isTemplate } from '@/lib/contracts/model'
import { repeatText, stateText } from '@/lib/contracts/text'
import { toIsoDay } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { orderShort, statusText } from '@/lib/orders/text'
import type { OrderStatus } from '@/lib/orders/model'
import { session } from '@/lib/session'
import { ensurePlanFeature } from '@/lib/plan-feature-gate'
import '@/styles/contracts.css'

const props = defineProps<{ order: Order; canEdit: boolean }>()

const route = useRoute()
const router = useRouter()
const data = shallowRef<ContractOrder | null>(null)
const failed = ref(false)
const generated = shallowRef<ContractOrder[] | null>(null)
const editing = ref(false)
const today = toIsoDay(new Date())

const template = computed(() => (data.value && isTemplate(data.value.isContract, data.value.contract) ? data.value.contract : null))
const parent = computed(() => (data.value?.contract?.parentOrderId ? data.value.contract : null))
const contractsOn = computed(() => (session.company as { useContracts?: boolean } | null)?.useContracts === true)
const canEnable = computed(() => props.canEdit && contractsOn.value && !!data.value && !template.value && !parent.value && props.order.status !== 'canceled')
const line = computed(() => (template.value ? stateText(template.value, today) : null))
const sortedGenerated = computed(() => [...(generated.value ?? [])].sort((a, b) => (b.number ?? 0) - (a.number ?? 0)))

async function load() {
  failed.value = false
  try {
    data.value = await loadContractOrder(props.order.id)
    if (template.value) generated.value = await loadGenerated(props.order.id)
  } catch (error) {
    console.warn('contracts: order contract not read', error)
    failed.value = true
  }
}

function open(id: string) {
  void router.push({ query: { ...route.query, order: id } })
}

onMounted(load)
// Saved elsewhere (status, items): read the contract again with the new version.
watch(() => props.order.version, () => void load())
</script>

<template>
  <section v-if="template || parent || canEnable || failed" class="od-sec od-contract" aria-labelledby="od-contract-title" data-testid="order-contract">
    <h3 id="od-contract-title">{{ t('contract') }}</h3>
    <p v-if="failed" class="sub">
      {{ t('web.contracts.loadFailed') }} <button type="button" class="link" @click="load">{{ t('web.tryAgain') }}</button>
    </p>
    <template v-else-if="template">
      <p class="od-contract-repeat"><strong>{{ repeatText(template) }}</strong></p>
      <p v-if="line" class="contract-state" :class="`contract-state--${line.tone}`" data-testid="order-contract-next">{{ line.text }}</p>
      <button v-if="canEdit" type="button" class="btn" data-testid="order-contract-adjust" @click="editing = true">{{ t('web.contracts.adjust') }}</button>
      <div class="od-contract-generated">
        <h4 class="picker-h">{{ t('web.contracts.generatedTitle', { order: orderShort() }) }}</h4>
        <p v-if="generated && !sortedGenerated.length" class="sub">{{ t('web.contracts.generatedNone') }}</p>
        <ul v-else-if="generated" class="od-contract-list" data-testid="order-contract-generated">
          <li v-for="child in sortedGenerated" :key="child.id">
            <button type="button" class="link" @click="open(child.id)">{{ orderShort() }} {{ child.number ?? '' }}</button>
            <span class="sub"> · {{ statusText(child.status as OrderStatus) }}</span>
          </li>
        </ul>
      </div>
    </template>
    <p v-else-if="parent">
      <button type="button" class="link" data-testid="order-contract-parent" @click="open(parent.parentOrderId as string)">
        {{ t('web.contracts.fromParent', { order: orderShort(), number: parent.parentOrderNumber ?? '' }) }}
      </button>
    </p>
    <template v-else-if="canEnable">
      <p class="sub">{{ t('contractsRowHint') }}</p>
      <button type="button" class="btn" data-testid="order-contract-enable" @click="ensurePlanFeature('contracts') && (editing = true)">{{ t('web.contracts.repeatThis', { order: orderShort() }) }}</button>
    </template>
    <ContractEditor v-if="editing && data" :order="data" @saved="editing = false; load()" @close="editing = false" />
  </section>
</template>
