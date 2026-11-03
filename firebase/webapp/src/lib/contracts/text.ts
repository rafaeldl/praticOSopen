// Words for contracts. Keys stay literal so the build keeps them.
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { fromIsoDay } from '@/lib/format'
import { orderShort } from '@/lib/orders/text'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { session } from '@/lib/session'
import { dayOf, endedDay, nextPlanned, stateOf, titleClashes, type Contract, type Repeat } from './model'

/** "Todo mês", "A cada 2 semanas" (ContractRepeat.label). */
export function repeatText(repeat: Repeat | Pick<Contract, 'frequency' | 'interval'>): string {
  const count = repeat.interval || 1
  switch (repeat.frequency) {
    case 'daily':
      return t('contractEveryDays', { count })
    case 'weekly':
      return t('contractEveryWeeks', { count })
    case 'yearly':
      return t('contractEveryYears', { count })
    default:
      return t('contractEveryMonths', { count })
  }
}

/** A wall date ("2026-12-03T00:00:00.000") as the company's short date. */
export function dayText(wall: string | null | undefined): string {
  return wall ? formatDate(fromIsoDay(dayOf(wall)), session.company?.country) : ''
}

/** "Contratos", or "Contratos que se repetem" when the segment calls each order "Contrato" (contract.title.label). */
export function contractsTitle(): string {
  const plural = resolveLabel('service_order._entity_plural', segmentLabels(), (key) => t(key))
  return titleClashes(plural, t('contracts')) ? t('recurringOrdersTitle', { orders: plural }) : t('contracts')
}

/** The last line of a row and of the order's card: next order, paused or ended (contract.list.row). */
export function stateText(contract: Contract, today: string): { text: string; tone: 'normal' | 'late' | 'muted' } {
  const order = orderShort()
  const state = stateOf(contract)
  if (state === 'paused') return { text: t('web.contracts.pausedSince', { date: dayText(contract.pausedAt) }), tone: 'muted' }
  if (state === 'ended') {
    const day = endedDay(contract)
    return { text: day ? t('contractEndedOn', { date: dayText(day) }) : t('contractEnded'), tone: 'muted' }
  }
  const planned = nextPlanned(contract, today)
  if (planned.kind === 'none') return { text: t('web.contracts.noNext', { order }), tone: 'muted' }
  if (planned.kind === 'manual') return { text: t('web.contracts.noAuto', { order }), tone: 'muted' }
  if (planned.late) return { text: t('web.contracts.nextLate', { order, date: dayText(planned.date) }), tone: 'late' }
  return { text: t('contractNextOrderOn', { order, date: dayText(planned.date) }), tone: 'normal' }
}
