const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// Segmentos iniciais do sistema
const SEGMENTS = [
  {
    id: 'hvac',
    name: 'Ar Condicionado / Refrigeração',
    icon: '❄️',
    active: true,
    customFields: [
      { key: 'btus', label: 'BTUs', type: 'number' },
      {
        key: 'voltage',
        label: 'Voltagem',
        type: 'select',
        options: ['110V', '220V']
      }
    ],
  },
  {
    id: 'automotive',
    name: 'Oficina Mecânica / Automotivo',
    icon: '🚗',
    active: true,
    customFields: [
      { key: 'year', label: 'Ano', type: 'number' },
      { key: 'plate', label: 'Placa', type: 'text' },
    ],
  },
  {
    id: 'smartphones',
    name: 'Celulares / Smartphones',
    icon: '📱',
    active: true,
    customFields: [
      { key: 'imei', label: 'IMEI', type: 'text' },
      { key: 'storage', label: 'Armazenamento', type: 'text' },
    ],
  },
  {
    id: 'computers',
    name: 'Informática / Computadores',
    icon: '💻',
    active: true,
    customFields: [
      { key: 'serial', label: 'Número de Série', type: 'text' },
      { key: 'processor', label: 'Processador', type: 'text' },
    ],
  },
  {
    id: 'home-appliances',
    name: 'Eletrodomésticos',
    icon: '🏠',
    active: true,
    customFields: [
      {
        key: 'voltage',
        label: 'Voltagem',
        type: 'select',
        options: ['110V', '220V', 'Bivolt']
      },
    ],
  },
  {
    id: 'electronics',
    name: 'Eletrônicos em Geral',
    icon: '🔌',
    active: true,
    customFields: [],
  },
];

async function seedSegments() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  POPULANDO SEGMENTOS NO FIRESTORE');
  console.log('════════════════════════════════════════════════════════════\n');

  try {
    let created = 0;
    let updated = 0;

    for (const segment of SEGMENTS) {
      const { id, ...data } = segment;
      const segmentRef = db.collection('segments').doc(id);

      // Verifica se já existe
      const doc = await segmentRef.get();

      if (doc.exists) {
        console.log(`⚠️  Segment '${data.name}' (${id}) já existe - atualizando...`);
        await segmentRef.set({
          ...data,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        updated++;
      } else {
        console.log(`📝 Criando segment: ${data.name} (ID: ${id})`);
        await segmentRef.set({
          ...data,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        created++;
      }
    }

    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  ✅ SEED CONCLUÍDO COM SUCESSO!');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  • Segmentos criados: ${created}`);
    console.log(`  • Segmentos atualizados: ${updated}`);
    console.log(`  • Total processado: ${SEGMENTS.length}`);
    console.log('════════════════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erro ao popular segmentos:', error);
    process.exit(1);
  }
}

// Executar seed
seedSegments();
