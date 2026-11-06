<script setup lang="ts">
// "+ Cadastrar «X»" inside the order (order.quick.*): instead of saving the name
// alone, a small block asks the one or two fields companies really fill. All
// optional but the name: Enter registers and the order goes on; Esc goes back to
// the search; "Mais dados" hands the draft to the full form.
import { computed, nextTick, onMounted, reactive, ref, toRef } from 'vue'
import MoneyInput from '@/components/MoneyInput.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { findByPhone, serialError } from '@/lib/customers/model'
import { fieldMasks, segmentField, useMask } from '@/lib/segment-fields'
import { productWord, resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import type { CatalogItem, Customer, Device } from '@/lib/orders/catalog'
import { createCustomer, createDevice, createItem, customerDraft, deviceDraft, registerKinds } from '@/lib/orders/quick-create'
import { country as companyCountry, deviceLabel, lineKindText } from '@/lib/orders/text'

type Kind = 'customer' | 'device' | 'item'
const props = defineProps<{
  kind: Kind
  /** What was typed in the search. */
  text: string
  id: string
  /** Every customer, for the repeated phone (customer only). */
  customers?: Customer[]
}>()
const emit = defineEmits<{
  saved: [record: Customer | Device | CatalogItem]
  /** The phone is another customer's: use that one. */
  use: [customer: Customer]
  /** "Mais dados": the full form with what was typed. */
  more: [draft: { name: string; phone?: string; serial?: string }]
  cancel: []
}>()

const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const country = computed(() => session.company?.country)
const kinds = registerKinds()
const form = reactive({
  ...(props.kind === 'customer' ? customerDraft(props.text) : { name: '', phone: '' }),
  ...(props.kind === 'device' ? deviceDraft(props.text) : { serial: '' }),
  ...(props.kind === 'item' ? { name: props.text.trim() } : {}),
  itemKind: (kinds[0] ?? 'service') as CatalogItem['kind'],
  value: null as number | null,
})
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const root = ref<HTMLElement | null>(null)

const onPhone = useMask(toRef(form, 'phone'), () => fieldMasks(segmentField('customer.phone'), country.value))
const onSerial = useMask(toRef(form, 'serial'), () => fieldMasks(segmentField('device.serial'), country.value), (text) => text.toUpperCase())

const title = computed(() => (props.kind === 'customer' ? t('web.quick.newCustomer') : props.kind === 'device' ? t('web.quick.newDevice', { device: deviceLabel() }) : t('web.quick.newItem', { product: productWord(t('orderItemPartWord')) })))
const duplicate = computed(() => {
  if (props.kind !== 'customer' || !form.phone.trim()) return null
  const found = findByPhone((props.customers ?? []).map((c) => ({ ...c, phone: c.phone ?? null })), form.phone, country.value)
  return found ? ((props.customers ?? []).find((c) => c.id === found.id) ?? null) : null
})
const serialProblem = computed(() => (props.kind === 'device' ? serialError(form.serial, form.name, segmentField('device.serial')?.pattern) : null))
const nameMissing = computed(() => props.kind !== 'device' && !form.name.trim())
const editPrices = can('viewPrices') && can('editPrices')

// The cursor goes to what is still empty: the phone after a name, the name after a phone, the plate after a model.
// Marked with data-autofocus for a sheet (Layer focuses it) and focused here when inline.
const first =
  props.kind === 'customer' ? (form.name ? 'phone' : 'name') : props.kind === 'device' ? (form.name ? 'serial' : 'name') : editPrices ? 'value' : kinds.length > 1 ? `kind-${form.itemKind}` : 'name'
const auto = (field: string) => (field === first ? '' : undefined)
onMounted(async () => {
  await nextTick()
  ;(document.getElementById(`${props.id}-${first}`) as HTMLInputElement | null)?.focus()
})

async function save() {
  if (saving.value) return
  tried.value = true
  if (nameMissing.value) {
    failed.value = props.kind === 'customer' ? t('customerSaveNeedsName') : t('web.quick.needsName')
    document.getElementById(`${props.id}-name`)?.focus()
    return
  }
  if (serialProblem.value) {
    failed.value = serialProblem.value === 'required' ? t('deviceSaveNeedsAny', { first: label('device.model').toLocaleLowerCase(), second: label('device.serial').toLocaleLowerCase() }) : t('invalidFormat')
    document.getElementById(`${props.id}-serial`)?.focus()
    return
  }
  saving.value = true
  failed.value = ''
  try {
    if (props.kind === 'customer') emit('saved', await createCustomer({ name: form.name, phone: form.phone }))
    else if (props.kind === 'device') emit('saved', await createDevice({ name: form.name, serial: form.serial }))
    else emit('saved', await createItem({ name: form.name, kind: form.itemKind, value: form.value }))
  } catch (error) {
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && !event.ctrlKey && !event.metaKey && !(event.target instanceof HTMLButtonElement)) {
    event.preventDefault()
    event.stopPropagation()
    void save()
  } else if (event.key === 'Escape') {
    event.preventDefault()
    event.stopPropagation()
    emit('cancel')
  }
}

const more = () => emit('more', { name: form.name.trim(), ...(props.kind === 'customer' ? { phone: form.phone.trim() } : {}), ...(props.kind === 'device' ? { serial: form.serial.trim() } : {}) })
defineExpose({ save, root })
</script>

<template>
  <div ref="root" class="quick" role="group" :aria-labelledby="`${id}-title`" :data-testid="`quick-${kind}`" @keydown="onKeydown">
    <div class="quick-head">
      <strong :id="`${id}-title`">{{ title }}</strong>
      <button v-if="kind !== 'item'" type="button" class="link small" :data-testid="`quick-${kind}-more`" @click="more">{{ t('web.customers.moreData') }}</button>
    </div>
    <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
    <div class="quick-fields">
      <template v-if="kind === 'customer'">
        <div>
          <label class="field-label" :for="`${id}-name`">{{ label('customer.name') }}</label>
          <input :id="`${id}-name`" v-model="form.name" class="field" autocomplete="off" :aria-invalid="tried && nameMissing" :data-autofocus="auto('name')" />
        </div>
        <div>
          <label class="field-label" :for="`${id}-phone`">{{ t('customerPhoneLabel') }}</label>
          <input :id="`${id}-phone`" :value="form.phone" class="field" type="tel" inputmode="tel" autocomplete="off" :data-autofocus="auto('phone')" :aria-describedby="`${id}-phone-hint`" @input="onPhone" />
        </div>
      </template>
      <template v-else-if="kind === 'device'">
        <div>
          <label class="field-label" :for="`${id}-name`">{{ label('device.model') }}</label>
          <input :id="`${id}-name`" v-model="form.name" class="field" autocomplete="off" :data-autofocus="auto('name')" />
        </div>
        <div>
          <label class="field-label" :for="`${id}-serial`">{{ label('device.serial') }}</label>
          <input
            :id="`${id}-serial`"
            :value="form.serial"
            class="field num"
            autocomplete="off"
            autocapitalize="characters"
            :data-autofocus="auto('serial')"
            :placeholder="segmentField('device.serial')?.placeholder ?? ''"
            :aria-invalid="tried && !!serialProblem"
            @input="onSerial"
          />
        </div>
      </template>
      <template v-else>
        <div class="quick-wide">
          <label class="field-label" :for="`${id}-name`">{{ t('web.quick.itemName') }}</label>
          <input :id="`${id}-name`" v-model="form.name" class="field" autocomplete="off" :aria-invalid="tried && nameMissing" :data-autofocus="auto('name')" />
        </div>
        <div v-if="kinds.length > 1" role="radiogroup" :aria-label="t('web.quick.itemKind')">
          <span class="field-label" aria-hidden="true">{{ t('web.quick.itemKind') }}</span>
          <div class="chips">
            <button
              v-for="option in kinds"
              :id="`${id}-kind-${option}`"
              :key="option"
              type="button"
              class="chip"
              role="radio"
              :aria-checked="form.itemKind === option"
              :aria-pressed="form.itemKind === option"
              :data-autofocus="auto(`kind-${option}`)"
              @click="form.itemKind = option"
            >{{ lineKindText(option) }}</button>
          </div>
        </div>
        <MoneyInput v-if="editPrices" :id="`${id}-value`" :data-autofocus="auto('value')" v-model="form.value" :label="t('price')" :country="companyCountry()" />
      </template>
    </div>
    <div class="quick-foot">
      <p v-if="duplicate" class="sub small" role="status" data-testid="quick-duplicate">
        {{ t('web.quick.phoneOf', { name: duplicate.name }) }}
        <button type="button" class="link" @click="emit('use', duplicate)">{{ t('web.quick.useCustomer', { name: duplicate.name }) }}</button>
      </p>
      <p v-else-if="kind === 'customer'" :id="`${id}-phone-hint`" class="sub small">{{ t('web.quick.phoneOptional') }}</p>
      <span v-else></span>
      <span class="quick-btns">
        <button type="button" class="btn btn--small" @click="emit('cancel')">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--small btn--primary" :disabled="saving" :data-testid="`quick-${kind}-save`" @click="save">
          {{ saving ? t('web.newOrder.saving') : kind === 'item' ? t('web.quick.registerAndAdd') : t('web.quick.register') }} <kbd>Enter</kbd>
        </button>
      </span>
    </div>
  </div>
</template>
