/**
 * Role × path matrix against storage.rules.
 *
 * `allow` is who the rules let through (the test enforces it); only members
 * of the company (custom claim roles[companyId]) touch tenants/{companyId}/**
 * and companies/{companyId}/**. `allow` equals `shouldAllow` in every case;
 * if a rule ever has to differ, write why next to the case
 * (docs/E2E_ROLES_TESTING.md).
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
// clearStorage does not always finish before the next case: a new receipt needs a fresh name.
let uploads = 0;
const uniqueName = () => `new_${Date.now()}_${uploads++}`;

const ADMINS: Actor[] = ['owner', 'admin'];

export const STORAGE_CASES: StorageCase[] = [
  { id: 'orderPhoto.read', title: 'ver foto de OS', run: read(`${T}/orders/o1/photos/p1.png`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'orderPhoto.upload', title: 'enviar foto para OS', run: upload(`${T}/orders/o1/photos/new.png`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'orderPhoto.delete', title: 'apagar foto de OS', run: remove(`${T}/orders/o1/photos/p1.png`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'orderPhotos.list', title: 'listar fotos de OS', run: list(`${T}/orders/o1/photos`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'tenant.list', title: 'listar todos os arquivos da empresa', run: list(T), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'tenant.delete', title: 'apagar arquivo qualquer da empresa (exclusão de conta antiga)', run: remove(`${T}/orders/o1/documents/d1.pdf`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'tenant.deleteOther', title: 'apagar arquivo fora dos caminhos conhecidos', run: remove(`${T}/legacy/x.png`), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'orderDocument.read', title: 'baixar documento da OS', run: read(`${T}/orders/o1/documents/d1.pdf`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'orderDocument.upload', title: 'anexar documento na OS', run: upload(`${T}/orders/o1/documents/new.pdf`, PDF), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'paymentProof.read', title: 'ver comprovante de pagamento da OS', run: read(`${T}/orders/o1/payments/t1/f1.pdf`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'paymentProof.upload', title: 'enviar comprovante de pagamento da OS', run: upload(`${T}/orders/o1/payments/t1/new.pdf`, PDF), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'formPhoto.upload', title: 'enviar foto de checklist', run: upload(`${T}/orders/o1/forms/f1/new.png`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'productPhoto.upload', title: 'trocar foto de produto', run: upload(`${T}/products/prod1/new.png`), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'servicePhoto.upload', title: 'trocar foto de serviço', run: upload(`${T}/services/serv1/new.png`), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'devicePhoto.upload', title: 'trocar foto de aparelho', run: upload(`${T}/devices/dev1/new.png`), allow: ['owner', 'admin', 'supervisor'], shouldAllow: ['owner', 'admin', 'supervisor'] },
  { id: 'tenantLogo.upload', title: 'trocar logo da empresa', run: upload(`${T}/logo/new.png`), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'companyLogo.read', title: 'ver logo (caminho do cadastro)', run: read('companies/c1/logo/l1.png'), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'companyLogo.upload', title: 'trocar logo (caminho do cadastro)', run: upload('companies/c1/logo.png'), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'companyLogo.delete', title: 'apagar logo da empresa', run: remove('companies/c1/logo/l1.png'), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'userPhoto.upload', title: 'trocar foto de perfil de colega', run: upload(`${T}/users/ghost/new.png`), allow: ADMINS, shouldAllow: ADMINS },
  { id: 'userPhoto.own', title: 'trocar a própria foto de perfil (técnico)', run: upload(`${T}/users/tech1/new.png`), allow: [...ADMINS, 'technician'], shouldAllow: [...ADMINS, 'technician'] },
  { id: 'receipt.read', title: 'ver comprovante de recebimento', run: read(`${T}/receipts/r1/f1.pdf`), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'receipt.upload', title: 'enviar comprovante de recebimento', run: (s) => upload(`${T}/receipts/r1/${uniqueName()}.pdf`, PDF)(s), allow: MEMBERS, shouldAllow: MEMBERS },
  { id: 'receipt.overwrite', title: 'sobrescrever comprovante de recebimento', run: upload(`${T}/receipts/r1/f1.pdf`, PDF), allow: [], shouldAllow: [] },
  { id: 'unknown.path', title: 'gravar fora dos caminhos conhecidos', run: upload('anything/else.png'), allow: [], shouldAllow: [] },
  { id: 'tenant.unknownWrite', title: 'gravar caminho desconhecido dentro da empresa', run: upload(`${T}/legacy/new.png`), allow: [], shouldAllow: [] },
];

const SEED_FILES: [string, { contentType: string }][] = [
  [`${T}/orders/o1/photos/p1.png`, PNG],
  [`${T}/orders/o1/documents/d1.pdf`, PDF],
  [`${T}/orders/o1/payments/t1/f1.pdf`, PDF],
  [`${T}/receipts/r1/f1.pdf`, PDF],
  [`${T}/legacy/x.png`, PNG],
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

  it('nenhum caminho fica aberto para quem não é da empresa, e allow segue shouldAllow', () => {
    const outsiders: Actor[] = ['otherCompany', 'noCompany', 'anonymous'];
    expect(STORAGE_CASES.filter((c) => c.allow.some((a) => outsiders.includes(a))).map((c) => c.id)).toEqual([]);
    expect(STORAGE_CASES.filter((c) => c.allow.join() !== c.shouldAllow.join()).map((c) => c.id)).toEqual([]);
  });
});
