<template>
  <div class="card-stagger card-v2 rounded-2xl bg-white p-5 shadow-[0_2px_10px_rgba(27,94,123,0.03)] lg:p-6">
    <h3 class="mb-4 text-sm font-bold text-[#1A2B3C]">{{ t.tracking }}</h3>

    <!-- Stepper -->
    <div class="flex items-start justify-between">
      <template v-for="(step, i) in steps" :key="step.key">
        <!-- Step column -->
        <div class="flex w-[70px] flex-col items-center gap-1.5">
          <!-- Circle -->
          <div
            :class="[
              'step-circle flex items-center justify-center rounded-full',
              'h-7 w-7 lg:h-11 lg:w-11',
              step.done
                ? 'bg-[#1B5E7B] shadow-[0_2px_8px_rgba(27,94,123,0.3)]'
                : 'bg-[#F0F4F8] border-[1.5px] border-[#D0DAE4]',
            ]"
            :style="{ animationDelay: (0.15 + i * 0.1) + 's' }"
          >
            <svg v-if="step.done" class="h-3 w-3 lg:h-4 lg:w-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
            <span v-else class="text-[10px] lg:text-[11px] font-semibold text-[#8FA3B8]">{{ i + 1 }}</span>
          </div>
          <!-- Label -->
          <span
            :class="[
              'text-center leading-tight w-full',
              'text-[10px] lg:text-xs',
              step.done ? 'font-bold text-[#1B5E7B]' : 'font-medium text-[#8FA3B8]',
            ]"
          >
            {{ step.label }}
          </span>
        </div>

        <!-- Connector line (between steps, not after last) -->
        <div
          v-if="i < steps.length - 1"
          :class="[
            'mt-3.5 lg:mt-[22px] h-[2px] flex-1 rounded-full transition-colors duration-500',
            steps[i + 1].done ? 'bg-[#1B5E7B]' : 'bg-[#E2E8F0]',
          ]"
        />
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  status: string
}>()

const { t } = useOrderI18n()

const currentStep = computed(() => {
  const map: Record<string, number> = {
    quote: 1,
    approved: 2,
    progress: 3,
    done: 4,
    canceled: 1,
  }
  return map[props.status] || 1
})

const steps = computed(() => {
  const step = currentStep.value
  return [
    { key: 'received', label: t.value.received, done: step >= 1 },
    { key: 'approved', label: t.value.approved, done: step >= 2 },
    { key: 'progress', label: t.value.inProgress, done: step >= 3 },
    { key: 'done', label: t.value.completed, done: step >= 4 },
  ]
})
</script>
