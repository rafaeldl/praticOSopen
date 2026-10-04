/**
 * Membership Service
 * Single source of truth for "is this user a member of this company, and with
 * which role". Membership is confirmed against server-only data: the company
 * owner and `companies/{cid}/private/membership.members` ({ [uid]: role }),
 * which only the Admin SDK can write. The user's own `companies` array is only
 * used for ordering and as a hint for the owner role. The company `users` array
 * and the `memberships` subcollection are display data, not verification sources.
 */

import { db } from './firestore.service';

export interface VerifiedMembership {
  companyId: string;
  /** Lowercase role */
  role: string;
}

const OWNER_ROLES = ['owner', 'admin'];

/** Server-only member map: companies/{cid}/private/membership */
export const PRIVATE_COLLECTION = 'private';
export const MEMBERSHIP_DOC = 'membership';

export function privateMembershipRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection(PRIVATE_COLLECTION).doc(MEMBERSHIP_DOC);
}

/** Reads the role of `uid` from a private membership snapshot's data. */
export function memberRole(data: unknown, uid: string): string | null {
  const members = (data as { members?: unknown } | undefined)?.members;
  if (!members || typeof members !== 'object') return null;
  return lower((members as Record<string, unknown>)[uid]);
}

function lower(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : null;
}

export function ownerId(owner: unknown): string | null {
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
 * 2. `private/membership.members[uid]` → that role ('owner' becomes 'admin',
 *    since the uid is not the company owner).
 * Otherwise returns null.
 *
 * `entryRole` (the role in the user's own `companies` entry) is only used in case 1.
 */
export async function verifyMembership(
  uid: string,
  companyId: string,
  entryRole?: unknown,
): Promise<VerifiedMembership | null> {
  const companySnap = await db.collection('companies').doc(companyId).get();
  if (!companySnap.exists) return null;

  const company = companySnap.data() || {};

  // 1. Owner
  if (ownerId(company.owner) === uid) {
    const requested = lower(entryRole);
    const role = requested && OWNER_ROLES.includes(requested) ? requested : 'admin';
    return { companyId, role };
  }

  // 2. Server-only member map
  const privateSnap = await privateMembershipRef(companyId).get();
  const role = privateSnap.exists ? memberRole(privateSnap.data(), uid) : null;
  if (!role) return null;

  return { companyId, role: role === 'owner' ? 'admin' : role };
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
