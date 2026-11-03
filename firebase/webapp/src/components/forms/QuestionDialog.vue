<script setup lang="ts">
// One question of the checklist (checklist.form.question-edit): the text, the
// kind of answer (the default is the first of the list, "Sim ou não", unlike
// the app), the options one per line for a choice, required and "Pode pôr
// foto". "Só foto" is never required. "Pronto" checks it first
// (checklist.question.validation); "Apagar pergunta" leaves on the next save.
import { computed, reactive, ref } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { editedItem, ITEM_TYPES, questionProblem, type FormItem, type ItemType } from '@/lib/forms/model'
import { session } from '@/lib/session'

const props = defineProps<{ item: FormItem | null }>()
const emit = defineEmits<{ save: [item: FormItem]; remove: [item: FormItem]; close: [] }>()

const newId = () => `q${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`
const form = reactive({
  label: props.item?.label ?? '',
  type: (props.item?.type ?? ITEM_TYPES[0]) as ItemType,
  optionsText: (props.item?.options ?? []).join('\n'),
  required: props.item?.required ?? false,
  allowPhotos: props.item?.allowPhotos ?? true,
})
const tried = ref(false)
const problem = computed(() => questionProblem(form.label, form.type, form.optionsText))
const hasOptions = computed(() => form.type === 'select' || form.type === 'checklist')
const segment = computed(() => session.company?.segment ?? 'other')
const TYPE_TEXT: Record<ItemType, () => string> = {
  boolean: () => t('formItemTypeBoolean'),
  select: () => t('formItemTypeSelect'),
  checklist: () => t('formItemTypeChecklist'),
  text: () => t('formItemTypeText'),
  number: () => t('formItemTypeNumber'),
  photo_only: () => t('formItemTypePhoto'),
}

function done() {
  tried.value = true
  if (problem.value) {
    document.getElementById(problem.value === 'label' ? 'qd-label' : 'qd-options')?.focus()
    return
  }
  emit('save', editedItem(props.item, { id: props.item?.id ?? newId(), ...form }))
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    event.stopPropagation()
    done()
  }
}
</script>

<template>
  <Layer kind="dialog" :label="item ? t('checklistQuestion') : t('checklistQuestionNew')" @close="emit('close')">
    <template #default="{ close }">
      <form novalidate data-testid="question-dialog" @submit.prevent="done" @keydown="onKeydown">
        <div class="layer-head">
          <h2 class="layer-title">{{ item ? t('checklistQuestion') : t('checklistQuestionNew') }}</h2>
        </div>
        <div class="layer-body q-form">
          <div>
            <label class="field-label" for="qd-label">{{ t('checklistQuestion') }}</label>
            <textarea id="qd-label" v-model="form.label" class="field" rows="2" :placeholder="t('checklistQuestionPlaceholder', { segment })" :aria-invalid="tried && problem === 'label'" aria-describedby="qd-label-error" data-autofocus></textarea>
            <p v-if="tried && problem === 'label'" id="qd-label-error" class="field-error">{{ t('checklistQuestionNeedsLabel') }}</p>
          </div>
          <div>
            <label class="field-label" for="qd-type">{{ t('checklistAnswerType') }}</label>
            <select id="qd-type" v-model="form.type" class="field">
              <option v-for="type in ITEM_TYPES" :key="type" :value="type">{{ TYPE_TEXT[type]() }}</option>
            </select>
          </div>
          <div v-if="hasOptions">
            <label class="field-label" for="qd-options">{{ t('checklistOptions') }}</label>
            <textarea id="qd-options" v-model="form.optionsText" class="field" rows="4" :placeholder="t('checklistOptionsPlaceholder')" :aria-invalid="tried && problem === 'options'" aria-describedby="qd-options-error"></textarea>
            <p v-if="tried && problem === 'options'" id="qd-options-error" class="field-error">{{ t('checklistQuestionNeedsOptions') }}</p>
          </div>
          <template v-if="form.type !== 'photo_only'">
            <label class="check-row">
              <input v-model="form.required" class="check" type="checkbox" aria-describedby="qd-required-hint" />
              <span>{{ t('checklistQuestionRequired') }} <span id="qd-required-hint" class="sub">{{ t('checklistQuestionRequiredHint') }}</span></span>
            </label>
            <label class="check-row">
              <input v-model="form.allowPhotos" class="check" type="checkbox" />
              <span>{{ t('checklistQuestionAllowPhotos') }}</span>
            </label>
          </template>
        </div>
        <div class="layer-foot">
          <button v-if="item" type="button" class="btn btn--ghost link--danger q-delete" @click="emit('remove', item)">{{ t('checklistQuestionDelete') }}</button>
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" data-testid="question-done">{{ t('checklistQuestionDone') }}</button>
        </div>
      </form>
    </template>
  </Layer>
</template>
