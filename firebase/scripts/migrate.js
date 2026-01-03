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

// Collections que mantêm estrutura (apenas movem para subcollection)
const COLLECTIONS_TO_MIGRATE = [
  'orders',
  'customers',
  'devices',
  'products',
  'services',
];

async function migrateAll() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  INICIANDO MIGRAÇÃO DE DADOS PARA SUBCOLLECTIONS (NODE.JS)');
  console.log('════════════════════════════════════════════════════════════\n');
  console.log('  Este script migra:');
  console.log('  1. Collections → /companies/{companyId}/{collection}');
  console.log('  2. roles → /companies/{companyId}/memberships + user.companies\n');

  if (!readline.keyInYN('Você tem certeza que deseja iniciar a migração em PRODUÇÃO?')) {
    console.log('Operação cancelada.');
    process.exit(0);
  }

  const report = {
    migrated: 0,
    skipped: 0,
    errors: 0
  };

  // 1. Migrar collections normais
  for (const collection of COLLECTIONS_TO_MIGRATE) {
    const result = await migrateCollection(collection);
    report.migrated += result.migrated;
    report.skipped += result.skipped;
    report.errors += result.errors;
  }

  // 2. Migrar roles → memberships (com transformação)
  const rolesResult = await migrateRolesToMemberships();
  report.migrated += rolesResult.migrated;
  report.skipped += rolesResult.skipped;
  report.errors += rolesResult.errors;

  console.log('\n════════════════════════════════════════════════════════════');
  console.log('  MIGRAÇÃO CONCLUÍDA');
  console.log(`  Total migrado: ${report.migrated} documentos`);
  console.log(`  Total pulado: ${report.skipped} documentos`);
  console.log(`  Total erros: ${report.errors}`);
  console.log('════════════════════════════════════════════════════════════');
  console.log('\n  📋 Próximos passos:');
  console.log('  1. Execute npm run refresh-claims para atualizar custom claims');
  console.log('  2. Teste o app com a nova estrutura');
  console.log('  3. Após validação, execute npm run cleanup para remover dados legados\n');
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

// ════════════════════════════════════════════════════════════════════════════
// MIGRAÇÃO ROLES → MEMBERSHIPS
//
// Arquitetura:
// - Source of Truth: user.companies (array de CompanyRoleAggr)
// - Índice Reverso: /companies/{companyId}/memberships/{userId}
// ════════════════════════════════════════════════════════════════════════════

async function migrateRolesToMemberships() {
  console.log('► Migrando roles → memberships');

  const result = { migrated: 0, skipped: 0, errors: 0 };
  const snapshot = await db.collection('roles').get();

  if (snapshot.empty) {
    console.log('  Collection roles vazia.');
    return result;
  }

  // Agrupar roles por userId para atualizar user.companies de uma vez
  const rolesByUser = new Map();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const companyId = data.company?.id;
    const userId = data.user?.id;

    if (!companyId || !userId) {
      result.skipped++;
      continue;
    }

    if (!rolesByUser.has(userId)) {
      rolesByUser.set(userId, []);
    }
    rolesByUser.get(userId).push({
      docId: doc.id,
      data,
      companyId,
      userId,
    });
  }

  console.log(`  Encontrados ${snapshot.size} roles para ${rolesByUser.size} usuários`);

  // Processar cada usuário
  for (const [userId, roles] of rolesByUser) {
    try {
      const batch = db.batch();

      // 1. Atualizar user.companies (source of truth)
      const userRef = db.collection('users').doc(userId);
      const userDoc = await userRef.get();

      let existingCompanies = [];
      if (userDoc.exists) {
        existingCompanies = userDoc.data().companies || [];
      }

      // Mapear companies existentes por ID
      const companiesMap = new Map();
      for (const c of existingCompanies) {
        if (c.company?.id) {
          companiesMap.set(c.company.id, c);
        }
      }

      // Adicionar/atualizar de roles
      for (const role of roles) {
        const { data, companyId } = role;

        // Atualizar user.companies se ainda não existe
        if (!companiesMap.has(companyId)) {
          companiesMap.set(companyId, {
            company: data.company,
            role: data.role,
          });
        }

        // 2. Criar membership (índice reverso)
        const membershipRef = db
          .collection('companies')
          .doc(companyId)
          .collection('memberships')
          .doc(userId);

        const membershipData = {
          userId: userId,
          user: data.user,
          role: data.role,
          joinedAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        };

        batch.set(membershipRef, membershipData, { merge: true });
        result.migrated++;
      }

      // Atualizar user.companies
      if (userDoc.exists) {
        const updatedCompanies = Array.from(companiesMap.values());
        batch.update(userRef, { companies: updatedCompanies });
      }

      await batch.commit();
      process.stdout.write(`  ✓ Usuário ${userId}: ${roles.length} roles migrados\r`);

    } catch (e) {
      console.error(`  ✗ Erro ao migrar roles do usuário ${userId}:`, e.message);
      result.errors += roles.length;
    }
  }

  console.log(`\n  ✓ roles → memberships: ${result.migrated} migrados, ${result.skipped} pulados.`);
  return result;
}

migrateAll().catch(console.error);
