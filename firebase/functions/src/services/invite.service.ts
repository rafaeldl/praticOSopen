/**
 * Unified Invite Service
 * Manages collaborator invitations via app and WhatsApp
 */

import { v4 as uuidv4 } from 'uuid';
import {
  db,
} from './firestore.service';
import {
  RoleType,
  UserAggr,
  toDate,
} from '../models/types';
import * as companyService from './company.service';
import * as channelLinkService from './channel-link.service';

// Bot WhatsApp number (from environment or config)
const BOT_WHATSAPP_NUMBER = process.env.BOT_WHATSAPP_NUMBER || '+5548988794742';

// Token expiration time (7 days)
const INVITE_TOKEN_EXPIRATION = 7 * 24 * 60 * 60 * 1000;

// ============================================================================
// Types
// ============================================================================

export interface Invite {
  token: string;
  name?: string;
  email?: string;
  phone?: string;
  company: { id: string; name: string };
  role: RoleType;
  invitedBy: UserAggr;
  createdAt: string;
  expiresAt: string;
  status: 'pending' | 'accepted' | 'rejected' | 'cancelled';
  acceptedAt?: string;
  acceptedByUserId?: string;
  acceptedByUserName?: string;
  channel: 'app' | 'whatsapp';
}

export interface CreateInviteParams {
  name?: string;
  email?: string;
  phone?: string;
  companyId: string;
  companyName: string;
  role: RoleType;
  invitedBy: UserAggr;
  channel: 'app' | 'whatsapp';
}

export interface AcceptInviteResult {
  success: true;
  companyId: string;
  companyName: string;
  role: RoleType;
}

export interface AcceptInviteError {
  success: false;
  error: string;
}

// ============================================================================
// Token Generation
// ============================================================================

/**
 * Generate a unique invite token
 * Format: INV_ + 8 uppercase alphanumeric characters
 */
export function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = 'INV_';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Get reference to invites collection
 */
function getInvitesCollection() {
  return db.collection('links').doc('invites').collection('tokens');
}

// ============================================================================
// Invite Operations
// ============================================================================

/**
 * Create a new invite
 */
export async function createInvite(
  params: CreateInviteParams
): Promise<{ token: string; expiresAt: Date }> {
  // Validate: at least one of email or phone required
  if (!params.email && !params.phone) {
    throw new Error('At least one of email or phone is required');
  }

  // Generate unique token
  let token = generateToken();
  let attempts = 0;
  const maxAttempts = 10;

  // Ensure token is unique
  while (attempts < maxAttempts) {
    const existing = await getInvitesCollection().doc(token).get();
    if (!existing.exists) break;
    token = generateToken();
    attempts++;
  }

  if (attempts >= maxAttempts) {
    // Fallback to UUID-based token
    token = `INV_${uuidv4().substring(0, 8).toUpperCase()}`;
  }

  const expiresAt = new Date(Date.now() + INVITE_TOKEN_EXPIRATION);

  // Build invite data, excluding undefined values (Firestore doesn't accept undefined)
  const inviteData: Record<string, unknown> = {
    token,
    company: {
      id: params.companyId,
      name: params.companyName,
    },
    role: params.role,
    invitedBy: params.invitedBy,
    channel: params.channel,
    status: 'pending',
    createdAt: new Date().toISOString(),
    expiresAt: expiresAt.toISOString(),
  };

  // Only add optional fields if they have values
  if (params.name) inviteData.name = params.name;
  if (params.email) inviteData.email = params.email;
  if (params.phone) inviteData.phone = params.phone;

  await getInvitesCollection().doc(token).set(inviteData);

  return { token, expiresAt };
}

/**
 * Accept an invite
 */
