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
import { AuthenticatedRequest, Order } from '../models/types';
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
    'attachPhotos', 'createOrder', 'editOrder', 'fillForms', 'manageCustomers', 'viewCustomers',
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
async function companyUsesFinancial(req: AuthenticatedRequest, res: Response): Promise<boolean | undefined> {
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

/** Every order, or only the ones the user created (same as firestore.rules). */
export function canSeeOrder(req: AuthenticatedRequest, order: Pick<Order, 'createdBy'>): boolean {
  const role = req.userContext?.role;
  if (role === 'owner' || role === 'admin' || role === 'manager' || role === 'supervisor') return true;
  return !!req.userContext?.userId && order.createdBy?.id === req.userContext.userId;
}

/** Same body as requirePermission in auth.middleware (older apps read it). */
export function forbidden(res: Response, message = 'Not allowed'): void {
  res.status(403).json({ success: false, error: { code: 'INSUFFICIENT_PERMISSIONS', message } });
}

function internalError(res: Response, error: unknown): void {
  console.error('Permission check error:', (error as Error).name);
  res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Internal error' } });
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
