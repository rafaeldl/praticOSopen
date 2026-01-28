/**
 * Channel Link Service
 * Manages linking/unlinking messaging channels (WhatsApp, Telegram, etc.)
 */

import { v4 as uuidv4 } from 'uuid';
import * as admin from 'firebase-admin';
import {
  db,
  auth,
} from './firestore.service';
import {
  ChannelLink,
  LinkToken,
  RoleType,
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
  const expiresAt = new Date(Date.now() + LINK_TOKEN_EXPIRATION);

  const tokenData: LinkToken = {
    token,
    userId,
    companyId,
    role,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    used: false,
    userName,
    companyName,
  };

  await db.collection('linkTokens').doc(token).set(tokenData);

  return token;
}

/**
 * Validate and consume a link token
 */
export async function consumeLinkToken(token: string): Promise<LinkToken | null> {
  const tokenDoc = await db.collection('linkTokens').doc(token).get();

  if (!tokenDoc.exists) return null;

  const tokenData = tokenDoc.data() as LinkToken;

  // Check if already used
  if (tokenData.used) return null;

  // Check if expired
  if (tokenData.expiresAt.toDate() < new Date()) return null;

  // Mark as used
  await tokenDoc.ref.update({ used: true });

  return tokenData;
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
 * Generate wa.me link with token
 */
export function generateWhatsAppLink(botNumber: string, token: string): string {
  const cleanNumber = botNumber.replace(/\D/g, '');
  const message = encodeURIComponent(`Vincular: ${token}`);
  return `https://wa.me/${cleanNumber}?text=${message}`;
}
