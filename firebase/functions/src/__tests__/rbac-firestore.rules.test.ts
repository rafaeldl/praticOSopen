/**
 * Role × action matrix against firestore.rules (see rbac/firestore-matrix.ts).
 *
 * Every case runs for every actor: the 6 roles of company c1, an admin of
 * another company, a signed-in user without company and an anonymous visitor.
 * Allowed actors must succeed; everyone else must be denied.
 *
 * Run with the emulator: `npm run test:rules`. Skipped without
 * FIRESTORE_EMULATOR_HOST. RULES_FILE may point to a mutated rules file
 * (scripts/rules-mutation-check.sh).
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { ACTORS, ACTOR_INFO, CASES, seed, type Actor, type Firestore } from './rbac/firestore-matrix';

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeEmulator = emulatorHost ? describe : describe.skip;

const PROJECT_ID = 'demo-praticos';
const RULES_FILE = process.env.RULES_FILE || resolve(__dirname, '../../../firestore.rules');

describeEmulator('firestore.rules RBAC matrix', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const rut = require('@firebase/rules-unit-testing') as typeof import('@firebase/rules-unit-testing');
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require('firebase/firestore') as typeof import('firebase/firestore');

  let env: RulesTestEnvironment;

  const dbFor = (actor: Actor) => {
    const { uid, roles } = ACTOR_INFO[actor];
    const ctx = uid
      ? env.authenticatedContext(uid, { roles, email: `${uid}@example.com`, email_verified: true })
      : env.unauthenticatedContext();
    // rules-unit-testing returns the compat instance; the modular API accepts it at runtime.
    return ctx.firestore() as unknown as Firestore;
  };

  beforeAll(async () => {
    const [host, port] = emulatorHost!.split(':');
    env = await rut.initializeTestEnvironment({
      projectId: `${PROJECT_ID}-rbac`,
      firestore: { rules: readFileSync(RULES_FILE, 'utf8'), host, port: Number(port) },
    });
  });

  afterAll(async () => {
    await env?.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled((ctx) => seed(ctx.firestore() as unknown as Firestore, fs));
  });

  for (const c of CASES) {
    describe(`[${c.area}] ${c.title} (${c.id})`, () => {
      for (const actor of ACTORS) {
        const allowed = c.allow.includes(actor);
        it(`${actor} ${allowed ? 'pode' : 'não pode'}`, async () => {
          const uid = ACTOR_INFO[actor].uid ?? 'anon';
          const attempt = c.run({ db: dbFor(actor), fs, uid });
          if (allowed) await rut.assertSucceeds(attempt);
          else await rut.assertFails(attempt);
        });
      }
    });
  }
});
