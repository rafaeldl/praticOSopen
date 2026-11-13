<script setup lang="ts">
// "Etapas do serviço" (company.stages.edit, docs/WORK_STAGES.md): the steps an
// order goes through while "Em andamento" (Pintura, Polimento), in order. Each
// one has a name and, optionally, words of a service that suggest it. Empty
// list turns stages off and the board goes back to one column per status.
// Ids of existing stages are kept, so orders stay where they are; an order in a
// removed stage shows in the first one.
// Plan (#724): adding a stage needs `workStages` (Pro); the stages a company
// already has stay, can be renamed, moved and removed.
import { computed, nextTick, ref } from 'vue'
import { ArrowDown, ArrowUp, Check, Plus, Trash2, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import PlanFeatureNotice from '@/components/PlanFeatureNotice.vue'
import { usePlanFeature } from '@/lib/plan-feature-gate'
import { t } from '@/i18n'
import { draftsOf, stagesFromDrafts, type StageDraft, type WorkStage } from '@/lib/orders/stages'
import { saveCompany } from '@/lib/settings/data'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/orders.css'

const props = defineProps<{ stages: WorkStage[] }>()
const emit = defineEmits<{ close: []; saved: [stages: WorkStage[], updatedAt: string] }>()

const drafts = ref<StageDraft[]>(draftsOf(props.stages))
const initial = JSON.stringify(drafts.value)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const saving = ref(false)
const failed = ref('')
const problemAt = ref<number | null>(null)
let allowClose = false
const dirty = computed(() => JSON.stringify(drafts.value) !== initial)
const workStages = usePlanFeature('workStages')

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function add() {
  if (!workStages.value.allowed) return
  drafts.value.push({ name: '', keywords: '' })
  await nextTick()
  document.getElementById(`st-name-${drafts.value.length - 1}`)?.focus()
}

function move(index: number, by: -1 | 1) {
  const to = index + by
  if (to < 0 || to >= drafts.value.length) return
  const list = [...drafts.value]
  ;[list[index], list[to]] = [list[to]!, list[index]!]
  drafts.value = list
  announce(t('web.stages.moved', { name: list[to]!.name || t('web.stages.newStage'), place: to + 1 }))
}

function remove(index: number) {
  const [gone] = drafts.value.splice(index, 1)
  announce(t('web.stages.removed', { name: gone?.name || t('web.stages.newStage') }))
}

async function save() {
  if (saving.value) return
  failed.value = ''
  problemAt.value = null
  const result = stagesFromDrafts(drafts.value)
  if ('problem' in result) {
    problemAt.value = result.problem.index
    failed.value = t(result.problem.kind === 'empty' ? 'web.stages.nameMissing' : 'web.stages.nameRepeated')
    document.getElementById(`st-name-${result.problem.index}`)?.focus()
    return
  }
  saving.value = true
  try {
    const updatedAt = await saveCompany({ workStages: result.stages })
    allowClose = true
    showToast(t(result.stages.length ? 'web.company.saved' : 'web.stages.turnedOff'))
    emit('saved', result.stages, updatedAt)
  } catch (error) {
    console.error('company: stages failed', error)
    failed.value = t('companySettingSaveError')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('web.stages.title')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="stages-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('web.stages.title') }}</h2>
      </div>
      <div class="drawer-body">
        <p class="sub">{{ t('web.stages.lead') }}</p>
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <p v-if="!drafts.length" class="sub" data-testid="stages-empty">{{ t('web.stages.empty') }}</p>
        <ol class="stage-edit-list">
          <li v-for="(draft, index) in drafts" :key="draft.id ?? `new-${index}`" class="stage-edit" :data-testid="`stage-edit-${index}`">
            <div class="stage-edit-head">
              <span class="stage-edit-n" aria-hidden="true">{{ index + 1 }}</span>
              <label class="sr" :for="`st-name-${index}`">{{ t('web.stages.nameLabel', { n: index + 1 }) }}</label>
              <input
                :id="`st-name-${index}`"
                v-model="draft.name"
                class="field"
                maxlength="40"
                :placeholder="t('web.stages.namePlaceholder')"
                :aria-invalid="problemAt === index ? 'true' : undefined"
                :data-testid="`stage-name-${index}`"
              />
              <button type="button" class="icon-btn" :disabled="index === 0" :aria-label="t('web.stages.up', { name: draft.name || t('web.stages.newStage') })" @click="move(index, -1)"><ArrowUp :size="16" aria-hidden="true" /></button>
              <button type="button" class="icon-btn" :disabled="index === drafts.length - 1" :aria-label="t('web.stages.down', { name: draft.name || t('web.stages.newStage') })" @click="move(index, 1)"><ArrowDown :size="16" aria-hidden="true" /></button>
              <button type="button" class="icon-btn" :aria-label="t('web.stages.remove', { name: draft.name || t('web.stages.newStage') })" :data-testid="`stage-remove-${index}`" @click="remove(index)"><Trash2 :size="16" aria-hidden="true" /></button>
            </div>
            <div class="stage-edit-words">
              <label class="field-label" :for="`st-words-${index}`">{{ t('web.stages.wordsLabel') }}</label>
              <input :id="`st-words-${index}`" v-model="draft.keywords" class="field" :placeholder="t('web.stages.wordsPlaceholder')" :data-testid="`stage-words-${index}`" />
            </div>
          </li>
        </ol>
        <p v-if="workStages.allowed">
          <button type="button" class="btn" data-testid="stage-add" @click="add"><Plus :size="16" aria-hidden="true" />{{ t('web.stages.add') }}</button>
        </p>
        <PlanFeatureNotice v-else feature="workStages" :required-plan="workStages.requiredPlan" heading-level="h2" />
        <p class="hint">{{ t('web.stages.removeHint') }}</p>
      </div>
      <div class="drawer-foot">
        <span class="hint"></span>
        <button type="submit" class="btn btn--primary" :disabled="saving || !dirty" data-testid="save-stages">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>

<style scoped>
.stage-edit-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.6rem; }
.stage-edit { display: grid; gap: 0.4rem; padding: 0.7rem; border: 1px solid var(--color-rule); border-radius: 6px; background: var(--color-card); }
.stage-edit-head { display: flex; align-items: center; gap: 0.35rem; }
.stage-edit-head .field { flex: 1; min-width: 0; }
.stage-edit-n { min-width: 1.6rem; text-align: center; font-variant-numeric: tabular-nums; color: var(--color-muted); }
.stage-edit-words { padding-left: 1.95rem; display: grid; gap: 0.25rem; }
</style>
