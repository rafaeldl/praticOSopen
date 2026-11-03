<script setup lang="ts">
// "Receber" and "Dar desconto". The id of the transaction is made once when the
// dialog opens: pressing again after a network failure sends the same id, and
// the server books it once (WEB_API, clientTransactionId).
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { newTransactionId } from '@/lib/orders/writes'
import { country, money } from '@/lib/orders/text'
import { roundMoney } from '@/lib/rules/order-rules'

const props = defineProps<{ kind: 'receive' | 'discount'; remaining: number; total: number; busy?: boolean }>()
const emit = defineEmits<{ save: [value: { amount: number; paymentMethod?: string; clientTransactionId: string }]; close: [] }>()

const transactionId = newTransactionId()
const amount = ref<number | null>(props.kind === 'receive' ? props.remaining : null)
const method = ref('')
const title = computed(() => (props.kind === 'receive' ? t('receiveTitle') : t('receiveGiveDiscount')))
// Never above what is left, like ReceivePaymentSheet (max: remaining). The balance follows the order live.
const tooMuch = computed(() => (amount.value ?? 0) > props.remaining + 0.001)
const valid = computed(() => (amount.value ?? 0) > 0 && !tooMuch.value)
const preview = computed(() =>
  props.kind === 'discount' && valid.value
    ? t('receiveDiscountNewTotal', { from: money(props.total), to: money(roundMoney(props.total - (amount.value ?? 0))) })
    : '',
)
const METHODS = [
  { id: 'pix', label: () => t('paymentMethodPix') },
  { id: 'cash', label: () => t('paymentMethodCash') },
  { id: 'card', label: () => t('paymentMethodCard') },
  { id: 'other', label: () => t('paymentMethodOther') },
]

function save() {
  if (!valid.value || props.busy) return
  emit('save', { amount: amount.value as number, ...(method.value ? { paymentMethod: method.value } : {}), clientTransactionId: transactionId })
}
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ title }}</h2>
          <p class="sub">{{ t('receiveMissing') }}: <span class="num">{{ money(remaining) }}</span></p>
        </div>
        <div class="layer-body">
          <MoneyInput id="money-amount" v-model="amount" :label="kind === 'receive' ? t('receiveCustomerAmountLabel') : t('discount')" :country="country()" required />
          <p v-if="tooMuch" class="field-error" role="alert">{{ kind === 'discount' ? t('web.order.discountTooMuch', { amount: money(remaining) }) : t('web.order.receiveTooMuch', { amount: money(remaining) }) }}</p>
          <p v-else-if="preview" class="sub">{{ preview }}</p>
          <template v-if="kind === 'receive'">
            <label class="field-label" for="money-method">{{ t('receivePaymentMethodQuestion') }} <span class="muted">({{ t('receivePaymentMethodOptional') }})</span></label>
            <select id="money-method" v-model="method" class="field">
              <option value="">{{ t('receivePaymentMethodNone') }}</option>
              <option v-for="item in METHODS" :key="item.id" :value="item.id">{{ item.label() }}</option>
            </select>
          </template>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="!valid || busy">
            {{ kind === 'receive' ? t('receiveMarkReceived') : t('receiveGiveDiscount') }}
          </button>
        </div>
      </form>
    </template>
  </Layer>
</template>
