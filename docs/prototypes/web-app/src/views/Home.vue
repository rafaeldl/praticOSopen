<script setup>
import { computed } from 'vue'
import { db, ui, go, customerOf, deviceOf, rest, lateDays, isHeld, isOpen, isToday, quoteAge, doneAge, sentence, paid } from '../store.js'
import { NOW, brl, brlShort, hhmm, longDay, sameDay, daysBetween, plural } from '../format.js'
import StatusLabel from '../components/StatusLabel.vue'

const orders = computed(() => db.value.orders)
const attention = computed(() => {
  const out = []
  orders.value.filter((o) => lateDays(o)).sort((a, b) => lateDays(b) - lateDays(a)).forEach((o) => out.push({ o, level: 1, why: sentence(o) }))
  orders.value.filter(isHeld).filter((o) => !lateDays(o)).forEach((o) => out.push({ o, level: 2, why: sentence(o) }))
  orders.value.filter((o) => o.status === 'quote' && o.sentAt && quoteAge(o) >= 3).forEach((o) => out.push({ o, level: 3, why: sentence(o) }))
  orders.value.filter((o) => o.status === 'done' && rest(o) > 0 && doneAge(o) >= 7).forEach((o) => out.push({ o, level: 4, why: `Pronta há ${doneAge(o)} dias, falta receber ${brl(rest(o))}` }))
  return out
})
const first = computed(() => attention.value[0])
const rest7 = computed(() => attention.value.slice(1, 7))
const agenda = computed(() => orders.value.filter((o) => isOpen(o) && o.scheduledAt && sameDay(o.scheduledAt, NOW)).sort((a, b) => new Date(a.scheduledAt) - new Date(b.scheduledAt)))
const dueToday = computed(() => orders.value.filter((o) => isOpen(o) && o.dueAt && sameDay(o.dueAt, NOW)).length)
const toReceive = computed(() => orders.value.filter((o) => o.status === 'done').reduce((s, o) => s + rest(o), 0))
const receivedToday = computed(() => orders.value.flatMap((o) => o.payments).filter((p) => sameDay(p.at, NOW)).reduce((s, p) => s + p.amount, 0))
const quotes = computed(() => orders.value.filter((o) => o.status === 'quote'))
const quoteValue = computed(() => quotes.value.reduce((s, o) => s + rest(o), 0))
const title = computed(() => {
  if (!orders.value.length) return `${db.value.owner}, vamos abrir a primeira OS?`
  return `Hoje: ${plural(dueToday.value, 'entrega', 'entregas')} e ${brlShort(toReceive.value)} para receber`
})
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p class="page-sub">{{ longDay(NOW) }}, {{ db.company }}</p>
    </div>
  </header>
  <div v-if="orders.length" class="home">
    <div class="home-in">
      <div v-if="first" class="next">
        <p><strong>Comece por aqui</strong>{{ customerOf(first.o).name }}, OS {{ first.o.number }}. {{ first.why }}.</p>
        <button class="btn btn--primary" @click="go('os', { id: first.o.id })">Abrir a OS {{ first.o.number }}</button>
      </div>
      <div class="money-strip">
        <button @click="go('receber')"><b>{{ brl(toReceive) }}</b><span>Falta receber</span></button>
        <button @click="go('receber')"><b>{{ brl(receivedToday) }}</b><span>Recebido hoje</span></button>
        <button @click="go('os', { query: { f: 'quote' } })"><b>{{ brl(quoteValue) }}</b><span>Em {{ plural(quotes.length, 'orçamento', 'orçamentos') }}</span></button>
      </div>
      <section class="home-sec" aria-labelledby="h-att">
        <h2 id="h-att">Precisa de você</h2>
        <button v-for="a in rest7" :key="a.o.id" class="row-link" @click="ui.peek = a.o.id">
          <span>
            <span class="who">{{ customerOf(a.o).name }}</span>
            <span class="sub" style="display: block" :style="lateDays(a.o) ? 'color: var(--color-danger-text); font-weight: 700' : ''">{{ a.why }}</span>
          </span>
          <span class="num muted">OS {{ a.o.number }}</span>
        </button>
        <button v-if="attention.length > 7" class="link" style="margin-top: .5rem" @click="go('os')">Ver mais {{ attention.length - 7 }} nas ordens de serviço</button>
        <p v-if="!attention.length" class="muted" style="padding: .5rem 0">Nada urgente. Tudo em dia.</p>
      </section>
      <section class="home-sec" aria-labelledby="h-day">
        <h2 id="h-day">{{ db.labels.visit === 'Visita' ? 'Visitas de hoje' : 'Na oficina hoje' }}</h2>
        <button v-for="o in agenda" :key="o.id" class="row-link" @click="ui.peek = o.id">
          <span class="row-time" style="grid-column: 1 / -1">
            <span class="num">{{ hhmm(o.scheduledAt) }}</span>
            <span><span class="who">{{ customerOf(o).name }}</span><span class="sub" style="display: block">{{ deviceOf(o)?.label }}</span></span>
            <span class="sub">{{ o.assignee }}</span>
          </span>
        </button>
        <p v-if="!agenda.length" class="muted" style="padding: .5rem 0">Nada marcado para hoje.</p>
      </section>
    </div>
  </div>
  <div v-else class="empty">
    <h2>Sua primeira OS começa aqui</h2>
    <p>Escolha o cliente, o que vai ser feito e pronto. Depois este painel mostra o que precisa de você.</p>
    <button class="btn btn--primary" @click="ui.newOrder = true">Criar a primeira OS <kbd>N</kbd></button>
  </div>
</template>
