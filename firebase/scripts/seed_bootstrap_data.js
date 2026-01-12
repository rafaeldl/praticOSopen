const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════
// DADOS DE BOOTSTRAP POR SEGMENTO/SUBCATEGORIA
// ═══════════════════════════════════════════════════════════════════════════
// Importa dados modularizados de ./bootstrap/
// Cada segmento está em seu próprio arquivo com traduções (pt-BR, en-US, es-ES)

const BOOTSTRAP_DATA = require('./bootstrap');

// ═══════════════════════════════════════════════════════════════════════════
// FUNÇÃO DE SEED
// ═══════════════════════════════════════════════════════════════════════════

async function seedBootstrapData() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  POPULANDO DADOS DE BOOTSTRAP NO FIRESTORE');
  console.log('════════════════════════════════════════════════════════════\n');

  try {
    let created = 0;
    let updated = 0;
    let errors = 0;

    for (const [segmentId, subspecialties] of Object.entries(BOOTSTRAP_DATA)) {
      console.log(`\n📦 Processando segmento: ${segmentId}`);

      // Verifica se o segmento existe
      const segmentRef = db.collection('segments').doc(segmentId);
      const segmentDoc = await segmentRef.get();

      if (!segmentDoc.exists) {
        console.log(`  ⚠️  Segmento '${segmentId}' não existe - pulando...`);
        errors++;
        continue;
      }

      // Pega o cliente compartilhado do segmento
      const sharedCustomer = subspecialties._customer;

      // Itera sobre as subspecialties
      for (const [subspecialtyId, data] of Object.entries(subspecialties)) {
        // Pula _customer (é apenas metadata)
        if (subspecialtyId === '_customer') continue;

        const bootstrapRef = segmentRef.collection('bootstrap').doc(subspecialtyId);
        const bootstrapDoc = await bootstrapRef.get();

        // Monta o documento de bootstrap
        const bootstrapData = {
          services: data.services || [],
          products: data.products || [],
          devices: data.devices || [],
          customer: sharedCustomer || data.customer || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (bootstrapDoc.exists) {
          console.log(`  ⚠️  ${segmentId}/${subspecialtyId} já existe - atualizando...`);
          await bootstrapRef.set(bootstrapData, { merge: true });
          updated++;
        } else {
          console.log(`  ✅ Criando ${segmentId}/${subspecialtyId}`);
          bootstrapData.createdAt = admin.firestore.FieldValue.serverTimestamp();
          await bootstrapRef.set(bootstrapData);
          created++;
        }
      }
    }

    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  ✅ SEED DE BOOTSTRAP CONCLUÍDO COM SUCESSO!');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  • Documentos criados: ${created}`);
    console.log(`  • Documentos atualizados: ${updated}`);
    console.log(`  • Erros (segmentos não encontrados): ${errors}`);
    console.log('════════════════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erro ao popular dados de bootstrap:', error);
    process.exit(1);
  }
}

// Executar seed
seedBootstrapData();
