<script setup>
import { computed, ref, nextTick } from 'vue'
import { MoreHorizontal, Pause } from 'lucide-vue-next'
import { db, ui, customerOf, deviceOf, total, rest, lateDays, isHeld, sentence, setStatus, STATUS, doneAge, touch } from '../store.js'
import { brl, plural } from '../format.js'
import OrdersHead from './OrdersHead.vue'

const COLS = ['quote', 'approved', 'progress', 'done']
const hint = ref('')
const dragging = ref(null); const over = ref(null)
const cards = computed(() => Object.fromEntries(COLS.map((c) => [c, db.value.orders.filter((o) => o.status === c && (c !== 'done' || rest(o) > 0 || doneAge(o) <= 3))])))
const title = computed(() => {
  if (!db.value.orders.length) return 'Nenhuma OS no quadro'
  return `${plural(cards.value.approved.length, 'para começar', 'para começar')}, ${cards.value.progress.length} em andamento`
})
function drop(col) {
  const o = db.value.orders.find((x) => x.id === dragging.value)
  if (o && o.status !== col) setStatus(o, col)
  dragging.value = null; over.value = null
}
function moveKey(e, o) {
  if (!e.shiftKey || !['ArrowLeft', 'ArrowRight'].includes(e.key)) return
  e.preventDefault()
  const i = COLS.indexOf(o.status) + (e.key === 'ArrowRight' ? 1 : -1)
  if (i < 0 || i >= COLS.length) return
  setStatus(o, COLS[i])
  nextTick(() => document.getElementById('card-' + o.id)?.focus())
}
function moveMenu(o) {
  ui.picker = {
    title: 'Mover para onde?', sub: `OS ${o.number}, ${customerOf(o).name}`,
    options: COLS.map((id) => ({ id, label: STATUS[id].label, dot: STATUS[id].dot, current: id === o.status })),
    onPick: (id) => setStatus(o, id),
  }
}
</script>
<template>
  <OrdersHead :title="title" :sub="touch ? 'Deslize para ver as outras situações. Toque em … para mover.' : 'Arraste o cartão, ou aperte Shift e seta com ele em foco.'">
    <button class="btn btn--primary hide-phone" @click="ui.newOrderSeed = null; ui.newOrder = true">Nova OS <kbd>N</kbd></button>
  </OrdersHead>
  <div v-if="db.orders.length" class="board">
    <section v-for="c in COLS" :key="c" class="col" :class="{ 'is-over': over === c }" :aria-label="STATUS[c].label" @dragover.prevent="over = c" @dragleave.self="over = null" @drop.prevent="drop(c)">
      <div class="col-head"><span class="dot" :class="'dot--' + STATUS[c].dot" aria-hidden="true"></span>{{ c === 'done' ? 'Concluída' : STATUS[c].label }}<span class="num">{{ cards[c].length }}</span></div>
      <div class="col-list">
        <article v-for="o in cards[c]" :key="o.id" class="card" :class="{ 'is-dragging': dragging === o.id }" draggable="true" :data-order="o.id" @dragstart="dragging = o.id; $event.dataTransfer.setData('text/plain', o.id)" @dragend="dragging = null; over = null">
          <button :id="'card-' + o.id" class="card-open" @click="ui.peek = o.id" @keydown="moveKey($event, o)">
            <span class="card-top"><strong class="who">{{ customerOf(o).name }}</strong><span class="num">{{ o.number }}</span></span>
            <span class="sub">{{ deviceOf(o)?.label }}</span>
          </button>
          <span class="card-top"><span class="num">{{ brl(c === 'done' && rest(o) ? rest(o) : total(o)) }}</span></span>
          <span v-if="lateDays(o)" class="card-flag card-flag--late"><span class="dot dot--danger" aria-hidden="true"></span>{{ sentence(o) }}</span>
          <span v-else-if="isHeld(o)" class="card-flag"><Pause :size="13" aria-hidden="true" />{{ sentence(o) }}</span>
          <span v-else class="card-flag">{{ sentence(o) }}</span>
          <button class="icon-btn card-move" :aria-label="`Mover OS ${o.number}`" title="Mover" @click="moveMenu(o)"><MoreHorizontal :size="16" /></button>
        </article>
        <p v-if="!cards[c].length" class="muted small" style="padding: .25rem">Nenhuma aqui.</p>
      </div>
    </section>
  </div>
  <div v-else class="empty">
    <h2>O quadro aparece com a primeira OS</h2>
    <p>Cada OS vira um cartão, e você arrasta conforme o serviço anda.</p>
    <button class="btn" @click="ui.newOrder = true">Criar a primeira OS</button>
  </div>
</template>
