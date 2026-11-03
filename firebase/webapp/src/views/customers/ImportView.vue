<script setup lang="ts">
// Customers from a spreadsheet (desk extra of fatia 03). Three steps, one
// question each: which file, what each column holds, and what goes in. A phone
// already of a customer, or twice in the file, stays out; nothing is saved
// before "Importar". The file is read here, in the browser.
import { computed, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { Upload } from '@lucide/vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { importCustomers, loadCustomerDirectory } from '@/lib/customers/data'
import { guessFields, IMPORT_CHUNK, IMPORT_FIELDS, IMPORT_MAX_ROWS, importPayload, parseCsv, readFile, reviewRows, type ImportField, type ImportRow } from '@/lib/customers/import'
import { formatPhone } from '@/lib/phone'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/customers.css'

const router = useRouter()
const step = ref<'pick' | 'map' | 'review'>('pick')
const table = shallowRef<string[][]>([])
const fields = ref<ImportField[]>([])
const review = shallowRef<ImportRow[]>([])
const pasted = ref('')
const over = ref(false)
const message = ref('')
const busy = ref(false)
const progress = ref(0)
const country = session.company?.country

const headers = computed(() => table.value[0] ?? [])
const body = computed(() => table.value.slice(1))
const good = computed(() => review.value.filter((row) => row.state === 'ok'))
const out = computed(() => review.value.length - good.value.length)
const hasName = computed(() => fields.value.includes('name'))
const FIELD_LABEL: Record<ImportField, () => string> = {
  '': () => t('web.import.skip'),
  name: () => t('name'),
  phone: () => t('phone'),
  email: () => t('email'),
  address: () => t('address'),
  taxId: () => t('cpfCnpj'),
}
const title = computed(() =>
  step.value === 'pick' ? t('web.import.title') : step.value === 'map' ? t('web.import.mapTitle') : t('web.import.reviewTitle', { count: good.value.length }),
)
const sub = computed(() =>
  step.value === 'pick' ? t('web.import.pickSub') : step.value === 'map' ? t('web.import.mapSub') : out.value ? t('web.import.outCount', { count: out.value }) : t('web.import.noneOut'),
)

function use(rows: string[][]) {
  if (rows.length < 2) {
    message.value = t('web.import.needsRows')
    return
  }
  if (rows.length - 1 > IMPORT_MAX_ROWS) {
    message.value = t('web.import.tooMany', { count: IMPORT_MAX_ROWS })
    return
  }
  table.value = rows
  fields.value = guessFields(rows[0] ?? [])
  message.value = ''
  step.value = 'map'
  announce(t('web.import.mapTitle'))
}

async function pickFile(file: File | undefined) {
  if (!file) return
  try {
    use(await readFile(file))
  } catch (error) {
    message.value = (error as Error)?.message === 'xls' ? t('web.import.oldExcel') : t('web.import.unreadable')
  }
}

async function toReview() {
  if (!hasName.value) return
  busy.value = true
  try {
    const directory = await loadCustomerDirectory(true)
    review.value = reviewRows(body.value, fields.value, directory.rows, country)
    step.value = 'review'
    announce(title.value)
  } catch (error) {
    message.value = t(errorMessageKey(error))
  } finally {
    busy.value = false
  }
}

/** In parts of up to 400 lines; each part has its id, so sending again never doubles a line. */
async function finish() {
  const payload = importPayload(review.value)
  if (!payload.length || busy.value) return
  busy.value = true
  progress.value = 0
  const importId = crypto.randomUUID()
  let created = 0
  try {
    for (let start = 0, part = 0; start < payload.length; start += IMPORT_CHUNK, part++) {
      const result = await importCustomers(`${importId}-${part}`, payload.slice(start, start + IMPORT_CHUNK))
      created += result.created + result.existing
      progress.value = Math.min(payload.length, start + IMPORT_CHUNK)
    }
    await loadCustomerDirectory(true)
    showToast(t('web.import.done', { count: created }))
    announce(t('web.import.done', { count: created }))
    void router.push('/customers')
  } catch (error) {
    message.value = `${t('web.import.failed', { count: created })} ${t(errorMessageKey(error))}`
  } finally {
    busy.value = false
  }
}

const stateText = (row: ImportRow) => {
  if (row.state === 'ok') return t('web.import.goesIn')
  if (row.state === 'noName') return t('web.import.noName')
  if (row.state === 'badTaxId') return t('web.import.badTaxId')
  if (row.state === 'duplicate') return t('web.import.duplicate', { name: row.clash ?? '' })
  return t('web.import.repeated', { line: row.clash ?? '' })
}
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p class="page-sub" data-testid="import-sub">{{ sub }}</p>
    </div>
    <RouterLink v-if="step === 'pick'" class="btn" to="/customers">{{ t('back') }}</RouterLink>
    <template v-else>
      <button type="button" class="btn" @click="step = step === 'review' ? 'map' : 'pick'">{{ t('back') }}</button>
      <button v-if="step === 'map'" type="button" class="btn btn--primary" :aria-disabled="!hasName || busy" data-testid="import-continue" @click="toReview">{{ t('web.import.continue') }}</button>
      <button v-else type="button" class="btn btn--primary" :aria-disabled="!good.length || busy" data-testid="import-finish" @click="finish">
        {{ busy ? t('web.import.progress', { done: progress, total: good.length }) : t('web.import.finish', { count: good.length }) }}
      </button>
    </template>
  </header>

  <div v-if="!can('manageCustomers')" class="empty" role="alert"><h2>{{ t('web.error.forbidden') }}</h2></div>
  <div v-else class="imp">
    <p v-if="message" class="field-error" role="alert" data-testid="import-message">{{ message }}</p>
    <template v-if="step === 'pick'">
      <div class="imp-pick">
        <label class="imp-drop" :class="{ 'is-over': over }" @dragover.prevent="over = true" @dragleave="over = false" @drop.prevent="over = false; pickFile($event.dataTransfer?.files[0])">
          <Upload :size="26" aria-hidden="true" />
          <strong>{{ t('web.import.drop') }}</strong>
          <span class="muted">{{ t('web.import.formats') }}</span>
          <input class="sr" type="file" accept=".csv,.txt,.xlsx" data-testid="import-file" @change="pickFile(($event.target as HTMLInputElement).files?.[0])" />
        </label>
        <div class="imp-paste">
          <label class="field-label" for="imp-text">{{ t('web.import.paste') }}</label>
          <textarea id="imp-text" v-model="pasted" class="field" rows="7"></textarea>
          <button type="button" class="btn" :aria-disabled="!pasted.trim()" @click="pasted.trim() && use(parseCsv(pasted))">{{ t('web.import.usePasted') }}</button>
        </div>
      </div>
      <p class="muted small">{{ t('web.import.rule') }}</p>
    </template>

    <template v-else-if="step === 'map'">
      <div class="imp-scroll">
        <table class="grid imp-table" data-testid="import-map">
          <caption class="sr">{{ t('web.import.mapTitle') }}</caption>
          <thead>
            <tr>
              <th v-for="(header, index) in headers" :key="index" scope="col">
                <span class="imp-h">{{ header }}</span>
                <select v-model="fields[index]" class="field select-mini" :aria-label="t('web.import.columnOf', { column: header })">
                  <option v-for="field in IMPORT_FIELDS" :key="field" :value="field">{{ FIELD_LABEL[field]() }}</option>
                </select>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(row, index) in body.slice(0, 5)" :key="index" class="no-click">
              <td v-for="(_, column) in headers" :key="column" :class="{ muted: !fields[column] }">{{ row[column] }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="!hasName" class="field-error" role="status">{{ t('web.import.needsName') }}</p>
      <p class="muted small">{{ t('web.import.showing', { shown: Math.min(5, body.length), total: body.length }) }}</p>
    </template>

    <div v-else class="imp-scroll">
      <table class="grid imp-table" data-testid="import-review">
        <caption class="sr">{{ title }}</caption>
        <thead>
          <tr>
            <th scope="col">{{ t('web.import.line') }}</th>
            <th scope="col">{{ t('name') }}</th>
            <th scope="col">{{ t('phone') }}</th>
            <th scope="col">{{ t('web.import.result') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in review" :key="row.line" class="no-click" :data-state="row.state">
            <td class="num">{{ row.line }}</td>
            <td>{{ row.name || '—' }}</td>
            <td class="num">{{ formatPhone(row.phone, country) }}</td>
            <td>
              <span class="status" :class="{ 'status--warn': row.state !== 'ok' }">
                <span class="dot" :class="row.state === 'ok' ? 'dot--success' : 'dot--warning'" aria-hidden="true"></span>{{ stateText(row) }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
