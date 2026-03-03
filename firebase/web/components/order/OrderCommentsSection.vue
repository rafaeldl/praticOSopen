<template>
  <div v-if="canComment" class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Header -->
    <div class="mb-3.5 flex items-center gap-2">
      <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
      <h3 class="text-sm font-bold text-[#1A2B3C]">{{ t.leaveMessage }}</h3>
    </div>

    <!-- Textarea -->
    <textarea
      v-model="newComment"
      :placeholder="t.messagePlaceholder"
      rows="3"
      class="mb-3.5 h-20 w-full resize-none rounded-xl border border-[#E2E8F0] bg-[#F5F7FA] px-3.5 py-3 text-[13px] leading-relaxed text-[#1A2B3C] transition-all focus:border-[#1B5E7B] focus:bg-white focus:outline-none placeholder:text-[#A0AEC0]"
    />

    <!-- Send button row -->
    <div class="flex justify-end">
      <button
        class="inline-flex items-center gap-1.5 rounded-full bg-[#1B5E7B] px-5 py-2.5 text-[13px] font-semibold text-white transition-all hover:bg-[#0D3B4F] active:scale-[0.97] disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="!newComment.trim() || sending"
        @click="sendComment"
      >
        <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
        </svg>
        {{ t.send }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  canComment: boolean
  token: string
}>()

const { t } = useOrderI18n()
const { addComment } = useOrderApi()

const newComment = ref('')
const sending = ref(false)

async function sendComment() {
  const text = newComment.value.trim()
  if (!text || sending.value) return

  sending.value = true
  try {
    const result = await addComment(props.token, text) as any
    if (result?.success) {
      newComment.value = ''
    }
  } catch {
    // Toast will handle error
  } finally {
    sending.value = false
  }
}
</script>
