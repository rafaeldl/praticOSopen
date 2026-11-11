/**
 * App permissions on the server.
 *
 * Same table as lib/models/permission.dart (RolePermissions): the routes used
 * by the app ask for the permission the app checks before showing the action,
 * so a call made outside the app cannot do more than the app allows.
 * rbac-api.test.ts checks this table against the golden copy of the app
 * (__tests__/rbac/app-permissions.json).
 *
 * Orders follow firestore.rules: owner, admin, manager and supervisor see
 * every order; consultant and technician only the ones they created.
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest, Order, OrderStatus } from '../models/types';
import { db } from '../services/firestore.service';
import * as orderService from '../services/order.service';

export type AppPermission =
  | 'assignOrder' | 'attachPhotos' | 'chargeOrder' | 'createOrder' | 'editOrder' | 'editPrices'
  | 'executeOrder' | 'fillForms' | 'manageCompany' | 'manageCustomers' | 'manageDevices'
  | 'manageForms' | 'manageProducts' | 'manageRoles' | 'manageServices' | 'manageSettings'
  | 'manageUsers' | 'viewAllOrders' | 'viewAssignedOrders' | 'viewBilling' | 'viewCustomers'
  | 'viewDashboard' | 'viewDevices' | 'viewFinancialReports' | 'viewOperationalReports'
  | 'viewOwnOrders' | 'viewPhotos' | 'viewPrices' | 'viewProducts' | 'viewServices';

type AppRole = 'admin' | 'manager' | 'supervisor' | 'consultant' | 'technician';

/** Denied when the company turned off "Valores e cobrança" (useFinancial: false). */
export const FINANCIAL_APP_PERMISSIONS: readonly AppPermission[] = [
  'chargeOrder', 'editPrices', 'viewBilling', 'viewFinancialReports', 'viewPrices',
];

export const APP_ROLE_PERMISSIONS: Record<AppRole, readonly AppPermission[]> = {
  admin: [
    'assignOrder', 'attachPhotos', 'chargeOrder', 'createOrder', 'editOrder', 'editPrices',
    'executeOrder', 'fillForms', 'manageCompany', 'manageCustomers', 'manageDevices',
    'manageForms', 'manageProducts', 'manageRoles', 'manageServices', 'manageSettings',
    'manageUsers', 'viewAllOrders', 'viewAssignedOrders', 'viewBilling', 'viewCustomers',
    'viewDashboard', 'viewDevices', 'viewFinancialReports', 'viewOperationalReports',
    'viewOwnOrders', 'viewPhotos', 'viewPrices', 'viewProducts', 'viewServices',
  ],
  manager: [
    'chargeOrder', 'editOrder', 'editPrices', 'viewAllOrders', 'viewAssignedOrders',
    'viewBilling', 'viewCustomers', 'viewDashboard', 'viewDevices', 'viewFinancialReports',
    'viewOperationalReports', 'viewOwnOrders', 'viewPhotos', 'viewPrices', 'viewProducts',
    'viewServices',
  ],
  supervisor: [
    'assignOrder', 'attachPhotos', 'createOrder', 'editOrder', 'executeOrder', 'fillForms',
    'manageCustomers', 'manageDevices', 'manageForms', 'viewAllOrders', 'viewAssignedOrders',
    'viewCustomers', 'viewDevices', 'viewOwnOrders', 'viewPhotos', 'viewProducts', 'viewServices',
  ],
  consultant: [
    'assignOrder', 'attachPhotos', 'createOrder', 'editOrder', 'fillForms', 'manageCustomers', 'viewCustomers',
    'viewDevices', 'viewOwnOrders', 'viewPhotos', 'viewPrices', 'viewProducts', 'viewServices',
  ],
  technician: [
    'attachPhotos', 'createOrder', 'editOrder', 'executeOrder', 'fillForms',
    'viewAssignedOrders', 'viewCustomers', 'viewDevices', 'viewPhotos',
  ],
};

/** 'owner' is read as admin, like the app (rolesTypeFromJson). Unknown roles get nothing. */
function appRoleOf(role: string | undefined): AppRole | null {
  if (role === 'owner') return 'admin';
  return role && role in APP_ROLE_PERMISSIONS ? (role as AppRole) : null;
}

/** Whether [role] has [permission] in a company with [useFinancial] (absent = on). */
export function roleHasPermission(
  role: string | undefined,
  permission: AppPermission,
  useFinancial: boolean | undefined,
): boolean {
  if (useFinancial === false && FINANCIAL_APP_PERMISSIONS.includes(permission)) return false;
  const appRole = appRoleOf(role);
  return !!appRole && APP_ROLE_PERMISSIONS[appRole].includes(permission);
}

