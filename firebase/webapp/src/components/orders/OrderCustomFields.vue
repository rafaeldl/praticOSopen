<script setup lang="ts">
// The segment's own fields of the order (order.custom-fields.view): the same
// `segments/{id}.customFields` under `service_order.*` as the app, without the
// ones the screen already has (status, dates, total, payment, address).
// Not copied from the app: there anyone edits in any status and nothing is
// validated; here only who edits the order's main fields, with required,
// minimum, maximum and pattern checked before saving (in one write).
import { computed, reactive, ref } from 'vue'
import CustomFieldInput from '@/components/customers/CustomFieldInput.vue'
import Layer from '@/components/Layer.vue'
import { locale, t } from '@/i18n'
import { formatDate, fromIsoDay } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { country } from '@/lib/orders/text'
import { updateOrderFields } from '@/lib/orders/writes'
import { fieldName, fieldOptions, fieldTitle, groupBySection, namespaceFields, readCustom, validateField, writeCustom, type FieldError, type FormField } from '@/lib/segment-fields'
import { showToast } from '@/lib/toast'
import { errorMessageKey } from '@/lib/api'

const BUILT_IN = ['service_order.status', 'service_order.scheduledDate', 'service_order.dueDate', 'service_order.total', 'service_order.payment', 'service_order.address', 'service_order.observation']

const props = defineProps<{ order: Order; canEdit: boolean }>()
const fields = computed(() => namespaceFields('service_order', BUILT_IN))
const groups = computed(() =>
  groupBySection(fields.value, locale.value, t('details'))
    .map((group) => ({ title: group.title, fields: group.fields.map((field) => ({ field, text: textOf(field, readCustom(props.order.customData, field)) })) }))
    .filter((group) => props.canEdit || group.fields.some((item) => item.text)),
)

function textOf(field: FormField, value: unknown): string {
  if (value === undefined || value === null || value === '') return ''
  if (field.type === 'date' && typeof value === 'string') return formatDate(fromIsoDay(value.slice(0, 10)), country())
  if (field.type === 'select') return fieldOptions(field, locale.value).find((option) => option.value === value)?.label ?? String(value)
  return String(value)
}

const editing = ref(false)
const saving = ref(false)
const tried = ref(false)
const values = reactive<Record<string, unknown>>({})
const errors = computed(() => Object.fromEntries(fields.value.map((field) => [field.key, validateField(field, values[fieldName(field)])])) as Record<string, FieldError>)

function open() {
  for (const field of fields.value) values[fieldName(field)] = readCustom(props.order.customData, field) ?? null
  tried.value = false
  editing.value = true
}

function errorText(field: FormField): string {
  const error = errors.value[field.key]
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${field.min}`
  if (error === 'max') return `${t('maximum')}: ${field.max}`
  if (error === 'minLength') return `${t('minimum')} ${field.minLength} ${t('characters')}`
  return ''
}

async function save() {
  tried.value = true
  if (saving.value || Object.values(errors.value).some(Boolean)) return
  saving.value = true
  try {
    await updateOrderFields(props.order.id, { customData: writeCustom(props.order.customData, fields.value, values) })
    editing.value = false
    showToast(t('web.saved'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <section v-if="fields.length && groups.length" class="od-sec" aria-labelledby="od-custom-title" data-testid="order-custom-fields">
    <h3 id="od-custom-title">
      {{ t('web.order.moreData') }}
      <button v-if="canEdit" type="button" class="link" @click="open">{{ t('web.order.editMoreData') }}</button>
    </h3>
    <template v-for="group in groups" :key="group.title">
      <h4 v-if="groups.length > 1" class="od-group">{{ group.title }}</h4>
      <dl class="kv">
        <template v-for="item in group.fields" :key="item.field.key">
          <dt>{{ fieldTitle(item.field, locale) }}</dt>
          <dd>{{ item.text || '—' }}</dd>
        </template>
      </dl>
    </template>
  </section>
  <Layer v-if="editing" kind="sheet" :label="t('web.order.moreData')" @close="editing = false">
    <template #default="{ close }">
      <form class="layer-form" novalidate @submit.prevent="save">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('web.order.moreData') }}</h2>
        </div>
        <div class="layer-body">
          <CustomFieldInput
            v-for="field in fields"
            :key="field.key"
            v-model="values[fieldName(field)]"
            :field="field"
            :error="tried || values[fieldName(field)] ? errorText(field) : ''"
          />
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="saving">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
