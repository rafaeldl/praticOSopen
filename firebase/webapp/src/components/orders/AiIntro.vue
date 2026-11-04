<script setup lang="ts">
// Apresentação do assistente (order.ai.intro, -try, -later): the app's
// showAiIntroOnce (ai_intro.dart). Once per browser, on Início after the list
// is up, only with the assistant on and only for who opens Nova OS. Marked as
// seen before it shows, so any answer is final. "Experimentar agora" opens Nova
// OS with the cursor in the assistant (the computer has no "já ouvindo": the
// person types or sends a photo).
import { nextTick } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { orderShort } from '@/lib/orders/text'
import { ui } from '@/lib/ui'

const emit = defineEmits<{ close: [] }>()

let tried = false
function tryNow(close: () => void) {
  tried = true
  close()
}
/** Nova OS opens only after this layer left the history (or its Voltar would close the drawer). */
async function onClose() {
  emit('close')
  if (!tried) return
  await nextTick()
  ui.newOrderSeed = { ...(ui.newOrderSeed ?? {}), assist: true }
  ui.newOrder = true
}
</script>

<template>
  <Layer kind="dialog" :label="t('web.aiIntro.title', { order: orderShort() })" @close="onClose">
    <template #default="{ close }">
      <div class="layer-head ai-intro" data-testid="ai-intro">
        <span class="ai ai-intro-mark" aria-hidden="true">✦</span>
        <h2 class="layer-title">{{ t('web.aiIntro.title', { order: orderShort() }) }}</h2>
      </div>
      <div class="layer-body">
        <p>{{ t('web.aiIntro.body') }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('aiIntroLater') }}</button>
        <button type="button" class="btn btn--primary" data-autofocus @click="tryNow(close)">{{ t('aiIntroTry') }}</button>
      </div>
    </template>
  </Layer>
</template>
