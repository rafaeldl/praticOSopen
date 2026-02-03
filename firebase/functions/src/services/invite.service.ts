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
 */
async function addCompanyToUser(
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
