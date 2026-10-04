/**
 * Company Service
 * Business logic for company and member operations
 */

import {
  db,
  FieldValue,
  getRootCollection,
  getDocument,
  updateDocument,
} from './firestore.service';
import { memberRole, ownerId, privateMembershipRef } from './membership.service';
import {
  Company,
  CompanyAggr,
  UserAggr,
  RoleType,
} from '../models/types';
import { CompanyMember } from '../models/api-response.types';

// ============================================================================
// Company Operations
// ============================================================================

/**
 * Get company by ID
 */
export async function getCompany(companyId: string): Promise<Company | null> {
  const collection = getRootCollection('companies');
  return getDocument<Company>(collection, companyId);
}

export interface UpdateCompanyInput {
  name?: string;
  phone?: string;
  email?: string;
  address?: string;
  logo?: string;
}

/**
 * Update company details
 */
export async function updateCompany(
  companyId: string,
  input: UpdateCompanyInput,
  updatedBy: UserAggr
): Promise<boolean> {
  const collection = getRootCollection('companies');

  // Check if company exists
  const existing = await getDocument<Company>(collection, companyId);
  if (!existing) return false;

  const updateData: Record<string, unknown> = {
    updatedBy,
    updatedAt: new Date().toISOString(),
  };

  if (input.name !== undefined) updateData.name = input.name;
  if (input.phone !== undefined) updateData.phone = input.phone;
  if (input.email !== undefined) updateData.email = input.email;
  if (input.address !== undefined) updateData.address = input.address;
  if (input.logo !== undefined) updateData.logo = input.logo;

  await updateDocument(collection, companyId, updateData);
  return true;
}

// ============================================================================
// Member Operations
// ============================================================================

/**
 * List company members with their linked channels
 */
export async function listCompanyMembers(companyId: string): Promise<CompanyMember[]> {
  // Get company to access users array
  const company = await getCompany(companyId);
  if (!company || !company.users) return [];

  const members: CompanyMember[] = [];

  for (const userRole of company.users) {
    // Get linked channels for this user
    const linkedChannels = await getLinkedChannels(userRole.user.id);

    members.push({
      userId: userRole.user.id,
      name: userRole.user.name,
      email: userRole.user.email,
      role: userRole.role,
      linkedChannels,
    });
  }

  // Also add owner
  if (company.owner) {
    const ownerLinkedChannels = await getLinkedChannels(company.owner.id);
    members.unshift({
      userId: company.owner.id,
      name: company.owner.name,
      email: company.owner.email,
      role: 'owner',
      linkedChannels: ownerLinkedChannels,
    });
  }

  return members;
}

type MemberEntry = { user: UserAggr; role: RoleType };

/**
 * Queues, inside a transaction, the writes that register `user` as a member of
 * `companyId` with `role`: server-only member map (source of truth), display
 * `users` array and display `memberships` document. `companyData` must have been
 * read in the same transaction.
 */
