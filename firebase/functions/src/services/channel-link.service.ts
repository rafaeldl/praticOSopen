/**
 * Channel Link Service
 * Manages linking/unlinking messaging channels (WhatsApp, Telegram, etc.)
 */

import { v4 as uuidv4 } from 'uuid';
import {
  db,
  auth,
} from './firestore.service';
import {
  ChannelLink,
  LinkToken,
  RoleType,
  toDate,
} from '../models/types';

// Use Date directly - Firestore SDK will convert it to Timestamp
const nowTimestamp = () => new Date();

// Token expiration times (in milliseconds)
const LINK_TOKEN_EXPIRATION = 15 * 60 * 1000; // 15 minutes

// ============================================================================
// Link Token Operations (Flow A - Magic Link)
// ============================================================================

/**
 * Generate a link token for a user
 */
export async function generateLinkToken(
  userId: string,
  companyId: string,
  role: RoleType,
  userName?: string,
  companyName?: string
): Promise<string> {
  const token = `LT_${uuidv4().replace(/-/g, '')}`;
  const expiresAt = new Date(Date.now() + LINK_TOKEN_EXPIRATION).toISOString();

  const tokenData: LinkToken = {
    token,
    userId,
    companyId,
    role,
    expiresAt,
    used: false,
    userName,
    companyName,
  };

  await db.collection('links').doc('tokens').collection('pending').doc(token).set(tokenData);

  return token;
}

/**
 * Validate and consume a link token
 * Uses a transaction to prevent race conditions
 */
export async function consumeLinkToken(token: string): Promise<LinkToken | null> {
  console.log(`[LINK] Consuming token: ${token}`);

  const tokenRef = db.collection('links').doc('tokens').collection('pending').doc(token);

  try {
    return await db.runTransaction(async (transaction) => {
      const tokenDoc = await transaction.get(tokenRef);

      if (!tokenDoc.exists) {
        console.log(`[LINK] Token NOT FOUND: ${token}`);
        return null;
      }

      const tokenData = tokenDoc.data() as LinkToken;

      // Check if already used
      if (tokenData.used) {
        console.log(`[LINK] Token already used: ${token}`);
        return null;
      }

      // Check if expired
      const expiresAt = toDate(tokenData.expiresAt);
      if (expiresAt && expiresAt < new Date()) {
        console.log(`[LINK] Token expired: ${token}, expiresAt: ${expiresAt?.toISOString()}`);
        return null;
      }

      // Mark as used within the transaction
      transaction.update(tokenRef, { used: true });
      console.log(`[LINK] Token consumed successfully for user: ${tokenData.userId}, company: ${tokenData.companyId}`);
      return tokenData;
    });
  } catch (error) {
    console.error(`[LINK] Error consuming token ${token}:`, error);
    return null;
  }
}

// ============================================================================
// WhatsApp Link Operations
// ============================================================================

/**
 * Get WhatsApp link for a number
 */
export async function getWhatsAppLink(number: string): Promise<ChannelLink | null> {
  const normalizedNumber = normalizeWhatsAppNumber(number);
  const doc = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .doc(normalizedNumber)
    .get();

  if (!doc.exists) return null;
  return doc.data() as ChannelLink;
}

/**
 * Link WhatsApp number to user
 * - Creates link document in /links/whatsapp/numbers/
 * - Updates user doc with whatsappPhone
 * - Adds phone to Firebase Auth (for SMS login)
 */
export async function linkWhatsApp(
  whatsappNumber: string,
  userId: string,
  companyId: string,
  role: RoleType,
  userName?: string,
  companyName?: string
): Promise<void> {
  const normalizedNumber = normalizeWhatsAppNumber(whatsappNumber);
  const authPhone = normalizeBrazilianPhoneForAuth(whatsappNumber);

  // 1. Create link document
  const linkData: ChannelLink = {
    channel: 'whatsapp',
    identifier: normalizedNumber,
    userId,
    companyId,
    role,
    linkedAt: nowTimestamp(),
    userName,
    companyName,
  };

  await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .doc(normalizedNumber)
    .set(linkData);

  // 2. Update user doc with WhatsApp phone
  const userUpdateData: Record<string, string> = {
    whatsappPhone: normalizedNumber, // 13 chars (WhatsApp format)
  };
  // Also store Auth phone if different
  if (authPhone !== normalizedNumber) {
    userUpdateData.phone = authPhone; // 14 chars (real format)
  }

  await db.collection('users').doc(userId).set(userUpdateData, { merge: true });

  // 3. Add phone to Firebase Auth (for SMS login)
  try {
    const userRecord = await auth.getUser(userId);

    // Only update if user doesn't have a phone or has a different one
    if (!userRecord.phoneNumber || userRecord.phoneNumber !== authPhone) {
      await auth.updateUser(userId, {
        phoneNumber: authPhone,
      });
      console.log(`[LINK] Added phone ${authPhone} to Auth user ${userId}`);
    }
  } catch (error) {
    // Non-fatal: user can still use WhatsApp, just won't have SMS login
    console.warn(`[LINK] Could not update Auth phone for user ${userId}:`, error);
  }
}

