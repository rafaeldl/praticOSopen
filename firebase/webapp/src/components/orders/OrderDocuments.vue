<script setup lang="ts">
// Documents of the order (order.details.section, order.media.*, order.document.*):
// nota, contrato, garantia… as files. Who sees photos opens them (a new tab:
// the browser shows images and PDFs); who attaches photos adds one ("Que
// documento é este?" first) and takes one out, asked first. Payment proofs
// live in "Já recebido", never here.
import { computed, ref, shallowRef } from 'vue'
import { FileText } from '@lucide/vue'
import { t } from '@/i18n'
import { formatNumber } from '@/lib/format'
import { ATTACHMENT_TYPES, attachmentProblem, fileSizeParts, type AttachmentType, type Order, type OrderAttachment } from '@/lib/orders/model'
import { country } from '@/lib/orders/text'
import { deleteDocument, uploadDocument } from '@/lib/orders/writes'
import { can } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog from './ChoiceDialog.vue'
import ConfirmDialog from './ConfirmDialog.vue'

const props = defineProps<{ order: Order; canEdit: boolean }>()
const canAttach = computed(() => props.canEdit && can('attachPhotos'))
const canView = computed(() => can('viewPhotos') || can('attachPhotos'))
const fileInput = ref<HTMLInputElement | null>(null)
const pending = shallowRef<File | null>(null)
const removing = shallowRef<OrderAttachment | null>(null)
const uploading = ref(false)
const problem = ref('')

const TYPE_TEXT: Record<AttachmentType, () => string> = {
  receipt: () => t('receipt'),
  invoice: () => t('invoice'),
  contract: () => t('contract'),
  warranty: () => t('warranty'),
  other: () => t('other'),
}
const typeChoices = ATTACHMENT_TYPES.map((type) => ({ id: type, label: TYPE_TEXT[type]() }))

function size(doc: OrderAttachment): string {
  const parts = fileSizeParts(doc.fileSize)
  return parts ? `${formatNumber(parts.value, country())} ${parts.unit}` : ''
}

function choose() {
  problem.value = ''
  fileInput.value?.click()
}

function picked(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file) return
  const wrong = attachmentProblem(file)
  if (wrong) {
    problem.value = wrong === 'type' ? t('web.order.documentType') : t('web.receive.proofSize')
    return
  }
  pending.value = file
}

async function upload(type: string) {
  const file = pending.value
  pending.value = null
  if (!file) return
  uploading.value = true
  try {
    await uploadDocument(props.order.id, file, type)
    showToast(t('documentAdded'))
    announce(t('documentAdded'))
  } catch (error) {
    console.warn('documents: upload failed', error)
    showToast(t('errorUploadingDocument'))
  } finally {
    uploading.value = false
  }
}

async function remove() {
  const doc = removing.value
  removing.value = null
  if (!doc) return
  try {
    await deleteDocument(props.order.id, doc)
    showToast(t('web.order.documentDeleted'))
  } catch (error) {
    console.warn('documents: delete failed', error)
    showToast(t('web.order.documentDeleteFailed'))
  }
}
</script>

<template>
  <section v-if="canView && (order.attachments.length || canAttach)" class="od-sec" aria-labelledby="od-docs-title" data-testid="order-documents">
    <h3 id="od-docs-title">
      {{ t('documents') }}
      <button v-if="canAttach" type="button" class="link" :disabled="uploading" @click="choose">{{ uploading ? t('orderUploading') : t('addDocument') }}</button>
    </h3>
    <ul v-if="order.attachments.length" class="doc-list">
      <li v-for="doc in order.attachments" :key="doc.id" class="doc-row" data-testid="document-row">
        <FileText :size="16" aria-hidden="true" />
        <span class="doc-main">
          <a class="link" :href="doc.url" target="_blank" rel="noopener noreferrer">{{ doc.fileName || t('document') }}</a>
          <span class="sub">{{ [TYPE_TEXT[doc.type](), size(doc)].filter(Boolean).join(' · ') }}</span>
        </span>
        <button v-if="canAttach" type="button" class="link link--danger" :aria-label="t('web.order.deleteDocumentOf', { name: doc.fileName || t('document') })" @click="removing = doc">
          {{ t('web.order.deleteDocument') }}
        </button>
      </li>
    </ul>
    <p v-else class="muted">{{ t('web.order.noDocuments') }}</p>
    <p v-if="problem" class="field-error" role="alert">{{ problem }}</p>
    <input
      v-if="canAttach"
      ref="fileInput"
      type="file"
      class="sr"
      accept="image/*,application/pdf,.doc,.docx,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      :aria-label="t('addDocument')"
      tabindex="-1"
      data-testid="document-input"
      @change="picked"
    />
  </section>
  <ChoiceDialog v-if="pending" :title="t('orderDocumentTypeTitle')" :sub="pending.name" :choices="typeChoices" @pick="upload" @close="pending = null" />
  <ConfirmDialog
    v-if="removing"
    :title="t('deleteDocument')"
    :body="t('confirmDeleteDocument')"
    :confirm="t('web.order.deleteDocument')"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="removing = null"
  />
</template>
