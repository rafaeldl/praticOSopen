<script setup lang="ts">
// Avaliações (ratings.view, ratings.open): what the customers thought. The
// average first ("4,5 de 5"), then the latest ratings; a row opens its order.
import { computed, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import { ChevronRight, Star } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { formatNumber } from '@/lib/format'
import { session } from '@/lib/session'
import { averageScore, loadRatings, type RatedOrder } from '@/lib/settings/ratings'
import '@/styles/settings.css'

const router = useRouter()
const ratings = shallowRef<RatedOrder[] | null>(null)
const failed = ref(false)
const country = computed(() => session.company?.country)
const orderShort = computed(() => t('orderShort'))
const average = computed(() => formatNumber(averageScore(ratings.value ?? []), country.value))

async function load() {
  failed.value = false
  ratings.value = null
  try {
    ratings.value = await loadRatings()
  } catch (error) {
    console.error('ratings: load failed', error)
    failed.value = true
  }
}

const detail = (order: RatedOrder) =>
  order.comment
    ? t('ratingCommentOrder', { comment: order.comment, number: order.number ?? '' })
    : t('ratingNoCommentOrder', { number: order.number ?? '' })

function open(order: RatedOrder) {
  void router.push({ path: '/', query: { order: order.id } })
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('ratings') }}</h1>
      <p class="page-sub">{{ t('ratingsSubtitle') }}</p>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!ratings && !failed" />
      <ErrorState v-else-if="failed" :body="t('errorOccurred')" :retry="load" />
      <EmptyState v-else-if="ratings && !ratings.length" :title="t('noRatingsYet')" :body="t('ratingsEmptyHint', { order: orderShort })" data-testid="ratings-empty" />
      <template v-else-if="ratings">
        <div class="set-section" data-testid="ratings-summary">
          <p class="rating-average num">{{ t('ratingScoreOf', { score: average }) }}</p>
          <p class="sub">{{ t('ratingsAverageOf', { count: ratings.length }) }}</p>
        </div>
        <section aria-labelledby="ratings-latest" class="set-section">
          <h2 id="ratings-latest" class="set-h">{{ t('ratingsLatest') }}</h2>
          <ul class="set-list" data-testid="ratings-list">
            <li v-for="order in ratings" :key="order.id">
              <button type="button" class="set-row" :data-order="order.number ?? ''" @click="open(order)">
                <span class="set-text">
                  <span class="who">{{ order.customerName || t('customerWithoutName') }}</span>
                  <span class="rating-stars" role="img" :aria-label="t('ratingScoreOf', { score: order.score })">
                    <Star v-for="index in 5" :key="index" :size="16" aria-hidden="true" :class="{ on: index <= order.score }" />
                  </span>
                  <span class="sub">{{ detail(order) }}</span>
                </span>
                <ChevronRight :size="18" aria-hidden="true" />
              </button>
            </li>
          </ul>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.rating-average { font-family: var(--font-display); font-size: 2rem; font-weight: 700; margin: 0; }
.rating-stars { display: inline-flex; gap: 0.1rem; color: var(--color-muted); }
.rating-stars .on { color: var(--color-warning-text, var(--color-ink)); fill: currentColor; }
</style>
