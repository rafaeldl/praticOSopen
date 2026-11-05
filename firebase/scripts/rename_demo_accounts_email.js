/**
 * Moves the demo accounts (docs/DEMO_ACCOUNTS.md) from @praticos.com.br,
 * a domain we don't own, to @praticos.app. Same uid, data and password.
 *
 * Updates Firebase Auth, users/{uid}.email, memberships user.email and
 * companies owner.email. Audit fields (createdBy/updatedBy) stay as history.
 *
 * Usage (Application Default Credentials with access to project praticos):
 *   cd firebase/functions
 *   node ../scripts/rename_demo_accounts_email.js           # dry run
 *   node ../scripts/rename_demo_accounts_email.js --apply   # writes
 * Safe to run twice.
 */
const admin = require(require.resolve('firebase-admin', { paths: [process.cwd()] }));

admin.initializeApp({ projectId: 'praticos' });

const APPLY = process.argv.includes('--apply');
const PREFIXES = ['demo', 'demo-pt', 'demo-en', 'demo-es'];

async function main() {
  const db = admin.firestore();
  const moves = {}; // oldEmail -> newEmail
  for (const p of PREFIXES) moves[`${p}@praticos.com.br`] = `${p}@praticos.app`;

  for (const [oldEmail, newEmail] of Object.entries(moves)) {
    let user;
    try {
      user = await admin.auth().getUserByEmail(oldEmail);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      user = await admin.auth().getUserByEmail(newEmail).catch(() => null);
      if (!user) {
        console.log(`${oldEmail}: not found`);
        continue;
      }
    }
    console.log(`auth ${user.uid}: ${user.email} -> ${newEmail}`);
    if (APPLY && user.email !== newEmail) {
      await admin.auth().updateUser(user.uid, { email: newEmail, emailVerified: true });
    }
  }

  const writes = [];
  const users = await db.collection('users').where('email', 'in', Object.keys(moves)).get();
  users.forEach((d) => writes.push([d.ref, { email: moves[d.get('email')] }]));

  // No collection-group index on user.email, so filter here (few docs).
  const memberships = await db.collectionGroup('memberships').get();
  memberships.forEach((d) => {
    const next = moves[d.get('user.email')];
    if (next) writes.push([d.ref, { 'user.email': next }]);
  });

  const companies = await db.collection('companies')
    .where('owner.email', 'in', Object.keys(moves)).get();
  companies.forEach((d) => writes.push([d.ref, { 'owner.email': moves[d.get('owner.email')] }]));

  for (const [ref, data] of writes) {
    console.log(`${ref.path}: ${JSON.stringify(data)}`);
    if (APPLY) await ref.update(data);
  }
  console.log(APPLY ? `done, ${writes.length} docs` : `dry run, ${writes.length} docs (use --apply)`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