export function writeMemberAdd(
  tx: FirebaseFirestore.Transaction,
  companyId: string,
  companyData: { users?: MemberEntry[] } | undefined,
  user: UserAggr,
  role: RoleType
): void {
  const users: MemberEntry[] = Array.isArray(companyData?.users) ? [...companyData!.users] : [];
  const existingIndex = users.findIndex((u) => u?.user?.id === user.id);
  if (existingIndex !== -1) {
    users[existingIndex] = { ...users[existingIndex], role };
  } else {
    users.push({ user, role });
  }

  tx.set(
    privateMembershipRef(companyId),
    { members: { [user.id]: role }, updatedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  tx.update(db.collection('companies').doc(companyId), {
    users,
    updatedAt: new Date().toISOString(),
  });
  tx.set(
    getMembershipRef(companyId, user.id),
    { user, role, joinedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
}

/**
 * Update member role
 */
export async function updateMemberRole(
  companyId: string,
  targetUserId: string,
  newRole: RoleType,
  updatedBy: UserAggr
): Promise<boolean> {
  const companyRef = db.collection('companies').doc(companyId);
  const privateRef = privateMembershipRef(companyId);
  const membershipRef = getMembershipRef(companyId, targetUserId);

  const updated = await db.runTransaction(async (tx) => {
    const companySnap = await tx.get(companyRef);
    if (!companySnap.exists) return false;
    const company = companySnap.data() as Company;

    // Cannot change owner's role
    if (ownerId(company.owner) === targetUserId) {
      throw new Error('Cannot change owner role');
    }

    const privateSnap = await tx.get(privateRef);
    const membershipSnap = await tx.get(membershipRef);

    const users = Array.isArray(company.users) ? [...company.users] : [];
    const userIndex = users.findIndex((u) => u?.user?.id === targetUserId);
    const inPrivate = memberRole(privateSnap.data(), targetUserId) !== null;

    if (userIndex === -1 && !inPrivate) return false;

    tx.set(
      privateRef,
      { members: { [targetUserId]: newRole }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    if (userIndex !== -1) {
      users[userIndex] = { ...users[userIndex], role: newRole };
    }
    tx.update(companyRef, { users, updatedBy, updatedAt: new Date().toISOString() });
    if (membershipSnap.exists) {
      tx.update(membershipRef, { role: newRole });
    }
    return true;
  });

  if (!updated) return false;

  // Also update in user's companies array
  await updateUserCompanyRole(targetUserId, companyId, newRole);

  // Update any linked channels
  await updateLinkedChannelRole(targetUserId, companyId, newRole);

  return true;
}

/**
 * Remove member from company
 */
export async function removeMember(
  companyId: string,
  targetUserId: string,
  removedBy: UserAggr
): Promise<boolean> {
  const companyRef = db.collection('companies').doc(companyId);

  const removed = await db.runTransaction(async (tx) => {
    const companySnap = await tx.get(companyRef);
    if (!companySnap.exists) return false;
    const company = companySnap.data() as Company;

    // Cannot remove owner
    if (ownerId(company.owner) === targetUserId) {
      throw new Error('Cannot remove owner');
    }

    const users = (company.users || []).filter((u) => u?.user?.id !== targetUserId);

    tx.set(
      privateMembershipRef(companyId),
      { members: { [targetUserId]: FieldValue.delete() }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    tx.update(companyRef, { users, updatedBy: removedBy, updatedAt: new Date().toISOString() });
    tx.delete(getMembershipRef(companyId, targetUserId));
    return true;
  });

  if (!removed) return false;

  // Remove from user's companies array
  await removeUserFromCompany(targetUserId, companyId);

  // Remove linked channels for this company
  await unlinkUserChannels(targetUserId, companyId);

  return true;
}

/**
 * Add member to company (server-side flows). Writes the server-only member
 * map, the display `users` array and the display membership document.
 */
export async function addMemberToCompany(
  companyId: string,
  user: UserAggr,
  role: RoleType
): Promise<void> {
  const companyRef = db.collection('companies').doc(companyId);
  await db.runTransaction(async (tx) => {
    const companySnap = await tx.get(companyRef);
    if (!companySnap.exists) throw new Error('Company not found');
    writeMemberAdd(tx, companyId, companySnap.data() as Company, user, role);
  });
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Reference to companies/{companyId}/memberships/{userId} (display index)
 */
export function getMembershipRef(companyId: string, userId: string) {
  return db.collection('companies').doc(companyId).collection('memberships').doc(userId);
}

/**
 * Get linked channels for a user
 */
async function getLinkedChannels(userId: string): Promise<string[]> {
  const channels: string[] = [];

  // Check WhatsApp links
  const whatsappSnapshot = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .where('userId', '==', userId)
    .limit(1)
    .get();

  if (!whatsappSnapshot.empty) {
    channels.push('whatsapp');
  }

  // Future: Check other channels (telegram, discord, etc.)

  return channels;
}

/**
 * Update user's role in their companies array
 */
async function updateUserCompanyRole(
  userId: string,
  companyId: string,
  newRole: RoleType
): Promise<void> {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const companies = userData?.companies || [];

  const companyIndex = companies.findIndex(
    (c: { company: CompanyAggr }) => c.company.id === companyId
  );

  if (companyIndex !== -1) {
    companies[companyIndex].role = newRole;
    await db.collection('users').doc(userId).update({ companies });
  }
}

/**
 * Remove company from user's companies array
 */
async function removeUserFromCompany(
  userId: string,
  companyId: string
): Promise<void> {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const companies = (userData?.companies || []).filter(
    (c: { company: CompanyAggr }) => c.company.id !== companyId
  );

  await db.collection('users').doc(userId).update({ companies });
}

/**
 * Update role in linked channels
 */
async function updateLinkedChannelRole(
  userId: string,
  companyId: string,
  newRole: RoleType
): Promise<void> {
  // Update WhatsApp links
  const whatsappSnapshot = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .where('userId', '==', userId)
    .where('companyId', '==', companyId)
    .get();

  const batch = db.batch();
  whatsappSnapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { role: newRole });
  });
  await batch.commit();
}

/**
 * Unlink user's channels for a specific company
 */
async function unlinkUserChannels(
  userId: string,
  companyId: string
): Promise<void> {
  // Delete WhatsApp links for this company
  const whatsappSnapshot = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .where('userId', '==', userId)
    .where('companyId', '==', companyId)
    .get();

  const batch = db.batch();
  whatsappSnapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();
}

/**
 * Convert Company to CompanyAggr
 */
export function toCompanyAggr(company: Company): CompanyAggr {
  return {
    id: company.id,
    name: company.name,
    country: company.country,
  };
}
