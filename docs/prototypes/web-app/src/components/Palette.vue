<script setup>
import { computed, ref, watch, nextTick } from 'vue'
import { Plus, ClipboardList, CalendarDays, Wallet, Users, Home, Kanban, FileText, User, Keyboard, Moon, Tags, Upload, Receipt, BarChart3 } from 'lucide-vue-next'
import { db, ui, go, prefs, customerOf, deviceOf, rest, sentence, isOpen, act, doneAge } from '../store.js'
import { brl, matches, plural } from '../format.js'
import Layer from './Layer.vue'

const q = ref(''); const active = ref(0)
const COMMANDS = [
  { id: 'new', label: 'Nova OS', icon: Plus, key: 'N', run: () => { ui.newOrderSeed = null; ui.newOrder = true } },
  { id: 'os', label: 'Ir para Ordens de serviço', icon: ClipboardList, run: () => go('os') },
  { id: 'qd', label: 'Ir para o Quadro', icon: Kanban, run: () => go('quadro') },
  { id: 'ag', label: 'Ir para a Agenda', icon: CalendarDays, run: () => go('agenda') },
  { id: 'rc', label: 'Ir para Receber', icon: Wallet, run: () => go('receber') },
  { id: 'cl', label: 'Ir para Clientes', icon: Users, run: () => go('clientes') },
  { id: 'fn', label: 'Ir para o Financeiro', icon: BarChart3, run: () => go('financeiro') },
  { id: 'nf', label: 'Ir para Notas fiscais', icon: Receipt, run: () => go('notas') },
  { id: 'ct', label: 'Ir para o Catálogo', icon: Tags, run: () => go('catalogo') },
  { id: 'im', label: 'Importar clientes de uma planilha', icon: Upload, run: () => go('importar') },
  { id: 'hm', label: 'Ir para o Início', icon: Home, run: () => go('inicio') },
  { id: 'dk', label: 'Trocar tema claro ou escuro', icon: Moon, run: () => { prefs.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark' } },
  { id: 'ks', label: 'Ver atalhos', icon: Keyboard, key: '?', run: () => { ui.shortcuts = true } },
]
const openOrder = (o) => () => go('os', { id: o.id })
const orderRow = (o) => {
  const c = customerOf(o); const d = deviceOf(o)
  return { id: 'o' + o.id, label: `OS ${o.number}, ${c.name}`, sub: `${d ? `${d.label} ${d.tag}, ` : ''}${sentence(o)}`, icon: FileText, run: openOrder(o) }
}
function chargeLate() {
  const list = db.value.orders.filter((o) => o.status === 'done' && rest(o) > 0 && doneAge(o) >= 7)
  ui.assist = {
    title: `Mandar lembrete a ${plural(list.length, 'cliente', 'clientes')}?`,
    body: 'Essas OS estão prontas há mais de 7 dias e faltam ser pagas. Vou mandar uma mensagem para cada um. Nada será enviado sem a sua confirmação.',
    lines: list.map((o) => ({ id: o.id, text: `${customerOf(o).name}, OS ${o.number}`, right: brl(rest(o)) })),
    label: `Mandar para ${plural(list.length, 'cliente', 'clientes')}`,
    onApply: () => act('Lembretes marcados como enviados', () => list.forEach((o) => { o.chargedAt = new Date().toISOString() })),
  }
}
const groups = computed(() => {
  const t = q.value.trim()
  const orders = db.value.orders
  if (!t) {
    return [
      { title: 'Ações', items: COMMANDS.slice(0, 5) },
      { title: 'OS recentes', items: orders.filter(isOpen).slice(0, 4).map(orderRow) },
    ]
  }
  const hay = (o) => { const c = customerOf(o); const d = deviceOf(o); return `${o.number} ${c.name} ${c.phone} ${d?.label || ''} ${d?.tag || ''}` }
  const os = orders.filter((o) => matches(hay(o), t) || String(o.number).includes(t)).slice(0, 6).map(orderRow)
  const cl = db.value.customers.filter((c) => matches(`${c.name} ${c.phone}`, t)).slice(0, 4).map((c) => ({
    id: c.id, label: c.name, sub: c.phone, icon: User, run: () => go('clientes', { id: c.id }),
  }))
  const cmd = COMMANDS.filter((c) => matches(c.label, t))
  const asks = /cobr|lembr/i.test(t) || t.split(' ').length > 2
  const ai = asks ? [{
    id: 'ai', ai: true, label: /cobr|lembr/i.test(t) ? 'Mandar lembrete a quem está devendo há mais de 7 dias' : `Pedir ao assistente: ${t}`,
    sub: 'Mostro antes de fazer', run: /cobr|lembr/i.test(t) ? chargeLate : () => { ui.assist = { title: 'Ainda não sei fazer isso', body: 'Neste protótipo o assistente só prepara lembretes de cobrança e preenche serviços na OS.', lines: [], label: 'Entendi', onApply() {} } },
  }] : []
  return [
    { title: 'OS', items: os }, { title: 'Clientes', items: cl }, { title: 'Assistente', items: ai }, { title: 'Ações', items: cmd },
  ].filter((g) => g.items.length)
})
const flat = computed(() => groups.value.flatMap((g) => g.items))
watch(q, () => { active.value = 0 })
function run(it) { ui.palette = false; nextTick(() => it.run()) }
function onKey(e) {
  if (e.key === 'ArrowDown') { e.preventDefault(); active.value = (active.value + 1) % flat.value.length; scroll() }
  if (e.key === 'ArrowUp') { e.preventDefault(); active.value = (active.value - 1 + flat.value.length) % flat.value.length; scroll() }
  if (e.key === 'Enter' && flat.value[active.value]) { e.preventDefault(); run(flat.value[active.value]) }
}
const optId = (i) => `pal-${i}`
function scroll() { nextTick(() => document.getElementById(optId(active.value))?.scrollIntoView({ block: 'nearest' })) }
</script>
<template>
  <Layer kind="palette" label="Buscar" @close="ui.palette = false">
    <input
      v-model="q" class="pal-input" data-autofocus role="combobox" aria-expanded="true" aria-controls="pal-list" aria-label="Buscar OS, cliente, placa, telefone ou ação"
      :aria-activedescendant="flat.length ? optId(active) : undefined" placeholder="Buscar OS, cliente, placa, telefone ou ação" @keydown="onKey"
    >
    <div id="pal-list" class="pal-list" role="listbox" aria-label="Resultados">
      <template v-for="g in groups" :key="g.title">
        <div class="pal-sec">{{ g.title }}</div>
        <div
          v-for="it in g.items" :id="optId(flat.indexOf(it))" :key="it.id" class="pal-opt" role="option" :aria-selected="flat.indexOf(it) === active"
          :class="{ 'is-active': flat.indexOf(it) === active }" @mousemove="active = flat.indexOf(it)" @mousedown.prevent="run(it)"
        >
          <span v-if="it.ai" class="ai" aria-hidden="true">✦</span><component :is="it.icon" v-else :size="17" aria-hidden="true" />
          <span class="pal-main">{{ it.label }}<br v-if="it.sub"><small v-if="it.sub">{{ it.sub }}</small></span>
          <kbd v-if="it.key">{{ it.key }}</kbd>
        </div>
      </template>
      <div v-if="!flat.length" class="empty" style="padding: 1rem">
        <p>Nada com “{{ q }}”. Tente o nome, a placa ou o número da OS.</p>
      </div>
    </div>
    <div class="pal-foot"><span><kbd>↑</kbd> <kbd>↓</kbd> escolher</span><span><kbd>Enter</kbd> abrir</span><span><kbd>Esc</kbd> fechar</span></div>
  </Layer>
</template>
