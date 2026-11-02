<script setup>
import { computed } from 'vue'
import { db, customerOf, deviceOf, subtotal, total, paid, rest, STATUS, methodLabel } from '../store.js'
import { brl, dayMonth, friendlyWhen } from '../format.js'
const props = defineProps({ order: Object, showValues: Boolean })
const c = computed(() => customerOf(props.order)); const d = computed(() => deviceOf(props.order))
</script>
<template>
  <article class="sheet">
    <header class="sheet-head">
      <div><strong class="sheet-co">{{ db.company }}</strong><span>{{ db.trade }}</span></div>
      <div class="sheet-no"><strong>OS {{ order.number }}</strong><span>{{ STATUS[order.status].label }}, {{ dayMonth(order.createdAt) }}</span></div>
    </header>
    <dl class="sheet-kv">
      <div><dt>Cliente</dt><dd>{{ c.name }}</dd></div>
      <div><dt>Telefone</dt><dd>{{ c.phone || ' ' }}</dd></div>
      <div v-if="d"><dt>{{ db.labels.device }}</dt><dd>{{ d.label }} {{ d.tag }}</dd></div>
      <div v-if="order.scheduledAt"><dt>{{ db.labels.visit }}</dt><dd>{{ friendlyWhen(order.scheduledAt) }}</dd></div>
    </dl>
    <p v-if="order.request" class="sheet-req"><b>O que o cliente pediu:</b> {{ order.request }}</p>
    <table class="sheet-items">
      <thead><tr><th>Serviços e peças</th><th>Qtd.</th><th v-if="showValues">Valor</th></tr></thead>
      <tbody><tr v-for="i in order.items" :key="i.id"><td>{{ i.name }}</td><td>{{ String(i.qty).replace('.', ',') }}</td><td v-if="showValues">{{ brl(i.qty * i.price) }}</td></tr></tbody>
    </table>
    <dl v-if="showValues" class="sheet-money">
      <div v-if="order.discount"><dt>Subtotal</dt><dd>{{ brl(subtotal(order)) }}</dd></div>
      <div v-if="order.discount"><dt>Desconto</dt><dd>−{{ brl(order.discount) }}</dd></div>
      <div class="is-total"><dt>Total</dt><dd>{{ brl(total(order)) }}</dd></div>
      <div v-for="p in order.payments" :key="p.id"><dt>{{ methodLabel(p.method) }}, {{ dayMonth(p.at) }}</dt><dd>{{ brl(p.amount) }}</dd></div>
      <div v-if="paid(order) && rest(order)"><dt>Falta receber</dt><dd>{{ brl(rest(order)) }}</dd></div>
    </dl>
    <footer class="sheet-sign"><div>Assinatura do cliente</div><div>{{ db.company }}</div></footer>
  </article>
</template>
