<script setup lang="ts">
// "Para quem vai a nota?" (customer.detail.invoice-recipient): the other
// customers, "Nenhum" first, ✓ on the current one, search above 10. Picking
// saves "Nota fiscal para" through the API (the server copies the summary).
import { computed, ref } from 'vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { changedSince, saveCustomer } from '@/lib/customers/data'
import { customerMatches, byName, type CustomerRow } from '@/lib/customers/model'
import { formatTaxId } from '@/lib/tax-id'
import { showToast } from '@/lib/toast'

const NONE = '__none__'
const props = defineProps<{
  customer: { id: string; name: string; invoiceRecipient?: { id: string; name: string } | null }
  version?: string | null
  directory: CustomerRow[]
}>()
const emit = defineEmits<{ saved: [recipient: { id: string; name: string } | null]; changed: []; close: [] }>()

const query = ref('')
const busy = ref(false)
const others = computed(() => props.directory.filter((row) => row.id !== props.customer.id).sort(byName))
const current = computed(() => props.customer.invoiceRecipient?.id ?? null)
const choices = computed<Choice[]>(() => [
  ...(query.value.trim() ? [] : [{ id: NONE, label: t('invoiceRecipientNone'), current: current.value === null }]),
  ...others.value
    .filter((row) => customerMatches({ ...row, name: `${row.legalName ?? ''} ${row.name}` }, query.value))
    .map((row) => ({
      id: row.id,
      label: row.legalName || row.name,
      sub: [row.legalName && row.legalName !== row.name ? row.name : '', row.taxId ? formatTaxId(row.taxId) : ''].filter(Boolean).join(' · ') || undefined,
      current: row.id === current.value,
    })),
])

async function pick(id: string) {
  if (busy.value) return
  const next = id === NONE ? null : (others.value.find((row) => row.id === id) ?? null)
  if ((next?.id ?? null) === current.value) return emit('close')
  busy.value = true
  try {
    await saveCustomer(props.customer.id, { invoiceRecipientId: next?.id ?? null, ...(props.version ? { version: props.version } : {}) })
    emit('saved', next ? { id: next.id, name: next.name } : null)
  } catch (error) {
    if (changedSince(error)) return emit('changed')
    console.warn('customer: invoice recipient not saved', error)
    showToast(`${t('customerSaveError')} ${t(errorMessageKey(error))}`.trim())
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <ChoiceDialog :title="t('invoiceRecipientPickerTitle')" :sub="customer.name" :choices="choices" @pick="pick" @close="emit('close')">
    <input
      v-if="others.length > 10"
      v-model="query"
      class="field"
      type="search"
      autocomplete="off"
      :aria-label="t('invoiceRecipientPickerTitle')"
      data-autofocus
      data-testid="invoice-recipient-search"
    />
  </ChoiceDialog>
</template>
