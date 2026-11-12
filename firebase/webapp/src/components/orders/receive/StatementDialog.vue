<script setup lang="ts">
// "Mandar extrato" (pay.customer.statement): the checked orders of the customer,
// with what is owed on each, as a WhatsApp message; with "Mandar com PDF" the
// PDF (services and parts of each order) is downloaded to attach. Without the
// customer's WhatsApp the message is copied. Same content as the app.
import { ref } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { loadCustomer } from '@/lib/customers/data'
import { whatsappNumber } from '@/lib/phone'
import type { OpenOrder } from '@/lib/receive/model'
import { statementText } from '@/lib/receive/statement'
import { session } from '@/lib/session'
import { copyText, downloadFile, openWhatsapp } from '@/lib/share'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{ customerId: string; customerName: string; orders: OpenOrder[] }>()
const emit = defineEmits<{ close: [] }>()
const busy = ref(false)

async function send(withPdf: boolean) {
  if (busy.value) return
  busy.value = true
  try {
    const load = await import('@/lib/pdf/load')
    const [orders, detail] = await Promise.all([load.statementOrders(props.orders), (props.customerId ? loadCustomer(props.customerId) : Promise.reject(new Error('no customer'))).catch(() => null)])
    const text = statementText(orders, load.statementTexts(), props.customerName || t('customerWithoutName'))
    if (withPdf) {
      const pdf = await load.statementPdf(orders, props.customerName)
      downloadFile(pdf.file, pdf.fileName)
    }
    const wa = whatsappNumber(detail?.customer.phone ?? '', session.company?.country)
    let said: string
    if (wa && openWhatsapp(wa, text, 'statement')) said = withPdf ? t('web.share.pdfAttach') : t('web.share.whatsappOpened')
    else if (await copyText(text, 'statement')) said = withPdf ? t('web.statement.pdfAndCopied') : t('web.share.textCopied')
    else said = t('web.share.copyFailed')
    showToast(said)
    announce(said)
    emit('close')
  } catch (error) {
    console.warn('statement: not sent', error)
    showToast(t('web.error.generic'))
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <Layer kind="dialog" :label="t('statementSendTitle', { name: customerName })" :guard="() => !busy" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('statementSendTitle', { name: customerName }) }}</h2>
      </div>
      <div class="layer-body" data-testid="statement-dialog">
        <p>{{ t('statementSendMessage') }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" :disabled="busy" @click="close()">{{ t('cancel') }}</button>
        <span class="spacer"></span>
        <button type="button" class="btn" :disabled="busy" data-testid="statement-text-only" @click="send(false)">{{ t('statementTextOnly') }}</button>
        <button type="button" class="btn btn--primary" :disabled="busy" data-autofocus data-testid="statement-with-pdf" @click="send(true)">{{ t('statementWithPdf') }}</button>
      </div>
    </template>
  </Layer>
</template>
