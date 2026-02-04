/**
 * Auth Token Service
 * Handles login tokens for WhatsApp users who want to access the app
 */

import { db } from './firestore.service';

// Token expiration time (15 minutes for security)
const AUTH_TOKEN_EXPIRATION_MS = 15 * 60 * 1000;

// ============================================================================
// Types
// ============================================================================

export interface AuthToken {
  token: string;           // LT_XXXXXXXX (also document ID)
  userId: string;
  companyId: string;
  createdAt: string;       // ISO string
  expiresAt: string;       // ISO string
  used: boolean;
  usedAt?: string;         // ISO string
}

export interface ValidateTokenResult {
  valid: boolean;
  userId?: string;
  companyId?: string;
  error?: string;
}

// ============================================================================
// Token Generation
// ============================================================================

/**
 * Generate a unique login token
 * Format: LT_ + 8 uppercase alphanumeric characters
 */
export function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = 'LT_';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Get reference to auth tokens collection
 */
function getAuthTokensCollection() {
  return db.collection('links').doc('auth').collection('tokens');
}

// ============================================================================
// Token Operations
// ============================================================================

/**
 * Create a login token for a user
 * @param userId - The user ID to create the token for
 * @param companyId - The company ID associated with the token
 * @returns The generated token and its expiration date
 */
export async function generateLoginToken(
  userId: string,
  companyId: string
): Promise<{ token: string; expiresAt: Date }> {
  // Validate required parameters
  if (!userId) {
    throw new Error('userId is required');
  }
  if (!companyId) {
    throw new Error('companyId is required');
  }

  // Generate unique token
  let token = generateToken();
  let attempts = 0;
  const maxAttempts = 10;

  // Ensure token is unique
  while (attempts < maxAttempts) {
    const existing = await getAuthTokensCollection().doc(token).get();
    if (!existing.exists) break;
    token = generateToken();
    attempts++;
  }

  if (attempts >= maxAttempts) {
    // Fallback to timestamp-based token for uniqueness
    const timestamp = Date.now().toString(36).toUpperCase();
    token = `LT_${timestamp.slice(-8)}`;
  }

  const now = new Date();
  const expiresAt = new Date(now.getTime() + AUTH_TOKEN_EXPIRATION_MS);

  const authToken: AuthToken = {
    token,
    userId,
    companyId,
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    used: false,
  };

  await getAuthTokensCollection().doc(token).set(authToken);

  return { token, expiresAt };
}

/**
 * Validate and consume a token (mark as used)
 * One-time use: token cannot be used again after successful validation
 * @param token - The token to validate
 * @returns Validation result with user and company info if valid
 */
export async function validateAndConsume(token: string): Promise<ValidateTokenResult> {
  // Validate token format
  if (!token || !token.startsWith('LT_')) {
    return { valid: false, error: 'Invalid token format' };
  }

  const tokenDoc = await getAuthTokensCollection().doc(token).get();

  if (!tokenDoc.exists) {
    return { valid: false, error: 'Token not found' };
  }

  const authToken = tokenDoc.data() as AuthToken;

  // Check if already used
  if (authToken.used) {
    return { valid: false, error: 'Token has already been used' };
  }

  // Check if expired
  const expiresAt = new Date(authToken.expiresAt);
  if (expiresAt < new Date()) {
    return { valid: false, error: 'Token has expired' };
  }

  // Mark token as used (don't delete for audit trail)
  await tokenDoc.ref.update({
    used: true,
    usedAt: new Date().toISOString(),
  });

  return {
    valid: true,
    userId: authToken.userId,
    companyId: authToken.companyId,
  };
}

/**
 * Get token info without consuming
 * @param token - The token to look up
 * @returns The AuthToken if found, null otherwise
 */
export async function getToken(token: string): Promise<AuthToken | null> {
  if (!token) {
    return null;
  }

  const doc = await getAuthTokensCollection().doc(token).get();

  if (!doc.exists) {
    return null;
  }

  return doc.data() as AuthToken;
}
