<template>
  <main class="flex min-h-screen flex-col items-center justify-center px-6 text-center">
    <div class="mb-8">
      <div class="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-2xl bg-[rgba(74,155,217,0.12)]">
        <svg class="h-10 w-10 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
      </div>
      <h1 class="mb-3 text-2xl font-bold font-heading">{{ t.profileComingSoonTitle }}</h1>
      <p class="max-w-md text-[var(--text-secondary)]">{{ t.profileComingSoonDesc }}</p>
    </div>

    <a
      href="https://praticos.web.app"
      class="inline-flex items-center gap-2 rounded-full bg-brand-primary px-6 py-3 font-semibold text-white transition-all hover:-translate-y-0.5 hover:shadow-lg"
    >
      PraticOS
      <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/>
      </svg>
    </a>

    <div class="mt-16 text-sm text-[var(--text-tertiary)]">
      {{ t.poweredBy }} <a href="https://praticos.web.app" target="_blank" class="text-brand-primary hover:underline">PraticOS</a>
    </div>
  </main>
</template>

<script setup lang="ts">
const route = useRoute()
const slug = route.params.slug as string

const { t } = useOrderI18n()

// SEO meta for the profile stub
useSeoMeta({
  title: `${slug} | PraticOS`,
  description: t.value.profileComingSoonDesc,
  ogTitle: `${slug} | PraticOS`,
  ogDescription: t.value.profileComingSoonDesc,
  robots: 'noindex, nofollow',
})
</script>
