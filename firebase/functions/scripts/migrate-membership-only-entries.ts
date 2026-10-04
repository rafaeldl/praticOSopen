/**
 * Migrate Membership-Only Entries Script
 * Finds user company entries whose only server-side backing is a
 * `companies/{cid}/memberships/{uid}` document (the user is neither the owner
 * nor listed in `companies/{cid}.users`) and adds the user to
 * `companies/{cid}.users` with the membership role, so that membership
 * verification (owner + users array) keeps recognizing them.
 *
 * Output never includes emails or names: uid/cid prefixes only.
 *
 * Usage (dry run, default; uses Application Default Credentials):
 *   npm run memberships:migrate
 *
 * Apply changes:
 *   npm run memberships:migrate -- --apply
 *
 * Emulator:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=demo-praticos npm run memberships:migrate
 */

import * as admin from 'firebase-admin';

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'praticos';
const APPLY = process.argv.includes('--apply');
const PAGE_SIZE = 300;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();
const short = (id: string) => `${id.slice(0, 6)}…`;

type Data = FirebaseFirestore.DocumentData;

function ownerId(owner: unknown): string | null {
  if (typeof owner === 'string') return owner;
  if (owner && typeof owner === 'object') {
    const id = (owner as { id?: unknown }).id;
    return typeof id === 'string' ? id : null;
  }
  return null;
}

function inUsersArray(company: Data, uid: string): boolean {
  const users: unknown[] = Array.isArray(company.users) ? company.users : [];
  return users.some((u) => (u as { user?: { id?: unknown } } | null)?.user?.id === uid);
}

function userAggr(uid: string, user: Data): Record<string, string> {
  const aggr: Record<string, string> = { id: uid };
  if (typeof user.name === 'string') aggr.name = user.name;
  if (typeof user.email === 'string' && user.email) aggr.email = user.email;
  return aggr;
}

async function main() {
  console.log(`Project: ${PROJECT_ID} | Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}`);

  const stats = { users: 0, entries: 0, backed: 0, membershipOnly: 0, migrated: 0, unbacked: 0, errors: 0 };
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) break;
    last = page.docs[page.docs.length - 1];

    for (const userDoc of page.docs) {
      stats.users++;
      const uid = userDoc.id;
      const user = userDoc.data();
      const entries: unknown[] = Array.isArray(user.companies) ? user.companies : [];
      const seen = new Set<string>();

      for (const item of entries) {
        const cid = (item as { company?: { id?: unknown } } | null)?.company?.id;
        if (typeof cid !== 'string' || !cid || seen.has(cid)) continue;
        seen.add(cid);
        stats.entries++;

        try {
          const companyRef = db.collection('companies').doc(cid);
          const companySnap = await companyRef.get();
          const company = companySnap.data();
          if (!companySnap.exists || !company) {
            stats.unbacked++;
            console.log(`uid=${short(uid)} cid=${short(cid)} company not found (left as is)`);
            continue;
          }
          if (ownerId(company.owner) === uid || inUsersArray(company, uid)) {
            stats.backed++;
            continue;
          }

          const membershipSnap = await companyRef.collection('memberships').doc(uid).get();
          const role = membershipSnap.exists ? membershipSnap.get('role') : undefined;
          if (typeof role !== 'string' || !role) {
            stats.unbacked++;
            console.log(`uid=${short(uid)} cid=${short(cid)} no server backing (left as is)`);
            continue;
          }

          stats.membershipOnly++;
          console.log(`uid=${short(uid)} cid=${short(cid)} membership-only role=${role}${APPLY ? '' : ' (would add to users)'}`);
          if (!APPLY) continue;

          const added = await db.runTransaction(async (tx) => {
            const fresh = await tx.get(companyRef);
            const data = fresh.data();
            if (!fresh.exists || !data || inUsersArray(data, uid)) return false;
            const users: unknown[] = Array.isArray(data.users) ? data.users : [];
            tx.update(companyRef, {
              users: [...users, { user: userAggr(uid, user), role }],
              updatedAt: new Date().toISOString(),
            });
            return true;
          });
          if (added) stats.migrated++;
        } catch (error) {
          stats.errors++;
          console.error(`uid=${short(uid)} cid=${short(cid)} error: ${(error as Error).message}`);
        }
      }
    }
  }

  console.log('\nSummary');
  console.log(`  users scanned:           ${stats.users}`);
  console.log(`  company entries:         ${stats.entries}`);
  console.log(`  backed (owner/users):    ${stats.backed}`);
  console.log(`  membership-only:         ${stats.membershipOnly}`);
  console.log(`  migrated:                ${stats.migrated}`);
  console.log(`  without server backing:  ${stats.unbacked}`);
  console.log(`  errors:                  ${stats.errors}`);
  if (!APPLY && stats.membershipOnly) console.log('\nDry run only. Re-run with --apply to migrate.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal:', (error as Error).message);
    process.exit(1);
  });
