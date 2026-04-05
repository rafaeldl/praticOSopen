<template>
  <div v-if="bio" class="rounded-xl border border-[#E4E4E7] bg-white p-7">
    <h3 class="mb-3 text-lg font-semibold text-[#18181B]">{{ t.about }}</h3>
    <p
      :class="[
        'whitespace-pre-line text-[15px] leading-relaxed text-[#71717A]',
        !expanded && 'line-clamp-4',
      ]"
    >
      {{ bio }}
    </p>
    <button
      v-if="isLong"
      class="mt-2 text-sm font-semibold text-[#2563EB] hover:underline"
      @click="expanded = !expanded"
    >
      {{ expanded ? t.readLess : t.readMore }}
    </button>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  bio: string
}>()

const { t } = useProfileI18n()
const expanded = ref(false)
const isLong = computed(() => props.bio.length > 200 || props.bio.split('\n').length > 4)
</script>
