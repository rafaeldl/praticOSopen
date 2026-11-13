<script setup lang="ts">
// Integrações (integrations.*, asaas.*, advanced.integrations): owner and admin
// only (manageUsers), the same guard the API keeps. "Pagamentos" (Asaas) shows
// only for a company in the pilot (asaasEnabled): connect with the API key,
// account and environment, disconnect with a confirmation. "ChatGPT e Claude":
// the connections, a new one shows its URL once (the API never returns it
// again) and turning one off asks first.
import { onMounted, ref, shallowRef } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import Layer from '@/components/Layer.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { formatDate } from '@/lib/format'
import { session } from '@/lib/session'
import {
  connectAsaas,
  createToken,
  disconnectAsaas,
  listTokens,
  loadPaymentSettings,
  revokeToken,
  type McpToken,
  type PaymentSettings,
} from '@/lib/settings/data'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature, handlePlanFeatureError, usePlanFeature } from '@/lib/plan-feature-gate'
import { PLAN_NAME } from '@/lib/plan-limits'
import { announce } from '@/lib/ui'
import '@/styles/settings.css'

const ASAAS_PANEL = 'https://www.asaas.com/customerConfigIntegrations/index'
const ASAAS_SANDBOX_PANEL = 'https://sandbox.asaas.com/customerConfigIntegrations/index'

const tokens = shallowRef<McpToken[] | null>(null)
// Plan (#724): a new ChatGPT/Claude connection is Business, connecting Asaas is
// Starter; connections already made stay listed and can be revoked.
const mcp = usePlanFeature('mcp')
const tokensFailed = ref(false)
const payments = shallowRef<PaymentSettings | null>(null)
const paymentsFailed = ref(false)
const apiKey = ref('')
const connecting = ref(false)
const asaasError = ref('')
const dialog = ref<'new' | 'url' | 'revoke' | 'disconnect' | null>(null)
const newName = ref('')
const newError = ref('')
const creating = ref(false)
const createdUrl = ref('')
const revoking = shallowRef<McpToken | null>(null)

async function loadTokens() {
  tokensFailed.value = false
  tokens.value = null
  try {
    tokens.value = await listTokens()
  } catch (error) {
    console.error('integrations: tokens failed', error)
    tokensFailed.value = true
  }
}

async function loadPayments() {
  paymentsFailed.value = false
  try {
    payments.value = await loadPaymentSettings()
  } catch (error) {
    console.error('integrations: payments failed', error)
    paymentsFailed.value = true
  }
}

function asaasText(error: unknown): string {
  const code = error instanceof ApiError ? error.code : ''
  if (code === 'ASAAS_INVALID_API_KEY') return t('asaasErrorInvalidKey')
  if (code === 'FORBIDDEN') return t('asaasErrorForbidden')
  if (code === 'ASAAS_UNAVAILABLE' || code === 'NETWORK') return t('asaasErrorUnavailable')
  return t('asaasErrorGeneric')
}

async function connect() {
  asaasError.value = ''
  if (!apiKey.value.trim()) {
    asaasError.value = t('web.integrations.keyMissing')
    return
  }
  if (!ensurePlanFeature('charges')) return
  connecting.value = true
  try {
    payments.value = { ...(payments.value ?? { asaasEnabled: true }), ...(await connectAsaas(apiKey.value.trim())), asaasConnected: true }
    apiKey.value = ''
    showToast(t('asaasConnectedToast'))
    announce(t('asaasConnectedToast'))
  } catch (error) {
    console.error('integrations: connect failed', error instanceof ApiError ? error.code : 'error')
    if (handlePlanFeatureError(error)) return
    asaasError.value = asaasText(error)
  } finally {
    connecting.value = false
  }
}

async function disconnect() {
  dialog.value = null
  connecting.value = true
  asaasError.value = ''
  try {
    await disconnectAsaas()
    payments.value = { asaasEnabled: true, asaasConnected: false }
    showToast(t('asaasDisconnectedToast'))
    announce(t('asaasDisconnectedToast'))
  } catch (error) {
    asaasError.value = asaasText(error)
  } finally {
    connecting.value = false
  }
}

function openNew() {
  if (!ensurePlanFeature('mcp')) return
  newName.value = ''
  newError.value = ''
  dialog.value = 'new'
}

