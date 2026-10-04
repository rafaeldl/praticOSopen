/**
 * Recompute Claims Script
 * Recomputes the `roles` custom claim of every user from memberships verified
 * against server-side company data (same logic as the updateUserClaims trigger)
 * and compares it with the current claims.
 *
 * Output never includes emails or names: users are identified by uid prefix.
 *
 * Usage (dry run, default; uses Application Default Credentials):
 *   npm run claims:recompute
 *
 * Apply changes:
 *   npm run claims:recompute -- --apply
 *
 * Emulator:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
 *   GCLOUD_PROJECT=demo-praticos npm run claims:recompute
 */

import * as admin from 'firebase-admin';

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'praticos';
const APPLY = process.argv.includes('--apply');
const PAGE_SIZE = 300;
const AUTH_BATCH = 100;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

// membership.service logs dropped entries with the full uid; the diff below
// already reports them by uid prefix, so those lines are suppressed here.
const originalWarn = console.warn;
console.warn = (...args: unknown[]) => {
  if (typeof args[0] === 'string' && args[0].startsWith('[Membership]')) return;
  originalWarn(...args);
};

type Roles = Record<string, string>;

interface RoleDiff {
  added: string[];
  removed: string[];
  changed: string[];
}

const short = (id: string) => `${id.slice(0, 6)}…`;

function diffRoles(current: Roles, next: Roles): RoleDiff {
  const added: string[] = [];
  const removed: string[] = [];
  const changed: string[] = [];
  for (const [cid, role] of Object.entries(next)) {
    if (!(cid in current)) added.push(`${short(cid)}=${role}`);
    else if (current[cid] !== role) changed.push(`${short(cid)}:${current[cid]}->${role}`);
  }
  for (const [cid, role] of Object.entries(current)) {
    if (!(cid in next)) removed.push(`${short(cid)}=${role}`);
  }
  return { added, removed, changed };
}

function normalizeRoles(value: unknown): Roles {
  if (!value || typeof value !== 'object') return {};
  const roles: Roles = {};
  for (const [cid, role] of Object.entries(value as Record<string, unknown>)) {
    if (typeof role === 'string') roles[cid] = role;
  }
  return roles;
}

async function main() {
  // Imported after initializeApp so the shared firestore.service reuses this app.
  const { buildRolesClaim } = await import('../src/services/membership.service');
  const db = admin.firestore();
  const auth = admin.auth();

  console.log(`Project: ${PROJECT_ID} | Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}`);

  const stats = { users: 0, unchanged: 0, changed: 0, applied: 0, noAuthUser: 0, errors: 0 };
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    last = page.docs[page.docs.length - 1];

    for (let i = 0; i < page.docs.length; i += AUTH_BATCH) {
      const docs = page.docs.slice(i, i + AUTH_BATCH);
      const authResult = await auth.getUsers(docs.map((d) => ({ uid: d.id })));
      const authUsers = new Map(authResult.users.map((u) => [u.uid, u]));

      for (const doc of docs) {
        stats.users++;
        const uid = doc.id;
        const authUser = authUsers.get(uid);
        if (!authUser) {
          stats.noAuthUser++;
          continue;
        }

        try {
          const companies = doc.get('companies');
          const next = await buildRolesClaim(uid, Array.isArray(companies) ? companies : []);
          const claims = authUser.customClaims || {};
          const current = normalizeRoles(claims.roles);
          const diff = diffRoles(current, next);

          if (!diff.added.length && !diff.removed.length && !diff.changed.length) {
            stats.unchanged++;
            continue;
          }

          stats.changed++;
          const parts = [
            diff.added.length ? `+[${diff.added.join(', ')}]` : '',
            diff.removed.length ? `-[${diff.removed.join(', ')}]` : '',
            diff.changed.length ? `~[${diff.changed.join(', ')}]` : '',
          ].filter(Boolean);
          console.log(`uid=${short(uid)} ${parts.join(' ')}`);

          if (APPLY) {
            await auth.setCustomUserClaims(uid, { ...claims, roles: next });
            stats.applied++;
          }
        } catch (error) {
          stats.errors++;
          console.error(`uid=${short(uid)} error: ${(error as Error).message}`);
        }
      }
    }
  }

  console.log('\nSummary');
  console.log(`  users scanned:         ${stats.users}`);
  console.log(`  unchanged:             ${stats.unchanged}`);
  console.log(`  with differences:      ${stats.changed}`);
  console.log(`  applied:               ${stats.applied}`);
  console.log(`  without auth account:  ${stats.noAuthUser}`);
  console.log(`  errors:                ${stats.errors}`);
  if (!APPLY && stats.changed) console.log('\nDry run only. Re-run with --apply to update claims.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal:', (error as Error).message);
    process.exit(1);
  });
