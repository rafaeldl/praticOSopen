const admin = require('firebase-admin');
const readline = require('readline-sync');

admin.initializeApp();
const db = admin.firestore();
const BATCH_SIZE = 500;

async function refreshClaims() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  REFRESH DE USER CLAIMS (NODE.JS)');
  console.log('════════════════════════════════════════════════════════════\n');

  if (!readline.keyInYN('Deseja forçar a atualização de claims para TODOS os usuários?')) {
    process.exit(0);
  }

  const snapshot = await db.collection('users').get();
  console.log(`► Usuários encontrados: ${snapshot.size}`);

  let batch = db.batch();
  let batchCount = 0;
  let processed = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.reference, {
      '_claimsRefreshedAt': admin.firestore.FieldValue.serverTimestamp()
    });

    batchCount++;
    processed++;

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      process.stdout.write(`  ✓ Processados: ${processed}...\r`);
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`\n\n  ✓ Concluído! ${processed} usuários tocados.`);
  console.log('  Acompanhe os logs da function updateUserClaims.');
}

refreshClaims().catch(console.error);