/** Reads `useFinancial` of the request's company once per request. */
export async function companyUsesFinancial(req: AuthenticatedRequest, res: Response): Promise<boolean | undefined> {
  if (!('useFinancial' in res.locals)) {
    const companyId = req.userContext?.companyId;
    const snap = companyId ? await db.collection('companies').doc(companyId).get() : null;
    res.locals.useFinancial = snap?.data()?.useFinancial as boolean | undefined;
  }
  return res.locals.useFinancial as boolean | undefined;
}

/** Whether the request's user has [permission] (company option included). */
export async function can(
  req: AuthenticatedRequest,
  res: Response,
  permission: AppPermission,
): Promise<boolean> {
  const financial = FINANCIAL_APP_PERMISSIONS.includes(permission);
  return roleHasPermission(
    req.userContext?.role,
    permission,
    financial ? await companyUsesFinancial(req, res) : undefined,
  );
}

/**
 * Every order, or only the ones the user created; the technician also sees the
 * ones assigned to them (same as firestore.rules, isOrderAssignee).
 */
export function canSeeOrder(req: AuthenticatedRequest, order: Partial<Pick<Order, 'createdBy' | 'assignedTo'>>): boolean {
  const role = req.userContext?.role;
  if (role === 'owner' || role === 'admin' || role === 'manager' || role === 'supervisor') return true;
  const userId = req.userContext?.userId;
  if (!userId) return false;
  return order.createdBy?.id === userId || (role === 'technician' && order.assignedTo?.id === userId);
}

/**
 * Same flow as AuthorizationService.canChangeOrderStatus and firestore.rules.
 * Keeping the status is not a change, so it is always allowed.
 */
export function canChangeOrderStatus(
  req: AuthenticatedRequest,
  order: Pick<Order, 'status' | 'createdBy'>,
  newStatus: OrderStatus,
): boolean {
  const from = order.status;
  if (!canSeeOrder(req, order)) return false;
  if (from === newStatus) return true;

  const role = appRoleOf(req.userContext?.role);
  if (role === 'admin' || role === 'manager') return true;
  if (role === 'consultant') return from === 'quote' && (newStatus === 'approved' || newStatus === 'canceled');
  if (role !== 'supervisor' && role !== 'technician') return false;

  const isCreator = !!req.userContext?.userId && order.createdBy?.id === req.userContext.userId;
  if (from === 'quote') return isCreator && (newStatus === 'approved' || newStatus === 'progress');
  if (from === 'approved') return newStatus === 'progress' || newStatus === 'done';
  return from === 'progress' && newStatus === 'done';
}

/** Status a new order can start in, same as orderCreateFieldsAllowed in firestore.rules. */
export function canCreateOrderWithStatus(req: AuthenticatedRequest, status: OrderStatus): boolean {
  const role = appRoleOf(req.userContext?.role);
  if (role === 'admin') return true;
  if (role === 'consultant') return status === 'quote' || status === 'approved' || status === 'canceled';
  if (role === 'supervisor' || role === 'technician') {
    return status === 'quote' || status === 'approved' || status === 'progress';
  }
  return false;
}

/** Supervisor and technician edit items only on quotes (AuthorizationService.canEditOrderMainFields). */
export function canEditOrderMainFields(req: AuthenticatedRequest, order: Pick<Order, 'status' | 'createdBy'>): boolean {
  const role = appRoleOf(req.userContext?.role);
  if (!role || !canSeeOrder(req, order)) return false;
  return (role !== 'supervisor' && role !== 'technician') || order.status === 'quote';
}

/**
 * Who registers money received on [order] ("Receber"), same as the app's
 * AuthorizationService.canReceiveOnOrderFor and `canReceiveOnOrder` in
 * firestore.rules: financial access (owner, admin, manager) on any order; a
 * consultant on the orders they created, when the company uses values.
 * Supervisor and technician never. Discount stays with financial access.
 */
export function canReceiveOnOrder(
  req: AuthenticatedRequest,
  order: Partial<Pick<Order, 'createdBy'>> | null | undefined,
  useFinancial: boolean | undefined,
): boolean {
  const role = req.userContext?.role;
  if (roleHasPermission(role, 'viewFinancialReports', useFinancial)) return true;
  const userId = req.userContext?.userId;
  return appRoleOf(role) === 'consultant'
    && roleHasPermission(role, 'viewPrices', useFinancial)
    && !!userId
    && order?.createdBy?.id === userId;
}

/** Discount and money of others: financial access only (viewFinancialReports, company option included). */
export function canGiveDiscount(req: AuthenticatedRequest, useFinancial: boolean | undefined): boolean {
  return roleHasPermission(req.userContext?.role, 'viewFinancialReports', useFinancial);
}