/**
 * Unlink WhatsApp number
 */
export async function unlinkWhatsApp(whatsappNumber: string): Promise<boolean> {
  const normalizedNumber = normalizeWhatsAppNumber(whatsappNumber);
  const docRef = db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .doc(normalizedNumber);

  const doc = await docRef.get();
  if (!doc.exists) return false;

  await docRef.delete();
  return true;
}

/**
 * Check if WhatsApp number is linked
 */
export async function isWhatsAppLinked(whatsappNumber: string): Promise<boolean> {
  const link = await getWhatsAppLink(whatsappNumber);
  return link !== null;
}

/**
 * Get all links for a user
 */
export async function getUserLinks(userId: string): Promise<ChannelLink[]> {
  const links: ChannelLink[] = [];

  // Check WhatsApp links
  const whatsappSnapshot = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .where('userId', '==', userId)
    .get();

  whatsappSnapshot.docs.forEach((doc) => {
    links.push(doc.data() as ChannelLink);
  });

  // Future: Check other channels

  return links;
}

// ============================================================================
// User Creation (for new users via invite)
// ============================================================================

/**
 * Create a new Firebase Auth user for a WhatsApp-only user
 */
export async function createUserFromWhatsApp(
  whatsappNumber: string,
  name: string
): Promise<string> {
  const normalizedNumber = normalizeWhatsAppNumber(whatsappNumber);

  // Create user in Firebase Auth
  const userRecord = await auth.createUser({
    phoneNumber: normalizedNumber,
    displayName: name,
  });

  // Create user document in Firestore
  await db.collection('users').doc(userRecord.uid).set({
    id: userRecord.uid,
    name,
    phone: normalizedNumber,
    createdAt: nowTimestamp(),
    createdVia: 'whatsapp_invite',
  });

  return userRecord.uid;
}

/**
 * Get user by phone number
 */
export async function getUserByPhone(phone: string): Promise<{ id: string; name: string } | null> {
  const normalizedPhone = normalizeWhatsAppNumber(phone);

  try {
    // Try Firebase Auth first
    const userRecord = await auth.getUserByPhoneNumber(normalizedPhone);
    return {
      id: userRecord.uid,
      name: userRecord.displayName || 'User',
    };
  } catch {
    // User not found in Auth, check Firestore
    const snapshot = await db
      .collection('users')
      .where('phone', '==', normalizedPhone)
      .limit(1)
      .get();

    if (snapshot.empty) return null;

    const userData = snapshot.docs[0].data();
    return {
      id: snapshot.docs[0].id,
      name: userData.name || 'User',
    };
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Normalize WhatsApp number to E.164 format
 */
function normalizeWhatsAppNumber(number: string): string {
  // Remove all non-digit characters except leading +
  let normalized = number.replace(/[^\d+]/g, '');

  // Ensure it starts with +
  if (!normalized.startsWith('+')) {
    normalized = '+' + normalized;
  }

  return normalized;
}

/**
 * Normalize Brazilian phone number for Firebase Auth
 *
 * WhatsApp uses old 8-digit format for Brazilian mobiles.
 * Real format has 9 digits (starting with 9).
 *
 * Example:
 * - WhatsApp: +554884090709 (13 chars) → +55 48 84090709 (8 digits)
 * - Auth:     +5548984090709 (14 chars) → +55 48 984090709 (9 digits)
 */
function normalizeBrazilianPhoneForAuth(phone: string): string {
  const normalized = normalizeWhatsAppNumber(phone);

  // Check if Brazilian number: +55 + 10 digits = 13 chars total
  if (!normalized.startsWith('+55') || normalized.length !== 13) {
    return normalized;
  }

  // Extract parts: +55 (3) + area code (2) + subscriber (8)
  const areaCode = normalized.substring(3, 5);
  const subscriber = normalized.substring(5);

  // Check if subscriber starts with 7, 8, or 9 (mobile indicators)
  const firstDigit = subscriber.charAt(0);
  if (['7', '8', '9'].includes(firstDigit)) {
    // Insert "9" after area code: +55 + area + 9 + subscriber
    return `+55${areaCode}9${subscriber}`;
  }

  return normalized;
}

/**
 * Generate wa.me link with token
 */
export function generateWhatsAppLink(botNumber: string, token: string): string {
  const cleanNumber = botNumber.replace(/\D/g, '');
  const message = encodeURIComponent(`Vincular: ${token}`);
  return `https://wa.me/${cleanNumber}?text=${message}`;
}
