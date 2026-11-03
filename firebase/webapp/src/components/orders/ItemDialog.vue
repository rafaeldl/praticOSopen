<script setup lang="ts">
// One line of the order: description, price (only who sees values) and
// quantity (only parts, at least 1). An empty price means "sem valor".
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import type { OrderLine } from '@/lib/orders/model'
import { country, lineKindText, money } from '@/lib/orders/text'
import { roundMoney } from '@/lib/rules/order-rules'

const props = defineProps<{ line: OrderLine; showsMoney: boolean; canEditPrice: boolean; busy?: boolean }>()
const emit = defineEmits<{ save: [patch: { description?: string; value?: number | null; quantity?: number }]; remove: []; close: [] }>()

const description = ref(props.line.description && props.line.description !== props.line.name ? props.line.description : '')
const value = ref<number | null>(props.line.value ?? null)
const quantity = ref(props.line.quantity ?? 1)
const total = computed(() => (value.value === null ? null : roundMoney(value.value * (props.line.kind === 'product' ? quantity.value : 1))))

function save() {
  if (props.busy) return
  const patch: { description?: string; value?: number | null; quantity?: number } = {}
  const before = props.line.description && props.line.description !== props.line.name ? props.line.description : ''
  if (description.value.trim() !== before) patch.description = description.value.trim()
  if (props.showsMoney && props.canEditPrice && value.value !== (props.line.value ?? null)) patch.value = value.value
  if (props.line.kind === 'product' && quantity.value !== (props.line.quantity ?? 1)) patch.quantity = Math.max(1, Math.round(quantity.value))
  emit('save', patch)
}
</script>

<template>
  <Layer kind="sheet" :label="line.name" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ line.name }}</h2>
          <p class="sub">{{ lineKindText(line.kind) }}</p>
        </div>
        <div class="layer-body">
          <label class="field-label" for="item-description">{{ t('orderItemDescription') }}</label>
          <input id="item-description" v-model="description" class="field" maxlength="500" data-autofocus aria-describedby="item-description-hint" />
          <p id="item-description-hint" class="sub">{{ t('orderItemDescriptionHint') }}</p>
          <template v-if="showsMoney && canEditPrice">
            <MoneyInput id="item-price" v-model="value" :label="t('orderItemPrice')" :country="country()" />
            <p class="sub">{{ t('orderItemPriceHint') }}</p>
          </template>
          <div v-if="line.kind === 'product'" class="qty">
            <label class="field-label" for="item-quantity">{{ t('orderItemQuantity') }}</label>
            <div class="qty-row">
              <button type="button" class="btn" :aria-label="t('orderItemLess')" :disabled="quantity <= 1" @click="quantity = Math.max(1, quantity - 1)">−</button>
              <input id="item-quantity" v-model.number="quantity" class="field num qty-input" type="number" min="1" step="1" inputmode="numeric" />
              <button type="button" class="btn" :aria-label="t('orderItemMore')" @click="quantity += 1">+</button>
            </div>
          </div>
          <p v-if="showsMoney && total !== null" class="sub">{{ t('total') }}: <span class="num">{{ money(total) }}</span></p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn btn--ghost btn--danger" :disabled="busy" @click="emit('remove')">{{ t('orderItemRemove') }}</button>
          <span class="spacer"></span>
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="busy">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
