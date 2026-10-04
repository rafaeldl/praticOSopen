/**
 * Seed Private Membership Script
 * Builds the server-only member map `companies/{cid}/private/membership`
 * ({ members: { [uid]: role }, updatedAt }) used to verify company membership.
 *
 * Sources (never the user's own `companies` entries alone):
 * - `companies/{cid}.users[]` entries;
 * - users whose `companies` entry is backed by a `companies/{cid}/memberships/{uid}`
 *   document with a role.
 * Members already present in the map are kept unchanged (idempotent). The
 * company owner is verified by ownership and is not added. Entries without any
 * server-side backing are only reported.
 *
 * Output never includes emails or names: uid/cid prefixes only.
 *
 * Usage (dry run, default; uses Application Default Credentials):
 *   npm run memberships:seed
 * Apply:
 *   npm run memberships:seed -- --apply
 * Emulator:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=demo-praticos npm run memberships:seed
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
type Members = Record<string, string>;

function ownerId(owner: unknown): string | null {
  if (typeof owner === 'string') return owner;
  if (owner && typeof owner === 'object') {
    const id = (owner as { id?: unknown }).id;
    return typeof id === 'string' ? id : null;
  }
  return null;
}

function lower(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim().toLowerCase() : null;
}

function usersArrayMembers(company: Data): Members {
  const members: Members = {};
  const users: unknown[] = Array.isArray(company.users) ? company.users : [];
  for (const item of users) {
    const entry = item as { user?: { id?: unknown }; role?: unknown } | null;
    const uid = entry?.user?.id;
    const role = lower(entry?.role);
    if (typeof uid === 'string' && uid && role && !(uid in members)) members[uid] = role;
  }
  return members;
}

async function* paginate(collection: string) {
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db.collection(collection).orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    if (page.empty) return;
    last = page.docs[page.docs.length - 1];
    yield* page.docs;
  }
}

async function main() {
  console.log(`Project: ${PROJECT_ID} | Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}`);
  const stats = {
    userEntries: 0,
    ownerEntries: 0,
    usersArrayEntries: 0,
    membershipDocEntries: 0,
    unbacked: 0,
    companies: 0,
    companiesChanged: 0,
    membersAdded: 0,
    errors: 0,
  };

  // 1. User entries backed only by a memberships document
  const fromMembershipDocs: Record<string, Members> = {};
  for await (const userDoc of paginate('users')) {
    const uid = userDoc.id;
    const entries: unknown[] = Array.isArray(userDoc.get('companies')) ? userDoc.get('companies') : [];
    const seen = new Set<string>();
    for (const item of entries) {
      const cid = (item as { company?: { id?: unknown } } | null)?.company?.id;
      if (typeof cid !== 'string' || !cid || seen.has(cid)) continue;
      seen.add(cid);
      stats.userEntries++;

      const companySnap = await db.collection('companies').doc(cid).get();
      const company = companySnap.data();
      if (!companySnap.exists || !company) {
        stats.unbacked++;
        console.log(`uid=${short(uid)} cid=${short(cid)} company not found (no backing)`);
        continue;
      }
      if (ownerId(company.owner) === uid) {
        stats.ownerEntries++;
        continue;
      }
      if (uid in usersArrayMembers(company)) {
        stats.usersArrayEntries++;
        continue;
      }
      const membershipSnap = await db.collection('companies').doc(cid).collection('memberships').doc(uid).get();
      const role = membershipSnap.exists ? lower(membershipSnap.get('role')) : null;
      if (!role) {
        stats.unbacked++;
        console.log(`uid=${short(uid)} cid=${short(cid)} no server-side backing`);
        continue;
      }
      stats.membershipDocEntries++;
      (fromMembershipDocs[cid] ??= {})[uid] = role;
    }
  }

  // 2. Per company: existing map ∪ users[] ∪ membership-doc-backed entries
  for await (const companyDoc of paginate('companies')) {
    stats.companies++;
    const cid = companyDoc.id;
    const company = companyDoc.data();
    const owner = ownerId(company.owner);
    const candidates: Members = { ...usersArrayMembers(company), ...(fromMembershipDocs[cid] || {}) };
    for (const uid of Object.keys(candidates)) {
      if (uid === owner) delete candidates[uid];
    }
    if (!Object.keys(candidates).length) continue;

    try {
      const privateRef = db.collection('companies').doc(cid).collection('private').doc('membership');
      const additions = await db.runTransaction(async (tx) => {
        const snap = await tx.get(privateRef);
        const existing: Members = (snap.get('members') as Members | undefined) || {};
        const toAdd: Members = {};
        for (const [uid, role] of Object.entries(candidates)) {
          if (!(uid in existing)) toAdd[uid] = role;
        }
        if (APPLY && Object.keys(toAdd).length) {
          tx.set(
            privateRef,
            { members: toAdd, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
            { merge: true },
          );
        }
        return toAdd;
      });

      const added = Object.entries(additions);
      if (!added.length) continue;
      stats.companiesChanged++;
      stats.membersAdded += added.length;
      const list = added.map(([uid, role]) => `${short(uid)}=${role}`).join(', ');
      console.log(`cid=${short(cid)} +[${list}]${APPLY ? '' : ' (dry run)'}`);
    } catch (error) {
      stats.errors++;
      console.error(`cid=${short(cid)} error: ${(error as Error).message}`);
    }
  }

  console.log('\nSummary');
  console.log(`  user company entries:          ${stats.userEntries}`);
  console.log(`    backed by ownership:         ${stats.ownerEntries}`);
  console.log(`    backed by users array:       ${stats.usersArrayEntries}`);
  console.log(`    backed by membership doc:    ${stats.membershipDocEntries}`);
  console.log(`    without server backing:      ${stats.unbacked}`);
  console.log(`  companies scanned:             ${stats.companies}`);
  console.log(`  companies ${APPLY ? 'updated' : 'to update'}:            ${stats.companiesChanged}`);
  console.log(`  members ${APPLY ? 'added' : 'to add'}:                ${stats.membersAdded}`);
  console.log(`  errors:                        ${stats.errors}`);
  if (!APPLY && stats.membersAdded) console.log('\nDry run only. Re-run with --apply to write.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal:', (error as Error).message);
    process.exit(1);
  });
