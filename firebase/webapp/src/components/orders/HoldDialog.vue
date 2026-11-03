<script setup lang="ts">
// "Por que parou?": the optional note first, then the reason, which saves.
import { ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'
import { HOLD_REASONS, type HoldReason } from '@/lib/orders/model'
import { holdReasonText } from '@/lib/orders/text'

const emit = defineEmits<{ save: [reason: HoldReason, note: string]; close: [] }>()
const note = ref('')
</script>

<template>
  <Layer kind="sheet" :label="t('orderHoldSheetTitle')" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('orderHoldSheetTitle') }}</h2>
      </div>
      <div class="layer-body">
        <label class="field-label" for="hold-note">{{ t('orderHoldNoteHint') }}</label>
        <textarea id="hold-note" v-model="note" class="field" maxlength="500" rows="2"></textarea>
        <div class="opts" role="group" :aria-label="t('orderHoldSheetTitle')">
          <button v-for="reason in HOLD_REASONS" :key="reason" type="button" class="opt" @click="emit('save', reason, note.trim())">
            {{ holdReasonText(reason) }}
          </button>
        </div>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>
