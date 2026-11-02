<script setup>
import { computed, ref, watch, nextTick } from 'vue'
import { Check, X } from 'lucide-vue-next'
import { prefs, ui, db, go, resetData, orderById, customerOf, rest, total, undo, receiveMany, METHODS, act, toast, deviceOf, clientLink, chargeOf, createCharge, greeting, STATUS } from '../store.js'
import { brl, plural, modKey, parseMoney, vMoney } from '../format.js'
import Layer from './Layer.vue'
import ClientPage from './ClientPage.vue'
import PrintSheet from './PrintSheet.vue'

/* picker */
function pick(op) { const f = ui.picker.onPick; ui.picker = null; nextTick(() => f(op.id)) }
function arrow(e) {
  const list = [...e.currentTarget.querySelectorAll('button')]
  const i = list.indexOf(document.activeElement)
  if (e.key === 'ArrowDown') { e.preventDefault(); list[(i + 1) % list.length].focus() }
  if (e.key === 'ArrowUp') { e.preventDefault(); list[(i - 1 + list.length) % list.length].focus() }
}
/* confirm */
function okConfirm() { const f = ui.confirm.onOk; ui.confirm = null; f() }

/* receive */
const method = ref(null); const amount = ref(''); const recvError = ref(''); let lastMethod = null
const recvOrders = computed(() => (ui.receive || []).map(orderById).filter(Boolean))
const recvTotal = computed(() => recvOrders.value.reduce((s, o) => s + rest(o), 0))
const recvPeople = computed(() => {
  const m = new Map()
  recvOrders.value.forEach((o) => {
    const c = customerOf(o)
    m.set(c.id, { name: c.name, value: (m.get(c.id)?.value || 0) + rest(o), count: (m.get(c.id)?.count || 0) + 1 })
  })
  return [...m.values()]
})
watch(() => ui.receive, () => { amount.value = recvOrders.value.length === 1 ? String(recvTotal.value).replace('.', ',') : ''; method.value = lastMethod; recvError.value = '' })
const parsedAmount = computed(() => parseMoney(amount.value))
const recvValue = computed(() => (recvOrders.value.length === 1 ? parsedAmount.value || 0 : recvTotal.value))
function pickMethod(id, e) {
  method.value = id; recvError.value = ''
  if (e.detail === 0) e.currentTarget.closest('form').querySelector('[type=submit]').focus()
}
function confirmReceive() {
  if (!recvValue.value) return
  if (!method.value) { recvError.value = 'Escolha como o cliente pagou.'; document.querySelector('.layer fieldset button')?.focus(); return }
  lastMethod = method.value
  receiveMany(recvOrders.value, method.value, recvOrders.value.length === 1 ? Math.min(recvValue.value, recvTotal.value) : undefined)
  ui.receive = null
}

/* send */
const sendOrder = computed(() => ui.send && orderById(ui.send))
const sendValues = ref(true); const sendPhotos = ref(true); const sendPay = ref(true)
const canPay = computed(() => { const o = sendOrder.value; return !!o && rest(o) > 0 && o.status !== 'quote' && o.status !== 'canceled' })
const sendDefault = computed(() => {
  const o = sendOrder.value
  if (!o) return ''
  const c = customerOf(o); const d = deviceOf(o)
  const money = sendValues.value ? ` Total: ${brl(total(o))}.` : ''
  const pay = canPay.value && sendPay.value ? ' Pelo link você paga por Pix, boleto ou cartão.' : ''
  return `Olá, ${greeting(c)}! Aqui é da ${db.value.company}. A sua OS ${o.number}${d ? ` (${d.label})` : ''} está assim: ${STATUS[o.status].label.toLowerCase()}. Veja os detalhes neste link: ${clientLink(o)}.${money}${pay}`
})
const sendText = ref('')
watch(sendDefault, (t) => { sendText.value = t }, { immediate: true })
watch(() => ui.send, () => { sendValues.value = true; sendPhotos.value = true; sendPay.value = true })
function doSend() {
  const o = sendOrder.value
  navigator.clipboard?.writeText(sendText.value).catch(() => {})
  act('Mensagem copiada. Cole no WhatsApp do cliente.', () => {
    o.sentAt = new Date().toISOString(); o.copiedOnly = true; o.sentTotal = total(o)
    if (canPay.value && sendPay.value) createCharge([o])
  })
  ui.send = null
}
function printFromSend() { const id = ui.send; ui.send = null; nextTick(() => { ui.print = id }) }

/* print */
const printOrder = computed(() => ui.print && orderById(ui.print))
const printValues = ref(true)
function doPrint() { window.print() }
const recvHasLink = computed(() => recvOrders.value.some((o) => chargeOf(o)))
/* assistant batch */
function applyAssist() { const f = ui.assist.onApply; ui.assist = null; f() }

