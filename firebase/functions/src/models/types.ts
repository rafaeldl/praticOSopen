/**
 * PraticOS API Types
 * Core type definitions shared across the API
 */

import { Request } from 'express';

// Date type that supports both Firestore Timestamp and ISO string format
// This allows compatibility between Flutter app (ISO strings) and legacy data (Timestamps)
export type DateValue = FirebaseFirestore.Timestamp | string;

/**
 * Convert DateValue (Timestamp or ISO string) to JavaScript Date
 * Handles both Firestore Timestamp objects and ISO string formats
 */
export function toDate(value: DateValue | null | undefined): Date | null {
  if (!value) return null;
  if (typeof value === 'string') {
    return new Date(value);
  }
  // Firestore Timestamp has toDate() method
  if (typeof (value as FirebaseFirestore.Timestamp).toDate === 'function') {
    return (value as FirebaseFirestore.Timestamp).toDate();
  }
  return null;
}

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
  createdAt: DateValue;
  expiresAt?: DateValue;
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
  expiresAt: DateValue;
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
  expiresAt: DateValue;
  accepted: boolean;
  acceptedByUserId?: string;
  acceptedAt?: DateValue;
  createdAt: DateValue;
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
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
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
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
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
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
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
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
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
  description?: string;
  createdAt: DateValue;
  createdBy: UserAggr;
}

export interface PaymentTransaction {
  id: string;
  type: TransactionType;
  amount: number;
  description?: string;
  createdAt: DateValue;
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
  dueDate?: DateValue;
  status: OrderStatus;
  done: boolean;
  paid: boolean;
  payment: PaymentStatus;
  paidAmount: number;
  transactions?: PaymentTransaction[];
  assignedTo?: UserAggr;
  rating?: OrderRating;
  company: CompanyAggr;
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
  updatedBy?: UserAggr;
}

// ============================================================================
// Form Types (Dynamic Forms/Checklists)
// ============================================================================

export type FormItemType = 'text' | 'number' | 'select' | 'checklist' | 'photo_only' | 'boolean';
export type FormStatus = 'pending' | 'in_progress' | 'completed';

export interface FormItemDefinition {
  id: string;
  label: string;
  type: FormItemType;
  options?: string[];
  required: boolean;
  allowPhotos: boolean;
  labelI18n?: Record<string, string>;
  optionsI18n?: Record<string, string[]>;
}

export interface FormDefinition {
  id: string;
  title: string;
  description?: string;
  isActive: boolean;
  items: FormItemDefinition[];
  titleI18n?: Record<string, string>;
  descriptionI18n?: Record<string, string>;
  company: CompanyAggr;
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
  updatedBy?: UserAggr;
}

export interface FormResponse {
  itemId: string;
  value: unknown;
  photoUrls: string[];
}

export interface OrderForm {
  id: string;
  formDefinitionId: string;
  title: string;
  status: FormStatus;
  items: FormItemDefinition[];
  responses: FormResponse[];
  startedAt?: DateValue;
  completedAt?: DateValue;
  updatedAt?: DateValue;
  titleI18n?: Record<string, string>;
}

export interface FormItemPhoto {
  id: string;
  url: string;
  storagePath: string;
  createdAt: DateValue;
  createdBy: UserAggr;
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
  createdAt: DateValue;
  createdBy: UserAggr;
  updatedAt?: DateValue;
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
    type: 'apiKey' | 'bot' | 'bearer' | 'shareToken';
    companyId: string;
    userId?: string;
    permissions?: string[];
  };
  userContext?: UserContext;
  shareTokenAuth?: ShareTokenAuth;
}

// ============================================================================
// Share Token Types (Customer Magic Link)
// ============================================================================

export type ShareTokenPermission = 'view' | 'approve' | 'comment';

export interface ShareToken {
  token: string;                        // "ST_<uuid>"
  orderId: string;
  companyId: string;
  permissions: ShareTokenPermission[];
  customer: CustomerAggr;
  createdAt: string;
  expiresAt: string;
  createdBy: UserAggr;
  viewCount: number;
  lastViewedAt?: string;
  approvedAt?: string;
  rejectedAt?: string;
  rejectionReason?: string;
}

export interface ShareTokenAuth {
  type: 'shareToken';
  token: string;
  companyId: string;
  orderId: string;
  permissions: ShareTokenPermission[];
  customer: CustomerAggr;
}

// ============================================================================
// Order Comment Types
// ============================================================================

export type CommentAuthorType = 'customer' | 'internal';
export type CommentSource = 'app' | 'magicLink' | 'bot';

export interface CommentAuthor {
  name: string;
  email?: string;
  phone?: string;
  userId?: string;
}

export interface OrderComment {
  id: string;
  text: string;
  authorType: CommentAuthorType;
  author: CommentAuthor;
  source: CommentSource;
  shareToken?: string;
  isInternal: boolean;
  createdAt: string;
  updatedAt?: string;
  deleted?: boolean;
}

// ============================================================================
// Order Rating Types (Customer Rating)
// ============================================================================

export interface OrderRating {
  score: number;       // 1-5 stars
  comment?: string;    // Optional (max 500 chars)
  createdAt: string;
  customerName: string;
}
