<script setup lang="ts">
// The usage-statistics notice (LGPD): once per browser, after the first screen,
// with "Recusar" and "Aceitar" of equal weight. Until a "yes" nothing is sent and
// firebase/analytics is never downloaded (lib/analytics.ts). The answer can be
// changed in Configurações › Este navegador.
import { t } from '@/i18n'
import { setConsent, startAnalytics } from '@/lib/analytics'

function answer(value: 'granted' | 'denied') {
  setConsent(value)
  if (value === 'granted') void startAnalytics()
}
</script>

<template>
  <section class="consent" role="region" :aria-label="t('web.analytics.title')" data-testid="analytics-consent">
    <p class="consent-text">
      {{ t('web.analytics.body') }}
      <a class="link" href="/privacy.html" target="_blank" rel="noopener">{{ t('web.analytics.policy') }}</a>
    </p>
    <div class="consent-btns">
      <button type="button" class="btn" data-testid="analytics-deny" @click="answer('denied')">{{ t('web.analytics.deny') }}</button>
      <button type="button" class="btn" data-testid="analytics-accept" @click="answer('granted')">{{ t('web.analytics.accept') }}</button>
    </div>
  </section>
</template>

<style scoped>
.consent {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 55;
  max-width: min(26rem, calc(100vw - 2rem));
  background: var(--color-card);
  color: var(--color-ink);
  border: 1px solid var(--color-rule);
  border-radius: 8px;
  padding: 0.9rem 1rem;
  box-shadow: 0 10px 24px oklch(18% 0.05 255 / 0.18);
}
.consent-text { margin: 0 0 0.75rem; }
.consent-btns { display: flex; gap: 0.5rem; justify-content: flex-end; flex-wrap: wrap; }
@media (max-width: 40rem) {
  .consent { left: 1rem; right: 1rem; max-width: none; bottom: calc(4.1rem + env(safe-area-inset-bottom)); }
}
@media (forced-colors: active) {
  .consent { border-color: CanvasText; }
}
</style>
