<template>
  <div class="order-card animate-fade-in-up rounded-2xl border border-[var(--border-color)] bg-[var(--bg-card)] overflow-hidden mt-8">
    <div class="flex items-center gap-3 border-b border-[var(--border-color)] px-5 py-4">
      <svg class="h-5 w-5 text-brand-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
      <h3 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">{{ t.comments }}</h3>
    </div>
    <div class="p-5">
      <!-- Comments list -->
      <div v-if="allComments.length" class="mb-5 flex max-h-[400px] flex-col gap-3 overflow-y-auto pr-2">
        <div
          v-for="(comment, i) in allComments"
          :key="i"
          :class="[
            'max-w-[85%] rounded-2xl p-3.5 px-4.5 animate-[fadeIn_0.3s_ease]',
            comment.authorType === 'customer'
              ? 'self-start rounded-bl-sm bg-[var(--bg-tertiary)]'
              : 'self-end rounded-br-sm bg-[rgba(74,155,217,0.15)]',
          ]"
        >
          <div :class="['mb-1.5 flex items-center gap-1.5 text-xs font-semibold', comment.authorType === 'customer' ? 'text-[var(--text-secondary)]' : 'text-brand-primary']">
            <svg v-if="comment.authorType === 'customer'" class="h-3 w-3" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/></svg>
            <svg v-else class="h-3 w-3" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
            {{ comment.authorName || (comment.authorType === 'customer' ? customerName : t.team) }}
          </div>
          <div class="text-[0.9375rem] leading-relaxed text-[var(--text-primary)]">{{ comment.text }}</div>
          <div class="mt-2 text-[0.6875rem] text-[var(--text-tertiary)]">{{ formatDate(comment.createdAt, lang) }}</div>
        </div>
      </div>

      <!-- No comments -->
      <div v-else class="py-10 text-center text-[var(--text-tertiary)]">
        <svg class="mx-auto mb-3 h-12 w-12 opacity-50" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
        </svg>
        <p>{{ t.noComments }}</p>
      </div>

      <!-- Comment input -->
      <div v-if="canComment" class="flex gap-3 rounded-2xl border border-[var(--border-color)] bg-[var(--bg-tertiary)] p-4">
        <textarea
          v-model="newComment"
          :placeholder="t.addComment"
          rows="1"
          class="min-h-[48px] max-h-[120px] flex-1 resize-none rounded-xl border border-[var(--border-color)] bg-[var(--bg-card)] p-3 px-4 font-body text-[0.9375rem] text-[var(--text-primary)] transition-all focus:border-brand-primary focus:outline-none placeholder:text-[var(--text-tertiary)]"
          @input="autoResize"
        />
        <button
          class="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl bg-brand-primary text-white transition-all hover:bg-brand-primary-light hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="!newComment.trim() || sending"
          @click="sendComment"
        >
          <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="22" y1="2" x2="11" y2="13"/>
            <polygon points="22 2 15 22 11 13 2 9 22 2"/>
          </svg>
        </button>
      </div>
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

function autoResize(e: Event) {
  const el = e.target as HTMLTextAreaElement
  el.style.height = 'auto'
  el.style.height = Math.min(el.scrollHeight, 120) + 'px'
}

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