async function create() {
  newError.value = ''
  if (!newName.value.trim()) {
    newError.value = t('web.integrations.nameMissing')
    return
  }
  creating.value = true
  try {
    const created = await createToken(newName.value.trim())
    // The URL carries the secret: shown here once, never kept or logged.
    createdUrl.value = created.url ?? ''
    dialog.value = 'url'
    void loadTokens()
  } catch (error) {
    if (planFeatureRefused(error)) return
    newError.value = error instanceof ApiError && error.status === 403 ? t('integrationsErrorForbidden') : t('integrationsErrorGeneric')
  } finally {
    creating.value = false
  }
}

/** A 402 PLAN_FEATURE closes the form and opens the plan notice. */
function planFeatureRefused(error: unknown): boolean {
  if (!handlePlanFeatureError(error)) return false
  dialog.value = null
  return true
}

async function copyUrl() {
  try {
    await navigator.clipboard.writeText(createdUrl.value)
    showToast(t('web.integrations.copied'))
    announce(t('web.integrations.copied'))
  } catch {
    showToast(t('web.team.copyFailed'))
  }
}

function closeUrl() {
  createdUrl.value = ''
  dialog.value = null
}

async function revoke() {
  const token = revoking.value
  dialog.value = null
  revoking.value = null
  if (!token) return
  try {
    await revokeToken(token.id)
    showToast(t('integrationsRevoked'))
    announce(t('integrationsRevoked'))
  } catch (error) {
    showToast(error instanceof ApiError && error.status === 404 ? t('integrationsErrorNotFound') : t('integrationsErrorGeneric'))
  }
  void loadTokens()
}

const used = (token: McpToken) => (token.lastUsedAt ? t('integrationsLastUsed', { date: formatDate(token.lastUsedAt, session.company?.country) }) : t('integrationsNeverUsed'))

