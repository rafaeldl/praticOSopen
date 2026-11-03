<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watchEffect } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { locale, t } from '@/i18n'
import { loadSegmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { handleShortcut, registerShortcut } from '@/lib/shortcuts'
import { ui } from '@/lib/ui'
import AppShell from '@/views/AppShell.vue'
import LoadingState from '@/components/LoadingState.vue'
import ToastHost from '@/components/ToastHost.vue'

const route = useRoute()
const router = useRouter()
const bare = computed(() => route.meta.bare === true)
// Until the guard answers, the route is unknown: the shell must not flash for
// someone about to land on the login screen.
const ready = ref(false)
void router.isReady().then(() => (ready.value = true))

watchEffect(() => {
  const title = route.meta.title
  document.title = title ? `${t(title)} · PraticOS` : 'PraticOS'
})

watchEffect(() => {
  if (session.company) void loadSegmentLabels(session.company.segment, locale.value)
})

// A "no" from the access list can arrive after the start (remembered "yes" revoked).
watchEffect(() => {
  if (ready.value && session.uid && session.webAccess === 'denied' && route.name !== 'notAllowed') {
    void router.replace({ name: 'notAllowed' })
  }
})

// Moving between screens must not leave focus on a link that may be gone.
const stopFocus = router.afterEach((to, from) => {
  if (from.matched.length === 0 || to.path === from.path) return
  void nextTick(() => document.querySelector<HTMLElement>('[data-page-title]')?.focus({ preventScroll: true }))
})

const removers = [
  registerShortcut({ keys: 'mod+k', label: 'web.shortcuts.palette', global: true, run: () => (ui.palette = !ui.palette) }),
  registerShortcut({ keys: '?', label: 'web.shortcuts.help', run: () => (ui.shortcuts = true) }),
]

onMounted(() => window.addEventListener('keydown', handleShortcut))
onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleShortcut)
  removers.forEach((remove) => remove())
  stopFocus()
})
</script>

<template>
  <LoadingState v-if="!ready" />
  <RouterView v-else-if="bare" />
  <AppShell v-else />
  <ToastHost />
  <div class="sr" role="status" aria-live="polite">{{ ui.live }}</div>
</template>
