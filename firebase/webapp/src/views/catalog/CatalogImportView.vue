<script setup lang="ts">
// Catalog from a spreadsheet (desk extra of fatia 05), the same three steps as
// the customer import: which file, what each column holds, and what goes in.
// A name already in the catalog, or twice in the file, stays out; prices are
// read as typed ("150" is 150) and only for who changes prices. Nothing is
// saved before "Importar"; the import id is born on the review, so sending
// again after a failure never doubles a line.
import { computed, ref, shallowRef } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Upload } from '@lucide/vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { importItems, loadCatalogList } from '@/lib/catalog/data'
import {
  CATALOG_FIELDS,
  CATALOG_IMPORT_CHUNK,
  CATALOG_IMPORT_MAX_ROWS,
  catalogImportPayload,
  guessCatalogFields,
  pickKind,
  reviewCatalogRows,
  visibleKinds,
  type CatalogField,
  type CatalogImportRow,
  type CatalogKind,
} from '@/lib/catalog/model'
import { parseCsv, readFile } from '@/lib/customers/import'
import { money } from '@/lib/orders/text'
import { forgetLists } from '@/lib/orders/catalog'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/customers.css'
import '@/styles/catalog.css'

const route = useRoute()
const router = useRouter()
const manageable = visibleKinds((permission) => can(permission)).filter((kind) => can(kind === 'service' ? 'manageServices' : 'manageProducts'))
const defaultKind = ref<CatalogKind>(pickKind(route.query.kind, manageable) ?? 'service')
const step = ref<'pick' | 'map' | 'review'>('pick')
const table = shallowRef<string[][]>([])
const fields = ref<CatalogField[]>([])
const review = shallowRef<CatalogImportRow[]>([])
const pasted = ref('')
const over = ref(false)
const message = ref('')
const busy = ref(false)
const progress = ref(0)
const country = session.company?.country
const prices = can('editPrices')
let importId = ''

const productLabel = computed(() => resolveLabel('product._entity', segmentLabels(), (key) => t(key), t('product')))
const kindName = (kind: CatalogKind | null) => (kind === 'service' ? t('service') : kind === 'product' ? productLabel.value : '—')
const headers = computed(() => table.value[0] ?? [])
const body = computed(() => table.value.slice(1))
const good = computed(() => review.value.filter((row) => row.state === 'ok'))
const out = computed(() => review.value.length - good.value.length)
const hasName = computed(() => fields.value.includes('name'))
const offered = computed(() => CATALOG_FIELDS.filter((field) => field !== 'value' || prices))
const showPrice = computed(() => prices && fields.value.includes('value'))
const FIELD_LABEL: Record<CatalogField, () => string> = {
  '': () => t('web.import.skip'),
  name: () => t('name'),
  kind: () => t('web.catalogImport.kind'),
  value: () => t('catalogPriceLabel'),
}
const title = computed(() =>
  step.value === 'pick' ? t('web.catalogImport.title') : step.value === 'map' ? t('web.import.mapTitle') : t('web.catalogImport.reviewTitle', { count: good.value.length }),
)
const sub = computed(() =>
  step.value === 'pick' ? t('web.import.pickSub') : step.value === 'map' ? t('web.import.mapSub') : out.value ? t('web.import.outCount', { count: out.value }) : t('web.import.noneOut'),
)

function use(rows: string[][]) {
  if (rows.length < 2) {
    message.value = t('web.catalogImport.needsRows')
    return
  }
  if (rows.length - 1 > CATALOG_IMPORT_MAX_ROWS) {
    message.value = t('web.import.tooMany', { count: CATALOG_IMPORT_MAX_ROWS })
    return
  }
  table.value = rows
  // A price column is never offered to who does not change prices.
  fields.value = guessCatalogFields(rows[0] ?? []).map((field) => (field === 'value' && !prices ? '' : field))
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
  if (!hasName.value || busy.value) return
  busy.value = true
  try {
    // Fresh lists: what entered a minute ago counts as already there.
    const lists = await Promise.all(manageable.map((kind) => loadCatalogList(kind, true).then((list) => [kind, list.items] as const)))
    const existing = { service: [], product: [], ...Object.fromEntries(lists) } as Record<CatalogKind, { name: string }[]>
    review.value = reviewCatalogRows(body.value, fields.value, existing, { defaultKind: defaultKind.value, country, prices, productLabel: productLabel.value }).map((row) =>
      // A kind the person cannot manage stays out like an unknown one.
      row.state === 'ok' && row.kind && !manageable.includes(row.kind) ? { ...row, state: 'badKind' as const } : row,
    )
    importId = crypto.randomUUID()
    step.value = 'review'
    announce(title.value)
  } catch (error) {
    message.value = t(errorMessageKey(error))
  } finally {
    busy.value = false
  }
}

