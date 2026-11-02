<script setup>
import { computed, ref } from 'vue'
import { UploadCloud } from 'lucide-vue-next'
import { db, go, act, phoneDigits, phone } from '../store.js'
import { norm, plural } from '../format.js'

const FIELDS = [['', 'Não importar'], ['name', 'Nome'], ['phone', 'Telefone'], ['email', 'E-mail'], ['address', 'Endereço'], ['zip', 'CEP'], ['device', 'Veículo ou equipamento']]
const SAMPLE = `Nome;Celular;E-mail;Endereço;CEP;Carro ou equipamento;Observação
Rita Fagundes;(47) 90000-1101;rita@exemplo.com.br;Rua Sete, 12;89100-100;Fiat Argo 2021;cliente antiga
Paulo Nogueira;(47) 90000-1102;;Rua das Flores, 90;89100-110;Ford Ka 2018;
Mercado Bom Preço;(47) 90000-1103;compras@exemplo.com.br;Av. Central, 500;89100-120;Fiat Strada 2022;empresa
Helena Duarte;(47) 90000-1104;;;;Chevrolet Prisma 2016;
Tiago Bastos;(47) 90000-1105;tiago@exemplo.com.br;Rua Oito, 3;89100-130;;
Rita F.;47 90000-1101;;;;;mesmo número da primeira
;(47) 90000-1106;;;;;sem nome
Sandra Melo;(47) 90000-1107;;Rua Nova, 44;89100-140;Honda Fit 2015;
Marcos Vieira;(47) 90000-0118;;;;;telefone repetido`
const step = ref('pick'); const text = ref(''); const drag = ref(false); const msg = ref('')
const table = ref([]); const map = ref([])

