/**
 * Refusals of the order write rules, mapped to HTTP by the routes
 * (routes/v1/orders.routes.ts `sendOrderError`). Thrown inside Firestore
 * transactions, so nothing is written when one is raised.
 */
export type OrderErrorCode =
  | 'INSUFFICIENT_PERMISSIONS'
  | 'VALIDATION_ERROR'
  | 'NOT_FOUND'
  | 'ORDER_CHANGED'
  | 'CUSTOMER_CHANGED'
  | 'DEVICE_CHANGED'
  | 'CATALOG_ITEM_CHANGED'
  | 'ITEM_NOT_FOUND'
  | 'TRANSACTION_NOT_FOUND'
  | 'TRANSACTION_ID_CONFLICT'
  | 'PAYMENT_EXCEEDS_BALANCE'
  | 'ORDER_ID_CONFLICT'
  | 'ASAAS_LOCKED'
  | 'RECEIPT_SHARE'
  | 'INVALID_DEVICE'
  | 'INVALID_ASSIGNEE'
  | 'INVALID_CURSOR'
  | 'UNSUPPORTED_QUERY'
  | 'HOLD_NOT_ALLOWED'
  | 'ORDER_STATUS';

export class OrderRuleError extends Error {
  constructor(
    readonly code: OrderErrorCode,
    readonly httpStatus: number,
    message: string,
    /** Extra fields sent in the error body (e.g. the current balance). */
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'OrderRuleError';
  }
}

export function forbiddenOrder(message = 'Not allowed on this order'): OrderRuleError {
  return new OrderRuleError('INSUFFICIENT_PERMISSIONS', 403, message);
}
