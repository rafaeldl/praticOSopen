/**
 * Membership Service
 * Single source of truth for "is this user a member of this company, and with
 * which role". Membership is always confirmed against server-side company data
 * (owner, company `users` array, `memberships` subcollection); the user's own
 * `companies` array is only used for ordering and as a hint for the owner role.
 */

import { db } from './firestore.service';

export interface VerifiedMembership {
  companyId: string;
  /** Lowercase role */
  role: string;
}

const OWNER_ROLES = ['owner', 'admin'];

function lower(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : null;
}

function ownerId(owner: unknown): string | null {
  if (typeof owner === 'string') return owner;
  if (owner && typeof owner === 'object') {
    const id = (owner as { id?: unknown }).id;
    return typeof id === 'string' ? id : null;
  }
  return null;
}

/**
 * Verifies that `uid` belongs to `companyId` using server-side data.
 *
 * Resolution order:
 * 1. Company owner → `entryRole` when it is 'owner' or 'admin', otherwise 'admin'.
 * 2. Company `users` array → that role.
 * 3. `companies/{companyId}/memberships/{uid}` → that role.
 * Otherwise returns null.
 *
 * `entryRole` (the role in the user's own `companies` entry) is only used in case 1.
 */
export async function verifyMembership(
  uid: string,
  companyId: string,
  entryRole?: unknown,
): Promise<VerifiedMembership | null> {
  const companyRef = db.collection('companies').doc(companyId);
  const companySnap = await companyRef.get();
  if (!companySnap.exists) return null;

  const company = companySnap.data() || {};

  // 1. Owner
  if (ownerId(company.owner) === uid) {
    const requested = lower(entryRole);
    const role = requested && OWNER_ROLES.includes(requested) ? requested : 'admin';
    return { companyId, role };
  }

  // 2. Company users array
  const users: unknown[] = Array.isArray(company.users) ? company.users : [];
  for (const item of users) {
    const member = item as { user?: { id?: unknown }; role?: unknown } | null;
    if (member?.user?.id === uid) {
      const role = lower(member.role);
      if (role) return { companyId, role };
    }
  }

  // 3. Membership document
  const membershipSnap = await companyRef.collection('memberships').doc(uid).get();
  if (membershipSnap.exists) {
    const role = lower(membershipSnap.data()?.role);
    if (role) return { companyId, role };
  }

  return null;
}

/**
 * Verifies every entry of a user's `companies` array and returns only the
 * memberships confirmed by server-side data, in the user's order, without
 * duplicates. Unconfirmed entries are dropped and logged (identifiers only).
 */
export async function verifyUserMemberships(
  uid: string,
  entries: unknown[],
): Promise<VerifiedMembership[]> {
  if (!Array.isArray(entries)) return [];

  const verified: VerifiedMembership[] = [];
  const seen = new Set<string>();

  for (const item of entries) {
    if (!item || typeof item !== 'object') continue;
    const entry = item as { company?: { id?: unknown }; role?: unknown };
    const companyId = entry.company?.id;
    if (typeof companyId !== 'string' || !companyId || seen.has(companyId)) continue;
    seen.add(companyId);

    const membership = await verifyMembership(uid, companyId, entry.role);
    if (membership) {
      verified.push(membership);
    } else {
      console.warn(`[Membership] Unverified company entry ignored: uid=${uid} cid=${companyId}`);
    }
  }

  return verified;
}

/**
 * Builds the `roles` custom claim ({ [companyId]: role }) from verified
 * memberships only.
 */
export async function buildRolesClaim(
  uid: string,
  entries: unknown[],
): Promise<Record<string, string>> {
  const roles: Record<string, string> = {};
  for (const { companyId, role } of await verifyUserMemberships(uid, entries)) {
    roles[companyId] = role;
  }
  return roles;
}
