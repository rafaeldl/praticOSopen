// Pure state/decision logic for the order card's action buttons.
//
// No React, no DOM: this module only computes "which buttons apply" and
// "what happened after a write", so it can be unit-tested with plain Jest
// from firebase/functions (see src/mcp/__tests__/card-state.test.ts) without
// a component renderer. order-card.tsx imports these functions and keeps
// only React state wiring and JSX.

export interface OrderItem {
  name?: string;
  value?: number;
  quantity?: number;
}

// Mirrors OrderCardData in src/mcp/widgets/order-card.ts (toCardData's
// allowlist) — the only fields the card is allowed to rely on.
export interface OrderData {
  number?: number;
  status?: string;
  customer?: { name?: string } | null;
  devices?: { name?: string; serial?: string }[];
  services?: OrderItem[];
  products?: OrderItem[];
  total?: number;
  shareUrl?: string | null;
}

/** Shape of the value bridge.ts's callTool() promise resolves with (CallToolResult). */
export interface ToolCallResult {
  isError?: boolean;
  structuredContent?: { order?: OrderData };
}

export interface AvailableActions {
  approve: boolean;
  markDone: boolean;
  copyLink: boolean;
}

/**
 * Which buttons apply to the CURRENT order. Derived from `order` alone —
 * never from a pending confirmation or a leftover success/error message, so
 * a message is always additive and never hides a control the order's status
 * still allows.
 */
export function availableActions(order: OrderData): AvailableActions {
  return {
    approve: order.status === 'quote',
    markDone: order.status !== 'done' && order.status !== 'canceled',
    copyLink: Boolean(order.shareUrl),
  };
}

export const WRITE_FAILED_MESSAGE = 'Não foi possível atualizar';

const STATUS_MESSAGE: Record<'done' | 'approved', string> = {
  done: 'Concluída',
  approved: 'Aprovada',
};

export interface StatusResult {
  order: OrderData;
  message: string;
  error?: boolean;
}

/**
 * The write did not go through at all: `callTool` rejected (network error,
 * JSON-RPC error). The order is left exactly as it was — a rejection carries
 * no information about server state, so nothing about the order is assumed.
 */
export function writeFailed(order: OrderData): StatusResult {
  return { order, message: WRITE_FAILED_MESSAGE, error: true };
}

/**
 * Applies the outcome of an `update_order_status` call to the current order.
 *
 * - `result` missing or `isError: true`: the tool itself reported failure.
 *   The order is left untouched (same as `writeFailed`) so the buttons stay
 *   exactly as they were and the user can retry.
 * - success with `structuredContent.order` present: that is the updated
 *   `OrderDetail` the route returned (see withOrderCard/orderResult in
 *   src/mcp/widgets/order-card.ts and src/mcp/tools/write.ts — proven by
 *   order-card-dispatch.test.ts), so it becomes the new current order.
 * - success without `structuredContent.order` (e.g. a host that strips
 *   structured content): optimistically apply the requested status so the
 *   card does not go stale, since the call did succeed.
 */
export function applyStatusResult(
  order: OrderData,
  result: ToolCallResult | null | undefined,
  requestedStatus: 'done' | 'approved',
): StatusResult {
  if (!result || result.isError) return writeFailed(order);

  const updated = result.structuredContent?.order;
  if (updated) {
    const label = STATUS_MESSAGE[updated.status as 'done' | 'approved'] ?? STATUS_MESSAGE[requestedStatus];
    return { order: updated, message: label };
  }

  return { order: { ...order, status: requestedStatus }, message: STATUS_MESSAGE[requestedStatus] };
}
