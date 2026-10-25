/**
 * Role × path matrix against storage.rules.
 *
 * `allow` is what the rules do TODAY (the test enforces it). `shouldAllow` is
 * what they should do: only members of the company (custom claim
 * roles[companyId]) touch tenants/{companyId}/**. While the two differ the
 * case is a documented gap (see docs/E2E_ROLES_TESTING.md). Whoever fixes
 * storage.rules updates `allow` here and the gap disappears.
 *
 * Run with the emulator: `npm run test:rules`. Skipped without
 * FIREBASE_STORAGE_EMULATOR_HOST.
 */

import { readFileSync } from 'fs';
import { resolve } from 'path';
import type { RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { ACTORS, ACTOR_INFO, ROLE_ACTORS, type Actor } from './rbac/firestore-matrix';

const emulatorHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const describeEmulator = emulatorHost ? describe : describe.skip;

const RULES_FILE = process.env.STORAGE_RULES_FILE || resolve(__dirname, '../../../storage.rules');

const MEMBERS: Actor[] = [...ROLE_ACTORS];
const SIGNED_IN: Actor[] = [...ROLE_ACTORS, 'otherCompany', 'noCompany'];

 
type Storage = any;

interface StorageCase {
  id: string;
  title: string;
  run: (storage: Storage) => Promise<unknown>;
  allow: Actor[];
  shouldAllow: Actor[];
}

const PNG = { contentType: 'image/png' };
const PDF = { contentType: 'application/pdf' };
const T = 'tenants/c1';

const read = (path: string) => (s: Storage) => s.ref(path).getMetadata();
const upload = (path: string, meta = PNG) => (s: Storage) => s.ref(path).putString('x', 'raw', meta);
const remove = (path: string) => (s: Storage) => s.ref(path).delete();
const list = (path: string) => (s: Storage) => s.ref(path).listAll();

export const STORAGE_CASES: StorageCase[] = [
  { id: 'orderPhoto.read', title: 'ver foto de OS', run: read(`${T}/orders/o1/photos/p1.png`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'orderPhoto.upload', title: 'enviar foto para OS', run: upload(`${T}/orders/o1/photos/new.png`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'orderPhoto.delete', title: 'apagar foto de OS', run: remove(`${T}/orders/o1/photos/p1.png`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'orderPhotos.list', title: 'listar fotos de OS', run: list(`${T}/orders/o1/photos`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'tenant.list', title: 'listar todos os arquivos da empresa', run: list(T), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'orderDocument.read', title: 'baixar documento da OS', run: read(`${T}/orders/o1/documents/d1.pdf`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'orderDocument.upload', title: 'anexar documento na OS', run: upload(`${T}/orders/o1/documents/new.pdf`, PDF), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'paymentProof.read', title: 'ver comprovante de pagamento da OS', run: read(`${T}/orders/o1/payments/t1/f1.pdf`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'formPhoto.upload', title: 'enviar foto de checklist', run: upload(`${T}/orders/o1/forms/f1/new.png`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'productPhoto.upload', title: 'trocar foto de produto', run: upload(`${T}/products/prod1/new.png`), allow: SIGNED_IN, shouldAllow: ['owner', 'admin'] },
  { id: 'devicePhoto.upload', title: 'trocar foto de aparelho', run: upload(`${T}/devices/dev1/new.png`), allow: SIGNED_IN, shouldAllow: ['owner', 'admin', 'supervisor'] },
  { id: 'tenantLogo.upload', title: 'trocar logo da empresa', run: upload(`${T}/logo/new.png`), allow: SIGNED_IN, shouldAllow: ['owner', 'admin'] },
  { id: 'companyLogo.upload', title: 'trocar logo (caminho do cadastro)', run: upload('companies/c1/logo.png'), allow: SIGNED_IN, shouldAllow: ['owner', 'admin'] },
  { id: 'companyLogo.delete', title: 'apagar logo da empresa', run: remove('companies/c1/logo/l1.png'), allow: SIGNED_IN, shouldAllow: ['owner', 'admin'] },
  { id: 'userPhoto.upload', title: 'trocar foto de perfil de colega', run: upload(`${T}/users/tech1/new.png`), allow: SIGNED_IN, shouldAllow: ['owner', 'admin'] },
  // Recibos: a regra própria checa a empresa, mas o curinga tenants/** (read)
  // libera a leitura para todos, e a sobrescrita passa como create.
  { id: 'receipt.read', title: 'ver comprovante de recebimento', run: read(`${T}/receipts/r1/f1.pdf`), allow: SIGNED_IN, shouldAllow: MEMBERS },
  { id: 'receipt.upload', title: 'enviar comprovante de recebimento', run: upload(`${T}/receipts/r1/new.pdf`, PDF), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'receipt.overwrite', title: 'sobrescrever comprovante de recebimento', run: upload(`${T}/receipts/r1/f1.pdf`, PDF), allow: MEMBERS, shouldAllow: [] },
  { id: 'unknown.path', title: 'gravar fora dos caminhos conhecidos', run: upload('anything/else.png'), allow: [], shouldAllow: [] },
];

const SEED_FILES: [string, { contentType: string }][] = [
  [`${T}/orders/o1/photos/p1.png`, PNG],
  [`${T}/orders/o1/documents/d1.pdf`, PDF],
  [`${T}/orders/o1/payments/t1/f1.pdf`, PDF],
  [`${T}/receipts/r1/f1.pdf`, PDF],
  ['companies/c1/logo/l1.png', PNG],
];

describeEmulator('storage.rules matrix', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const rut = require('@firebase/rules-unit-testing') as typeof import('@firebase/rules-unit-testing');
  let env: RulesTestEnvironment;

  const storageFor = (actor: Actor): Storage => {
    const { uid, roles } = ACTOR_INFO[actor];
    const ctx = uid ? env.authenticatedContext(uid, { roles }) : env.unauthenticatedContext();
    return ctx.storage();
  };

  beforeAll(async () => {
    const [host, port] = emulatorHost!.split(':');
    env = await rut.initializeTestEnvironment({
      projectId: 'demo-praticos-storage',
      storage: { rules: readFileSync(RULES_FILE, 'utf8'), host, port: Number(port) },
    });
  });

  afterAll(async () => {
    await env?.cleanup();
  });

  beforeEach(async () => {
    await env.clearStorage();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const s = ctx.storage();
      for (const [path, meta] of SEED_FILES) await s.ref(path).putString('x', 'raw', meta);
    });
  });

  for (const c of STORAGE_CASES) {
    const gap = c.allow.join() !== c.shouldAllow.join();
    describe(`${c.title} (${c.id})${gap ? ' [GAP: regra diferente do esperado]' : ''}`, () => {
      for (const actor of ACTORS) {
        const allowed = c.allow.includes(actor);
        it(`${actor} ${allowed ? 'consegue' : 'é barrado'}`, async () => {
          const attempt = c.run(storageFor(actor));
          if (allowed) await rut.assertSucceeds(attempt);
          else await rut.assertFails(attempt);
        });
      }
    });
  }

  it('lista os caminhos abertos para quem não é da empresa (gaps conhecidos)', () => {
    const open = STORAGE_CASES.filter((c) => c.allow.includes('otherCompany')).map((c) => c.id);
    // Só diminui. Se crescer, alguém abriu um caminho novo para outras empresas.
    expect(open.length).toBeLessThanOrEqual(16);
  });
});
