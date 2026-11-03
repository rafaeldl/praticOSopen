<script setup lang="ts">
// New or edit service/product (catalog.form.*), in a drawer over the list.
// Name first (example by segment), then the price for who changes prices, and
// "Foto e mais dados" with the photo and the segment fields. Nothing is saved
// before "Salvar": the photo waits in the browser and goes up only after the
// item exists, so cancelling leaves nothing behind (app defect C9). Closing
// with changes asks, also when editing (C6). A stale version is refused by the
// server and the list is read again (C10). Errors always show (C7, C8).
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue'
import { Check, ImagePlus, MoreHorizontal, Package, Wrench, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import CustomFieldInput from '@/components/customers/CustomFieldInput.vue'
import ChoiceDialog, { type Choice } from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { locale, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { changedSince, deleteItem, saveItem, uploadItemPhoto } from '@/lib/catalog/data'
import type { CatalogItem, CatalogKind } from '@/lib/catalog/model'
import { groupBySection, namespaceFields, readCustom, validateField, writeCustom, type FieldError } from '@/lib/segment-fields'
import { can, session } from '@/lib/session'
import { isMac } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{
  kind: CatalogKind
  /** Editing this one; without it, a new item. */
  item?: CatalogItem | null
  /** Singular name of the kind on screen ("serviço", "peça"). */
  entity: string
  /** The segment gave its own name to products ("Peça"): texts use it. */
  labeled: boolean
}>()
const emit = defineEmits<{ saved: [id: string]; changed: []; removed: []; close: [] }>()

const MAX_PHOTO = 10 * 1024 * 1024
const FIELD_TYPES = ['text', 'textarea', 'number', 'select', 'date']
const editing = !!props.item
const canPrice = can('editPrices')
const canManage = can(props.kind === 'service' ? 'manageServices' : 'manageProducts')
const country = computed(() => session.company?.country)
const fieldList = computed(() => namespaceFields(props.kind, []).filter((field) => FIELD_TYPES.includes(field.type ?? '')))
const fieldName = (key: string) => key.split('.').pop() as string
const initial = {
  name: props.item?.name ?? '',
  value: (props.item?.value ?? null) as number | null,
  custom: Object.fromEntries(fieldList.value.map((field) => [fieldName(field.key), readCustom(props.item?.customData, field) ?? null])) as Record<string, unknown>,
}
const form = reactive({ ...initial, custom: { ...initial.custom } })
// Fields of a segment that arrived after the form opened come with what the item has.
watch(fieldList, (list) => {
  for (const field of list) {
    const name = fieldName(field.key)
    if (name in form.custom) continue
    const value = readCustom(props.item?.customData, field) ?? null
    initial.custom[name] = value
    form.custom[name] = value
  }
})
const photo = ref<{ file: File; url: string } | null>(null)
const removePhoto = ref(false)
const photoError = ref('')
const more = ref(!!props.item?.photo || Object.values(initial.custom).some((value) => value !== null && value !== ''))
const saving = ref(false)
const failed = ref('')
const tried = ref(false)
const dialog = ref<null | 'menu' | 'delete'>(null)
const menuButton = ref<HTMLElement | null>(null)
const layer = ref<InstanceType<typeof Layer> | null>(null)
let allowClose = false

const isService = props.kind === 'service'
const title = computed(() => {
  if (editing) return props.item?.name || props.entity
  if (props.labeled) return t('web.catalog.newLabeled', { entity: props.entity })
  return isService ? t('catalogNewService') : t('catalogNewProduct')
})
const saveText = computed(() => (props.labeled ? t('web.catalog.saveLabeled', { entity: props.entity }) : isService ? t('saveServiceButton') : t('saveProductButton')))
const deleteText = computed(() => (props.labeled ? t('web.catalog.deleteLabeled', { entity: props.entity }) : isService ? t('deleteServiceAction') : t('deleteProductAction')))
const segment = computed(() => (session.company as { segment?: string } | null)?.segment ?? 'other')
const placeholder = computed(() => (isService ? t('serviceNameHint', { segment: segment.value }) : t('productNameHint', { segment: segment.value })))
const canSave = computed(() => !!form.name.trim() && !saving.value)
const dirty = computed(() => JSON.stringify(form) !== JSON.stringify(initial) || !!photo.value || removePhoto.value)
const fieldErrors = computed(() => Object.fromEntries(fieldList.value.map((field) => [field.key, validateField(field, form.custom[fieldName(field.key)])])) as Record<string, FieldError>)
const sections = computed(() => groupBySection(fieldList.value, locale.value, t('web.catalog.general')))
const shownPhoto = computed(() => photo.value?.url ?? (removePhoto.value ? null : (props.item?.photo ?? null)))
const menuChoices = computed<Choice[]>(() => (editing && canManage ? [{ id: 'delete', label: deleteText.value, danger: true }] : []))
const saveKey = isMac ? '⌘ Enter' : 'Ctrl Enter'

function errorText(error: FieldError, min?: number, max?: number, minLength?: number): string {
  if (error === 'required') return t('required')
  if (error === 'pattern' || error === 'number') return t('invalidFormat')
  if (error === 'min') return `${t('minimum')}: ${min}`
  if (error === 'max') return `${t('maximum')}: ${max}`
  if (error === 'minLength') return `${t('minimum')} ${minLength} ${t('characters')}`
  return ''
}

function choosePhoto(file: File | null | undefined) {
  if (!file) return
  if (!file.type.startsWith('image/')) {
    photoError.value = t('web.catalog.photoNotImage')
    return
  }
  if (file.size >= MAX_PHOTO) {
    photoError.value = t('web.catalog.photoTooBig')
    return
  }
  photoError.value = ''
  if (photo.value) URL.revokeObjectURL(photo.value.url)
  photo.value = { file, url: URL.createObjectURL(file) }
  removePhoto.value = false
}

function onPaste(event: ClipboardEvent) {
  const file = [...(event.clipboardData?.files ?? [])].find((item) => item.type.startsWith('image/'))
  if (file) {
    event.preventDefault()
    choosePhoto(file)
  }
}

function dropPhoto() {
  if (photo.value) URL.revokeObjectURL(photo.value.url)
  photo.value = null
  removePhoto.value = !!props.item?.photo
}

async function save() {
  tried.value = true
  if (!form.name.trim()) {
    failed.value = t('web.catalog.needsName')
    document.getElementById('kf-name')?.focus()
    return
  }
  if (Object.values(fieldErrors.value).some(Boolean)) {
    more.value = true
    failed.value = t('web.customers.fixFields')
    return
  }
  if (saving.value) return
  saving.value = true
  failed.value = ''
  try {
    const customData = fieldList.value.length || props.item?.customData ? writeCustom(props.item?.customData, fieldList.value, form.custom) : undefined
    const result = await saveItem(props.kind, props.item?.id ?? null, {
      name: form.name.trim(),
      // Only who changes prices sends one: otherwise the price kept stays (catalog.form.price).
      ...(canPrice && (!editing || form.value !== initial.value) ? { value: form.value } : {}),
      ...(customData !== undefined ? { customData } : {}),
      // Removing the photo says which one the person saw: a photo the app put there since stays (revisão M2).
      ...(editing && removePhoto.value && !photo.value ? { photo: null, photoSeen: props.item?.photo ?? null } : {}),
      ...(editing && props.item?.version ? { version: props.item.version } : {}),
    })
    allowClose = true
    if (photo.value) {
      try {
        const uploaded = await uploadItemPhoto(props.kind, result.id, photo.value.file)
        await saveItem(props.kind, result.id, { photo: uploaded })
      } catch (error) {
        console.warn('catalog: photo not saved', error)
        showToast(t('web.catalog.photoFailed'))
        emit('saved', result.id)
        return
      }
    }
    announce(t('web.catalog.saved'))
    emit('saved', result.id)
  } catch (error) {
    // Saved by someone else since it opened: nothing is written over it; the list reads the new one.
    if (changedSince(error)) {
      allowClose = true
      emit('changed')
      return
    }
    console.warn('catalog: not saved', error)
    const key = errorMessageKey(error)
    failed.value = key === 'web.error.generic' ? t('web.catalog.saveFailed') : `${t('web.catalog.saveFailed')} ${t(key)}`
  } finally {
    saving.value = false
  }
}

async function remove() {
  if (!props.item || saving.value) return
  saving.value = true
  try {
    await deleteItem(props.kind, props.item.id)
    allowClose = true
    showToast(t('web.catalog.deleted', { name: props.item.name }))
    emit('removed')
  } catch (error) {
    dialog.value = null
    failed.value = t(errorMessageKey(error))
  } finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault()
    event.stopPropagation()
    void save()
  }
}

function guard(): boolean {
  if (allowClose || !dirty.value) return true
  const ok = window.confirm(`${t('web.catalog.discardTitle')}\n${t('web.catalog.discardBody')}`)
  if (ok) allowClose = true
  return ok
}

onBeforeUnmount(() => {
  if (photo.value) URL.revokeObjectURL(photo.value.url)
})
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="title" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="catalog-form" novalidate @submit.prevent="save()" @keydown="onKeydown" @paste="onPaste">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ title }}</h2>
        <span class="spacer"></span>
        <button v-if="menuChoices.length" ref="menuButton" type="button" class="icon-btn" :aria-label="t('catalogItemActions')" data-testid="catalog-item-menu" @click="dialog = 'menu'">
          <MoreHorizontal :size="18" aria-hidden="true" />
        </button>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div>
          <label class="field-label" for="kf-name">{{ t('name') }}</label>
          <input id="kf-name" v-model="form.name" class="field" autocomplete="off" :placeholder="placeholder" :aria-invalid="tried && !form.name.trim()" data-autofocus />
        </div>
        <div v-if="canPrice">
          <MoneyInput id="kf-price" v-model="form.value" :label="t('catalogPriceLabel')" :country="country" />
          <p class="sub field-hint">{{ t('catalogPriceHint') }}</p>
        </div>
        <details class="more-options" :open="more" @toggle="more = ($event.target as HTMLDetailsElement).open">
          <summary>{{ t('web.catalog.moreData') }}</summary>
          <div class="more-body">
            <div class="cat-photo" data-testid="catalog-photo" @dragover.prevent @drop.prevent="choosePhoto($event.dataTransfer?.files[0])">
              <span class="field-label" id="kf-photo-label">{{ isService ? t('addServicePhoto') : t('addProductPhoto') }}</span>
              <div class="cat-photo-row">
                <img v-if="shownPhoto" class="cat-thumb cat-thumb--big" :src="shownPhoto" :alt="t('web.catalog.photoPreview')" data-testid="catalog-photo-preview" />
                <span v-else class="cat-thumb cat-thumb--big" aria-hidden="true"><Wrench v-if="isService" :size="22" /><Package v-else :size="22" /></span>
                <div class="cat-photo-actions">
                  <label class="btn">
                    <ImagePlus :size="15" aria-hidden="true" />{{ shownPhoto ? t('web.catalog.photoChange') : t('web.catalog.photoPick') }}
                    <input class="sr" type="file" accept="image/*" data-testid="catalog-photo-file" aria-describedby="kf-photo-hint" @change="choosePhoto(($event.target as HTMLInputElement).files?.[0])" />
                  </label>
                  <button v-if="shownPhoto" type="button" class="btn btn--ghost" data-testid="catalog-photo-remove" @click="dropPhoto">{{ t('web.catalog.photoRemove') }}</button>
                </div>
              </div>
              <p id="kf-photo-hint" class="sub field-hint">{{ t('web.catalog.photoHint') }}</p>
              <p v-if="photoError" class="field-error" role="alert">{{ photoError }}</p>
            </div>
            <template v-for="section in sections" :key="section.title">
              <h3 class="form-section">{{ section.title }}</h3>
              <CustomFieldInput
                v-for="field in section.fields"
                :key="field.key"
                v-model="form.custom[fieldName(field.key)]"
                :field="field"
                :error="tried || form.custom[fieldName(field.key)] ? errorText(fieldErrors[field.key] ?? null, field.min, field.max, field.minLength) : ''"
              />
            </template>
          </div>
        </details>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ !form.name.trim() ? t('web.catalog.needsName') : '' }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !canSave }" data-testid="save-catalog-item">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : saveText }} <kbd>{{ saveKey }}</kbd>
        </button>
      </div>
    </form>
  </Layer>
  <ChoiceDialog v-if="dialog === 'menu' && item" :anchor="menuButton" :title="item.name" :choices="menuChoices" @pick="dialog = 'delete'" @close="dialog = null" />
  <ConfirmDialog
    v-else-if="dialog === 'delete' && item"
    :title="t('catalogDeleteTitle', { name: item.name })"
    :body="t('catalogDeleteMessage')"
    :confirm="deleteText"
    :keep="t('cancel')"
    danger
    @confirm="remove"
    @close="dialog = null"
  />
</template>
