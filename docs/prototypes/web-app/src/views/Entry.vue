<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { Check } from 'lucide-vue-next'
import { prefs, db, go } from '../store.js'

const step = ref('in'); const email = ref(''); const askMail = ref(false)
const seg = ref('auto'); const name = ref(''); const phone = ref('')
const TRADES = [['auto', 'Oficina mecânica', 'Veículos, placas e peças'], ['hvac', 'Refrigeração e ar-condicionado', 'Equipamentos, visitas e contratos']]
const STEPS = ['ramo', 'negocio', 'clientes']
const at = computed(() => STEPS.indexOf(step.value) + 1)
watch(step, () => nextTick(() => document.querySelector('[data-page-title]')?.focus({ preventScroll: true })))
const start = () => { step.value = 'ramo' }
function done(next) {
  prefs.seg = seg.value; prefs.empty = true
  db.value.company = name.value.trim() || 'Seu negócio'
  go(next)
}
</script>
<template>
  <div class="entry">
    <aside class="entry-side">
      <div class="logo" aria-label="PraticOS">Prát<i>ic</i><b>OS</b></div>
      <p class="entry-claim">Suas ordens de serviço, clientes e cobranças no computador e no celular.</p>
      <p class="fiction">Protótipo com dados fictícios. Nenhuma conta é criada.</p>
    </aside>
    <main class="entry-main">
      <div class="entry-box">
        <template v-if="step === 'in'">
          <h1 class="page-title" tabindex="-1" data-page-title>Entrar no PraticOS</h1>
          <p class="muted">Use a mesma conta do celular. Tudo o que está lá aparece aqui.</p>
          <div class="entry-btns">
            <button class="btn btn--primary btn--wide" @click="start">Continuar com Google</button>
            <button class="btn btn--wide" @click="start">Continuar com Apple</button>
            <button v-if="!askMail" class="btn btn--wide" @click="askMail = true">Continuar com e-mail</button>
            <form v-else class="entry-mail" @submit.prevent="start">
              <label class="field-label" for="en-mail">Seu e-mail</label>
              <input id="en-mail" v-model="email" class="field" type="email" autocomplete="off" autofocus>
              <button class="btn btn--wide" :disabled="!email.includes('@')">Mandar link de entrada</button>
            </form>
          </div>
          <button class="proto-sim" @click="go('inicio')">Simular quem já tem conta</button>
        </template>
        <template v-else-if="step === 'ramo'">
          <p class="muted small">Passo {{ at }} de 3</p>
          <h1 class="page-title" tabindex="-1" data-page-title>Com o que você trabalha?</h1>
          <div class="opts">
            <button v-for="[id, label, sub] in TRADES" :key="id" class="opt opt--big" :aria-pressed="seg === id" @click="seg = id">
              <span><strong>{{ label }}</strong><span class="sub block-line">{{ sub }}</span></span>
              <Check v-if="seg === id" class="check-mark" :size="17" aria-label="escolhido" />
            </button>
          </div>
          <button class="btn btn--primary btn--wide" @click="step = 'negocio'">Continuar</button>
        </template>
        <form v-else-if="step === 'negocio'" class="entry-form" @submit.prevent="step = 'clientes'">
          <p class="muted small">Passo {{ at }} de 3</p>
          <h1 class="page-title" tabindex="-1" data-page-title>Como seu negócio se chama?</h1>
          <p class="muted">É o nome que seu cliente vê em cada ordem de serviço. Se trabalha sozinho, pode ser o seu.</p>
          <p class="muted"><strong>OS</strong> é a ordem de serviço: o registro de cada trabalho. Você vai ver essa sigla em todo o sistema.</p>
          <div><label class="field-label" for="en-name">Nome</label><input id="en-name" v-model="name" class="field" autocomplete="off"></div>
          <div><label class="field-label" for="en-phone">WhatsApp do negócio</label><input id="en-phone" v-model="phone" class="field" inputmode="tel" autocomplete="off"></div>
          <button class="btn btn--primary btn--wide" :disabled="!name.trim()">Continuar</button>
          <button type="button" class="link" @click="step = 'ramo'">Voltar</button>
        </form>
        <template v-else>
          <p class="muted small">Passo {{ at }} de 3</p>
          <h1 class="page-title" tabindex="-1" data-page-title>Você já tem uma lista de clientes?</h1>
          <p class="muted">Traga de uma planilha ou de outro sistema e comece com tudo pronto.</p>
          <button class="btn btn--primary btn--wide" @click="done('importar')">Importar planilha</button>
          <button class="btn btn--wide" @click="done('inicio')">Agora não</button>
        </template>
      </div>
    </main>
  </div>
</template>