export async function acceptInvite(
  token: string,
  userId: string,
  userName: string
): Promise<AcceptInviteResult | AcceptInviteError> {
  // Get invite
  const inviteDoc = await getInvitesCollection().doc(token).get();

  if (!inviteDoc.exists) {
    return { success: false, error: 'Invalid invite code' };
  }

  const invite = inviteDoc.data() as Invite;

  // Check status
  if (invite.status === 'accepted') {
    return { success: false, error: 'Invite has already been used' };
  }

  if (invite.status === 'cancelled') {
    return { success: false, error: 'Invite has been cancelled' };
  }

  if (invite.status === 'rejected') {
    return { success: false, error: 'Invite has been rejected' };
  }

  // Check if expired
  const expiresAt = toDate(invite.expiresAt);
  if (expiresAt && expiresAt < new Date()) {
    return { success: false, error: 'Invite has expired' };
  }

  // Add user to company
  await companyService.addMemberToCompany(
    invite.company.id,
    { id: userId, name: userName },
    invite.role
  );

  // Add company to user's companies array
  await addCompanyToUser(userId, invite.company, invite.role);

  // Mark invite as accepted
  await inviteDoc.ref.update({
    status: 'accepted',
    acceptedByUserId: userId,
    acceptedByUserName: userName,
    acceptedAt: new Date().toISOString(),
  });

  return {
    success: true,
    companyId: invite.company.id,
    companyName: invite.company.name,
    role: invite.role,
  };
}

/**
 * Get invite by token
 */
export async function getByToken(token: string): Promise<Invite | null> {
  const doc = await getInvitesCollection().doc(token).get();
  if (!doc.exists) return null;
  return doc.data() as Invite;
}

/**
 * List pending invites for a company
 */
export async function listByCompany(companyId: string): Promise<Invite[]> {
  const snapshot = await getInvitesCollection()
    .where('company.id', '==', companyId)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .limit(100)
    .get();

  return snapshot.docs.map((doc) => doc.data() as Invite);
}

/**
 * List pending invites for a user (by email or phone)
 */
export async function listByUser(email?: string, phone?: string): Promise<Invite[]> {
  if (!email && !phone) {
    return [];
  }

  const invites: Invite[] = [];
  const seenTokens = new Set<string>();

  // Query by email if provided
  if (email) {
    const emailSnapshot = await getInvitesCollection()
      .where('email', '==', email)
      .where('status', '==', 'pending')
      .get();

    emailSnapshot.docs.forEach((doc) => {
      const invite = doc.data() as Invite;
      if (!seenTokens.has(invite.token)) {
        // Check if not expired
        const expiresAt = toDate(invite.expiresAt);
        if (expiresAt && expiresAt > new Date()) {
          invites.push(invite);
          seenTokens.add(invite.token);
        }
      }
    });
  }

  // Query by phone if provided
  if (phone) {
    const phoneSnapshot = await getInvitesCollection()
      .where('phone', '==', phone)
      .where('status', '==', 'pending')
      .get();

    phoneSnapshot.docs.forEach((doc) => {
      const invite = doc.data() as Invite;
      if (!seenTokens.has(invite.token)) {
        // Check if not expired
        const expiresAt = toDate(invite.expiresAt);
        if (expiresAt && expiresAt > new Date()) {
          invites.push(invite);
          seenTokens.add(invite.token);
        }
      }
    });
  }

  // Sort by createdAt descending
  invites.sort((a, b) => {
    return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
  });

  return invites;
}

/**
 * List invites created by a specific user
 */
