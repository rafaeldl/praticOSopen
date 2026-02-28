<template>
  <main class="min-h-screen" :class="{ 'pb-24': hasCtaFooter }">
    <!-- Loading -->
    <div v-if="pending" class="flex min-h-[60vh] flex-col items-center justify-center gap-6">
      <div class="h-12 w-12 animate-spin rounded-full border-[3px] border-[var(--border-color)] border-t-brand-primary" />
      <p class="text-[var(--text-secondary)]">{{ t.loading }}</p>
    </div>

    <!-- Error / Not found -->
    <div v-else-if="error || !profileData" class="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center">
      <div class="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-status-canceled-bg">
        <svg class="h-10 w-10 text-status-canceled" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
      </div>
      <h2 class="mb-3 text-2xl font-semibold">{{ t.notFoundTitle }}</h2>
      <p class="mb-8 max-w-[400px] text-[var(--text-secondary)]">{{ t.notFoundDesc }}</p>
      <a
        href="https://praticos.web.app"
        class="inline-flex items-center gap-2 rounded-full bg-brand-primary px-6 py-3 font-semibold text-white transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        {{ t.backHome }}
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/>
        </svg>
      </a>
    </div>

    <!-- Profile content -->
    <template v-else>
      <ProfileHeader :company="company" :segment-label="segmentLabel" />

      <div class="mx-auto max-w-[600px] px-5">
        <ProfileStatsBar :stats="stats" />
        <ProfileAbout v-if="company.bio" :bio="company.bio" />
        <ProfileServicesList
          :services="services"
          :show-prices="company.showPrices"
          :country="company.country"
        />
        <ProfilePortfolioGrid
          :photos="portfolio"
          @open-lightbox="openLightbox"
        />
        <ProfileReviewsSection :reviews="reviews" />

        <!-- Footer -->
        <div class="py-8 text-center text-sm text-[var(--text-tertiary)]">
          {{ t.poweredBy }} <a href="https://praticos.web.app" target="_blank" class="text-brand-primary hover:underline">PraticOS</a>
        </div>
      </div>
    </template>

    <!-- Language switcher (above CTA footer) -->
    <ProfileLangSwitcher v-if="profileData" />

    <!-- CTA footer -->
    <ProfileCTAFooter v-if="profileData" :company="company" />

    <!-- Photo lightbox (reusing existing component) -->
    <OrderPhotoLightbox
      v-if="portfolio?.length"
      :photos="portfolio"
      :initial-index="lightboxIndex"
      :is-open="lightboxOpen"
      @close="lightboxOpen = false"
    />
  </main>
</template>

<script setup lang="ts">
const route = useRoute()
const slug = route.params.slug as string

const { t, getSegmentLabel } = useProfileI18n()

// SSR data fetch
const { data: profileData, error, pending } = await useFetch(`/api/profile/${slug}`)

// Computed data from response
const profile = computed(() => (profileData.value as any)?.data)
const company = computed(() => profile.value?.company || {})
const services = computed(() => profile.value?.services || [])
const reviews = computed(() => profile.value?.reviews || [])
const portfolio = computed(() => profile.value?.portfolio || [])
const stats = computed(() => profile.value?.stats || { completedOrders: 0, avgRating: 0, reviewCount: 0 })

const segmentLabel = computed(() => getSegmentLabel(company.value?.segment))

const hasCtaFooter = computed(() => company.value?.whatsapp || company.value?.phone)

// SEO meta — indexable (public profile)
useSeoMeta({
  title: company.value?.name
    ? t.value.seoTitle.replace('{name}', company.value.name)
    : `${slug} | PraticOS`,
  description: company.value?.name
    ? t.value.seoDescription
        .replace('{name}', company.value.name)
        .replace('{segment}', segmentLabel.value || '')
        .replace('{city}', company.value.city || '')
    : '',
  ogTitle: company.value?.name
    ? t.value.seoTitle.replace('{name}', company.value.name)
    : `${slug} | PraticOS`,
  ogDescription: company.value?.name
    ? t.value.seoDescription
        .replace('{name}', company.value.name)
        .replace('{segment}', segmentLabel.value || '')
        .replace('{city}', company.value.city || '')
    : '',
  ogImage: company.value?.logo || '',
  robots: 'index, follow',
})

// Schema.org LocalBusiness structured data
useHead({
  script: profile.value ? [{
    type: 'application/ld+json',
    innerHTML: JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'LocalBusiness',
      name: company.value?.name,
      image: company.value?.logo,
      telephone: company.value?.phone,
      address: company.value?.city ? {
        '@type': 'PostalAddress',
        addressLocality: company.value.city,
        addressRegion: company.value.state,
        addressCountry: company.value.country,
      } : undefined,
      aggregateRating: stats.value?.reviewCount > 0 ? {
        '@type': 'AggregateRating',
        ratingValue: stats.value.avgRating,
        reviewCount: stats.value.reviewCount,
        bestRating: 5,
        worstRating: 1,
      } : undefined,
      hasOfferCatalog: services.value?.length > 0 ? {
        '@type': 'OfferCatalog',
        name: t.value.servicesTitle,
        itemListElement: services.value.slice(0, 10).map((s: any) => ({
          '@type': 'Offer',
          itemOffered: {
            '@type': 'Service',
            name: s.name,
          },
        })),
      } : undefined,
    }),
  }] : [],
})

// Lightbox state
const lightboxOpen = ref(false)
const lightboxIndex = ref(0)

function openLightbox(index: number) {
  lightboxIndex.value = index
  lightboxOpen.value = true
}
</script>
