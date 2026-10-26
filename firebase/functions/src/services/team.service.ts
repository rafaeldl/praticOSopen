/**
 * Team Service
 * Role change and removal of a company member, done by an owner/admin from the
 * app (routes/v1/team.routes.ts).
 *
 * The app cannot do this itself: firestore.rules only let a user write their
 * own `users/{uid}`, and the colleague's `companies` list feeds the `roles`
 * claim. Here one transaction updates every copy of the membership:
 * - companies/{cid}/private/membership.members (source of truth)
 * - companies/{cid}.users and companies/{cid}/memberships/{uid} (display)
 * - users/{uid}.companies (the member's own list)
 * and, after the commit, the member's `roles` claim and WhatsApp links.
 *
 * Rules: the company owner's role is never changed and the owner is never
 * removed; the company always keeps at least one admin (the owner counts).
 */

import { auth, db, FieldValue } from './firestore.service';
import { buildRolesClaim, memberRole, ownerId, privateMembershipRef } from './membership.service';
import { getMembershipRef, unlinkUserChannels, updateLinkedChannelRole } from './company.service';
import { Company, RoleType, UserAggr } from '../models/types';

export type TeamErrorCode = 'COMPANY_NOT_FOUND' | 'MEMBER_NOT_FOUND' | 'OWNER_PROTECTED' | 'LAST_ADMIN';

export class TeamError extends Error {
  constructor(public readonly code: TeamErrorCode, message: string) {
    super(message);
    this.name = 'TeamError';
  }
}

type CompanyEntry = { company?: { id?: string }; role?: string };
const ADMIN_ROLES = ['owner', 'admin'];

async function loadState(tx: FirebaseFirestore.Transaction, companyId: string, targetUserId: string) {
  const companyRef = db.collection('companies').doc(companyId);
  const companySnap = await tx.get(companyRef);
  if (!companySnap.exists) throw new TeamError('COMPANY_NOT_FOUND', 'Company not found');
  const company = companySnap.data() as Company;

  const privateSnap = await tx.get(privateMembershipRef(companyId));
  const membershipSnap = await tx.get(getMembershipRef(companyId, targetUserId));
  const userRef = db.collection('users').doc(targetUserId);
  const userSnap = await tx.get(userRef);

  if (ownerId(company.owner) === targetUserId) {
    throw new TeamError('OWNER_PROTECTED', 'The company owner cannot be changed or removed');
  }

  const users = Array.isArray(company.users) ? [...company.users] : [];
  const isMember =
    memberRole(privateSnap.data(), targetUserId) !== null ||
    users.some((u) => u?.user?.id === targetUserId) ||
    membershipSnap.exists;
  if (!isMember) throw new TeamError('MEMBER_NOT_FOUND', 'Member not found');

  const companies: CompanyEntry[] =
    userSnap.exists && Array.isArray(userSnap.get('companies')) ? [...userSnap.get('companies')] : [];

  return { companyRef, company, users, privateSnap, membershipSnap, userRef, userSnap, companies };
}

/** Admins left after `targetUserId` becomes `newRole` (null = removed). The owner counts. */
function adminsAfter(
  company: Company,
  privateData: unknown,
  targetUserId: string,
  newRole: string | null,
): number {
  const admins = new Set<string>();
  const owner = ownerId(company.owner);
  if (owner) admins.add(owner);
  const members = (privateData as { members?: Record<string, unknown> } | undefined)?.members ?? {};
  for (const uid of Object.keys(members)) {
    const role = memberRole(privateData, uid);
    if (role && ADMIN_ROLES.includes(role)) admins.add(uid);
  }
  for (const u of company.users ?? []) {
    if (u?.user?.id && ADMIN_ROLES.includes(String(u.role).toLowerCase())) admins.add(u.user.id);
  }
  admins.delete(targetUserId);
  if (newRole && ADMIN_ROLES.includes(newRole)) admins.add(targetUserId);
  return admins.size;
}

/** Rebuilds the member's `roles` claim from their (already updated) companies list. */
async function refreshRolesClaim(userId: string, companies: CompanyEntry[]): Promise<void> {
  try {
    await auth.setCustomUserClaims(userId, { roles: await buildRolesClaim(userId, companies) });
  } catch (error) {
    if ((error as { code?: string })?.code === 'auth/user-not-found') return;
    throw error;
  }
}

/**
 * Side effects after the transaction committed (claim, WhatsApp links). The
 * change is already saved, so a failure here is logged and the request still
 * succeeds. The users/{uid} write in the transaction also fires the
 * updateUserClaims trigger, which rebuilds the claim if this step failed.
 */
async function afterCommit(
  step: string,
  companyId: string,
  userId: string,
  fn: () => Promise<unknown>,
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    console.error(`[team] ${step} post-commit step failed`, { companyId, userId, error });
  }
}

export async function changeMemberRole(
  companyId: string,
  targetUserId: string,
  newRole: RoleType,
  updatedBy: UserAggr,
): Promise<void> {
  const result = await db.runTransaction(async (tx) => {
    const s = await loadState(tx, companyId, targetUserId);
    if (adminsAfter(s.company, s.privateSnap.data(), targetUserId, newRole) === 0) {
      throw new TeamError('LAST_ADMIN', 'The company must keep at least one admin');
    }

    tx.set(
      privateMembershipRef(companyId),
      { members: { [targetUserId]: newRole }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    const users = s.users.map((u) => (u?.user?.id === targetUserId ? { ...u, role: newRole } : u));
    tx.update(s.companyRef, { users, updatedBy, updatedAt: new Date().toISOString() });
    if (s.membershipSnap.exists) tx.update(getMembershipRef(companyId, targetUserId), { role: newRole });

    const companies = s.companies.map((c) => (c?.company?.id === companyId ? { ...c, role: newRole } : c));
    if (s.userSnap.exists) tx.update(s.userRef, { companies });
    return { companies, hasUser: s.userSnap.exists };
  });

  await afterCommit('changeMemberRole', companyId, targetUserId, async () => {
    if (result.hasUser) await refreshRolesClaim(targetUserId, result.companies);
  });
  await afterCommit('changeMemberRole', companyId, targetUserId, () =>
    updateLinkedChannelRole(targetUserId, companyId, newRole));
}

export async function removeTeamMember(
  companyId: string,
  targetUserId: string,
  removedBy: UserAggr,
): Promise<void> {
  const result = await db.runTransaction(async (tx) => {
    const s = await loadState(tx, companyId, targetUserId);
    if (adminsAfter(s.company, s.privateSnap.data(), targetUserId, null) === 0) {
      throw new TeamError('LAST_ADMIN', 'The company must keep at least one admin');
    }

    tx.set(
      privateMembershipRef(companyId),
      { members: { [targetUserId]: FieldValue.delete() }, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    const users = s.users.filter((u) => u?.user?.id !== targetUserId);
    tx.update(s.companyRef, { users, updatedBy: removedBy, updatedAt: new Date().toISOString() });
    if (s.membershipSnap.exists) tx.delete(getMembershipRef(companyId, targetUserId));

    const companies = s.companies.filter((c) => c?.company?.id !== companyId);
    if (s.userSnap.exists) tx.update(s.userRef, { companies });
    return { companies, hasUser: s.userSnap.exists };
  });

  await afterCommit('removeTeamMember', companyId, targetUserId, async () => {
    if (result.hasUser) await refreshRolesClaim(targetUserId, result.companies);
  });
  await afterCommit('removeTeamMember', companyId, targetUserId, () =>
    unlinkUserChannels(targetUserId, companyId));
}
