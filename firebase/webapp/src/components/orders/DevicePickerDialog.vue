<script setup lang="ts">
// "Em quais veículos?" (order.device-picker.one / .multi): the app's
// DevicePickerSheet, asked when an item goes into an order with two or more
// devices. Geral (no device), Selecionar Tudo, or one or several devices; the
// item enters once per chosen device. ✓ only with something chosen; Cancelar
// adds nothing.
import { computed, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { canConfirm, emptyPick, pickResult, toggleAll, toggleDevice, toggleGeneral, type PickResult } from '@/lib/orders/device-pick'
import type { DeviceAggr } from '@/lib/orders/model'
import { segmentLabels, resolveLabel } from '@/lib/segments'

const props = defineProps<{ devices: DeviceAggr[]; sub?: string }>()
const emit = defineEmits<{ pick: [result: PickResult]; close: [] }>()
const state = ref(emptyPick())
const list = computed(() => props.devices.filter((d): d is DeviceAggr & { id: string } => !!d.id))
const ids = computed(() => list.value.map((d) => d.id))
const allOn = computed(() => ids.value.length > 0 && ids.value.every((id) => state.value.ids.includes(id)))
const plural = resolveLabel('device._entity_plural', segmentLabels(), (key) => t(key)).toLocaleLowerCase()
const title = t('pickerDevicesTitle', { devices: plural })

function confirm(close: () => void) {
  const result = pickResult(state.value, ids.value)
  if (!result) return
  emit('pick', result)
  close()
}
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
        <p v-if="sub" class="sub">{{ sub }}</p>
      </div>
      <div class="layer-body" data-testid="device-picker">
        <fieldset class="pick-orders">
          <legend class="sr">{{ title }}</legend>
          <div class="check-row">
            <input id="dp-general" class="check" type="checkbox" :checked="state.general" data-testid="device-picker-general" @change="state = toggleGeneral(state)" />
            <label for="dp-general">{{ t('generalNoDevice') }}</label>
          </div>
          <div v-if="list.length > 1" class="check-row">
            <input id="dp-all" class="check" type="checkbox" :checked="allOn" data-testid="device-picker-all" @change="state = toggleAll(state, ids)" />
            <label for="dp-all">{{ t('selectAll') }}</label>
          </div>
          <div v-for="device in list" :key="device.id" class="check-row">
            <input :id="`dp-${device.id}`" class="check" type="checkbox" :checked="state.ids.includes(device.id)" @change="state = toggleDevice(state, device.id)" />
            <label :for="`dp-${device.id}`">{{ device.name }}<span v-if="device.serial" class="sub num"> · {{ device.serial }}</span></label>
          </div>
        </fieldset>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
        <button type="button" class="btn btn--primary" :disabled="!canConfirm(state)" data-testid="device-picker-confirm" @click="confirm(close)">{{ t('confirm') }}</button>
      </div>
    </template>
  </Layer>
</template>
