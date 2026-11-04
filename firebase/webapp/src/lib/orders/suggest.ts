// Choices suggested by what was done before, confirmed with Enter
// (docs/web-app/timed-comparison.md): the payment method and the next step.
// Kept per company in this browser; nothing here is written to the server.
import { ref } from 'vue'
import { readStorage, writeStorage } from '@/lib/storage'
import type { OrderStatus, OrderTransaction } from './model'

const FORWARD: OrderStatus[] = ['quote', 'approved', 'progress', 'done']
const methodKey = (companyId: string) => `praticos.lastPaymentMethod.${companyId}`
const stepKey = (companyId: string) => `praticos.nextStatus.${companyId}`

export function rememberMethod(companyId: string | null | undefined, method: string): void {
  if (companyId && method) writeStorage(methodKey(companyId), method)
}

/** The method of this order's last payment; else the last one used here; else none. */
export function suggestedMethod(order: { transactions: OrderTransaction[] }, companyId: string | null | undefined): string {
  const own = [...order.transactions].reverse().find((item) => item.type === 'payment' && item.paymentMethod)?.paymentMethod
  if (own) return own
  return (companyId && readStorage(methodKey(companyId))) || ''
}

/** Bumped on every write: a screen showing the step follows at once (reactive, no reload). */
const stepsVersion = ref(0)

function readSteps(companyId: string): Partial<Record<OrderStatus, OrderStatus>> {
  void stepsVersion.value
  try {
    return JSON.parse(readStorage(stepKey(companyId)) ?? '{}') as Partial<Record<OrderStatus, OrderStatus>>
  } catch {
    return {}
  }
}

function writeSteps(companyId: string, steps: Partial<Record<OrderStatus, OrderStatus>>) {
  writeStorage(stepKey(companyId), JSON.stringify(steps))
  stepsVersion.value++
}

/**
 * Only a move forward is remembered (never back, never Cancelado). Written when
 * the person chooses, before the server answers: the page may be left before the
 * answer arrives. Returns how to put the previous memory back (the write was refused).
 */
export function rememberTransition(companyId: string | null | undefined, from: OrderStatus, to: OrderStatus): () => void {
  if (!companyId || FORWARD.indexOf(to) <= FORWARD.indexOf(from) || !FORWARD.includes(from)) return () => {}
  const before = readSteps(companyId)
  writeSteps(companyId, { ...before, [from]: to })
  return () => {
    const now = readSteps(companyId)
    if (now[from] !== to) return
    const restored = { ...now }
    if (before[from]) restored[from] = before[from]
    else delete restored[from]
    writeSteps(companyId, restored)
  }
}

/** Where this person went from this status last time, if still allowed. */
export function preferredStep(companyId: string | null | undefined, from: OrderStatus, allowed: OrderStatus[]): OrderStatus | null {
  if (!companyId) return null
  const to = readSteps(companyId)[from]
  return to && allowed.includes(to) ? to : null
}