function guess(h) {
  const t = norm(h)
  if (/nome|cliente|razao/.test(t)) return 'name'
  if (/cel|tel|fone|whats/.test(t)) return 'phone'
  if (/mail/.test(t)) return 'email'
  if (/cep/.test(t)) return 'zip'
  if (/end|rua|logradouro/.test(t)) return 'address'
  if (/carro|veic|placa|equip|aparelho/.test(t)) return 'device'
  return ''
}
function read(raw) {
  const lines = raw.split(/\r?\n/).filter((l) => l.trim())
  if (lines.length < 2) { msg.value = 'Precisa ter a linha de títulos e pelo menos um cliente.'; return }
  const sep = ['\t', ';', ','].find((s) => lines[0].includes(s)) || ';'
  const rows = lines.map((l) => l.split(sep).map((x) => x.trim()))
  map.value = rows[0].map(guess)
  table.value = rows
  msg.value = ''; step.value = 'map'
}
function pickFile(file) {
  if (!file) return
  if (/\.xlsx?$/i.test(file.name)) { msg.value = 'Neste protótipo, abra a planilha, copie as linhas e cole no quadro ao lado.'; return }
  file.text().then(read)
}
const headers = computed(() => table.value[0] || [])
const body = computed(() => table.value.slice(1))
const valueOf = (row, key) => { const i = map.value.indexOf(key); return i < 0 ? '' : row[i] || '' }
const review = computed(() => {
  const seen = new Map(db.value.customers.map((c) => [phoneDigits(c.phone), c.name]))
  return body.value.map((row) => {
    const name = valueOf(row, 'name'); const phone = valueOf(row, 'phone'); const digits = phoneDigits(phone)
    const dup = digits.length >= 10 ? seen.get(digits) : null
    const state = !name ? 'noname' : dup ? 'dup' : 'ok'
    if (state === 'ok' && digits) seen.set(digits, name)
    return { row, name, phone, device: valueOf(row, 'device'), state, why: state === 'noname' ? 'Sem nome' : state === 'dup' ? `Telefone já é de ${dup}` : '' }
  })
})
const good = computed(() => review.value.filter((r) => r.state === 'ok'))
const skip = computed(() => review.value.length - good.value.length)
const hasName = computed(() => map.value.includes('name'))
function finish() {
  const stamp = Date.now()
  act(`${plural(good.value.length, 'cliente importado', 'clientes importados')}`, () => {
    good.value.forEach((r, i) => {
      const id = `im${stamp}${i}`
      db.value.customers.unshift({
        id, name: r.name, phone: r.phone, email: valueOf(r.row, 'email'), address: valueOf(r.row, 'address'), zip: valueOf(r.row, 'zip'), kind: 'person',
        devices: r.device ? [{ id: id + 'd', label: r.device, tag: '' }] : [],
      })
    })
  })
  go('clientes')
}
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ step === 'pick' ? 'Traga seus clientes de uma planilha' : step === 'map' ? 'O que tem em cada coluna?' : `${plural(good.length, 'cliente pronto', 'clientes prontos')} para entrar` }}</h1>
      <p class="page-sub">{{ step === 'pick' ? 'Excel, Google Planilhas ou arquivo de outro sistema.' : step === 'map' ? 'Já marquei o que reconheci. Confira.' : skip ? `${plural(skip, 'linha fica', 'linhas ficam')} de fora.` : 'Nenhuma linha ficou de fora.' }}</p>
    </div>
    <span class="spacer"></span>
    <button v-if="step === 'pick'" class="btn" @click="go('clientes')">Voltar</button>
    <template v-else>
      <button class="btn" @click="step = step === 'done' ? 'map' : 'pick'">Voltar</button>
      <button v-if="step === 'map'" class="btn btn--primary" :disabled="!hasName" @click="step = 'done'">Continuar</button>
      <button v-else class="btn btn--primary" :disabled="!good.length" @click="finish">Importar {{ plural(good.length, 'cliente', 'clientes') }}</button>
    </template>
  </header>
  <div class="imp">
    <template v-if="step === 'pick'">
      <div class="imp-pick">
        <label class="imp-drop" :class="{ 'is-over': drag }" @dragover.prevent="drag = true" @dragleave="drag = false" @drop.prevent="drag = false; pickFile($event.dataTransfer.files[0])">
          <UploadCloud :size="26" aria-hidden="true" /><strong>{{ phone ? 'Toque para escolher o arquivo' : 'Arraste o arquivo aqui' }}</strong><span v-if="!phone" class="muted">ou clique para escolher</span>
          <input class="sr" type="file" accept=".csv,.txt,.xls,.xlsx" aria-label="Escolher arquivo" @change="pickFile($event.target.files[0])">
        </label>
        <div class="imp-paste">
          <label class="field-label" for="imp-text">Ou copie as linhas da planilha e cole aqui</label>
          <textarea id="imp-text" v-model="text" class="field" rows="7"></textarea>
          <div class="row-gap"><button class="btn" :disabled="!text.trim()" @click="read(text)">Usar o que colei</button><button class="link" @click="read(SAMPLE)">Usar planilha de exemplo</button></div>
        </div>
      </div>
      <p v-if="msg" class="warn" role="status">{{ msg }}</p>
      <p class="muted small">Telefone repetido não entra duas vezes. Neste protótipo, nada sai do seu navegador.</p>
    </template>
    <template v-else-if="step === 'map'">
      <div class="imp-scroll">
        <table class="grid imp-table">
          <thead><tr><th v-for="(h, i) in headers" :key="i"><span class="imp-h">{{ h }}</span><select v-model="map[i]" class="field select-mini" :aria-label="`O que tem na coluna ${h}`"><option v-for="[v, l] in FIELDS" :key="v" :value="v">{{ l }}</option></select></th></tr></thead>
          <tbody><tr v-for="(r, i) in body.slice(0, 5)" :key="i" class="no-click"><td v-for="(_, j) in headers" :key="j" :class="{ muted: !map[j] }">{{ r[j] }}</td></tr></tbody>
        </table>
      </div>
      <p v-if="!hasName" class="warn" role="status">Escolha a coluna do nome para continuar.</p>
      <p class="muted small">Mostrando {{ Math.min(5, body.length) }} de {{ plural(body.length, 'linha', 'linhas') }}.</p>
    </template>
    <div v-else class="imp-scroll">
      <table class="grid imp-table">
        <thead><tr><th>Nome</th><th>Telefone</th><th>{{ db.labels.device }}</th><th>Situação</th></tr></thead>
        <tbody>
          <tr v-for="(r, i) in review" :key="i" class="no-click">
            <td class="who">{{ r.name || '(sem nome)' }}</td><td><span class="num">{{ r.phone }}</span></td><td>{{ r.device }}</td>
            <td><span v-if="r.state === 'ok'" class="status"><span class="dot dot--success" aria-hidden="true"></span>Vai entrar</span><span v-else class="status status--warn"><span class="dot dot--warning" aria-hidden="true"></span>Fica de fora: {{ r.why }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
