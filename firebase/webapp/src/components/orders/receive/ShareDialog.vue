<script setup lang="ts">
// "Mandar para o cliente" (order.share-sheet.*): the order's link with the text
// that goes with it, sent by WhatsApp, copied or shared. The link comes from the
// API (the server's SHARE_BASE_URL, never built here: defect 5). Changing what
// the customer can do or the validity makes a new link and turns the old one off
// (defect 4). Nothing is sent by itself: WhatsApp opens with the text, the person sends.
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { loadCustomer } from '@/lib/customers/data'
import { formatDate } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { country, orderShort, orderTitle } from '@/lib/orders/text'
import { whatsappNumber } from '@/lib/phone'
import { createShareToken, listShareTokens, revokeShareToken } from '@/lib/receive/data'
import { messageKind, permissionKind, PERMISSIONS_OF, pickToken, validityDays, whatsappLink, type PermissionKind, type ShareToken } from '@/lib/receive/model'
import { session } from '@/lib/session'
import { canShareSheet, copyText, onShare, openWhatsapp, shareSheet } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/receive.css'

/** send (key W): opens WhatsApp as soon as the link is ready; the sheet stays only when it cannot. */
const props = defineProps<{ order: Order; send?: boolean }>()
const emit = defineEmits<{ close: []; pickCustomer: [] }>()

type State = 'loading' | 'ready' | 'failed' | 'noCustomer'
const state = ref<State>(props.order.customer?.id || props.order.customer?.name ? 'loading' : 'noCustomer')
const token = shallowRef<ShareToken | null>(null)
const phone = ref(props.order.customer?.phone ?? '')
const busy = ref(false)
const copied = ref(false)
const confirmRevoke = ref(false)
const text = ref('')
const edited = ref(false)

const name = computed(() => props.order.customer?.name?.trim() || '')
const kind = computed<PermissionKind>(() => permissionKind(token.value?.permissions ?? []))
// Measured when the link arrives: a link made after the dialog opened is not counted a day longer.
const days = computed(() => (token.value ? validityDays(token.value, new Date()) : 7))
const wa = computed(() => whatsappNumber(phone.value, country()))
const canShare = canShareSheet()
/** Where the sends of this sheet are counted (lib/share onShare). */
const CONTEXT = 'order'
const VALIDITIES = [7, 14, 30]

const who = computed(() => {
  const params = { name: name.value || t('shareTheCustomer'), order: orderShort() }
  if (kind.value === 'all') return t('shareCanAll', params)
  if (kind.value === 'approve') return t('shareCanApprove', params)
  if (kind.value === 'comment') return t('shareCanComment', params)
  return t('shareCanView', params)
})
const until = computed(() => (token.value ? t('shareValidUntil', { date: formatDate(token.value.expiresAt, country()) }) : ''))

/** The words that go with the link: by the order's situation, what the link allows, the segment's name for an order and the language. */
const message = computed(() => {
  const order = `${orderShort()} ${props.order.number ?? ''}`.trim()
  const greeting = name.value ? t('web.share.msgHello', { name: name.value }) : t('web.share.msgHelloNoName')
  const situation = {
    quote: t('web.share.msgQuote', { order }),
    approved: t('web.share.msgApproved', { order }),
    progress: t('web.share.msgProgress', { order }),
    done: t('web.share.msgDone', { order }),
    other: t('web.share.msgOther', { order }),
  }[messageKind(props.order.status)]
  const action = {
    all: t('web.share.msgDoAll'),
    approve: t('web.share.msgDoApprove'),
    comment: t('web.share.msgDoComment'),
    view: t('web.share.msgDoView'),
  }[kind.value]
  const company = session.company?.name ? `\n${session.company.name}` : ''
  return `${greeting} ${situation} ${action}\n${token.value?.url ?? ''}${company}`
})
watch(message, (value) => {
  if (!edited.value) text.value = value
}, { immediate: true })

