<script setup lang="ts">
// Team comments: the last two, "Ver todos (N)", and a box to write. Who writes
// chooses whether the customer sees it on the order link; it starts on "só a
// equipe" (order.comments.visibility). Deleted comments stay out.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { t } from '@/i18n'
import { firestoreClient } from '@/lib/firebase'
import { formatDayMonth } from '@/lib/format'
import { isoOf } from '@/lib/orders/model'
import { country } from '@/lib/orders/text'
import { addComment } from '@/lib/orders/writes'
import { session } from '@/lib/session'
import { showToast } from '@/lib/toast'

interface Comment {
  id: string
  text: string
  author: string
  mine: boolean
  customer: boolean
  internal: boolean
  at: string
  deleted?: boolean
}

const props = defineProps<{ orderId: string }>()
const comments = shallowRef<Comment[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const all = ref(false)
const text = ref('')
const internal = ref(true)
const sending = ref(false)
let stop: (() => void) | undefined

const shown = computed(() => (all.value ? comments.value : comments.value.slice(-2)))

onMounted(async () => {
  const [db, { collection, onSnapshot }] = await Promise.all([firestoreClient(), import('firebase/firestore')])
  stop = onSnapshot(
    collection(db, 'companies', session.companyId as string, 'orders', props.orderId, 'comments'),
    (snapshot) => {
      comments.value = snapshot.docs
        .map((doc) => {
          const data = doc.data() as Record<string, unknown>
          const author = (data.author ?? {}) as { name?: string; email?: string; userId?: string }
          return {
            id: doc.id,
            text: String(data.text ?? ''),
            author: author.userId === session.uid ? t('orderCommentYou') : data.authorType === 'customer' ? t('commentFromCustomer') : author.name || author.email || t('commentFromTeam'),
            mine: author.userId === session.uid,
            customer: data.authorType === 'customer',
            internal: data.isInternal !== false,
            at: isoOf(data.createdAt) ?? '',
            deleted: data.deleted === true,
          }
        })
        .filter((comment) => !comment.deleted && comment.text)
        .sort((a, b) => a.at.localeCompare(b.at))
      state.value = 'ready'
    },
    () => (state.value = 'failed'),
  )
})
onBeforeUnmount(() => stop?.())

async function send() {
  const value = text.value.trim()
  if (!value || sending.value) return
  sending.value = true
  try {
    await addComment(props.orderId, value, internal.value)
    text.value = ''
  } catch (error) {
    console.warn('comments: not sent', error)
    showToast(t('commentSendError'))
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <section class="od-sec od-sec--comments" aria-labelledby="od-comments-title">
    <h3 id="od-comments-title">
      {{ t('comments') }}
      <button v-if="comments.length > 2 && !all" type="button" class="link" @click="all = true">{{ t('seeAllCount', { count: comments.length }) }}</button>
    </h3>
    <p v-if="state === 'failed'" class="muted" role="alert">{{ t('web.error.generic') }}</p>
    <p v-else-if="state === 'ready' && !comments.length" class="muted">{{ t('commentsEmpty') }}</p>
    <ul v-else class="comments" data-testid="comments">
      <li v-for="comment in shown" :key="comment.id" class="comment">
        <b>{{ comment.author }}</b>
        <span class="muted small"> · {{ formatDayMonth(comment.at, country()) }}<template v-if="comment.internal && !comment.customer"> · {{ t('commentTeamOnlyTag') }}</template></span>
        <br />{{ comment.text }}
      </li>
    </ul>
    <form class="comment-form" @submit.prevent="send">
      <label class="sr" for="od-comment">{{ t('web.order.writeComment') }}</label>
      <textarea id="od-comment" v-model="text" class="field" rows="2" maxlength="2000" :placeholder="t('commentPlaceholder')" @keydown.enter.exact.prevent="send"></textarea>
      <div class="comment-row">
        <label class="sr" for="od-comment-visibility">{{ t('web.order.commentVisibility') }}</label>
        <select id="od-comment-visibility" v-model="internal" class="field select-mini">
          <option :value="true">{{ t('commentsTeamOnly') }}</option>
          <option :value="false">{{ t('commentsCustomerSees') }}</option>
        </select>
        <button type="submit" class="btn" :disabled="!text.trim() || sending">{{ t('web.order.send') }}</button>
      </div>
    </form>
  </section>
</template>
