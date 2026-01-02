const admin = require('firebase-admin');
const readline = require('readline-sync');

admin.initializeApp();
const db = admin.firestore();
const BATCH_SIZE = 500;
const COLLECTIONS_TO_MIGRATE = [
  'orders',
  'customers',
  'devices',
  'products',
  'services',
  'roles',
];

async function rollbackAll() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  INICIANDO ROLLBACK DE DADOS (NODE.JS)');
  console.log('════════════════════════════════════════════════════════════\n');
  console.log('ATENÇÃO: Isso copiará dados das subcollections de volta para a raiz.');
  
  if (!readline.keyInYN('Você tem certeza absoluta que deseja executar o ROLLBACK?')) {
    process.exit(0);
  }

  const companiesSnapshot = await db.collection('companies').get();
  console.log(`► Encontradas ${companiesSnapshot.size} empresas.`);

  for (const company of companiesSnapshot.docs) {
    console.log(`\n► Processando empresa: ${company.id}`);
    
    for (const collection of COLLECTIONS_TO_MIGRATE) {
      await rollbackCollection(company.id, collection);
    }
  }

  console.log('\n════════════════════════════════════════════════════════════');
  console.log('  ROLLBACK CONCLUÍDO');
  console.log('════════════════════════════════════════════════════════════');
}

async function rollbackCollection(companyId, collectionName) {
  const snapshot = await db
    .collection('companies')
    .doc(companyId)
    .collection(collectionName)
    .get();

  if (snapshot.empty) return;

  console.log(`  - Restaurando ${collectionName} (${snapshot.size} docs)...`);

  let batch = db.batch();
  let batchCount = 0;
  let totalRestored = 0;

  for (const doc of snapshot.docs) {
    const oldRef = db.collection(collectionName).doc(doc.id);
    batch.set(oldRef, doc.data(), { merge: true });
    
    batchCount++;
    totalRestored++;

    if (batchCount >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }
}

rollbackAll().catch(console.error);