async function load() {
  if (state.value === 'noCustomer') return
  state.value = 'loading'
  try {
    const [tokens] = await Promise.all([listShareTokens(props.order.id), refreshPhone()])
    token.value = pickToken(tokens, new Date()) ?? (await createAndReread())
    state.value = 'ready'
    await nextTick()
    ready()
  } catch (error) {
    console.warn('share: link not made', error)
    state.value = 'failed'
  }
}

/**
 * No valid link yet: make one, then read the list again and take the newest
 * valid one. Two tabs opening at once both create, and the server keeps only
 * the newest (revokeOlderTokens): both tabs end on the link that still opens.
 */
async function createAndReread(): Promise<ShareToken> {
  const made = await createShareToken(props.order.id, PERMISSIONS_OF.all, 7)
  try {
    return pickToken(await listShareTokens(props.order.id), new Date()) ?? made
  } catch {
    return made
  }
}

/** The phone from the customer's record, not the copy inside the order (defect 80). */
async function refreshPhone() {
  const id = props.order.customer?.id
  if (!id) return
  try {
    const detail = await loadCustomer(id)
    if (detail.customer.phone) phone.value = detail.customer.phone
  } catch {
    // The copy in the order stays.
  }
}

/**
 * A new link with these rules. The server turns the older ones of this order
 * off when it makes it (revokeOlderTokens, #514), so the previous link stops
 * opening (defect 4). A DELETE here would also clear the order's reference to
 * the new link.
 */
