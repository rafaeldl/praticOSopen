/**
 * Company Service
 * Business logic for company and member operations
 */

import {
  db,
  getRootCollection,
  getDocument,
  updateDocument,
} from './firestore.service';
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

/**
 * Update member role
 */
export async function updateMemberRole(
  companyId: string,
  targetUserId: string,
  newRole: RoleType,
  updatedBy: UserAggr
): Promise<boolean> {
  const company = await getCompany(companyId);
  if (!company) return false;

  // Cannot change owner's role
  if (company.owner?.id === targetUserId) {
    throw new Error('Cannot change owner role');
  }

  // Find and update user in users array
  const users = company.users || [];
  const userIndex = users.findIndex((u) => u.user.id === targetUserId);

  if (userIndex === -1) return false;

  users[userIndex].role = newRole;

  const collection = getRootCollection('companies');
  await updateDocument(collection, companyId, {
    users,
    updatedBy,
    updatedAt: new Date().toISOString(),
  });

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
  const company = await getCompany(companyId);
  if (!company) return false;

  // Cannot remove owner
  if (company.owner?.id === targetUserId) {
    throw new Error('Cannot remove owner');
  }

  // Remove from users array
  const users = (company.users || []).filter((u) => u.user.id !== targetUserId);

  const collection = getRootCollection('companies');
  await updateDocument(collection, companyId, {
    users,
    updatedBy: removedBy,
    updatedAt: new Date().toISOString(),
  });

  // Remove from user's companies array
  await removeUserFromCompany(targetUserId, companyId);

  // Remove linked channels for this company
  await unlinkUserChannels(targetUserId, companyId);

  return true;
}

/**
 * Add member to company (used by invite accept)
 */
export async function addMemberToCompany(
  companyId: string,
  user: UserAggr,
  role: RoleType
): Promise<void> {
  const company = await getCompany(companyId);
  if (!company) throw new Error('Company not found');

  const users = company.users || [];

  // Check if user already exists
  const existingIndex = users.findIndex((u) => u.user.id === user.id);
  if (existingIndex !== -1) {
    // Update role if already exists
    users[existingIndex].role = role;
  } else {
    // Add new user
    users.push({ user, role });
  }

  const collection = getRootCollection('companies');
  await updateDocument(collection, companyId, {
    users,
    updatedAt: new Date().toISOString(),
  });
}

// ============================================================================
// Helper Functions
// ============================================================================

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
