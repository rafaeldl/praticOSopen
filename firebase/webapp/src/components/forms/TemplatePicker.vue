<script setup lang="ts">
// "Qual checklist?" (checklist.pick.choose): the company's active checklists
// and the segment's ready-made ones, as in the app (labels "Da empresa" and
// "Globais" only with both), by title, searched in title and description. A
// ready one goes straight into the order, for anyone who adds checklists.
// "Novo checklist" for who manages them, coming back with it chosen
// (checklist.pick.create). A failed read of the company's is an error with
// "Tentar de novo", never an empty list (the app turns it into one).
import { computed, ref } from 'vue'
import { Plus } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { locale, t } from '@/i18n'
import { descriptionOf, pickerGroups, templateMatches, titleOf, type Template } from '@/lib/forms/model'

const props = defineProps<{ templates: Template[] | null; ready?: Template[] | null; failed: boolean; canCreate: boolean; sub?: string }>()
const emit = defineEmits<{ pick: [template: Template]; create: []; retry: []; close: [] }>()

const query = ref('')
const groups = computed(() => pickerGroups(props.templates ?? [], props.ready ?? null))
const active = computed(() => [...groups.value.company, ...groups.value.ready])
const match = (list: Template[]) => list.filter((template) => template.isActive && templateMatches(template, query.value, locale.value))
const sections = computed(() => {
  const both = groups.value.company.length > 0 && groups.value.ready.length > 0
  return [
    { id: 'company', title: both ? t('fromCompany') : '', items: match(groups.value.company) },
    { id: 'ready', title: both ? t('global') : '', items: match(groups.value.ready) },
  ].filter((section) => section.items.length)
})
const shown = computed(() => sections.value.flatMap((section) => section.items))
</script>

<template>
  <Layer kind="sheet" :label="t('pickerChecklistTitle')" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('pickerChecklistTitle') }}</h2>
        <p v-if="sub" class="sub">{{ sub }}</p>
      </div>
      <div class="layer-body" data-testid="checklist-picker">
        <LoadingState v-if="templates === null && !failed" />
        <ErrorState v-else-if="failed" :body="t('errorLoadingProcedures')" :retry="() => emit('retry')" />
        <template v-else>
          <div v-if="active.length > 10">
            <label class="sr" for="tp-search">{{ t('searchProcedure') }}</label>
            <input id="tp-search" v-model="query" class="field" type="search" autocomplete="off" :placeholder="t('searchProcedure')" data-autofocus />
          </div>
          <EmptyState v-if="!active.length" :title="t('noProceduresAvailable')" :body="canCreate ? undefined : t('web.forms.askManager')" />
          <p v-else-if="!shown.length" class="muted">{{ t('web.forms.noMatch', { query }) }}</p>
          <div class="opts" role="group" :aria-label="t('pickerChecklistTitle')">
            <button v-if="canCreate" type="button" class="opt" data-testid="picker-new" @click="emit('create')">
              <Plus :size="16" aria-hidden="true" /><span class="opt-main">{{ t('pickerNewChecklist') }}</span>
            </button>
            <template v-for="section in sections" :key="section.id">
              <h3 v-if="section.title" class="picker-h">{{ section.title }}</h3>
              <button v-for="template in section.items" :key="`${section.id}-${template.id}`" type="button" class="opt" :data-autofocus="template === shown[0] && active.length <= 10 ? '' : undefined" @click="emit('pick', template)">
                <span class="opt-main">
                  <span>{{ titleOf(template, locale) }}</span>
                  <small class="sub">{{ [descriptionOf(template, locale), t('checklistQuestions', { count: template.items.length })].filter(Boolean).join(' · ') }}</small>
                </span>
              </button>
            </template>
          </div>
        </template>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>
