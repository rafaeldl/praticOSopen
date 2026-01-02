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

// Collections que mantêm mesma estrutura (apenas mudam de lugar)
const COLLECTIONS_TO_ROLLBACK = [
  'orders',
  'customers',
  'devices',
  'products',
  'services',
];

async function rollbackAll() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  INICIANDO ROLLBACK DE DADOS (NODE.JS)');
  console.log('════════════════════════════════════════════════════════════\n');
  console.log('  Este script reverte:');
  console.log('  1. /companies/{companyId}/{collection} → /{collection}');
  console.log('  2. /companies/{companyId}/memberships → /roles');
  console.log('  3. Limpa user.companies dos usuários afetados\n');
  console.log('  ⚠️  ATENÇÃO: Isso pode causar perda de dados se houver');
  console.log('  alterações feitas apenas na nova estrutura!\n');

  if (!readline.keyInYN('Você tem certeza absoluta que deseja executar o ROLLBACK?')) {
    process.exit(0);
  }

  const report = { restored: 0, errors: 0 };

  const companiesSnapshot = await db.collection('companies').get();
  console.log(`► Encontradas ${companiesSnapshot.size} empresas.`);

  // Cache de dados das companies para usar no rollback de memberships
  const companiesData = new Map();
  for (const company of companiesSnapshot.docs) {
    companiesData.set(company.id, company.data());
  }

  for (const company of companiesSnapshot.docs) {
    console.log(`\n► Processando empresa: ${company.id}`);

    // 1. Rollback collections normais
    for (const collection of COLLECTIONS_TO_ROLLBACK) {
      const result = await rollbackCollection(company.id, collection);
      report.restored += result.restored;
      report.errors += result.errors;
    }

    // 2. Rollback memberships → roles
    const membershipResult = await rollbackMembershipsToRoles(
      company.id,
      companiesData.get(company.id)
    );
    report.restored += membershipResult.restored;
    report.errors += membershipResult.errors;
  }

  // 3. Limpar user.companies
  console.log('\n► Limpando user.companies...');
  const cleanupResult = await cleanupUserCompanies();
  report.restored += cleanupResult.cleaned;
  report.errors += cleanupResult.errors;

  console.log('\n════════════════════════════════════════════════════════════');
  console.log('  ROLLBACK CONCLUÍDO');
  console.log(`  Total restaurado: ${report.restored}`);
  console.log(`  Total erros: ${report.errors}`);
  console.log('════════════════════════════════════════════════════════════');
  console.log('\n  📋 Próximos passos:');
  console.log('  1. Execute npm run refresh-claims para limpar claims');
  console.log('  2. Faça deploy do app com código legado\n');
}

async function rollbackCollection(companyId, collectionName) {
  const result = { restored: 0, errors: 0 };

  const snapshot = await db
    .collection('companies')
    .doc(companyId)
    .collection(collectionName)
    .get();

  if (snapshot.empty) return result;

  console.log(`  - Restaurando ${collectionName} (${snapshot.size} docs)...`);

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    try {
      const oldRef = db.collection(collectionName).doc(doc.id);
      batch.set(oldRef, doc.data(), { merge: true });

      batchCount++;
      result.restored++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    } catch (e) {
      console.error(`    ✗ Erro ao restaurar ${doc.id}: ${e.message}`);
      result.errors++;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return result;
}

// ════════════════════════════════════════════════════════════════════════════
// ROLLBACK MEMBERSHIPS → ROLES
//
// Converte a estrutura nova (Membership) de volta para a legada (UserRole)
// ════════════════════════════════════════════════════════════════════════════

async function rollbackMembershipsToRoles(companyId, companyData) {
  const result = { restored: 0, errors: 0 };

  const snapshot = await db
    .collection('companies')
    .doc(companyId)
    .collection('memberships')
    .get();

  if (snapshot.empty) return result;

  console.log(`  - Restaurando memberships → roles (${snapshot.size} docs)...`);

  // Criar CompanyAggr para o campo company do UserRole
  const companyAggr = {
    id: companyId,
    name: companyData?.name || null,
  };

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    try {
      const membership = doc.data();
      const userId = doc.id;

      // Converter Membership → UserRole (estrutura legada)
      // O ID do documento roles era gerado automaticamente, então criamos um novo
      const roleDocId = `${companyId}_${userId}`;
      const roleRef = db.collection('roles').doc(roleDocId);

      const userRoleData = {
        user: membership.user || { id: userId },
        role: membership.role,
        company: companyAggr,
        createdAt: membership.joinedAt || admin.firestore.FieldValue.serverTimestamp(),
        createdBy: membership.user || { id: userId },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: membership.user || { id: userId },
      };

      batch.set(roleRef, userRoleData, { merge: true });

      batchCount++;
      result.restored++;

      if (batchCount >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    } catch (e) {
      console.error(`    ✗ Erro ao restaurar membership ${doc.id}: ${e.message}`);
      result.errors++;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  return result;
}

// ════════════════════════════════════════════════════════════════════════════
// CLEANUP USER.COMPANIES
//
// Remove o array companies dos usuários (estrutura legada não usava)
// ════════════════════════════════════════════════════════════════════════════

async function cleanupUserCompanies() {
  const result = { cleaned: 0, errors: 0 };

  const snapshot = await db.collection('users').get();

  if (snapshot.empty) return result;

  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    try {
      const userData = doc.data();

      // Só limpa se tiver o campo companies
      if (userData.companies && Array.isArray(userData.companies) && userData.companies.length > 0) {
        batch.update(doc.ref, {
          companies: admin.firestore.FieldValue.delete(),
        });

        batchCount++;
        result.cleaned++;

        if (batchCount >= BATCH_SIZE) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }
    } catch (e) {
      console.error(`    ✗ Erro ao limpar user ${doc.id}: ${e.message}`);
      result.errors++;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`  ✓ ${result.cleaned} usuários limpos.`);
  return result;
}

rollbackAll().catch(console.error);
