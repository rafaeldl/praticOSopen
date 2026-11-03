<script setup lang="ts">
// Change the price of the selected items (desk extra). Raise or lower by a
// percentage, with every item before and after on screen; "Aplicar" asks once
// more, then the server changes all of them or none (each change carries the
// price the person saw). Items without a price stay as they are.
import { computed, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { moneyDigits } from '@/lib/format'
import { money as formatMoney } from '@/lib/orders/text'
import { percentOk, priceChanges, type CatalogItem, type PriceChange } from '@/lib/catalog/model'
import { session } from '@/lib/session'

const props = defineProps<{ items: CatalogItem[]; busy?: boolean; error?: string }>()
const emit = defineEmits<{ apply: [changes: PriceChange[]]; close: [] }>()

const direction = ref<'up' | 'down'>('up')
const percentText = ref('10')
const round = ref(false)
const confirming = ref(false)
const country = computed(() => session.company?.country)
const digits = computed(() => moneyDigits(country.value))
const percent = computed(() => Number(percentText.value.replace(',', '.').trim()))
const valid = computed(() => percentText.value.trim() !== '' && percentOk({ direction: direction.value, percent: percent.value }))
const result = computed(() => (valid.value ? priceChanges(props.items, { direction: direction.value, percent: percent.value, round: round.value }, digits.value) : { changes: [], withoutPrice: 0, same: 0 }))
const count = computed(() => result.value.changes.length)
const title = computed(() => t('web.catalog.pricesTitle', { count: props.items.length }))
const money = (value: number) => formatMoney(value)

function apply() {
  if (!valid.value || !count.value || props.busy) return
  confirming.value = true
}
</script>

<template>
  <Layer kind="drawer" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <form class="drawer" data-testid="price-dialog" @submit.prevent="apply">
        <div class="drawer-head">
          <h2 class="layer-title">{{ title }}</h2>
        </div>
        <div class="drawer-body">
          <p v-if="error" class="field-error" role="alert" data-testid="price-error">{{ error }}</p>
          <div class="tabs" role="group" :aria-label="t('web.catalog.direction')">
            <button type="button" :aria-pressed="direction === 'up'" data-testid="price-up" @click="direction = 'up'">{{ t('web.catalog.raise') }}</button>
            <button type="button" :aria-pressed="direction === 'down'" data-testid="price-down" @click="direction = 'down'">{{ t('web.catalog.lower') }}</button>
          </div>
          <div class="cat-pct">
            <label class="field-label" for="pd-percent">{{ t('web.catalog.percent') }}</label>
            <div class="money">
              <input id="pd-percent" v-model="percentText" class="field money-input" inputmode="decimal" autocomplete="off" :aria-invalid="!valid || undefined" aria-describedby="pd-percent-error" data-autofocus />
              <span class="money-symbol" aria-hidden="true">%</span>
            </div>
            <p v-if="!valid" id="pd-percent-error" class="field-error">{{ t('web.catalog.percentInvalid', { max: direction === 'down' ? 100 : 1000 }) }}</p>
          </div>
          <label class="check-row"><input v-model="round" class="check" type="checkbox" data-testid="price-round" />{{ t('web.catalog.roundWhole') }}</label>
          <div class="cat-preview">
            <table class="grid" data-testid="price-preview">
              <caption class="sr">{{ title }}</caption>
              <thead>
                <tr>
                  <th scope="col">{{ t('name') }}</th>
                  <th scope="col" class="c-money">{{ t('web.catalog.before') }}</th>
                  <th scope="col" class="c-money">{{ t('web.catalog.after') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="change in result.changes" :key="change.item.id" class="no-click">
                  <td>{{ change.item.name }}</td>
                  <td class="c-money"><span class="num">{{ money(change.from) }}</span></td>
                  <td class="c-money"><span class="num">{{ money(change.to) }}</span></td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-if="valid && !count" class="muted" role="status">{{ t('web.catalog.nothingChanges') }}</p>
          <p v-if="result.withoutPrice" class="sub">{{ t('web.catalog.withoutPriceStays', { count: result.withoutPrice }) }}</p>
          <p v-if="result.same" class="sub">{{ t('web.catalog.sameStays', { count: result.same }) }}</p>
        </div>
        <div class="drawer-foot">
          <button type="button" class="btn" @click="close()">{{ t('back') }}</button>
          <button type="submit" class="btn btn--primary" :aria-disabled="!valid || !count || busy" data-testid="price-apply">{{ t('web.catalog.apply', { count }) }}</button>
        </div>
      </form>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="confirming"
    :title="t('web.catalog.confirmTitle', { count })"
    :body="t('web.catalog.confirmBody')"
    :confirm="t('web.catalog.confirm')"
    :keep="t('back')"
    @confirm="confirming = false; emit('apply', result.changes)"
    @close="confirming = false"
  />
</template>
