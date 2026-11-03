<script setup lang="ts">
// The printable receipt (receipt.pdf.content): company, number, "Recebemos de…",
// the orders and what each one got, the total and who registered. Printed by the
// browser, which saves PDF with any script (no Latin-1 limit: defect 17). "Ainda
// falta" is left out: the receipt does not keep the balance of that day, and the
// balance of today would change an old receipt (defect 15).
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { country, money, orderShort } from '@/lib/orders/text'
import type { Receipt } from '@/lib/receive/data'
import { session } from '@/lib/session'

defineProps<{ receipt: Receipt; customerName: string }>()
</script>

<template>
  <Teleport to="body">
    <article class="print-sheet" data-testid="receipt-print">
      <header>
        <p class="print-company">{{ session.company?.name }}</p>
        <h1>{{ t('pdfReceiptTitle') }} · {{ t('pdfReceiptNumber', { number: receipt.id.slice(0, 8).toUpperCase() }) }}</h1>
      </header>
      <p>{{ t('pdfReceiptSentence', { name: receipt.customer?.name || customerName, amount: money(receipt.amount), date: receipt.paidAt ? formatDate(receipt.paidAt, country()) : '' }) }}</p>
      <table>
        <thead>
          <tr>
            <th scope="col">{{ orderShort() }}</th>
            <th scope="col">{{ t('pdfReceiptPaidColumn') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="part in receipt.allocations" :key="part.orderId">
            <td>{{ orderShort() }} {{ part.orderNumber ?? '' }}</td>
            <td>{{ money(part.amount) }}</td>
          </tr>
        </tbody>
      </table>
      <p class="print-total">{{ t('pdfReceiptTotal') }}: {{ money(receipt.amount) }}</p>
      <p v-if="receipt.createdBy?.name">{{ t('pdfReceiptRecordedBy', { name: receipt.createdBy.name }) }}</p>
    </article>
  </Teleport>
</template>
