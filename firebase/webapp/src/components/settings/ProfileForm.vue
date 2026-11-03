<script setup lang="ts">
// "Seu perfil" (profile.edit.save, profile.edit.photo): name (required) and
// photo. Unlike the app, the photo waits for "Salvar", and a failure is shown.
// The e-mail is a sentence, never edited.
import { computed, onBeforeUnmount, ref } from 'vue'
import { Check, X } from '@lucide/vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { saveProfileName, uploadProfilePhoto, type Profile } from '@/lib/settings/data'
import { session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import '@/styles/orders.css'

const props = defineProps<{ profile: Profile }>()
const emit = defineEmits<{ close: []; saved: [profile: Profile] }>()

const name = ref(props.profile.name)
const layer = ref<InstanceType<typeof Layer> | null>(null)
const tried = ref(false)
const saving = ref(false)
const failed = ref('')
const photo = ref<File | null>(null)
const preview = ref<string | null>(null)
const photoError = ref('')
let allowClose = false

const dirty = computed(() => name.value !== props.profile.name || !!photo.value)
const shown = computed(() => preview.value ?? props.profile.photo)
// The photo is kept per company, as in the app: without one there is nowhere to put it.
const canPhoto = computed(() => !!session.companyId)

function choose(file: File | undefined) {
  photoError.value = ''
  if (!file) return
  if (!/^image\/(jpeg|png|webp)$/.test(file.type) || file.size > 10 * 1024 * 1024) {
    photoError.value = t('web.company.logoInvalid')
    return
  }
  if (preview.value) URL.revokeObjectURL(preview.value)
  photo.value = file
  preview.value = URL.createObjectURL(file)
}

function guard(): boolean {
  if (allowClose || !dirty.value || saving.value) return true
  return window.confirm(`${t('web.company.discardTitle')}\n${t('web.company.discardBody')}`)
}

async function save() {
  tried.value = true
  if (!name.value.trim() || saving.value) return
  saving.value = true
  failed.value = ''
  try {
    if (name.value !== props.profile.name) await saveProfileName(name.value)
    const url = photo.value ? await uploadProfilePhoto(photo.value) : props.profile.photo
    allowClose = true
    showToast(t('web.account.profileSaved'))
    emit('saved', { ...props.profile, name: name.value.trim(), photo: url })
  } catch (error) {
    console.error('account: profile failed', error)
    failed.value = t('profileSaveFailed')
  } finally {
    saving.value = false
  }
}

onBeforeUnmount(() => {
  if (preview.value) URL.revokeObjectURL(preview.value)
})
</script>

<template>
  <Layer ref="layer" kind="drawer" :label="t('profileEditTitle')" :guard="guard" @close="emit('close')">
    <form class="drawer" data-testid="profile-form" novalidate @submit.prevent="save()">
      <div class="drawer-head">
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="layer?.close()"><X :size="18" aria-hidden="true" /></button>
        <h2 class="layer-title">{{ t('profileEditTitle') }}</h2>
      </div>
      <div class="drawer-body">
        <p v-if="failed" class="field-error" role="alert">{{ failed }}</p>
        <div v-if="canPhoto" class="logo-row">
          <span class="set-avatar set-avatar--big">
            <img v-if="shown" :src="shown" :alt="t('web.account.photoAlt')" data-testid="profile-photo" />
            <span v-else aria-hidden="true">{{ (name || '?').charAt(0).toUpperCase() }}</span>
          </span>
          <label class="btn">
            {{ t('profileChangePhoto') }}
            <input class="sr" type="file" accept="image/jpeg,image/png,image/webp" data-testid="profile-photo-file" @change="choose(($event.target as HTMLInputElement).files?.[0])" />
          </label>
          <p v-if="photoError" class="field-error" role="alert">{{ photoError }}</p>
        </div>
        <div>
          <label class="field-label" for="pf-name">{{ t('name') }}</label>
          <input id="pf-name" v-model="name" class="field" autocomplete="name" :placeholder="t('profileNamePlaceholder')" :aria-invalid="tried && !name.trim()" data-autofocus />
          <p v-if="tried && !name.trim()" class="field-error">{{ t('profileNameRequired') }}</p>
        </div>
        <p class="sub">{{ t('profileSignedInAs', { email: profile.email }) }}</p>
      </div>
      <div class="drawer-foot">
        <span class="hint" aria-live="polite">{{ !name.trim() ? t('profileNameRequired') : '' }}</span>
        <button type="submit" class="btn btn--primary" :class="{ 'is-muted': !name.trim() }" :disabled="saving" data-testid="save-profile">
          <Check :size="16" aria-hidden="true" />{{ saving ? t('web.newOrder.saving') : t('save') }}
        </button>
      </div>
    </form>
  </Layer>
</template>
