const { initializeFirebase, admin } = require('./firebase-init');
const readline = require('readline-sync');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

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

async function migrateAll() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  INICIANDO MIGRAÇÃO DE DADOS PARA SUBCOLLECTIONS (NODE.JS)');
  console.log('════════════════════════════════════════════════════════════\n');

  if (!readline.keyInYN('Você tem certeza que deseja iniciar a migração em PRODUÇÃO?')) {
    console.log('Operação cancelada.');
    process.exit(0);
  }

  const report = {
    migrated: 0,
    skipped: 0,
    errors: 0
  };

  for (const collection of COLLECTIONS_TO_MIGRATE) {
    const result = await migrateCollection(collection);
    report.migrated += result.migrated;
    report.skipped += result.skipped;
    report.errors += result.errors;
  }

  console.log('\n════════════════════════════════════════════════════════════');
  console.log('  MIGRAÇÃO CONCLUÍDA');
  console.log(`  Total migrado: ${report.migrated} documentos`);
  console.log(`  Total pulado: ${report.skipped} documentos`);
  console.log(`  Total erros: ${report.errors}`);
  console.log('════════════════════════════════════════════════════════════');
}

async function migrateCollection(collectionName) {
  console.log(`► Migrando collection: ${collectionName}`);
  
  const result = { migrated: 0, skipped: 0, errors: 0 };
  const snapshot = await db.collection(collectionName).get();
  
  if (snapshot.empty) {
    console.log(`  Collection ${collectionName} vazia.`);
    return result;
  }

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    try {
      const data = doc.data();
      const companyId = data.company?.id;

      if (!companyId) {
        // console.log(`  ⚠️  Doc ${doc.id} sem company.id - pulando`);
        result.skipped++;
        continue;
      }

      const newRef = db
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .doc(doc.id);

      // Verificação de existência (opcional, pode ser lento em grandes volumes)
      // Para performance máxima em cutover, podemos assumir overwrite ou usar create/update
      // Aqui vamos ler para garantir integridade (idempotência)
      const existingDoc = await newRef.get();
      
      if (existingDoc.exists) {
        const existingData = existingDoc.data();
        if (shouldSkip(existingData, data)) {
          result.skipped++;
          continue;
        }
      }

      batch.set(newRef, data);
      batchCount++;
      result.migrated++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        process.stdout.write(`  ✓ Processados: ${result.migrated}...\r`);
        batch = db.batch();
        batchCount = 0;
      }

    } catch (e) {
      console.error(`  ✗ Erro ao migrar ${doc.id}:`, e);
      result.errors++;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }
  
  console.log(`  ✓ ${collectionName}: ${result.migrated} migrados, ${result.skipped} pulados.`);
  return result;
}

function shouldSkip(existingData, newData) {
  const existingUpdated = existingData.updatedAt;
  const newUpdated = newData.updatedAt;

  if (!existingUpdated || !newUpdated) return true; // Na dúvida, não sobrescreve se já existe

  // Comparação de Strings (ISO8601) ou Timestamps
  if (typeof existingUpdated === 'string' && typeof newUpdated === 'string') {
    return existingUpdated >= newUpdated;
  }
  
  // Se for objeto Firestore Timestamp
  if (existingUpdated.toDate && newUpdated.toDate) {
    return existingUpdated.toDate() >= newUpdated.toDate();
  }

  return true; // Default skip
}

migrateAll().catch(console.error);