/** Per kind, in parts; each part has its id, so sending again never doubles a line. */
async function finish() {
  const payload = catalogImportPayload(review.value)
  const total = payload.service.length + payload.product.length
  if (!total || busy.value) return
  busy.value = true
  progress.value = 0
  let done = 0
  try {
    for (const kind of ['service', 'product'] as const) {
      const lines = payload[kind]
      for (let start = 0, part = 0; start < lines.length; start += CATALOG_IMPORT_CHUNK, part++) {
        const result = await importItems(kind, `${importId}-${kind[0]}-${part}`, lines.slice(start, start + CATALOG_IMPORT_CHUNK))
        done += result.created + result.existing
        progress.value = done
      }
    }
    forgetLists()
    showToast(t('web.catalogImport.done', { count: done }))
    announce(t('web.catalogImport.done', { count: done }))
    const kind = payload.service.length ? 'service' : 'product'
    void router.push({ path: '/catalog', query: kind === manageable[0] ? {} : { kind } })
  } catch (error) {
    message.value = `${t('web.import.failed', { count: done })} ${t(errorMessageKey(error))}`
  } finally {
    busy.value = false
  }
}

const stateText = (row: CatalogImportRow) => {
  if (row.state === 'ok') return t('web.import.goesIn')
  if (row.state === 'noName') return t('web.import.noName')
  if (row.state === 'badKind') return t('web.catalogImport.badKind', { product: productLabel.value.toLocaleLowerCase() })
  if (row.state === 'badPrice') return t('web.catalogImport.badPrice')
  if (row.state === 'duplicate') return t('web.catalogImport.duplicate')
  return t('web.catalogImport.repeated', { line: row.clash ?? '' })
}
const priceCell = (row: CatalogImportRow) => (typeof row.value === 'number' ? money(row.value) : row.state === 'badPrice' ? row.rawValue : t('catalogNoPrice'))
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p class="page-sub" data-testid="import-sub">{{ sub }}</p>
    </div>
    <RouterLink v-if="step === 'pick'" class="btn" to="/catalog">{{ t('back') }}</RouterLink>
    <template v-else>
      <button type="button" class="btn" @click="step = step === 'review' ? 'map' : 'pick'">{{ t('back') }}</button>
      <button v-if="step === 'map'" type="button" class="btn btn--primary" :aria-disabled="!hasName || busy" data-testid="import-continue" @click="toReview">{{ t('web.import.continue') }}</button>
      <button v-else type="button" class="btn btn--primary" :aria-disabled="!good.length || busy" data-testid="import-finish" @click="finish">
        {{ busy ? t('web.import.progress', { done: progress, total: good.length }) : t('web.catalogImport.finish', { count: good.length }) }}
      </button>
    </template>
  </header>

  <div v-if="!manageable.length" class="empty" role="alert"><h2>{{ t('web.error.forbidden') }}</h2></div>
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
          <label class="field-label" for="cimp-text">{{ t('web.import.paste') }}</label>
          <textarea id="cimp-text" v-model="pasted" class="field" rows="7"></textarea>
          <button type="button" class="btn" :aria-disabled="!pasted.trim()" @click="pasted.trim() && use(parseCsv(pasted))">{{ t('web.import.usePasted') }}</button>
        </div>
      </div>
      <p class="muted small">{{ t('web.catalogImport.rule') }}</p>
    </template>

    <template v-else-if="step === 'map'">
      <div v-if="manageable.length > 1" class="cat-default">
        <label class="field-label" for="cimp-kind">{{ t('web.catalogImport.defaultKind') }}</label>
        <select id="cimp-kind" v-model="defaultKind" class="field select-mini" data-testid="import-default-kind">
          <option v-for="kind in manageable" :key="kind" :value="kind">{{ kindName(kind) }}</option>
        </select>
      </div>
      <div class="imp-scroll">
        <table class="grid imp-table" data-testid="import-map">
          <caption class="sr">{{ t('web.import.mapTitle') }}</caption>
          <thead>
            <tr>
              <th v-for="(header, index) in headers" :key="index" scope="col">
                <span class="imp-h">{{ header }}</span>
                <select v-model="fields[index]" class="field select-mini" :aria-label="t('web.import.columnOf', { column: header })">
                  <option v-for="field in offered" :key="field" :value="field">{{ FIELD_LABEL[field]() }}</option>
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
      <p v-if="!prices" class="muted small">{{ t('web.catalogImport.pricesOff') }}</p>
      <p class="muted small">{{ t('web.import.showing', { shown: Math.min(5, body.length), total: body.length }) }}</p>
    </template>

    <div v-else class="imp-scroll">
      <table class="grid imp-table" data-testid="import-review">
        <caption class="sr">{{ title }}</caption>
        <thead>
          <tr>
            <th scope="col">{{ t('web.import.line') }}</th>
            <th scope="col">{{ t('name') }}</th>
            <th scope="col">{{ t('web.catalogImport.kind') }}</th>
            <th v-if="showPrice" scope="col" class="c-money">{{ t('catalogPriceLabel') }}</th>
            <th scope="col">{{ t('web.import.result') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in review" :key="row.line" class="no-click" :data-state="row.state">
            <td class="num">{{ row.line }}</td>
            <td>{{ row.name || '—' }}</td>
            <td>{{ kindName(row.kind) }}</td>
            <td v-if="showPrice" class="c-money"><span :class="typeof row.value === 'number' ? 'num' : 'muted'">{{ priceCell(row) }}</span></td>
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
