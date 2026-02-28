<template>
  <main class="min-h-screen safe-area-bottom" :class="{ 'pt-0': true }">
    <!-- Loading -->
    <div v-if="pending" class="flex min-h-[60vh] flex-col items-center justify-center gap-6">
      <div class="h-12 w-12 animate-spin rounded-full border-[3px] border-[var(--border-color)] border-t-brand-primary" />
      <p class="text-[var(--text-secondary)]">{{ t.loading }}</p>
    </div>

    <!-- Error -->
    <div v-else-if="error || !orderData" class="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center">
      <div class="mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-status-canceled-bg">
        <svg class="h-10 w-10 text-status-canceled" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
        </svg>
      </div>
      <h2 class="mb-3 text-2xl font-semibold">{{ t.errorTitle }}</h2>
      <p class="max-w-[400px] text-[var(--text-secondary)]">{{ t.errorMessage }}</p>
    </div>

    <!-- Order content -->
    <template v-else>
      <OrderHeader :order="order" :company="company" />

      <div class="mx-auto max-w-[600px] px-5">
        <OrderInfoCard :order="order" :customer="orderData.customer" />
        <OrderDevicesCard :order="order" />
        <OrderPhotosCard :photos="order.photos" @open-lightbox="openLightbox" />
        <OrderServicesCard :order="order" :country="company?.country" />
        <OrderProductsCard :order="order" :country="company?.country" />
        <OrderTotalSection :order="order" :country="company?.country" />

        <!-- Action buttons for quotes -->
        <OrderActionButtons
          v-if="order.status === 'quote' && permissions.includes('approve')"
          @approve="showApproveModal = true"
          @reject="showRejectModal = true"
        />

        <!-- Rating (before comments if not yet rated) -->
        <OrderRatingSection
          v-if="order.status === 'done' && !order.rating?.score"
          :order="order"
          :token="token"
          @rated="refreshOrder"
        />

        <!-- Comments -->
        <OrderCommentsSection
          v-if="permissions.includes('comment') || permissions.includes('view')"
          :comments="comments"
          :can-comment="permissions.includes('comment')"
          :customer-name="orderData.customer?.name"
          :token="token"
        />

        <!-- Rating (after comments if already rated) -->
        <OrderRatingSection
          v-if="order.status === 'done' && order.rating?.score"
          :order="order"
          :token="token"
        />

        <OrderFooter />
      </div>
    </template>

    <!-- Language switcher -->
    <OrderLangSwitcher v-if="orderData" />

    <!-- Photo lightbox -->
    <PhotoLightbox
      v-if="order?.photos?.length"
      :photos="order.photos"
      :initial-index="lightboxIndex"
      :is-open="lightboxOpen"
      @close="lightboxOpen = false"
    />

    <!-- Confirm modals -->
    <ConfirmModal
      :is-open="showApproveModal"
      type="approve"
      :title="t.approveTitle"
      :message="t.approveMessage"
      @confirm="handleApprove"
      @cancel="showApproveModal = false"
    />

    <ConfirmModal
      :is-open="showRejectModal"
      type="reject"
      :title="t.rejectTitle"
      :message="t.rejectMessage"
      :show-input="true"
      :placeholder="t.rejectPlaceholder"
      @confirm="handleReject"
      @cancel="showRejectModal = false"
    />

    <!-- Toast -->
    <ToastNotification
      :message="toastMessage"
      :type="toastType"
      :visible="toastVisible"
    />
  </main>
</template>

<script setup lang="ts">
const route = useRoute()
const token = route.params.token as string

const { t } = useOrderI18n()
const { approveQuote, rejectQuote } = useOrderApi()

// SSR data fetch via server proxy
const { data: orderData, error, pending, refresh: refreshOrder } = await useFetch(`/api/orders/${token}`)

// Computed data from response
const order = computed(() => (orderData.value as any)?.data?.order)
const company = computed(() => (orderData.value as any)?.data?.company)
const comments = computed(() => (orderData.value as any)?.data?.comments || [])
const permissions = computed(() => (orderData.value as any)?.data?.permissions || [])

// SEO meta - noindex for share links
useHead({
  title: t.value.pageTitle,
  meta: [
    { name: 'robots', content: 'noindex, nofollow' },
    { name: 'description', content: t.value.pageDescription },
    { property: 'og:title', content: t.value.pageTitle },
    { property: 'og:description', content: t.value.pageDescription },
    { property: 'og:type', content: 'website' },
  ],
})

// Lightbox state
const lightboxOpen = ref(false)
const lightboxIndex = ref(0)

function openLightbox(index: number) {
  lightboxIndex.value = index
  lightboxOpen.value = true
}

// Modal state
const showApproveModal = ref(false)
const showRejectModal = ref(false)

// Toast state
const toastVisible = ref(false)
const toastMessage = ref('')
const toastType = ref<'success' | 'error'>('success')

function showToast(message: string, type: 'success' | 'error' = 'success') {
  toastMessage.value = message
  toastType.value = type
  toastVisible.value = true
  setTimeout(() => { toastVisible.value = false }, 3000)
}

async function handleApprove() {
  showApproveModal.value = false
  try {
    const result = await approveQuote(token) as any
    if (result?.success) {
      showToast(t.value.approved, 'success')
      setTimeout(() => refreshOrder(), 1500)
    }
  } catch (err: any) {
    showToast(err?.data?.error?.message || t.value.error, 'error')
  }
}

async function handleReject(reason: string) {
  showRejectModal.value = false
  try {
    const result = await rejectQuote(token, reason) as any
    if (result?.success) {
      showToast(t.value.rejected, 'success')
      setTimeout(() => refreshOrder(), 1500)
    }
  } catch (err: any) {
    showToast(err?.data?.error?.message || t.value.error, 'error')
  }
}
</script>
