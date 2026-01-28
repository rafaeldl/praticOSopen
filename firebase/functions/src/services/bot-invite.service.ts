/**
 * Bot Invite Service
 * Manages collaborator invitations via WhatsApp
 */

import { v4 as uuidv4 } from 'uuid';
import {
  db,
  Timestamp,
} from './firestore.service';
import {
  InviteCode,
  RoleType,
} from '../models/types';
import * as channelLinkService from './channel-link.service';
import * as companyService from './company.service';

// Token expiration time (24 hours)
const INVITE_TOKEN_EXPIRATION = 24 * 60 * 60 * 1000;

// Bot WhatsApp number (from environment or config)
const BOT_WHATSAPP_NUMBER = process.env.BOT_WHATSAPP_NUMBER || '+5511999999999';

// ============================================================================
// Invite Operations
// ============================================================================

/**
 * Create a new invite code
 */
export async function createInvite(
  companyId: string,
  companyName: string,
  invitedByUserId: string,
  invitedByName: string,
  collaboratorName: string,
  role: RoleType
): Promise<{ code: string; link: string; expiresAt: Date }> {
  // Generate unique invite code
  const code = `INVITE_${uuidv4().substring(0, 8).toUpperCase()}`;
  const expiresAt = new Date(Date.now() + INVITE_TOKEN_EXPIRATION);

  const inviteData: InviteCode = {
    code,
    companyId,
    companyName,
    invitedByUserId,
    invitedByName,
    collaboratorName,
    role,
    expiresAt: Timestamp.fromDate(expiresAt),
    accepted: false,
    createdAt: Timestamp.now(),
  };

  await db.collection('inviteCodes').doc(code).set(inviteData);

  // Generate WhatsApp link
  const link = generateInviteLink(code);

  return { code, link, expiresAt };
}

/**
 * Accept an invite
 */
export async function acceptInvite(
  inviteCode: string,
  whatsappNumber: string,
  name?: string
): Promise<{
  success: boolean;
  userId: string;
  userName: string;
  companyId: string;
  companyName: string;
  role: RoleType;
} | { success: false; error: string }> {
  // Get invite
  const inviteDoc = await db.collection('inviteCodes').doc(inviteCode).get();

  if (!inviteDoc.exists) {
    return { success: false, error: 'Invalid invite code' };
  }

  const invite = inviteDoc.data() as InviteCode;

  // Check if already accepted
  if (invite.accepted) {
    return { success: false, error: 'Invite has already been used' };
  }

  // Check if expired
  if (invite.expiresAt.toDate() < new Date()) {
    return { success: false, error: 'Invite has expired' };
  }

  // Check if WhatsApp is already linked
  const existingLink = await channelLinkService.getWhatsAppLink(whatsappNumber);
  if (existingLink) {
    return { success: false, error: 'This WhatsApp number is already linked to another account' };
  }

  // Check if user exists by phone, or create new user
  let userId: string;
  let userName = name || invite.collaboratorName;

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
    invite.companyId,
    { id: userId, name: userName },
    invite.role
  );

  // Link WhatsApp
  await channelLinkService.linkWhatsApp(
    whatsappNumber,
    userId,
    invite.companyId,
    invite.role,
    userName,
    invite.companyName
  );

  // Mark invite as accepted
  await inviteDoc.ref.update({
    accepted: true,
    acceptedByUserId: userId,
    acceptedAt: Timestamp.now(),
  });

  return {
    success: true,
    userId,
    userName,
    companyId: invite.companyId,
    companyName: invite.companyName,
    role: invite.role,
  };
}

/**
 * Get invite by code
 */
export async function getInvite(code: string): Promise<InviteCode | null> {
  const doc = await db.collection('inviteCodes').doc(code).get();
  if (!doc.exists) return null;
  return doc.data() as InviteCode;
}

/**
 * List invites for a company
 */
export async function listInvites(companyId: string): Promise<InviteCode[]> {
  const snapshot = await db
    .collection('inviteCodes')
    .where('companyId', '==', companyId)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  return snapshot.docs.map((doc) => doc.data() as InviteCode);
}

/**
 * List invites created by a user
 */
export async function listInvitesByUser(userId: string): Promise<InviteCode[]> {
  const snapshot = await db
    .collection('inviteCodes')
    .where('invitedByUserId', '==', userId)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  return snapshot.docs.map((doc) => doc.data() as InviteCode);
}

/**
 * Delete/revoke an invite
 */
export async function deleteInvite(code: string, requestingUserId: string): Promise<boolean> {
  const invite = await getInvite(code);

  if (!invite) return false;

  // Only the creator can delete the invite
  if (invite.invitedByUserId !== requestingUserId) {
    return false;
  }

  // Cannot delete accepted invites
  if (invite.accepted) {
    return false;
  }

  await db.collection('inviteCodes').doc(code).delete();
  return true;
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Generate WhatsApp invite link
 */
function generateInviteLink(code: string): string {
  const cleanNumber = BOT_WHATSAPP_NUMBER.replace(/\D/g, '');
  const message = encodeURIComponent(code);
  return `https://wa.me/${cleanNumber}?text=${message}`;
}