/** Money on the order: a payment or a transaction (same as orderHasNoMoney in firestore.rules). */
export function orderHasMoney(order: Partial<Pick<Order, 'paidAmount' | 'transactions'>>): boolean {
  return (Number(order.paidAmount) || 0) !== 0 || (order.transactions ?? []).length > 0;
}

/**
 * Who deletes an order (AuthorizationService.canDeleteOrder + firestore.rules
 * `allow delete`, contract order-delete.json): admin always; manager and
 * supervisor a quote without money; consultant and technician a quote without
 * money that they created.
 */
export function canDeleteOrder(
  req: AuthenticatedRequest,
  order: Pick<Order, 'status' | 'createdBy'> & Partial<Pick<Order, 'paidAmount' | 'transactions'>>,
): boolean {
  const role = appRoleOf(req.userContext?.role);
  if (!role || !canSeeOrder(req, order)) return false;
  if (role === 'admin') return true;
  if (order.status !== 'quote' || orderHasMoney(order)) return false;
  if (role === 'manager' || role === 'supervisor') return true;
  return !!req.userContext?.userId && order.createdBy?.id === req.userContext.userId;
}

/** Statuses an order can be marked "parada" in (docs/ORDER_ON_HOLD.md). */
export const HOLD_STATUSES: readonly string[] = ['approved', 'progress'];

/**
 * Who removes the "parada" mark: whoever changes the status of an active
 * order (financial or operator), in any status (`orderHoldChangeAllowed`).
 * The consultant only decides quotes, so never.
 */
export function canRemoveOrderHold(req: AuthenticatedRequest, order: Partial<Pick<Order, 'createdBy'>>): boolean {
  const role = appRoleOf(req.userContext?.role);
  return !!role && role !== 'consultant' && canSeeOrder(req, order);
}

/** Who marks it (canChangeOrderHoldFor). The status is checked apart (409 instead of 403). */
export function canChangeOrderHold(req: AuthenticatedRequest, order: Partial<Pick<Order, 'createdBy'>>): boolean {
  return canRemoveOrderHold(req, order);
}

/**
 * Who moves an order between work stages and reorders a stage: same people as
 * the "parada" mark (not the consultant). Starting an approved order also needs
 * canChangeOrderStatus to `progress`.
 */
export function canChangeOrderStage(req: AuthenticatedRequest, order: Partial<Pick<Order, 'createdBy'>>): boolean {
  return canRemoveOrderHold(req, order);
}

/** Same body as requirePermission in auth.middleware (older apps read it). */
export function forbidden(res: Response, message = 'Not allowed'): void {
  res.status(403).json({ success: false, error: { code: 'INSUFFICIENT_PERMISSIONS', message } });
}

function internalError(res: Response, error: unknown): void {
  console.error('Permission check error:', (error as Error).name);
  res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Internal error' } });
}

/**
 * router.param callback for `:number`: the order must be one the user can see.
 * No user context or a missing order goes on to the route, which answers them.
 */
export async function checkOrderNumberAccess(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
  value: string,
): Promise<void> {
  try {
    const companyId = req.userContext?.companyId;
    const orderNumber = parseInt(value, 10);
    if (!companyId || isNaN(orderNumber) || canSeeOrder(req, {})) return next();
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (order && !canSeeOrder(req, order)) return forbidden(res, 'Not allowed on this order');
    next();
  } catch (error) {
    internalError(res, error);
  }
}

/** Middleware: 403 unless the user has every one of [permissions]. */
export function requireAppPermission(...permissions: AppPermission[]) {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      for (const permission of permissions) {
        if (!(await can(req, res, permission))) return forbidden(res, `Permission '${permission}' is required`);
      }
      next();
    } catch (error) {
      internalError(res, error);
    }
  };
}

/** Middleware: the order in `req.params[param]` must accept item changes from the user. */
export function requireOrderItemsEditable(param = 'id') {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const companyId = req.userContext?.companyId;
      const order = companyId ? await orderService.getOrder(companyId, String(req.params[param])) : null;
      if (order && !canEditOrderMainFields(req, order)) return forbidden(res, 'Not allowed on this order');
      next();
    } catch (error) {
      internalError(res, error);
    }
  };
}

/**
 * Middleware: the order in `req.params[param]` must be one the user can see.
 * A missing order goes on to the route (which answers 404).
 */
export function requireOrderAccess(param = 'id') {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const companyId = req.userContext?.companyId;
      const raw = req.params[param];
      const orderId = Array.isArray(raw) ? raw[0] : raw;
      if (!companyId || !orderId) return forbidden(res);
      const order = await orderService.getOrder(companyId, String(orderId));
      if (order && !canSeeOrder(req, order)) return forbidden(res, 'Not allowed on this order');
      next();
    } catch (error) {
      internalError(res, error);
    }
  };
}
