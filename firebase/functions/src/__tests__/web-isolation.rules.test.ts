/**
 * Web client tenant-isolation tests for firestore.rules.
 *
 * The web app runs in the browser with authenticated users who control all of
 * the JavaScript, so it can issue any Firestore request its custom-claims allow
 * — including requests aimed at another company (c2) or at protected fields.
 *
 * The role × action matrix (rbac-firestore.rules.test.ts) already exercises
 * company c1's collections for every role plus an outsider. This file covers
 * the complementary direction the matrix does not seed: a fully authenticated
 * member of company c1 (or an outsider) trying to READ or WRITE company c2's
 * data, and a web client trying to grant itself a role or a paid plan by
 * writing protected fields/documents directly. Every case here is expected to
 * PASS against the current rules (the attack is denied, the legitimate control
 * is allowed).
 *
 * Run with the emulator: `npm run test:rules`. Skipped without
 * FIRESTORE_EMULATOR_HOST. RULES_FILE may point to a mutated rules file.
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeEmulator = emulatorHost ? describe : describe.skip;

const PROJECT_ID = 'demo-praticos-webiso';
const RULES_FILE = process.env.RULES_FILE || resolve(__dirname, '../../../firestore.rules');

describeEmulator('firestore.rules web tenant isolation', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const rut = require('@firebase/rules-unit-testing') as typeof import('@firebase/rules-unit-testing');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require('firebase/firestore') as typeof import('firebase/firestore');

  let env: RulesTestEnvironment;

  // Claims mirror what updateUserClaims writes: only verified memberships.
  const CLAIMS = {
    c1admin: { c1: 'admin' },
    c1owner: { c1: 'owner' },
    c1technician: { c1: 'technician' },
    c1consultant: { c1: 'consultant' },
    c2admin: { c2: 'admin' },
  } as const;

  type Who = keyof typeof CLAIMS;
  const UID: Record<Who, string> = {
    c1admin: 'admin1',
    c1owner: 'owner1',
    c1technician: 'tech1',
    c1consultant: 'cons1',
    c2admin: 'other1',
  };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const dbFor = (who: Who): any =>
    env
      .authenticatedContext(UID[who], {
        roles: CLAIMS[who],
        email: `${UID[who]}@example.com`,
        email_verified: true,
      })
      .firestore();

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const anonDb = (): any => env.unauthenticatedContext().firestore();

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
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const db = ctx.firestore() as any;
      const batch = db.batch();
      const set = (path: string, data: Record<string, unknown>) =>
        batch.set(db.doc(path), data);

      // Two independent tenants.
      set('companies/c1', { name: 'Company c1', owner: { id: 'owner1', name: 'Owner 1' } });
      set('companies/c2', { name: 'Company c2', owner: { id: 'other1', name: 'Owner 2' } });

      // c1 member docs (so the matrix-style actors resolve as members of c1).
      set('companies/c1/memberships/admin1', { user: { id: 'admin1' }, role: 'admin' });
      set('companies/c1/memberships/tech1', { user: { id: 'tech1' }, role: 'technician' });
      set('companies/c1/memberships/cons1', { user: { id: 'cons1' }, role: 'consultant' });

      // c2 data — the target of every cross-tenant attack below.
      set('companies/c2/orders/o2', { status: 'quote', createdBy: { id: 'other1', name: 'Owner 2' } });
      set('companies/c2/customers/cust2', { name: 'Cliente da c2' });
      set('companies/c2/devices/dev2', { name: 'Aparelho da c2' });
      set('companies/c2/products/prod2', { name: 'Peça da c2', value: 99 });
      set('companies/c2/financialEntries/fe2', { amount: 1000 });
      set('companies/c2/financialAccounts/fa2', { name: 'Caixa c2' });
      set('companies/c2/settings/payments', { enabled: true });
      set('companies/c2/settings/nfse', { serviceCode: '1.01' });
      set('companies/c2/invoices/inv2', { value: 1000 });
      set('companies/c2/customerCharges/cc2', { value: 1000 });
      set('companies/c2/receipts/r2', {
        createdBy: { id: 'other1' }, status: 'active', amount: 50, allocations: [{ orderId: 'o2', amount: 50 }],
      });
      set('companies/c2/private/membership', { members: { other1: 'owner' } });

      // c1 data used by the within-tenant role checks.
      set('companies/c1/orders/o1_other', { status: 'quote', createdBy: { id: 'someoneelse', name: 'X' } });
      set('companies/c1/financialEntries/fe1', { amount: 10 });
      set('companies/c1/receipts/r1_other', {
        createdBy: { id: 'someoneelse' }, status: 'active', amount: 10, allocations: [{ orderId: 'o1', amount: 10 }],
      });
      set('companies/c1/private/membership', { members: { owner1: 'owner' } });

      // Share token of c1 (only Cloud Functions read it, not even c1 members).
      set('links/share/tokens/ST_c1', { companyId: 'c1', orderId: 'o1_other' });

      await batch.commit();
    });
  });

  const deny = (p: Promise<unknown>) => rut.assertFails(p);
  const allow = (p: Promise<unknown>) => rut.assertSucceeds(p);

  // ── A member of c1 cannot READ c2's data ────────────────────────────────
  describe('cross-tenant reads are denied to a c1 member', () => {
    it('c1 admin cannot read a c2 order', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/orders/o2'))));
    it('c1 admin cannot list c2 orders', () =>
      deny(fs.getDocs(fs.collection(dbFor('c1admin'), 'companies/c2/orders'))));
    it('c1 admin cannot read a c2 customer', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/customers/cust2'))));
    it('c1 admin cannot read a c2 device', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/devices/dev2'))));
    it('c1 admin cannot read c2 financial entries', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/financialEntries/fe2'))));
    it('c1 admin cannot read c2 settings/payments', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/settings/payments'))));
    it('c1 admin cannot read c2 invoices', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/invoices/inv2'))));
    it('c1 admin cannot read c2 customerCharges', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/customerCharges/cc2'))));
    it('c1 admin cannot read c2 receipts', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/receipts/r2'))));
    it("c1 admin cannot read c2's server-only member map", () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c2/private/membership'))));
    it('c2 owner CAN read their own c2 order (control)', () =>
      allow(fs.getDoc(fs.doc(dbFor('c2admin'), 'companies/c2/orders/o2'))));
  });

  // ── A member of c1 cannot WRITE c2's data ───────────────────────────────
  describe('cross-tenant writes are denied to a c1 member', () => {
    it('c1 admin cannot create an order in c2', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1admin'), 'companies/c2/orders/injected'), {
        status: 'quote', createdBy: { id: 'admin1', name: 'Intruder' },
      })));
    it('c1 admin cannot update a c2 order', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1admin'), 'companies/c2/orders/o2'), { status: 'done' })));
    it('c1 admin cannot delete a c2 order', () =>
      deny(fs.deleteDoc(fs.doc(dbFor('c1admin'), 'companies/c2/orders/o2'))));
    it('c1 admin cannot create a customer in c2', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1admin'), 'companies/c2/customers/injected'), { name: 'x' })));
    it('c1 admin cannot edit the c2 company document', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1admin'), 'companies/c2'), { name: 'hijacked' })));
    it('c1 admin cannot write c2 financial entries', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1admin'), 'companies/c2/financialEntries/injected'), { amount: 1 })));
  });

  // ── A forged/own claim for c2 grants nothing in c1 ──────────────────────
  describe('a claim for another company grants nothing in c1', () => {
    it('c2 admin cannot read a c1 order', () =>
      deny(fs.getDoc(fs.doc(dbFor('c2admin'), 'companies/c1/orders/o1_other'))));
    it('c2 admin cannot read c1 customers', () =>
      deny(fs.getDoc(fs.doc(dbFor('c2admin'), 'companies/c1/customers/anything'))));
    it('c2 admin cannot read the c1 share token', () =>
      deny(fs.getDoc(fs.doc(dbFor('c2admin'), 'links/share/tokens/ST_c1'))));
    it('c1 admin cannot read the c1 share token either', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1admin'), 'links/share/tokens/ST_c1'))));
  });

  // ── Web client cannot self-escalate role via direct writes ──────────────
  describe('role escalation by writing protected documents is denied', () => {
    it('technician cannot create a membership for itself as admin', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1technician'), 'companies/c1/memberships/tech1'), {
        user: { id: 'tech1' }, role: 'admin',
      })));
    it('technician cannot promote its own existing membership to admin', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1technician'), 'companies/c1/memberships/tech1'), { role: 'admin' })));
    it('consultant cannot create a membership for itself as admin', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1consultant'), 'companies/c1/memberships/cons1'), {
        user: { id: 'cons1' }, role: 'admin',
      })));
    it('even the owner cannot write the server-only member map', () =>
      deny(fs.setDoc(fs.doc(dbFor('c1owner'), 'companies/c1/private/membership'), {
        members: { tech1: 'admin' },
      })));
    it('technician cannot read the server-only member map of its own company', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1technician'), 'companies/c1/private/membership'))));
  });

  // ── Web client cannot write protected company fields ────────────────────
  describe('protected company fields', () => {
    it('owner cannot give itself a paid plan', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1owner'), 'companies/c1'), {
        subscription: { plan: 'pro', status: 'active' },
      })));
    it('admin cannot give the company a paid plan', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1admin'), 'companies/c1'), {
        subscription: { plan: 'enterprise', status: 'active' },
      })));
    it('technician cannot toggle useFinancial on the company', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1technician'), 'companies/c1'), { useFinancial: false })));
    it('technician cannot toggle nfseEnabled on the company', () =>
      deny(fs.updateDoc(fs.doc(dbFor('c1technician'), 'companies/c1'), { nfseEnabled: true })));
  });

  // ── Within-tenant role limits a web client still cannot cross ───────────
  describe('within-tenant role restrictions hold for a web client', () => {
    it('technician cannot read an order created by someone else', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1technician'), 'companies/c1/orders/o1_other'))));
    it('consultant cannot read an order created by someone else', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1consultant'), 'companies/c1/orders/o1_other'))));
    it('technician cannot read company financial entries', () =>
      deny(fs.getDoc(fs.doc(dbFor('c1technician'), 'companies/c1/financialEntries/fe1'))));
    it("consultant cannot read a receipt registered by another user", () =>
      deny(fs.getDoc(fs.doc(dbFor('c1consultant'), 'companies/c1/receipts/r1_other'))));
    it('admin (financial) CAN read the same receipt (control)', () =>
      allow(fs.getDoc(fs.doc(dbFor('c1admin'), 'companies/c1/receipts/r1_other'))));
  });

  // ── Anonymous web visitor is shut out ───────────────────────────────────
  describe('anonymous visitor', () => {
    it('cannot read a company document', () =>
      deny(fs.getDoc(fs.doc(anonDb(), 'companies/c1'))));
    it('cannot read an order', () =>
      deny(fs.getDoc(fs.doc(anonDb(), 'companies/c1/orders/o1_other'))));
    it('cannot read a share token', () =>
      deny(fs.getDoc(fs.doc(anonDb(), 'links/share/tokens/ST_c1'))));
  });
});
