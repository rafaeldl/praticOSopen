/**
 * Production wiring of [AccountDeletionDeps]: Firestore (Admin SDK), the
 * default Storage bucket and Firebase Auth.
 */

import { auth, db, storage } from './firestore.service';
import { memberRole, ownerId, privateMembershipRef } from './membership.service';
import { removeMember } from './company.service';
import type { AccountDeletionDeps, CompanyInfo } from './account-deletion.service';

/** Company ids from a users/{uid}.companies array; malformed entries are ignored. */
export function companyIdsFromEntries(companies: unknown): string[] {
  if (!Array.isArray(companies)) return [];
  return companies.flatMap((entry: unknown) => {
    const id = (entry as { company?: { id?: unknown } } | null)?.company?.id;
    return typeof id === 'string' && id ? [id] : [];
  });
}

/** uids in `company.users` ([{ user: { id }, role }]); malformed entries are ignored. */
function usersArrayIds(users: unknown): string[] {
  if (!Array.isArray(users)) return [];
  return users.flatMap((entry: unknown) => {
    const id = (entry as { user?: { id?: unknown } } | null)?.user?.id;
    return typeof id === 'string' && id ? [id] : [];
  });
}

export async function readCompanyInfo(companyId: string, uid: string): Promise<CompanyInfo> {
  const companyRef = db.collection('companies').doc(companyId);
  const [companySnap, privateSnap, memberships] = await Promise.all([
    companyRef.get(),
    privateMembershipRef(companyId).get(),
    companyRef.collection('memberships').get(),
  ]);
  if (!companySnap.exists) {
    return {
      exists: false,
      ownerId: null,
      privateRole: null,
      otherOwnerInPrivateMap: false,
      hasOtherMembers: false,
      isMember: false,
    };
  }

  const company = companySnap.data() ?? {};
  const privateData = privateSnap.exists ? privateSnap.data() : undefined;
  const rawMembers = (privateData as { members?: unknown } | undefined)?.members;
  const members: Record<string, unknown> = rawMembers && typeof rawMembers === 'object' ? (rawMembers as Record<string, unknown>) : {};
  const membershipIds = memberships.docs.map((doc) => doc.id);

  const others = new Set<string>([...membershipIds, ...Object.keys(members), ...usersArrayIds(company.users)]);
  others.delete(uid);

  return {
    exists: true,
    ownerId: ownerId(company.owner),
    privateRole: memberRole(privateData, uid),
    otherOwnerInPrivateMap: Object.keys(members).some((id) => id !== uid && memberRole(privateData, id) === 'owner'),
    hasOtherMembers: others.size > 0,
    isMember: membershipIds.includes(uid) || uid in members,
  };
}

export function defaultAccountDeletionDeps(): AccountDeletionDeps {
  return {
    getUserCompanyIds: async (uid) => {
      const snap = await db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      return companyIdsFromEntries(snap.data()?.companies);
    },

    getOwnedCompanyIds: async (uid) => {
      // owner is a map ({ id, name }) or, in legacy docs, the uid string.
      const [byMap, byString] = await Promise.all([
        db.collection('companies').where('owner.id', '==', uid).get(),
        db.collection('companies').where('owner', '==', uid).get(),
      ]);
      return [...byMap.docs, ...byString.docs].map((doc) => doc.id);
    },

    getCompany: readCompanyInfo,

    deleteStoragePrefix: async (prefix) => {
      await storage.bucket().deleteFiles({ prefix });
    },

    deleteCompanyTree: async (companyId) => {
      await db.recursiveDelete(db.collection('companies').doc(companyId));
    },

    leaveCompany: async (companyId, uid) => {
      await removeMember(companyId, uid, { id: uid, name: '' });
    },

    deleteUserChannelLinks: async (uid) => {
      const snap = await db.collection('links').doc('whatsapp').collection('numbers').where('userId', '==', uid).get();
      if (snap.empty) return;
      const batch = db.batch();
      snap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    },

    deleteUserTree: async (uid) => {
      await db.recursiveDelete(db.collection('users').doc(uid));
    },

    deleteAuthUser: async (uid) => {
      try {
        await auth.deleteUser(uid);
        return true;
      } catch (error) {
        if ((error as { code?: string })?.code === 'auth/user-not-found') return false;
        throw error;
      }
    },
  };
}
