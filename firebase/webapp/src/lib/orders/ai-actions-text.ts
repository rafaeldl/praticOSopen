// Texts of the "Confere?" card's notices (ai_actions_sheet.dart).
import { t } from '@/i18n'
import type { Notice } from './ai-actions'
import { money } from './text'

export function noticeText(notice: Notice): string {
  if (notice.kind === 'canceled') return t('aiActionsOrderCanceled')
  if (notice.kind === 'cannotDiscount') return t('aiActionsCannotDiscount')
  if (notice.kind === 'cannotReceive') return t('aiActionsCannotReceive')
  if (notice.kind === 'nothingToReceive') return t('aiActionsNothingToReceive')
  if (notice.kind === 'onlyLeft') return t('aiActionsOnlyLeft', { amount: money(notice.amount) })
  if (notice.kind === 'pendingChecklists') return t('orderPendingChecklists', { count: notice.count })
  return t('permissionDenied')
}
