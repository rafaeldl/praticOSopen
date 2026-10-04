/**
 * Firestore security rules tests.
 *
 * Run with the emulator: `npm run test:rules`.
 * Skipped when FIRESTORE_EMULATOR_HOST is not set, so `npm test` stays offline.
 * RULES_FILE may point to an alternative rules file (defaults to ../firestore.rules).
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeEmulator = emulatorHost ? describe : describe.skip;

if (!emulatorHost) {
  console.info(
    '[firestore.rules.test] Skipped: FIRESTORE_EMULATOR_HOST is not set. Run `npm run test:rules`.',
  );
}

const PROJECT_ID = 'demo-praticos';
const RULES_FILE = process.env.RULES_FILE || resolve(__dirname, '../../../firestore.rules');

// Shapes mirror what the app writes (CompanyAggr.toJson includes `country`).
const companyAggr = (id: string, name = `Company ${id}`) => ({ id, name, country: null });
const entry = (id: string, role: string) => ({ company: companyAggr(id), role });

describeEmulator('firestore.rules', () => {
  // Loaded lazily so `npm test` does not need the emulator dependencies at runtime.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const rut = require('@firebase/rules-unit-testing') as typeof import('@firebase/rules-unit-testing');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require('firebase/firestore') as typeof import('firebase/firestore');

  let env: RulesTestEnvironment;

  const asUser = (uid: string, roles: Record<string, string> = {}, email?: string) =>
    env.authenticatedContext(uid, { roles, ...(email ? { email } : {}) }).firestore();

  beforeAll(async () => {
    const [host, port] = emulatorHost!.split(':');
    env = await rut.initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: readFileSync(RULES_FILE, 'utf8'), host, port: Number(port) },
    });
  });

  afterAll(async () => {
    await env?.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await fs.setDoc(fs.doc(db, 'companies/c1'), {
        name: 'Company c1',
        owner: { id: 'admin1', name: 'Admin' },
      });
      await fs.setDoc(fs.doc(db, 'companies/c1/orders/o1'), {
        number: 1,
        status: 'quote',
        createdBy: { id: 'admin1', name: 'Admin' },
      });
      await fs.setDoc(fs.doc(db, 'companies/c1/memberships/admin1'), {
        user: { id: 'admin1', name: 'Admin' },
        role: 'admin',
      });
      await fs.setDoc(fs.doc(db, 'users/admin1'), {
        id: 'admin1',
        name: 'Admin',
        companies: [entry('c1', 'admin')],
      });
      await fs.setDoc(fs.doc(db, 'users/tech1'), {
        id: 'tech1',
        name: 'Tech',
        companies: [entry('c1', 'technician')],
      });
      await fs.setDoc(fs.doc(db, 'users/outsider'), {
        id: 'outsider',
        name: 'Outsider',
        companies: [],
      });
      // Entry written by the server (invite accept / WhatsApp): no `country` key.
      await fs.setDoc(fs.doc(db, 'users/serverwritten'), {
        id: 'serverwritten',
        name: 'Server Written',
        companies: [{ company: { id: 'c1', name: 'Company c1' }, role: 'owner' }],
      });
      await fs.setDoc(fs.doc(db, 'links/invites/tokens/INV_1'), {
        token: 'INV_1',
        company: { id: 'c1', name: 'Company c1' },
        role: 'technician',
        email: 'invitee@example.com',
        status: 'pending',
        invitedBy: { id: 'admin1', name: 'Admin' },
      });
    });
  });

  /** Mirrors AuthService.signup: user + company + membership in one batch. */
  async function companyCreationBatch(uid: string, existing: unknown[], cid: string) {
    const db = asUser(uid);
    const batch = fs.writeBatch(db);
    batch.set(
      fs.doc(db, `users/${uid}`),
      { id: uid, name: 'New', email: `${uid}@example.com`, companies: [...existing, entry(cid, 'admin')] },
      { merge: true },
    );
    batch.set(fs.doc(db, `companies/${cid}`), {
      id: cid,
      name: `Company ${cid}`,
      owner: { id: uid, name: 'New' },
      country: null,
    });
    batch.set(fs.doc(db, `companies/${cid}/memberships/${uid}`), {
      user: { id: uid, name: 'New' },
      role: 'admin',
      joinedAt: fs.serverTimestamp(),
    });
    return batch.commit();
  }

  describe('users/{userId}', () => {
    it('allows first login with an empty companies list', async () => {
      await rut.assertSucceeds(
        fs.setDoc(fs.doc(asUser('newbie'), 'users/newbie'), { id: 'newbie', companies: [] }, { merge: true }),
      );
    });

    // Claims are issued by the server from verified memberships, so a company
    // listed only in the user's own document is absent from `roles`.
    it('a company entry written to the own profile does not give access to its orders', async () => {
      const db = asUser('outsider');
      await fs.updateDoc(fs.doc(db, 'users/outsider'), { companies: [entry('c1', 'admin')] });

      await rut.assertFails(fs.getDoc(fs.doc(db, 'companies/c1/orders/o1')));
      await rut.assertFails(fs.getDocs(fs.collection(db, 'companies/c1/orders')));
      await rut.assertFails(
        fs.setDoc(fs.doc(db, 'companies/c1/orders/o2'), { createdBy: { id: 'outsider' } }),
      );
      await rut.assertFails(fs.getDoc(fs.doc(db, 'companies/c1')));
    });

    it('a role changed on the own profile does not give admin access', async () => {
      // Claim keeps the server-verified role (technician)
      const db = asUser('tech1', { c1: 'technician' });
      await fs.updateDoc(fs.doc(db, 'users/tech1'), { companies: [entry('c1', 'admin')] });

      await rut.assertFails(fs.getDoc(fs.doc(db, 'companies/c1/orders/o1')));
      await rut.assertFails(fs.setDoc(fs.doc(db, 'companies/c1/products/p1'), { name: 'P' }));
      await rut.assertFails(
        fs.setDoc(fs.doc(db, 'companies/c1/memberships/tech9'), { role: 'admin' }),
      );
    });

    it('a user document created with company entries does not give access to them', async () => {
      const db = asUser('newbie');
      await fs.setDoc(fs.doc(db, 'users/newbie'), { id: 'newbie', companies: [entry('c1', 'admin')] });

      await rut.assertFails(fs.getDoc(fs.doc(db, 'companies/c1/orders/o1')));
      await rut.assertFails(fs.getDocs(fs.collection(db, 'companies/c1/memberships')));
    });

    it('allows a profile update that keeps companies unchanged', async () => {
      await rut.assertSucceeds(
        fs.setDoc(
          fs.doc(asUser('tech1', { c1: 'technician' }), 'users/tech1'),
          { id: 'tech1', name: 'Tech Renamed', photo: 'https://x/p.jpg', companies: [entry('c1', 'technician')] },
          { merge: true },
        ),
      );
    });

    it('allows field updates that do not touch companies (fcmTokens, preferredLanguage)', async () => {
      const db = asUser('tech1', { c1: 'technician' });
      await rut.assertSucceeds(fs.updateDoc(fs.doc(db, 'users/tech1'), { preferredLanguage: 'en' }));
      await rut.assertSucceeds(
        fs.updateDoc(fs.doc(db, 'users/tech1'), { fcmTokens: [{ token: 't', deviceId: 'd' }] }),
      );
      await rut.assertSucceeds(
        fs.setDoc(fs.doc(db, 'users/tech1'), { onboardingSegment: { skipped: true } }, { merge: true }),
      );
    });

    it('allows a profile update from the current app for server-written entries', async () => {
      // The app re-serializes entries: adds `country: null` and maps unknown roles to technician.
      await rut.assertSucceeds(
        fs.setDoc(
          fs.doc(asUser('serverwritten', { c1: 'owner' }), 'users/serverwritten'),
          { id: 'serverwritten', name: 'Renamed', companies: [entry('c1', 'technician')] },
          { merge: true },
        ),
      );
    });

    it('allows deleting the own user document', async () => {
      await rut.assertSucceeds(fs.deleteDoc(fs.doc(asUser('tech1', { c1: 'technician' }), 'users/tech1')));
    });

    it('does not allow reading another user document', async () => {
      await rut.assertFails(fs.getDoc(fs.doc(asUser('outsider'), 'users/tech1')));
    });
  });

  describe('company creation batch', () => {
    it('allows the signup batch (user + company + membership) for a new user', async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await fs.setDoc(fs.doc(ctx.firestore(), 'users/new1'), { id: 'new1', companies: [] });
      });
      await rut.assertSucceeds(companyCreationBatch('new1', [], 'cNew'));
    });

    it('allows creating a second company keeping existing entries', async () => {
      await rut.assertSucceeds(companyCreationBatch('tech1', [entry('c1', 'technician')], 'cNew'));
    });

    it('allows creating a company for a user with server-written entries', async () => {
      // The app re-serializes the existing entry before appending the new company.
      await rut.assertSucceeds(
        companyCreationBatch('serverwritten', [entry('c1', 'technician')], 'cNew'),
      );
    });
  });

  describe('companies/{cid}/memberships/{memberId}', () => {
    it('does not allow creating the own membership in an existing company', async () => {
      await rut.assertFails(
        fs.setDoc(fs.doc(asUser('outsider'), 'companies/c1/memberships/outsider'), {
          user: { id: 'outsider', name: 'Outsider' },
          role: 'admin',
        }),
      );
    });

    it('allows a company admin to create a membership', async () => {
      await rut.assertSucceeds(
        fs.setDoc(
          fs.doc(asUser('admin1', { c1: 'admin' }), 'companies/c1/memberships/tech2'),
          { user: { id: 'tech2', name: 'Tech 2' }, role: 'technician' },
          { merge: true },
        ),
      );
    });
  });

  describe('links/invites/tokens/{token}', () => {
    const invite = (token: string) => ({
      token,
      company: { id: 'c1', name: 'Company c1' },
      role: 'technician',
      email: 'someone@example.com',
      status: 'pending',
    });

    it('does not allow a technician to create an invite', async () => {
      await rut.assertFails(
        fs.setDoc(fs.doc(asUser('tech1', { c1: 'technician' }), 'links/invites/tokens/INV_T'), invite('INV_T')),
      );
    });

    it('allows a company admin to create an invite', async () => {
      await rut.assertSucceeds(
        fs.setDoc(fs.doc(asUser('admin1', { c1: 'admin' }), 'links/invites/tokens/INV_A'), invite('INV_A')),
      );
    });

    it('does not allow a technician to change the invite role', async () => {
      await rut.assertFails(
        fs.updateDoc(fs.doc(asUser('tech1', { c1: 'technician' }), 'links/invites/tokens/INV_1'), {
          role: 'admin',
        }),
      );
    });

    it('allows the invitee to accept with status fields only', async () => {
      await rut.assertSucceeds(
        fs.updateDoc(fs.doc(asUser('invitee', {}, 'invitee@example.com'), 'links/invites/tokens/INV_1'), {
          status: 'accepted',
          acceptedAt: fs.serverTimestamp(),
          acceptedByUserId: 'invitee',
        }),
      );
    });

    it('does not allow the invitee to change the invite role', async () => {
      await rut.assertFails(
        fs.updateDoc(fs.doc(asUser('invitee', {}, 'invitee@example.com'), 'links/invites/tokens/INV_1'), {
          role: 'admin',
        }),
      );
    });

    it('does not allow a company admin to move an invite to another company', async () => {
      await rut.assertFails(
        fs.updateDoc(fs.doc(asUser('admin1', { c1: 'admin' }), 'links/invites/tokens/INV_1'), {
          company: { id: 'c2', name: 'Company c2' },
        }),
      );
    });

    it('allows a company admin to cancel an invite', async () => {
      await rut.assertSucceeds(
        fs.updateDoc(fs.doc(asUser('admin1', { c1: 'admin' }), 'links/invites/tokens/INV_1'), {
          status: 'cancelled',
        }),
      );
    });
  });
});
