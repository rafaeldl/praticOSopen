<template>
  <div class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Header -->
    <div class="mb-3.5 flex items-center gap-2">
      <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
      <h3 class="text-sm font-bold text-[#1A2B3C]">{{ t.leaveMessage }}</h3>
    </div>

    <!-- Comments list -->
    <div v-if="allComments.length" class="mb-4 flex max-h-[360px] flex-col gap-2.5 overflow-y-auto">
      <div
        v-for="(comment, i) in allComments"
        :key="i"
        :class="[
          'max-w-[85%] rounded-2xl px-3.5 py-3',
          comment.authorType === 'customer'
            ? 'self-start rounded-bl-sm bg-[#F5F7FA]'
            : 'self-end rounded-br-sm bg-[#EBF4FA]',
        ]"
      >
        <div :class="['mb-1 flex items-center gap-1.5 text-[11px] font-semibold', comment.authorType === 'customer' ? 'text-[#5A7184]' : 'text-[#1B5E7B]']">
          <svg v-if="comment.authorType === 'customer'" class="h-3 w-3" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/></svg>
          <svg v-else class="h-3 w-3" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
          {{ comment.authorName || (comment.authorType === 'customer' ? customerName : t.team) }}
        </div>
        <div class="text-[13px] leading-relaxed text-[#1A2B3C]">{{ comment.text }}</div>
        <div class="mt-1.5 text-[10px] text-[#A0AEC0]">{{ formatDate(comment.createdAt, lang) }}</div>
      </div>
    </div>

    <!-- Comment input -->
    <div v-if="canComment" class="flex flex-col gap-3">
      <textarea
        v-model="newComment"
        :placeholder="t.addComment"
        rows="3"
        class="h-20 resize-none rounded-xl border border-[#E2E8F0] bg-[#F5F7FA] px-3.5 py-3 text-[13px] text-[#1A2B3C] transition-all focus:border-[#1B5E7B] focus:bg-white focus:outline-none focus:shadow-[0_0_0_3px_rgba(27,94,123,0.08)] placeholder:text-[#A0AEC0]"
      />
      <div class="flex justify-end">
        <button
          class="inline-flex items-center gap-1.5 rounded-full bg-[#1B5E7B] px-5 py-2.5 text-[13px] font-semibold text-white transition-all hover:bg-[#0D3B4F] hover:shadow-[0_4px_12px_rgba(27,94,123,0.25)] active:scale-[0.97] disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="!newComment.trim() || sending"
          @click="sendComment"
        >
          <svg class="h-3.5 w-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
          </svg>
          {{ t.send }}
        </button>
      </div>
    </div>

    <!-- No comments + no input -->
    <div v-if="!allComments.length && !canComment" class="py-6 text-center">
      <p class="text-[13px] text-[#A0AEC0]">{{ t.noComments }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatDate } from '~/utils/format'

const props = defineProps<{
  comments: any[]
  canComment: boolean
  customerName?: string
  token: string
}>()

const { t, lang } = useOrderI18n()
const { addComment } = useOrderApi()

const newComment = ref('')
const sending = ref(false)
const localComments = ref<any[]>([])

const allComments = computed(() => [...props.comments, ...localComments.value])

async function sendComment() {
  const text = newComment.value.trim()
  if (!text || sending.value) return

  sending.value = true
  try {
    const result = await addComment(props.token, text) as any
    if (result?.success) {
      localComments.value.push(result.data)
      newComment.value = ''
    }
  } catch {
    // Toast will handle error
  } finally {
    sending.value = false
  }
}
</script>
