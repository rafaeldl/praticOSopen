<template>
  <main class="magic-link min-h-screen bg-[#F5F7FA] safe-area-bottom">
    <!-- Loading -->
    <div v-if="pending" class="flex min-h-[60vh] flex-col items-center justify-center gap-6">
      <div class="h-10 w-10 animate-spin rounded-full border-[2.5px] border-[#E2E8F0] border-t-[#1B5E7B]" />
      <p class="text-[13px] text-[#5A7184]">{{ t.loading }}</p>
    </div>

    <!-- Error -->
    <div v-else-if="error || !orderData" class="flex min-h-[60vh] flex-col items-center justify-center px-6 text-center">
      <div class="mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-[#FEF2F2]">
        <svg class="h-8 w-8 text-[#EF4444]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
        </svg>
      </div>
      <h2 class="mb-2 text-xl font-bold text-[#1A2B3C]">{{ t.errorTitle }}</h2>
      <p class="max-w-[360px] text-[13px] leading-relaxed text-[#5A7184]">{{ t.errorMessage }}</p>
    </div>

    <!-- Order content -->
    <template v-else>
      <OrderHeader :order="order" :company="company" />

      <!-- Mobile layout (single column) -->
      <div class="lg:hidden px-4 py-5 space-y-4">
        <OrderQuoteApprovalCard
          v-if="order.status === 'quote' && permissions.includes('approve')"
          :order="order"
          :country="company?.country"
          @approve="showApproveModal = true"
          @reject="showRejectModal = true"
        />
        <OrderProgressCard v-else :status="order.status" />
        <OrderPhotosCard :photos="order.photos" @open-lightbox="openLightbox" />
        <OrderSummaryCard :order="order" :country="company?.country" />
        <OrderVehiclesCard :order="order" />
        <OrderChecklistCard :forms="order.forms" />
        <OrderActivityCard :comments="comments" />

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
          :customer-name="(orderData as any)?.customer?.name"
          :token="token"
        />

        <!-- Rating (after comments if already rated) -->
        <OrderRatingSection
          v-if="order.status === 'done' && order.rating?.score"
          :order="order"
          :token="token"
        />
      </div>

      <!-- Desktop layout (2 columns) -->
      <div class="hidden lg:flex mx-auto max-w-[1280px] px-16 py-8 gap-8">
        <!-- Main column -->
        <div class="flex-1 space-y-6">
          <OrderQuoteApprovalCard
            v-if="order.status === 'quote' && permissions.includes('approve')"
            :order="order"
            :country="company?.country"
            @approve="showApproveModal = true"
            @reject="showRejectModal = true"
          />
          <OrderProgressCard v-else :status="order.status" />
          <OrderPhotosCard :photos="order.photos" @open-lightbox="openLightbox" />
          <OrderSummaryCard :order="order" :country="company?.country" />
          <OrderChecklistCard :forms="order.forms" />
        </div>

        <!-- Sidebar -->
        <div class="w-[360px] shrink-0 space-y-6">
          <OrderVehiclesCard :order="order" />
          <OrderActivityCard :comments="comments" />

          <!-- Comments -->
          <OrderCommentsSection
            v-if="permissions.includes('comment') || permissions.includes('view')"
            :comments="comments"
            :can-comment="permissions.includes('comment')"
            :customer-name="(orderData as any)?.customer?.name"
            :token="token"
          />

          <!-- Rating -->
          <OrderRatingSection
            v-if="order.status === 'done'"
            :order="order"
            :token="token"
            @rated="refreshOrder"
          />
        </div>
      </div>

      <OrderFooter />
    </template>

    <!-- Language switcher -->
    <OrderLangSwitcher v-if="orderData" />

    <!-- Photo lightbox -->
    <OrderPhotoLightbox
      v-if="order?.photos?.length"
      :photos="order.photos"
      :initial-index="lightboxIndex"
      :is-open="lightboxOpen"
      @close="lightboxOpen = false"
    />

    <!-- Confirm modals -->
    <OrderConfirmModal
      :is-open="showApproveModal"
      type="approve"
      :title="t.approveTitle"
      :message="t.approveMessage"
      @confirm="handleApprove"
      @cancel="showApproveModal = false"
    />

    <OrderConfirmModal
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
    <OrderToastNotification
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
