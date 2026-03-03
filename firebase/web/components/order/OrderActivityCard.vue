<template>
  <div v-if="comments?.length" class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <!-- Header -->
    <div class="mb-3.5 flex items-center gap-2">
      <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
      </svg>
      <h3 class="text-sm font-bold text-[#1A2B3C]">{{ t.activity }}</h3>
    </div>

    <!-- Timeline -->
    <div class="flex flex-col">
      <div
        v-for="(item, index) in comments"
        :key="index"
        class="relative flex gap-3 pb-4 last:pb-0"
      >
        <!-- Dot + vertical line -->
        <div class="flex flex-col items-center pt-1">
          <div
            :class="[
              'h-2 w-2 flex-shrink-0 rounded-full',
              index === 0 ? 'bg-[#1B5E7B]' : 'bg-[#5A7184]/25',
            ]"
          />
          <div
            v-if="index < comments.length - 1"
            class="mt-1.5 w-px flex-1 bg-[#EDF2F7]"
          />
        </div>

        <!-- Content -->
        <div class="flex-1 min-w-0">
          <p class="text-[13px] leading-relaxed text-[#1A2B3C]">{{ item.text }}</p>
          <div class="mt-1 flex items-center gap-1.5 text-[11px] text-[#8FA3B8]">
            <span v-if="item.authorName">{{ item.authorName }}</span>
            <span v-if="item.authorName && item.createdAt">&middot;</span>
            <span v-if="item.createdAt">{{ formatActivityDate(item.createdAt) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  comments: any[]
}>()

const { t, lang } = useOrderI18n()

function formatActivityDate(dateStr: string): string {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  const locale = lang.value === 'en' ? 'en-US' : lang.value === 'es' ? 'es-ES' : 'pt-BR'
  return date.toLocaleDateString(locale, {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}
</script>
