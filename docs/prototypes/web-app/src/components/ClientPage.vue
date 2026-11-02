<script setup>
import { computed } from 'vue'
import { db, customerOf, deviceOf, total, rest, STATUS, greeting } from '../store.js'
import { brl } from '../format.js'
const props = defineProps({ order: Object, showValues: Boolean, showPhotos: Boolean, showPay: Boolean })
const c = computed(() => customerOf(props.order)); const d = computed(() => deviceOf(props.order))
</script>
<template>
  <div class="cp" aria-label="Prévia do que o cliente vê">
    <div class="cp-bar">{{ db.company }}</div>
    <div class="cp-body">
      <p class="cp-small">OS {{ order.number }}, {{ STATUS[order.status].label }}</p>
      <h3>Olá, {{ greeting(c) }}</h3>
      <p v-if="d" class="cp-small">{{ d.label }}</p>
      <ul class="cp-items"><li v-for="i in order.items" :key="i.id"><span>{{ i.name }}</span><span v-if="showValues" class="num">{{ brl(i.qty * i.price) }}</span></li></ul>
      <p v-if="showValues" class="cp-total"><span>Total</span><span class="num">{{ brl(total(order)) }}</span></p>
      <p v-if="showPhotos && order.photos.length" class="cp-small">{{ order.photos.length === 1 ? '1 foto do serviço' : `${order.photos.length} fotos do serviço` }}</p>
      <span v-if="order.status === 'quote'" class="cp-btn">Aprovar orçamento</span>
      <span v-if="showPay && rest(order) > 0" class="cp-btn">Pagar {{ brl(rest(order)) }}</span>
      <p v-if="showPay && rest(order) > 0" class="cp-small">Pix, boleto ou cartão</p>
    </div>
  </div>
</template>
