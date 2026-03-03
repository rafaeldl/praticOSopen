<template>
  <div v-if="forms?.length" class="space-y-4">
    <div
      v-for="form in forms"
      :key="form.id"
      class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6"
    >
      <!-- Header: icon + title + badge -->
      <div class="mb-3.5 flex items-center justify-between">
        <div class="flex items-center gap-2">
          <svg class="h-4 w-4 text-[#1B5E7B]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/>
            <rect x="9" y="3" width="6" height="4" rx="1"/>
            <path d="M9 14l2 2 4-4"/>
          </svg>
          <h3 class="text-sm font-bold text-[#1A2B3C]">{{ form.name || t.checklist }}</h3>
        </div>
        <span class="rounded-xl bg-[#E8F5E9] px-2.5 py-[3px] text-[11px] font-semibold text-[#2E7D32]">
          {{ completedCount(form) }}/{{ totalCount(form) }}
        </span>
      </div>

      <!-- Progress bar (5px like design) -->
      <div class="mb-4 h-[5px] overflow-hidden rounded-[3px] bg-[#EDF2F7]">
        <div
          class="progress-fill h-full rounded-[3px] bg-[#1B5E7B]"
          :style="{ '--progress-width': progressPercent(form) + '%', width: progressPercent(form) + '%' }"
        />
      </div>

      <!-- Items -->
      <div class="flex flex-col gap-2">
        <div
          v-for="item in form.items"
          :key="item.id"
          class="flex items-center justify-between gap-2 py-0.5"
        >
          <div class="flex items-center gap-2">
            <!-- Checkbox icons -->
            <svg v-if="itemStatus(item) === 'ok'" class="h-[18px] w-[18px] flex-shrink-0 text-[#1B5E7B]" viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm-9 14l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
            <svg v-else-if="itemStatus(item) === 'attention'" class="h-[18px] w-[18px] flex-shrink-0 text-[#E67E22]" viewBox="0 0 24 24" fill="currentColor">
              <path d="M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm-9 14l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
            </svg>
            <div v-else class="h-[18px] w-[18px] flex-shrink-0 rounded-[3px] border-[1.5px] border-[#D0DAE4] bg-[#F0F4F8]" />

            <span :class="['text-[13px]', itemStatus(item) !== 'pending' ? 'text-[#1A2B3C]' : 'text-[#8FA3B8]']">
              {{ item.label || item.name || '-' }}
            </span>
          </div>

          <span
            :class="[
              'flex-shrink-0 text-[11px] font-medium',
              itemStatus(item) === 'ok' ? 'text-[#2E7D32]' :
              itemStatus(item) === 'attention' ? 'text-[#E67E22]' :
              'text-[#A0AEC0]'
            ]"
          >
            {{ itemStatus(item) === 'ok' ? 'OK' : itemStatus(item) === 'attention' ? t.attention : t.pending }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  forms: any[]
}>()

const { t } = useOrderI18n()

function itemStatus(item: any): string {
  if (item.status) return item.status
  if (item.value === true || item.checked) return 'ok'
  if (item.value === 'attention') return 'attention'
  return 'pending'
}

function completedCount(form: any): number {
  if (!form.items?.length) return 0
  return form.items.filter((i: any) => itemStatus(i) !== 'pending').length
}

function totalCount(form: any): number {
  return form.items?.length || 0
}

function progressPercent(form: any): number {
  const total = totalCount(form)
  if (total === 0) return 0
  return Math.round((completedCount(form) / total) * 100)
}
</script>
