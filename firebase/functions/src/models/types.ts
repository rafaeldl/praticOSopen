/**
 * PraticOS API Types
 * Core type definitions shared across the API
 */

import { Request } from 'express';

// ============================================================================
// Authentication Types
// ============================================================================

export interface ApiKeyData {
  id: string;
  key: string;
  secret?: string;
  companyId: string;
  name: string;
  permissions: string[];
  active: boolean;
  createdAt: FirebaseFirestore.Timestamp;
  expiresAt?: FirebaseFirestore.Timestamp;
}

export interface ChannelLink {
  channel: 'whatsapp' | 'telegram' | 'discord';
  identifier: string;
  userId: string;
  companyId: string;
  role: RoleType;
  linkedAt: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue | Date;
  userName?: string;
  companyName?: string;
}

export interface LinkToken {
  token: string;
  userId: string;
  companyId: string;
  role: RoleType;
  expiresAt: FirebaseFirestore.Timestamp;
  used: boolean;
  userName?: string;
  companyName?: string;
}

export interface InviteCode {
  code: string;
  companyId: string;
  companyName: string;
  invitedByUserId: string;
  invitedByName: string;
  collaboratorName: string;
  role: RoleType;
  expiresAt: FirebaseFirestore.Timestamp;
  accepted: boolean;
  acceptedByUserId?: string;
  acceptedAt?: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
}

// ============================================================================
// User & Company Types
// ============================================================================

export type RoleType = 'owner' | 'admin' | 'supervisor' | 'manager' | 'consultant' | 'technician';

export interface UserAggr {
  id: string;
  name: string;
  email?: string;
  photo?: string;
}

export interface CompanyAggr {
  id: string;
  name: string;
  country?: string;
}

export interface UserContext {
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  role: RoleType;
  permissions: string[];
}

// ============================================================================
// Customer Types
// ============================================================================

export interface CustomerAggr {
  id: string;
  name: string;
  phone?: string | null;
  email?: string | null;
}

export interface Customer extends CustomerAggr {
  address?: string;
  company: CompanyAggr;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

// ============================================================================
// Device Types
// ============================================================================

export interface DeviceAggr {
  id: string;
  name: string;
  serial?: string | null;
  photo?: string | null;
}

export interface Device extends DeviceAggr {
  manufacturer?: string;
  category?: string;
  description?: string;
  company: CompanyAggr;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

// ============================================================================
// Catalog Types (Service & Product)
// ============================================================================

export interface ServiceAggr {
  id: string;
  name: string;
  value?: number;
  photo?: string | null;
}

export interface Service extends ServiceAggr {
  company: CompanyAggr;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

export interface ProductAggr {
  id: string;
  name: string;
  value?: number;
  photo?: string | null;
}

export interface Product extends ProductAggr {
  company: CompanyAggr;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

// ============================================================================
// Order Types
// ============================================================================

export type OrderStatus = 'quote' | 'approved' | 'progress' | 'done' | 'canceled';
export type PaymentStatus = 'unpaid' | 'partial' | 'paid';
export type TransactionType = 'payment' | 'discount';

export interface OrderService {
  service: ServiceAggr;
  description?: string;
  value: number;
  photo?: string;
}

export interface OrderProduct {
  product: ProductAggr;
  description?: string;
  value: number;
  quantity: number;
  photo?: string;
}

export interface OrderPhoto {
  id: string;
  url: string;
  storagePath: string;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
}

export interface PaymentTransaction {
  id: string;
  type: TransactionType;
  amount: number;
  description?: string;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
}

export interface OrderAggr {
  id: string;
  number: number;
  customer?: CustomerAggr;
  device?: DeviceAggr;
}

export interface Order {
  id: string;
  number: number;
  customer?: CustomerAggr;
  device?: DeviceAggr;
  services?: OrderService[];
  products?: OrderProduct[];
  photos?: OrderPhoto[];
  total: number;
  discount: number;
  dueDate?: FirebaseFirestore.Timestamp;
  status: OrderStatus;
  done: boolean;
  paid: boolean;
  payment: PaymentStatus;
  paidAmount: number;
  transactions?: PaymentTransaction[];
  assignedTo?: UserAggr;
  company: CompanyAggr;
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

// ============================================================================
// Company Types
// ============================================================================

export interface UserRoleAggr {
  user: UserAggr;
  role: RoleType;
}

export interface Company {
  id: string;
  name: string;
  email?: string;
  address?: string;
  logo?: string;
  phone?: string;
  site?: string;
  segment?: string;
  country?: string;
  subspecialties?: string[];
  owner: UserAggr;
  users?: UserRoleAggr[];
  createdAt: FirebaseFirestore.Timestamp;
  createdBy: UserAggr;
  updatedAt?: FirebaseFirestore.Timestamp;
  updatedBy?: UserAggr;
}

// ============================================================================
// Analytics Types
// ============================================================================

export interface AnalyticsPeriod {
  start: string;
  end: string;
}

export interface OrdersByStatus {
  quote: number;
  approved: number;
  progress: number;
  done: number;
  canceled: number;
}

export interface RevenueMetrics {
  total: number;
  paid: number;
  unpaid: number;
  discount: number;
}

export interface TopCustomer {
  id: string;
  name: string;
  total: number;
  orderCount: number;
}

export interface TopService {
  id: string;
  name: string;
  total: number;
  count: number;
}

export interface AnalyticsSummary {
  period: AnalyticsPeriod;
  orders: {
    total: number;
    byStatus: OrdersByStatus;
  };
  revenue: RevenueMetrics;
  topCustomers: TopCustomer[];
  topServices: TopService[];
}

export interface PendingOrder {
  id: string;
  number: number;
  customer?: CustomerAggr;
  device?: DeviceAggr;
  total?: number;
  remainingBalance?: number;
  dueDate?: string;
  daysOverdue?: number;
  createdAt: string;
}

export interface PendingItems {
  toApprove: PendingOrder[];
  dueToday: PendingOrder[];
  unpaid: PendingOrder[];
  overdue: PendingOrder[];
}

// ============================================================================
// Request Extensions
// ============================================================================

export interface AuthenticatedRequest extends Request {
  auth?: {
    type: 'apiKey' | 'bot' | 'bearer';
    companyId: string;
    userId?: string;
    permissions?: string[];
  };
  userContext?: UserContext;
}
