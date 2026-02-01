/**
 * Share Token Service
 * Manages magic link tokens for customer order tracking
 */

import { v4 as uuidv4 } from 'uuid';
import { db } from './firestore.service';
import { ShareToken, ShareTokenPermission, CustomerAggr, UserAggr } from '../models/types';

// Collection path for share tokens
const SHARE_TOKENS_COLLECTION = 'links/share/tokens';

/**
 * Generate a new share token for an order
 */
export async function generateShareToken(
  orderId: string,
  companyId: string,
  customer: CustomerAggr,
  permissions: ShareTokenPermission[],
  createdBy: UserAggr,
  expiresInDays = 7
): Promise<ShareToken> {
  const token = `ST_${uuidv4()}`;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + expiresInDays * 24 * 60 * 60 * 1000);

  const shareToken: ShareToken = {
    token,
    orderId,
    companyId,
    permissions,
    customer,
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    createdBy,
    viewCount: 0,
  };

  await db.collection(SHARE_TOKENS_COLLECTION).doc(token).set(shareToken);

  return shareToken;
}

/**
 * Validate a share token
 * Returns the token if valid, null if invalid or expired
 */
export async function validateShareToken(token: string): Promise<ShareToken | null> {
  if (!token || !token.startsWith('ST_')) {
    return null;
  }

  const doc = await db.collection(SHARE_TOKENS_COLLECTION).doc(token).get();

  if (!doc.exists) {
    return null;
  }

  const shareToken = doc.data() as ShareToken;

  // Check expiration
  const expiresAt = new Date(shareToken.expiresAt);
  if (expiresAt < new Date()) {
    return null;
  }

  return shareToken;
}

/**
 * Get share token by token string
 */
export async function getShareToken(token: string): Promise<ShareToken | null> {
  if (!token) {
    return null;
  }

  const doc = await db.collection(SHARE_TOKENS_COLLECTION).doc(token).get();

  if (!doc.exists) {
    return null;
  }

  return doc.data() as ShareToken;
}

/**
 * Increment view count for a token
 */
export async function incrementViewCount(token: string): Promise<void> {
  const tokenRef = db.collection(SHARE_TOKENS_COLLECTION).doc(token);

  await tokenRef.update({
    viewCount: (await tokenRef.get()).data()?.viewCount + 1 || 1,
    lastViewedAt: new Date().toISOString(),
  });
}

/**
 * Mark token as approved
 */
export async function markTokenApproved(token: string): Promise<void> {
  await db.collection(SHARE_TOKENS_COLLECTION).doc(token).update({
    approvedAt: new Date().toISOString(),
  });
}

/**
 * Mark token as rejected
 */
export async function markTokenRejected(token: string, reason?: string): Promise<void> {
  await db.collection(SHARE_TOKENS_COLLECTION).doc(token).update({
    rejectedAt: new Date().toISOString(),
    rejectionReason: reason || null,
  });
}

/**
 * Get all tokens for an order
 */
export async function getTokensForOrder(orderId: string, companyId: string): Promise<ShareToken[]> {
  const snapshot = await db
    .collection(SHARE_TOKENS_COLLECTION)
    .where('orderId', '==', orderId)
    .where('companyId', '==', companyId)
    .orderBy('createdAt', 'desc')
    .get();

  return snapshot.docs.map((doc) => doc.data() as ShareToken);
}

/**
 * Revoke (delete) a share token
 */
export async function revokeShareToken(token: string): Promise<void> {
  await db.collection(SHARE_TOKENS_COLLECTION).doc(token).delete();
}

/**
 * Check if token has a specific permission
 */
export function hasPermission(token: ShareToken, permission: ShareTokenPermission): boolean {
  return token.permissions.includes(permission);
}
