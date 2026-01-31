/**
 * API Response Types
 * Standard response formats for the API
 */

// ============================================================================
// Base Response Types
// ============================================================================

export interface ApiError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: ApiError;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    total: number;
    limit: number;
    offset: number;
    hasMore: boolean;
  };
}

// ============================================================================
// Auth Responses
// ============================================================================

export interface TokenResponse {
  accessToken: string;
  expiresIn: number;
  companyId: string;
}

export interface VerifyResponse {
  companyId: string;
  permissions: string[];
  expiresAt: string;
}

// ============================================================================
// Entity Responses
// ============================================================================

export interface CreateResponse {
  id: string;
  [key: string]: unknown;
}

export interface UpdateResponse {
  id: string;
  updated: boolean;
}

export interface DeleteResponse {
  success: boolean;
  message?: string;
}

// ============================================================================
// Order Responses
// ============================================================================

export interface OrderCreateResponse {
  id: string;
  number: number;
  status: string;
}

export interface AddItemResponse {
  success: boolean;
  newTotal: number;
}

export interface PaymentResponse {
  transactionId: string;
  paidAmount: number;
  remainingBalance: number;
  isFullyPaid: boolean;
}

// ============================================================================
// Bot Responses
// ============================================================================

export interface LinkResponse {
  success: boolean;
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  role: string;
}

export interface ContextResponse {
  linked: boolean;
  userId?: string;
  userName?: string;
  companyId?: string;
  companyName?: string;
  role?: string;
  permissions?: string[];
}

export interface InviteCreateResponse {
  inviteCode: string;
  inviteLink: string;
  expiresAt: string;
}

export interface InviteAcceptResponse {
  success: boolean;
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  role: string;
}

export interface SearchResponse<T> {
  exact?: T;
  suggestions: T[];
}

export interface QuickOrderResponse {
  orderId: string;
  orderNumber: number;
  status: string;
  customerCreated: boolean;
  deviceCreated: boolean;
}

export interface VCardResponse {
  vcard: string;
  displayName: string;
}

export interface SummaryResponse {
  message: string;
  data: Record<string, unknown>;
}

// ============================================================================
// Company Responses
// ============================================================================

export interface CompanyMember {
  userId: string;
  name: string;
  email?: string;
  phone?: string;
  role: string;
  linkedChannels: string[];
}

export interface CompanyMembersResponse {
  members: CompanyMember[];
}

// ============================================================================
// Error Codes
// ============================================================================

export const ErrorCodes = {
  // Authentication
  UNAUTHORIZED: 'UNAUTHORIZED',
  INVALID_API_KEY: 'INVALID_API_KEY',
  INVALID_TOKEN: 'INVALID_TOKEN',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  NOT_LINKED: 'NOT_LINKED',
  ALREADY_LINKED: 'ALREADY_LINKED',

  // Authorization
  FORBIDDEN: 'FORBIDDEN',
  INSUFFICIENT_PERMISSIONS: 'INSUFFICIENT_PERMISSIONS',

  // Validation
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INVALID_INPUT: 'INVALID_INPUT',
  MISSING_REQUIRED_FIELD: 'MISSING_REQUIRED_FIELD',

  // Resources
  NOT_FOUND: 'NOT_FOUND',
  ALREADY_EXISTS: 'ALREADY_EXISTS',
  CONFLICT: 'CONFLICT',

  // Rate Limiting
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',

  // Server
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
} as const;

export type ErrorCode = typeof ErrorCodes[keyof typeof ErrorCodes];
