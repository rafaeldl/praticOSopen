<script setup lang="ts">
// Campos do ramo na Nova OS (order.new.custom-fields): one group per section of
// `service_order.*`, without the request field (it has its own box), between
// the delivery and "Mais opções". Saved with the order (customData, as the app).
// Not copied from the app: there the ✓ never checks required, length or
// pattern; here the ✓ waits until they are right.
import { computed } from 'vue'
import CustomFieldInput from '@/components/customers/CustomFieldInput.vue'
import { locale, t } from '@/i18n'
import { newOrderFields } from '@/lib/orders/new-order-fields'
import { fieldName, groupBySection, validateField, type FieldError, type FormField } from '@/lib/segment-fields'

const props = defineProps<{ values: Record<string, unknown>; tried: boolean }>()
const fields = computed(() => newOrderFields())
const groups = computed(() => groupBySection(fields.value, locale.value, t('details')))

function errorText(field: FormField): string {
  const error: FieldError = validateField(field, props.values[fieldName(field)])
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${field.min}`
  if (error === 'max') return `${t('maximum')}: ${field.max}`
  if (error === 'minLength') return `${t('minimum')} ${field.minLength} ${t('characters')}`
  return ''
}
</script>

<template>
  <section v-for="group in groups" :key="group.title" class="step" :aria-label="group.title" data-testid="new-order-custom-fields">
    <h3 class="form-section">{{ group.title }}</h3>
    <CustomFieldInput
      v-for="field in group.fields"
      :key="field.key"
      v-model="values[fieldName(field)]"
      :field="field"
      :error="tried || values[fieldName(field)] ? errorText(field) : ''"
    />
  </section>
</template>
