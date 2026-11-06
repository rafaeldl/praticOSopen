<script setup lang="ts">
// "E-mail ao cliente" on the nota panel (issue #611): where the last e-mail
// went ("Enviada para fulano@… em 05/11/2026") or why it did not, and
// "Enviar de novo". Only for a direct nota that has its XML (issued or
// canceled); the live nota brings the new result, the answer shows it first.
import { computed, ref, watch } from 'vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { emailDeliveryText, resendDirectEmail } from '@/lib/nfse/direct-issue'
import type { EmailDelivery, NfseInvoice } from '@/lib/nfse/model'
import { country } from '@/lib/orders/text'
import { showToast } from '@/lib/toast'

const props = defineProps<{ invoice: NfseInvoice }>()

const sending = ref(false)
const resent = ref<EmailDelivery | null>(null)
watch(
  () => [props.invoice.id, props.invoice.emailDelivery?.at],
  () => (resent.value = null),
)

const shown = computed(() =>
  props.invoice.provider === 'direct' &&
  !!props.invoice.xmlPath &&
  ['authorized', 'cancellationDenied', 'canceled'].includes(props.invoice.status),
)
const delivery = computed(() => resent.value ?? props.invoice.emailDelivery)

async function send() {
  if (sending.value) return
  sending.value = true
  try {
    const result = await resendDirectEmail(props.invoice.id)
    resent.value = result
    if (result?.status === 'sent') showToast(t('nfseEmailSentToast', { email: result.to ?? '' }))
    else showToast(t(result?.reason === 'noEmail' ? 'nfseEmailNoAddressToast' : 'nfseEmailFailedToast'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <div v-if="shown" data-testid="nfse-email">
    <dt>{{ t('nfseEmailRow') }}</dt>
    <dd>
      <span :class="{ 'nfse-email-failed': delivery?.status === 'failed' }" data-testid="nfse-email-text">{{ emailDeliveryText(delivery, country()) }}</span>
      <button type="button" class="link nfse-email-send" :disabled="sending" data-testid="nfse-email-send" @click="send">
        {{ delivery ? t('nfseEmailSendAgain') : t('nfseEmailSend') }}
      </button>
    </dd>
  </div>
</template>

<style scoped>
.nfse-email-failed {
  color: var(--color-danger-text);
  font-weight: 700;
}
.nfse-email-send {
  display: block;
  margin-top: 4px;
}
</style>
