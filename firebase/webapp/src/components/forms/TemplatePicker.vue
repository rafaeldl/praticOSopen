<script setup lang="ts">
// "Qual checklist?" (checklist.pick.choose): the company's active checklists,
// by title, searched in title and description; "Novo checklist" for who
// manages them, coming back with it chosen (checklist.pick.create). A failed
// read is an error with "Tentar de novo", never an empty list (the app turns
// it into one). Ready-made ones of the segment go through "Checklists" first,
// where they count in the plan; the app puts them straight in the order.
import { computed, ref } from 'vue'
import { Plus } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { locale, t } from '@/i18n'
import { byTitle, descriptionOf, templateMatches, titleOf, type Template } from '@/lib/forms/model'

const props = defineProps<{ templates: Template[] | null; failed: boolean; canCreate: boolean; sub?: string }>()
const emit = defineEmits<{ pick: [template: Template]; create: []; retry: []; close: [] }>()

const query = ref('')
const active = computed(() => (props.templates ?? []).filter((template) => template.isActive).sort(byTitle))
const shown = computed(() => active.value.filter((template) => templateMatches(template, query.value, locale.value)))
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
            <button v-for="template in shown" :key="template.id" type="button" class="opt" :data-autofocus="template === shown[0] && active.length <= 10 ? '' : undefined" @click="emit('pick', template)">
              <span class="opt-main">
                <span>{{ titleOf(template, locale) }}</span>
                <small class="sub">{{ [descriptionOf(template, locale), t('checklistQuestions', { count: template.items.length })].filter(Boolean).join(' · ') }}</small>
              </span>
            </button>
          </div>
        </template>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>