async function replace(permissions: PermissionKind, expiresIn: number) {
  if (busy.value) return
  busy.value = true
  try {
    token.value = await createShareToken(props.order.id, PERMISSIONS_OF[permissions], expiresIn)
    edited.value = false
    showToast(t('web.share.newLink'))
    announce(t('web.share.newLink'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

async function revoke() {
  const current = token.value
  confirmRevoke.value = false
  if (!current || busy.value) return
  busy.value = true
  try {
    await revokeShareToken(props.order.id, current.token)
    showToast(t('web.share.revoked'))
    emit('close')
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    busy.value = false
  }
}

async function copy(value: string, done: string) {
  if (!(await copyText(value, CONTEXT))) return showToast(t('web.share.copyFailed'))
  copied.value = true
  setTimeout(() => (copied.value = false), 2000)
  showToast(done)
  announce(done)
}

/** "Mandar de outro jeito" (order.share-sheet.other): the browser's sheet; closed by the person says nothing. */
async function shareOther() {
  if ((await shareSheet({ title: orderTitle(props.order), text: text.value }, CONTEXT)) === 'failed') showToast(t('web.share.sheetFailed'))
}

function sentByWhatsApp() {
  onShare('whatsapp', CONTEXT)
  announce(t('web.share.whatsappOpened'))
}

const sendButton = ref<HTMLElement | null>(null)
/**
 * Ready: the focus goes to "Mandar pelo WhatsApp" (or "Copiar texto" without a
 * phone), so Enter sends (timed-comparison T5). Asked by W, WhatsApp opens at
 * once; if the browser blocks the new tab, the sheet stays with the button focused.
 */
function ready() {
  const focused = document.activeElement
  const inField = focused instanceof HTMLElement && focused.matches('input, textarea, select')
  if (!inField) sendButton.value?.focus()
  if (!props.send || !wa.value || !token.value) return
  if (!openWhatsapp(wa.value, text.value, CONTEXT)) return
  announce(t('web.share.whatsappOpened'))
  emit('close')
}

onMounted(load)
onBeforeUnmount(() => (copied.value = false))
</script>

<template>
  <Layer kind="sheet" :label="t('shareTitle')" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('shareTitle') }}</h2>
        <p v-if="state === 'ready'" class="sub" data-testid="share-who">{{ who }} {{ until }}</p>
      </div>
      <div class="layer-body share">
        <div v-if="state === 'noCustomer'" class="empty" role="alert" data-testid="share-no-customer">
          <h3>{{ t('web.share.noCustomerTitle', { order: orderShort() }) }}</h3>
          <p>{{ t('web.share.noCustomerBody') }}</p>
          <button type="button" class="btn btn--primary" @click="emit('pickCustomer')">{{ t('orderPickCustomerRow') }}</button>
        </div>
        <LoadingState v-else-if="state === 'loading'" :label="t('sharePreparing')" />
        <div v-else-if="state === 'failed'" class="empty" role="alert">
          <h3>{{ t('shareError') }}</h3>
          <button type="button" class="btn" @click="load">{{ t('web.tryAgain') }}</button>
        </div>
        <template v-else-if="token">
          <label class="field-label" for="share-text">{{ t('web.share.message') }}</label>
          <textarea id="share-text" v-model="text" class="field" rows="6" data-testid="share-text" @input="edited = true"></textarea>
          <p class="share-url"><span class="sr">{{ t('web.share.linkLabel') }}</span><code class="num" data-testid="share-url">{{ token.url }}</code></p>
          <div class="share-opts">
            <div>
              <label class="field-label" for="share-perm">{{ t('shareWhatCanDo') }}</label>
              <select id="share-perm" class="field" :value="kind" :disabled="busy" @change="replace(($event.target as HTMLSelectElement).value as PermissionKind, days)">
                <option value="all">{{ t('sharePermAll') }}</option>
                <option value="approve">{{ t('sharePermApprove') }}</option>
                <option value="comment">{{ t('sharePermComment') }}</option>
                <option value="view">{{ t('sharePermView') }}</option>
              </select>
            </div>
            <div>
              <label class="field-label" for="share-days">{{ t('shareValidityTitle') }}</label>
              <select id="share-days" class="field" :value="VALIDITIES.includes(days) ? days : ''" :disabled="busy" @change="replace(kind, Number(($event.target as HTMLSelectElement).value))">
                <option v-if="!VALIDITIES.includes(days)" value="" disabled>{{ t('shareValidityDays', { count: days }) }}</option>
                <option v-for="value in VALIDITIES" :key="value" :value="value">{{ t('shareValidityDays', { count: value }) }}</option>
              </select>
            </div>
          </div>
          <p class="sub">{{ t('web.share.replaceNote') }}</p>
          <div class="row-actions">
            <button type="button" class="link" :disabled="busy" @click="replace(kind, days)">{{ t('shareNewLink') }}</button>
            <button type="button" class="link link--danger" :disabled="busy" @click="confirmRevoke = true">{{ t('shareRevoke') }}</button>
          </div>
        </template>
      </div>
      <div v-if="state === 'ready' && token" class="layer-foot share-foot">
        <button v-if="canShare" type="button" class="btn" data-testid="share-other" @click="shareOther">{{ t('shareSendOtherWay') }}</button>
        <button type="button" class="btn" data-testid="share-copy" @click="copy(token.url, t('shareLinkCopied'))">{{ copied ? t('web.share.copied') : t('shareCopyLink') }}</button>
        <a
          v-if="wa"
          class="btn btn--primary"
          :href="whatsappLink(wa, text)"
          target="_blank"
          rel="noopener noreferrer"
          ref="sendButton"
          data-testid="share-whatsapp"
          @click="sentByWhatsApp"
        >{{ t('shareSendWhatsApp') }}</a>
        <button v-else ref="sendButton" type="button" class="btn btn--primary" data-testid="share-copy-text" @click="copy(text, t('web.share.textCopied'))">{{ t('web.share.copyText') }}</button>
      </div>
      <div v-else class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="confirmRevoke"
    :title="t('shareRevoke')"
    :body="t('shareRevokeConfirm', { order: orderShort() })"
    :confirm="t('shareRevoke')"
    :keep="t('cancel')"
    danger
    @confirm="revoke"
    @close="confirmRevoke = false"
  />
</template>
