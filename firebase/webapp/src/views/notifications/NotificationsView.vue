<script setup lang="ts">
// Avisos (notifications.*): what happened in the orders since the person last
// looked. New ones first, then the ones already read; a row opens the order.
import { computed, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { listNotices, markAllRead, markRead, noticeText, relativeTime, type Notice } from '@/lib/notifications'
import { country, orderShort } from '@/lib/orders/text'
import { showToast } from '@/lib/toast'

const router = useRouter()
const notices = shallowRef<Notice[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const busy = ref(false)
const now = new Date()
const fresh = computed(() => notices.value.filter((notice) => !notice.read))
const before = computed(() => notices.value.filter((notice) => notice.read))

async function load() {
  state.value = 'loading'
  try {
    notices.value = await listNotices()
    state.value = 'ready'
  } catch (error) {
    console.warn('notifications: list failed', error)
    state.value = 'failed'
  }
}

const subtitle = (notice: Notice) =>
  [notice.orderNumber !== null && String(notice.orderNumber) ? `${orderShort()} ${notice.orderNumber}` : '', relativeTime(notice.createdAt, now, country())]
    .filter(Boolean)
    .join(' · ')

/** Opening marks it read and goes to the order; a maintenance has none and goes to Início, where the list is. */
async function open(notice: Notice) {
  if (!notice.read) await markRead(notice.id).catch((error) => console.warn('notifications: not marked', error))
  await router.push(notice.orderId ? { path: '/', query: { order: notice.orderId } } : { path: '/' })
}

async function readAll() {
  busy.value = true
  try {
    await markAllRead()
    notices.value = notices.value.map((notice) => ({ ...notice, read: true }))
  } catch (error) {
    console.warn('notifications: mark all failed', error)
    showToast(t('web.error.generic'))
  } finally {
    busy.value = false
  }
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('noticesTitle') }}</h1>
      <p v-if="state === 'ready' && fresh.length" class="page-sub">{{ t('noticesNewCount', { count: fresh.length }) }}</p>
    </div>
    <button v-if="state === 'ready' && fresh.length" type="button" class="btn" :disabled="busy" @click="readAll">{{ t('noticesMarkAllRead') }}</button>
  </header>
  <LoadingState v-if="state === 'loading'" />
  <ErrorState v-else-if="state === 'failed'" :retry="load" />
  <EmptyState v-else-if="!notices.length" :title="t('noticesEmpty')" :body="t('noticesEmptyHint', { order: orderShort() })" />
  <div v-else class="notices">
    <section v-for="group in [{ key: 'new', title: t('noticesSectionNew'), items: fresh }, { key: 'before', title: t('noticesSectionBefore'), items: before }].filter((g) => g.items.length)" :key="group.key" :aria-labelledby="`notices-${group.key}`">
      <h2 :id="`notices-${group.key}`" class="notices-title">{{ group.title }}</h2>
      <ul class="notices-list">
        <li v-for="notice in group.items" :key="notice.id">
          <button type="button" class="notice" :class="{ 'is-new': !notice.read }" @click="open(notice)">
            <span class="notice-dot" aria-hidden="true"></span>
            <span class="notice-main">
              <span class="notice-text">{{ noticeText(notice) }}</span>
              <span v-if="subtitle(notice)" class="sub">{{ subtitle(notice) }}</span>
            </span>
          </button>
        </li>
      </ul>
    </section>
  </div>
</template>

<style scoped>
.notices { display: grid; gap: 1rem; max-width: 48rem; }
.notices-title { font-size: 0.8125rem; font-weight: 600; color: var(--color-muted); text-transform: uppercase; letter-spacing: 0.04em; margin: 0 0 0.25rem; }
.notices-list { list-style: none; margin: 0; padding: 0; border-top: 1px solid var(--color-rule); }
.notice { display: flex; align-items: flex-start; gap: 0.75rem; width: 100%; min-height: 2.75rem; padding: 0.6rem 0.25rem; border: 0; border-bottom: 1px solid var(--color-rule); background: transparent; color: var(--color-ink); text-align: left; cursor: pointer; }
.notice:hover { background: var(--color-paper-2); }
.notice-dot { flex: none; width: 0.625rem; height: 0.625rem; margin-top: 0.45rem; border-radius: 50%; }
.notice.is-new .notice-dot { background: var(--color-accent); }
.notice.is-new .notice-text { font-weight: 700; }
.notice-main { display: grid; gap: 0.15rem; min-width: 0; }
.notice-text { overflow-wrap: anywhere; }
</style>
