const { initializeFirebase, admin } = require('./firebase-init');
const readline = require('readline-sync');

// Inicializar Firebase (aceita caminho do service account como argumento)
let db;
try {
  initializeFirebase(process.argv[2]);
  db = admin.firestore();
} catch (error) {
  process.exit(1);
}

const BATCH_SIZE = 500;

async function refreshClaims() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  REFRESH DE USER CLAIMS');
  console.log('════════════════════════════════════════════════════════════\n');
  console.log('Este script força a Cloud Function updateUserClaims a rodar');
  console.log('para todos os usuários, atualizando seus custom claims.\n');
  console.log('Estrutura dos claims:');
  console.log('  { roles: { "companyId": "admin" | "manager" | "user" } }\n');

  if (!readline.keyInYN('Deseja forçar a atualização de claims para TODOS os usuários?')) {
    process.exit(0);
  }

  let snapshot;
  try {
    snapshot = await db.collection('users').get();
  } catch (error) {
    if (error.message && error.message.includes('Could not load the default credentials')) {
      console.error('\n❌ ERRO DE AUTENTICAÇÃO ao acessar o Firestore');
      console.error('As credenciais não foram configuradas corretamente.\n');
      console.error('⚠️  LEMBRE-SE:');
      console.error('   O arquivo google-services.json é para o CLIENT SDK (app Flutter),');
      console.error('   não para o Admin SDK! Você precisa de um Service Account JSON.\n');
      console.error('📋 SOLUÇÕES:\n');
      console.error('1. Obtenha um Service Account JSON:');
      console.error('   https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk\n');
      console.error('2. Configure a variável de ambiente:');
      console.error('   export GOOGLE_APPLICATION_CREDENTIALS="/caminho/para/service-account.json"');
      console.error('   npm run refresh-claims\n');
      console.error('3. Ou passe o arquivo como argumento:');
      console.error('   npm run refresh-claims /caminho/para/service-account.json\n');
      console.error('📖 Guia completo: firebase/scripts/COMO_OBTER_CREDENCIAIS.md');
      console.error('🔍 Verifique: npm run verificar-credenciais\n');
      process.exit(1);
    }
    throw error;
  }
  console.log(`► Usuários encontrados: ${snapshot.size}`);

  let batch = db.batch();
  let batchCount = 0;
  let processed = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
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

  console.log(`\n\n  ✓ Concluído! ${processed} usuários processados.`);
  console.log('  A Cloud Function updateUserClaims será disparada para cada um.');
  console.log('\n  📋 Próximos passos:');
  console.log('  1. Acompanhe os logs no Firebase Console → Functions');
  console.log('  2. Os usuários precisarão fazer logout/login para o token atualizar');
  console.log('  3. Ou use FirebaseAuth.instance.currentUser.getIdToken(true) no app\n');
}

refreshClaims().catch((error) => {
  console.error('\n❌ ERRO ao executar o script:');
  console.error(error.message);
  if (error.stack) {
    console.error('\nStack trace:', error.stack);
  }
  process.exit(1);
});