const SHORTCUTS = [
  ['Buscar e comandos', `${modKey} K`], ['Nova OS', 'N'], ['Filtrar a lista', '/'], ['Ir para as áreas', '1 a 7'],
  ['Próxima e anterior', 'J K'], ['Abrir no painel', 'Enter'], ['OS em página inteira', `${modKey} Enter`], ['Selecionar linha', 'Espaço'],
  ['Adicionar serviço ou peça', 'A'], ['Trocar cliente', 'C'], ['Trocar veículo ou equipamento', 'V'], ['Marcar dia e hora', 'D'],
  ['Mandar ao cliente', 'M'], ['Imprimir', 'P'], ['Anexar foto', 'F'], ['Mudar a situação', 'S'], ['Receber', 'R'],
  ['Mover cartão no quadro', 'Shift ← →'], ['Mover na agenda', 'Setas'], ['Fechar', 'Esc'], ['Esta lista', '?'],
]
const OPTS = {
  seg: [['auto', 'Oficina'], ['hvac', 'Refrigeração']],
  theme: [['light', 'Claro'], ['dark', 'Escuro'], ['system', 'Sistema']],
  action: [['yellow', 'Amarelo'], ['blue', 'Azul']],
  density: [['comfy', 'Confortável'], ['compact', 'Compacta']],
  font: [['sober', 'Mais sóbria'], ['site', 'Do site']],
}
</script>