export async function listByInviter(userId: string): Promise<Invite[]> {
  const snapshot = await getInvitesCollection()
    .where('invitedBy.id', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  return snapshot.docs.map((doc) => doc.data() as Invite);
}

/**
 * Cancel an invite
 */
export async function cancelInvite(
  token: string,
  requestingUserId: string
): Promise<boolean> {
  const invite = await getByToken(token);

  if (!invite) {
    return false;
  }

  // Only the creator can cancel the invite
  if (invite.invitedBy.id !== requestingUserId) {
    return false;
  }

  // Cannot cancel accepted invites
  if (invite.status === 'accepted') {
    return false;
  }

  // Already cancelled
  if (invite.status === 'cancelled') {
    return true;
  }

  await getInvitesCollection().doc(token).update({
    status: 'cancelled',
  });

  return true;
}

/**
 * Reject an invite (user-initiated)
 */
export async function rejectInvite(token: string): Promise<boolean> {
  const invite = await getByToken(token);

  if (!invite) {
    return false;
  }

  // Can only reject pending invites
  if (invite.status !== 'pending') {
    return false;
  }

  await getInvitesCollection().doc(token).update({
    status: 'rejected',
  });

  return true;
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Add company to user's companies array
 * Also exported as addCompanyToUserDoc for bot service
 */
export async function addCompanyToUserDoc(
  userId: string,
  company: { id: string; name: string },
  role: RoleType
): Promise<void> {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const companies = userData?.companies || [];

  // Check if company already exists
  const existingIndex = companies.findIndex(
    (c: { company: { id: string } }) => c.company.id === company.id
  );

  if (existingIndex !== -1) {
    // Update role if already exists
    companies[existingIndex].role = role;
  } else {
    // Add new company
    companies.push({
      company: { id: company.id, name: company.name },
      role,
    });
  }

  await db.collection('users').doc(userId).update({ companies });
}

// Alias for internal use
const addCompanyToUser = addCompanyToUserDoc;

/**
 * Mark invite as accepted (for bot service)
 */
export async function markAsAccepted(
  token: string,
  userId: string,
  userName: string
): Promise<void> {
  await getInvitesCollection().doc(token).update({
    status: 'accepted',
    acceptedByUserId: userId,
    acceptedByUserName: userName,
    acceptedAt: new Date().toISOString(),
  });
}

/**
 * Check if user is already a member of a company
 */
export async function isUserMemberOfCompany(
  userId: string,
  companyId: string
): Promise<boolean> {
  const company = await companyService.getCompany(companyId);
  if (!company) return false;

  // Check if user is owner
  if (company.owner?.id === userId) return true;

  // Check if user is in users array
  const users = company.users || [];
  return users.some((u) => u.user.id === userId);
}

/**
 * List all invites for a company (including non-pending)
 */
export async function listAllByCompany(companyId: string): Promise<Invite[]> {
  const snapshot = await getInvitesCollection()
    .where('company.id', '==', companyId)
    .orderBy('createdAt', 'desc')
    .limit(100)
    .get();

  return snapshot.docs.map((doc) => doc.data() as Invite);
}

// ============================================================================
// Phone Lookup Functions
// ============================================================================

/**
 * Normalize a phone number to E.164 format
 */
function normalizePhone(number: string): string {
  let normalized = number.replace(/[^\d+]/g, '');
  if (!normalized.startsWith('+')) {
    normalized = '+' + normalized;
  }
  return normalized;
}

/**
 * Generate Brazilian phone variants (8 vs 9 digit mobile numbers).
 *
 * WhatsApp often stores BR mobiles with 8 digits (+55 48 8409-0709),
 * while the invite may have been saved with 9 digits (+55 48 98409-0709)
 * or vice-versa.
 *
 * Returns an array of unique E.164 variants to query against.
 */
function getBrazilianPhoneVariants(phone: string): string[] {
  const normalized = normalizePhone(phone);
  const variants = new Set<string>([normalized]);

  if (!normalized.startsWith('+55')) {
    return [normalized];
  }

  const digits = normalized.substring(3); // everything after +55

  if (digits.length === 11) {
    // 9-digit subscriber: +55 XX 9XXXXXXXX → also try without the leading 9
    const areaCode = digits.substring(0, 2);
    const subscriber = digits.substring(2);
    if (subscriber.startsWith('9') && subscriber.length === 9) {
      variants.add(`+55${areaCode}${subscriber.substring(1)}`);
    }
  } else if (digits.length === 10) {
    // 8-digit subscriber: +55 XX XXXXXXXX → also try with leading 9
    const areaCode = digits.substring(0, 2);
    const subscriber = digits.substring(2);
    const firstDigit = subscriber.charAt(0);
    if (['7', '8', '9'].includes(firstDigit)) {
      variants.add(`+55${areaCode}9${subscriber}`);
    }
  }

  return Array.from(variants);
}

/**
 * Find pending, non-expired invites by phone number.
 * Handles Brazilian 8/9-digit mobile variants automatically.
 */
export async function findPendingInvitesByPhone(phone: string): Promise<Invite[]> {
  const variants = getBrazilianPhoneVariants(phone);
  const invites: Invite[] = [];
  const seenTokens = new Set<string>();

  for (const variant of variants) {
    const snapshot = await getInvitesCollection()
      .where('phone', '==', variant)
      .where('status', '==', 'pending')
      .get();

    for (const doc of snapshot.docs) {
      const invite = doc.data() as Invite;
      if (seenTokens.has(invite.token)) continue;

      // Check expiration
      const expiresAt = toDate(invite.expiresAt);
      if (expiresAt && expiresAt < new Date()) continue;

      invites.push(invite);
      seenTokens.add(invite.token);
    }
  }

  // Sort by createdAt descending
  invites.sort((a, b) =>
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  return invites;
}

// ============================================================================
// WhatsApp Bot Functions
// ============================================================================

export interface AcceptInviteViaWhatsAppResult {
  success: true;
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  role: RoleType;
}

export interface AcceptInviteViaWhatsAppError {
  success: false;
  error: string;
}

/**
 * Accept an invite via WhatsApp
 * Handles WhatsApp-specific logic: user creation, WhatsApp linking
 */
export async function acceptInviteViaWhatsApp(
  inviteCode: string,
  whatsappNumber: string,
  name?: string
): Promise<AcceptInviteViaWhatsAppResult | AcceptInviteViaWhatsAppError> {
  // Normalize invite code (support both old INVITE_ and new INV_ formats)
  const normalizedCode = normalizeInviteCode(inviteCode);

  // Get invite
  const invite = await getByToken(normalizedCode);

  if (!invite) {
    return { success: false, error: 'Invalid invite code' };
  }

  // Check if already accepted
  if (invite.status === 'accepted') {
    return { success: false, error: 'Invite has already been used' };
  }

  if (invite.status === 'cancelled') {
    return { success: false, error: 'Invite has been cancelled' };
  }

  // Check if expired
  if (invite.expiresAt && new Date(invite.expiresAt) < new Date()) {
    return { success: false, error: 'Invite has expired' };
  }

  // Check if WhatsApp is already linked
  const existingLink = await channelLinkService.getWhatsAppLink(whatsappNumber);
  if (existingLink) {
    return { success: false, error: 'This WhatsApp number is already linked to another account' };
  }

  // Check if user exists by phone, or create new user
  let userId: string;
  let userName = name || invite.name || 'Usuário';

  const existingUser = await channelLinkService.getUserByPhone(whatsappNumber);
  if (existingUser) {
    userId = existingUser.id;
    userName = existingUser.name;
  } else {
    // Create new user
    userId = await channelLinkService.createUserFromWhatsApp(whatsappNumber, userName);
  }

  // Add user to company
  await companyService.addMemberToCompany(
    invite.company.id,
    { id: userId, name: userName },
    invite.role
  );

  // Link WhatsApp
  await channelLinkService.linkWhatsApp(
    whatsappNumber,
    userId,
    invite.company.id,
    invite.role,
    userName,
    invite.company.name
  );

  // Add company to user's companies array (for claims update)
  await addCompanyToUserDoc(userId, invite.company, invite.role);

  // Mark invite as accepted
  await markAsAccepted(normalizedCode, userId, userName);

  return {
    success: true,
    userId,
    userName,
    companyId: invite.company.id,
    companyName: invite.company.name,
    role: invite.role,
  };
}

/**
 * Create invite and return WhatsApp link
 */
export async function createInviteWithWhatsAppLink(
  params: CreateInviteParams
): Promise<{ code: string; link: string; expiresAt: Date }> {
  const result = await createInvite(params);

  return {
    code: result.token,
    link: generateWhatsAppInviteLink(result.token),
    expiresAt: result.expiresAt,
  };
}

/**
 * Generate WhatsApp invite link
 */
export function generateWhatsAppInviteLink(code: string): string {
  const cleanNumber = BOT_WHATSAPP_NUMBER.replace(/\D/g, '');
  const message = encodeURIComponent(code);
  return `https://wa.me/${cleanNumber}?text=${message}`;
}

/**
 * Normalize invite code to support both old and new formats
 * Old format: INVITE_XXXXXXXX
 * New format: INV_XXXXXXXX
 */
export function normalizeInviteCode(code: string): string {
  const upperCode = code.trim().toUpperCase();

  // Already in new format
  if (upperCode.startsWith('INV_')) {
    return upperCode;
  }

  // Old format - keep as is for backwards compatibility
  if (upperCode.startsWith('INVITE_')) {
    return upperCode;
  }

  // No prefix - assume new format
  return `INV_${upperCode}`;
}
