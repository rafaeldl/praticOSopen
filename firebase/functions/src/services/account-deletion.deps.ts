/**
 * Production wiring of [AccountDeletionDeps]: Firestore (Admin SDK), the
 * default Storage bucket and Firebase Auth.
 */

import { auth, db, storage } from './firestore.service';
import { ownerId, privateMembershipRef } from './membership.service';
import { removeMember } from './company.service';
import type { AccountDeletionDeps } from './account-deletion.service';

export function defaultAccountDeletionDeps(): AccountDeletionDeps {
  return {
    getUserCompanyIds: async (uid) => {
      const snap = await db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      const companies = snap.data()?.companies;
      if (!Array.isArray(companies)) return [];
      return companies.flatMap((entry: unknown) => {
        const id = (entry as { company?: { id?: unknown } } | null)?.company?.id;
        return typeof id === 'string' && id ? [id] : [];
      });
    },

    getCompany: async (companyId) => {
      const snap = await db.collection('companies').doc(companyId).get();
      return { exists: snap.exists, ownerId: snap.exists ? ownerId(snap.data()?.owner) : null };
    },

    hasOtherMembers: async (companyId, uid) => {
      // Display memberships + server-only member map: any other uid blocks.
      const [memberships, privateSnap] = await Promise.all([
        db.collection('companies').doc(companyId).collection('memberships').select().get(),
        privateMembershipRef(companyId).get(),
      ]);
      if (memberships.docs.some((doc) => doc.id !== uid)) return true;
      const members = privateSnap.data()?.members;
      return !!members && typeof members === 'object' && Object.keys(members).some((id) => id !== uid);
    },

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
