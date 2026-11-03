<script setup lang="ts">
// Choosing is searching, by typing (WEB_APP_DESIGN, Combobox): the customer,
// the device or the catalog item, in a small dialog over the order.
import { t } from '@/i18n'
import Combobox, { type ComboboxGroup, type ComboboxItem } from '@/components/Combobox.vue'
import Layer from '@/components/Layer.vue'

defineProps<{ id: string; title: string; label: string; placeholder?: string; groups: (query: string) => ComboboxGroup[]; selectedId?: string | null }>()
const emit = defineEmits<{ pick: [item: ComboboxItem, query: string]; close: [] }>()
</script>

<template>
  <Layer kind="sheet" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
      </div>
      <div class="layer-body combo-dialog">
        <Combobox :id="id" :label="label" :placeholder="placeholder" :groups="groups" :selected-id="selectedId" autofocus @pick="(item, query) => emit('pick', item, query)" @cancel="close()" />
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>
