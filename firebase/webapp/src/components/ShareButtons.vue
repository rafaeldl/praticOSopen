<script setup lang="ts">
// The ways to send one thing, where the app opens its share sheet: the
// browser's own sheet when it has one (with the file when it takes files),
// "Copiar o link" and "Mandar pelo WhatsApp" in a new tab, to the number when
// there is one (else WhatsApp asks for the contact). The phone is the one of the
// customer's record when there is a customer (not the copy kept elsewhere:
// defect 80), normalized with the company's country code. Every way goes through
// lib/share onShare. "whatsapp" lets the screen do its part first (download the
// PDF the person then attaches).
import { computed, onMounted, ref } from 'vue'
import { t } from '@/i18n'
import { loadCustomer } from '@/lib/customers/data'
import { whatsappNumber } from '@/lib/phone'
import { session } from '@/lib/session'
import { canShareFiles, canShareSheet, copyText, onShare, shareSheet, whatsappUrl } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = withDefaults(
  defineProps<{
    /** Where it is sent from (onShare). */
    context: string
    /** The words for WhatsApp and the sheet. */
    text: string
    title?: string
    /** What "Copiar o link" copies; nothing hides the button. */
    copy?: string | null
    /** Phone as saved; empty lets the person choose the contact. */
    phone?: string | null
    /** The customer: their record's phone wins over `phone`. */
    customerId?: string | null
    /** The file for the sheet, read only when asked. Without it (or a browser that does not take it), the sheet gets the text. */
    file?: (() => Promise<File | null>) | null
    /** The blue one. */
    primary?: 'whatsapp' | 'sheet' | 'copy' | null
    /** Label of the sheet button (default "Compartilhar"). */
    sheetLabel?: string
    testid?: string
  }>(),
  { title: undefined, copy: null, phone: '', customerId: null, file: null, primary: null, sheetLabel: undefined, testid: 'share' },
)
const emit = defineEmits<{ whatsapp: [] }>()

const hasSheet = canShareSheet()
const recordPhone = ref<string | null>(null)
const number = computed(() => whatsappNumber(recordPhone.value || props.phone, session.company?.country))
onMounted(async () => {
  if (!props.customerId) return
  try {
    recordPhone.value = (await loadCustomer(props.customerId)).customer.phone || null
  } catch {
    // The phone given stays.
  }
})
const busy = ref(false)

async function sheet() {
  if (busy.value) return
  busy.value = true
  try {
    const file = props.file ? await props.file() : null
    const data: ShareData = file && canShareFiles([file]) ? { files: [file], title: props.title } : { title: props.title, text: props.text }
    const result = await shareSheet(data, props.context)
    if (result === 'failed') showToast(t('web.share.sheetFailed'))
  } finally {
    busy.value = false
  }
}

async function copyLink() {
  if (!props.copy) return
  if (await copyText(props.copy, props.context)) {
    showToast(t('shareLinkCopied'))
    announce(t('shareLinkCopied'))
  } else showToast(t('web.share.copyFailed'))
}

function whatsapp() {
  onShare('whatsapp', props.context)
  announce(t('web.share.whatsappOpened'))
  emit('whatsapp')
}
</script>

<template>
  <div class="share-buttons">
    <button v-if="hasSheet" type="button" class="btn" :class="{ 'btn--primary': primary === 'sheet' }" :disabled="busy" :data-testid="`${testid}-sheet`" @click="sheet">
      {{ sheetLabel ?? t('share') }}
    </button>
    <button v-if="copy" type="button" class="btn" :class="{ 'btn--primary': primary === 'copy' }" :data-testid="`${testid}-copy`" @click="copyLink">{{ t('shareCopyLink') }}</button>
    <a
      class="btn"
      :class="{ 'btn--primary': primary === 'whatsapp' }"
      :href="whatsappUrl(number, text)"
      target="_blank"
      rel="noopener noreferrer"
      :data-testid="`${testid}-whatsapp`"
      @click="whatsapp"
      >{{ t('shareSendWhatsApp') }}</a
    >
  </div>
</template>

<style scoped>
.share-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}
.share-buttons a.btn {
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
</style>