onMounted(() => {
  void loadTokens()
  void loadPayments()
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('integrations') }}</h1>
      <p class="page-sub">{{ t('web.integrations.lead') }}</p>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <p v-if="paymentsFailed" class="sub" role="status">
        {{ t('web.integrations.paymentsFailed') }} <button type="button" class="link" @click="loadPayments">{{ t('web.tryAgain') }}</button>
      </p>
      <section v-if="payments?.asaasEnabled" aria-labelledby="int-pay" class="set-section" data-testid="asaas-section">
        <h2 id="int-pay" class="set-h">{{ t('payments') }} · Asaas</h2>
        <p class="set-level">
          <span class="dot" :class="payments.asaasConnected ? 'dot--success' : 'dot--neutral'" aria-hidden="true"></span>
          <span data-testid="asaas-status">{{ payments.asaasConnected ? t('asaasConnected') : t('asaasDisconnected') }}</span>
        </p>
        <template v-if="payments.asaasConnected">
          <p class="set-lead">{{ t('asaasConnectedHeadline') }}</p>
          <ul class="set-list">
            <li>
              <div class="set-row">
                <span class="set-text"><span class="who">{{ t('asaasAccount') }}</span></span>
                <span class="set-end">{{ payments.asaasAccountName ?? '' }}</span>
              </div>
            </li>
            <li>
              <div class="set-row">
                <span class="set-text"><span class="who">{{ t('asaasEnvironment') }}</span></span>
                <span class="set-end set-level" data-testid="asaas-environment">
                  <span class="dot" :class="payments.asaasEnvironment === 'sandbox' ? 'dot--warning' : 'dot--success'" aria-hidden="true"></span>
                  {{ payments.asaasEnvironment === 'sandbox' ? t('asaasEnvironmentSandbox') : t('asaasEnvironmentProduction') }}
                </span>
              </div>
            </li>
          </ul>
          <p v-if="asaasError" class="field-error" role="alert">{{ asaasError }}</p>
          <div class="set-actions">
            <a class="btn" :href="payments.asaasEnvironment === 'sandbox' ? ASAAS_SANDBOX_PANEL : ASAAS_PANEL" target="_blank" rel="noopener noreferrer">{{ t('asaasOpenPanel') }}</a>
            <button type="button" class="btn btn--ghost set-danger" :disabled="connecting" data-testid="asaas-disconnect" @click="dialog = 'disconnect'">{{ t('asaasDisconnect') }}</button>
          </div>
        </template>
        <form v-else class="set-section" novalidate @submit.prevent="connect">
          <p class="set-lead">{{ t('asaasConnectHeadline') }}</p>
          <ol class="set-lead">
            <li>{{ t('asaasConnectStep1') }}</li>
            <li>{{ t('asaasConnectStep2') }}</li>
            <li>{{ t('asaasConnectStep3') }}</li>
          </ol>
          <p class="set-actions">
            <a class="link" :href="ASAAS_PANEL" target="_blank" rel="noopener noreferrer" data-testid="asaas-panel">{{ t('asaasOpenPanel') }}</a>
            <a class="link" :href="ASAAS_SANDBOX_PANEL" target="_blank" rel="noopener noreferrer">{{ t('asaasOpenSandboxPanel') }}</a>
          </p>
          <div style="max-width: 32rem">
            <label class="field-label" for="asaas-key">{{ t('asaasApiKey') }}</label>
            <input id="asaas-key" v-model="apiKey" class="field" type="password" autocomplete="off" spellcheck="false" :placeholder="t('asaasApiKeyPlaceholder')" aria-describedby="asaas-key-hint" />
            <p id="asaas-key-hint" class="sub field-hint">{{ t('asaasApiKeyHint') }}</p>
          </div>
          <p v-if="asaasError" class="field-error" role="alert" data-testid="asaas-error">{{ asaasError }}</p>
          <p><button type="submit" class="btn btn--primary" :disabled="connecting" data-testid="asaas-connect">{{ connecting ? t('asaasConnecting') : t('asaasConnect') }}</button></p>
        </form>
      </section>

      <section aria-labelledby="int-ai" class="set-section">
        <div class="set-actions" style="justify-content: space-between">
          <h2 id="int-ai" class="set-h">{{ t('integrationsAiSection') }}</h2>
          <button type="button" class="btn" data-testid="mcp-new" @click="openNew">+ {{ t('integrationsNew') }}<span v-if="!mcp.allowed" class="plan-badge">· {{ t('planFeatureBadge', { plan: PLAN_NAME[mcp.requiredPlan ?? 'business'] }) }}</span></button>
        </div>
        <LoadingState v-if="!tokens && !tokensFailed" />
        <ErrorState v-else-if="tokensFailed" :retry="loadTokens" />
        <p v-else-if="tokens && !tokens.length" class="muted" data-testid="mcp-empty">{{ t('web.integrations.empty') }}</p>
        <ul v-else-if="tokens" class="set-list" data-testid="mcp-list">
          <li v-for="token in tokens" :key="token.id" :data-token="token.id">
            <div class="set-row">
              <span class="set-text">
                <span class="who">{{ token.name }}</span>
                <span class="sub">{{ used(token) }}</span>
              </span>
              <button type="button" class="link link--danger" :aria-label="t('web.integrations.revokeNamed', { name: token.name })" @click="revoking = token; dialog = 'revoke'">{{ t('integrationsRevoke') }}</button>
            </div>
          </li>
        </ul>
      </section>
    </div>
  </div>

  <Layer v-if="dialog === 'new'" kind="dialog" :label="t('integrationsNew')" @close="dialog = null">
    <template #default="{ close }">
      <form novalidate @submit.prevent="create">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('integrationsNew') }}</h2>
        </div>
        <div class="layer-body">
          <label class="field-label" for="mcp-name">{{ t('name') }}</label>
          <input id="mcp-name" v-model="newName" class="field" autocomplete="off" :placeholder="t('integrationsNameHint')" data-autofocus />
          <p v-if="newError" class="field-error" role="alert">{{ newError }}</p>
        </div>
        <div class="layer-foot">
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button type="submit" class="btn btn--primary" :disabled="creating" data-testid="mcp-create">{{ t('save') }}</button>
        </div>
      </form>
    </template>
  </Layer>
  <Layer v-if="dialog === 'url'" kind="dialog" :label="t('integrationsNew')" @close="closeUrl">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ t('integrationsNew') }}</h2>
      </div>
      <div class="layer-body" data-testid="mcp-url">
        <p>{{ t('integrationsUrlOnce') }}</p>
        <p class="code-box code-box--url">{{ createdUrl }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" @click="close()">{{ t('close') }}</button>
        <button type="button" class="btn btn--primary" data-autofocus data-testid="mcp-copy" @click="copyUrl">{{ t('integrationsCopy') }}</button>
      </div>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="dialog === 'revoke' && revoking"
    :title="revoking.name"
    :body="t('integrationsRevokeConfirm')"
    :confirm="t('integrationsRevoke')"
    :keep="t('cancel')"
    danger
    @confirm="revoke"
    @close="dialog = null; revoking = null"
  />
  <ConfirmDialog
    v-if="dialog === 'disconnect'"
    :title="t('asaasDisconnect')"
    :body="t('asaasDisconnectConfirm')"
    :confirm="t('asaasDisconnect')"
    :keep="t('cancel')"
    danger
    @confirm="disconnect"
    @close="dialog = null"
  />
</template>