<template>
  <Layer v-if="ui.picker" :label="ui.picker.title" @close="ui.picker = null">
    <div class="layer-pad">
      <div><h2 class="layer-title">{{ ui.picker.title }}</h2><p v-if="ui.picker.sub" class="muted">{{ ui.picker.sub }}</p></div>
      <div class="opts" @keydown="arrow">
        <button v-for="(op, i) in ui.picker.options" :key="op.id" class="opt" :data-autofocus="op.current || i === 0 ? '' : undefined" :class="{ 'btn--danger': op.danger }" @click="pick(op)">
          <span v-if="op.dot" class="dot" :class="'dot--' + op.dot" aria-hidden="true"></span>{{ op.label }}
          <Check v-if="op.current" class="check-mark" :size="16" aria-label="atual" />
        </button>
      </div>
    </div>
  </Layer>

  <Layer v-if="ui.confirm" :label="ui.confirm.title" @close="ui.confirm = null">
    <div class="layer-pad"><h2 class="layer-title">{{ ui.confirm.title }}</h2><p class="muted">{{ ui.confirm.body }}</p></div>
    <div class="layer-foot">
      <button class="btn" data-autofocus @click="ui.confirm = null">{{ ui.confirm.keep || 'Voltar' }}</button>
      <button class="btn" :class="{ 'btn--danger': ui.confirm.danger }" @click="okConfirm">{{ ui.confirm.label }}</button>
    </div>
  </Layer>

  <Layer v-if="ui.receive" kind="dialog" label="Receber" @close="ui.receive = null">
    <form style="display: contents" @submit.prevent="confirmReceive">
      <div class="layer-pad">
        <h2 class="layer-title">Receber {{ brl(recvValue) }}</h2>
        <div class="opts" style="gap: .15rem">
          <div v-for="p in recvPeople" :key="p.name" class="pay-row"><span>{{ p.name }}, {{ plural(p.count, 'OS', 'OS') }}</span><span class="num">{{ brl(p.value) }}</span></div>
        </div>
        <div v-if="recvOrders.length === 1">
          <label class="field-label" for="rc-amount">Quanto recebeu?</label>
          <input id="rc-amount" v-model="amount" v-money class="field" data-autofocus>
        </div>
        <fieldset style="border: 0; padding: 0; margin: 0">
          <legend class="field-label">Como pagou?</legend>
          <div class="tabs" style="display: flex">
            <button v-for="[id, name] in METHODS" :key="id" type="button" style="flex: 1" :data-autofocus="recvOrders.length > 1 && id === 'pix' ? '' : undefined" :aria-pressed="method === id" @click="pickMethod(id, $event)">{{ name }}</button>
          </div>
          <p v-if="recvError" class="warn" role="alert">{{ recvError }}</p>
        </fieldset>
        <p v-if="recvHasLink" class="muted small">O link de pagamento que o cliente recebeu deixa de funcionar.</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="ui.receive = null">Voltar</button>
        <button type="submit" class="btn btn--primary">Marcar como recebido <kbd>Enter</kbd></button>
      </div>
    </form>
  </Layer>

  <Layer v-if="ui.send && sendOrder" kind="send" label="Mandar ao cliente" @close="ui.send = null">
    <div class="send">
      <div class="layer-pad">
        <h2 class="layer-title">Mandar ao cliente</h2>
        <p class="muted">Copia a mensagem com o link. Depois é só colar no WhatsApp de {{ customerOf(sendOrder).name }}, {{ customerOf(sendOrder).phone }}.</p>
        <div class="ticks">
          <label class="tick"><input v-model="sendValues" class="check" type="checkbox">Mostrar valores</label>
          <label class="tick"><input v-model="sendPhotos" class="check" type="checkbox">Mostrar fotos</label>
          <label v-if="canPay" class="tick"><input v-model="sendPay" class="check" type="checkbox">Incluir link de pagamento de {{ brl(rest(sendOrder)) }}</label>
        </div>
        <div><label class="field-label" for="send-text">Mensagem</label><textarea id="send-text" v-model="sendText" class="field" rows="6"></textarea></div>
      </div>
      <div class="send-preview">
        <p class="field-label">O que o cliente vê</p>
        <ClientPage :order="sendOrder" :show-values="sendValues" :show-photos="sendPhotos" :show-pay="canPay && sendPay" />
      </div>
    </div>
    <div class="layer-foot">
      <button class="btn" @click="printFromSend">Imprimir</button>
      <span class="spacer"></span>
      <button class="btn" @click="ui.send = null">Voltar</button>
      <button class="btn btn--primary" data-autofocus @click="doSend">Copiar mensagem</button>
    </div>
  </Layer>

  <Layer v-if="printOrder" kind="print" :label="`Imprimir OS ${printOrder.number}`" @close="ui.print = null">
    <div class="print-bar">
      <h2 class="layer-title">Imprimir OS {{ printOrder.number }}</h2>
      <span class="spacer"></span>
      <label class="tick"><input v-model="printValues" class="check" type="checkbox">Mostrar valores</label>
      <button class="btn" @click="ui.print = null">Voltar</button>
      <button class="btn btn--primary" data-autofocus @click="doPrint">Imprimir</button>
    </div>
    <div class="print-area"><PrintSheet :order="printOrder" :show-values="printValues" /></div>
  </Layer>

  <Layer v-if="ui.assist" :label="ui.assist.title" @close="ui.assist = null">
    <div class="layer-pad">
      <h2 class="layer-title"><span class="ai">✦</span> {{ ui.assist.title }}</h2>
      <p class="muted">{{ ui.assist.body }}</p>
      <div>
        <div v-for="l in ui.assist.lines" :key="l.id" class="pay-row"><span>{{ l.text }}</span><span class="num">{{ l.right }}</span></div>
      </div>
      <p v-if="ui.assist.sample" style="background: var(--color-paper-2); padding: .6rem .7rem; border-radius: 6px">{{ ui.assist.sample }}</p>
    </div>
    <div class="layer-foot">
      <button class="btn" data-autofocus @click="ui.assist = null">Agora não</button>
      <button class="btn btn--primary" @click="applyAssist">{{ ui.assist.label }}</button>
    </div>
  </Layer>

  <Layer v-if="ui.lightbox" :label="ui.lightbox.label" @close="ui.lightbox = null">
    <div class="layer-pad">
      <h2 class="layer-title">{{ ui.lightbox.label }}</h2>
      <div class="lightbox"><img v-if="ui.lightbox.src" :src="ui.lightbox.src" :alt="ui.lightbox.label"><span v-else class="muted">Foto de exemplo</span></div>
    </div>
    <div class="layer-foot"><button class="btn" data-autofocus @click="ui.lightbox = null">Fechar</button></div>
  </Layer>

  <Layer v-if="ui.shortcuts" kind="cheat" label="Atalhos" class="layer--dialog" @close="ui.shortcuts = null">
    <div class="layer-pad">
      <h2 class="layer-title">Atalhos do teclado</h2>
      <div class="cheat"><div v-for="[l, k] in SHORTCUTS" :key="l"><span>{{ l }}</span><kbd>{{ k }}</kbd></div></div>
      <p class="muted small">Toda ação tem botão. Atalho de uma tecla só funciona fora dos campos de texto.</p>
    </div>
    <div class="layer-foot"><button class="btn" data-autofocus @click="ui.shortcuts = null">Fechar</button></div>
  </Layer>

  <aside v-if="ui.proto" class="proto" aria-label="Ajustes do protótipo">
    <h2>Ajustes do protótipo, não fazem parte do produto</h2>
    <div v-for="(list, key) in OPTS" :key="key" class="proto-row">
      <span>{{ { seg: 'Ramo', theme: 'Tema', action: 'Botão principal', density: 'Densidade', font: 'Fonte' }[key] }}</span>
      <span class="tabs"><button v-for="[id, name] in list" :key="id" :aria-pressed="prefs[key] === id" @click="prefs[key] = id">{{ name }}</button></span>
    </div>
    <div class="proto-row"><span>Dados</span>
      <span class="tabs">
        <button :aria-pressed="!prefs.empty" @click="prefs.empty = false">Com exemplos</button>
        <button :aria-pressed="prefs.empty" @click="prefs.empty = true">Conta vazia</button>
      </span>
    </div>
    <button class="btn" @click="ui.proto = false; go('entrada')">Ver a tela de entrada</button>
    <button class="btn" @click="resetData(); ui.proto = false">Voltar os dados ao início</button>
  </aside>

  <div v-if="ui.toast" class="toast" role="status">
    <span>{{ ui.toast.text }}</span>
    <button v-if="ui.toast.undo" class="link" @click="undo">Desfazer</button>
    <button v-if="ui.toast.undo" class="icon-btn toast-x" aria-label="Fechar aviso" @click="ui.toast = null"><X :size="16" aria-hidden="true" /></button>
  </div>
</template>
