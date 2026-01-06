const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// Definição dos Formulários Globais por Segmento
const GLOBAL_FORMS = {
  automotive: [
    {
      id: 'checklist_entrada_auto',
      title: 'Vistoria de Entrada (Veículo)',
      description: 'Checklist visual do estado do veículo na recepção.',
      isActive: true,
      items: [
        {
          id: 'lataria_fotos',
          label: 'Fotos da Lataria (Avarias)',
          type: 'photo_only',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'nivel_combustivel',
          label: 'Nível de Combustível',
          type: 'select',
          options: ['Reserva', '1/4', '1/2', '3/4', 'Cheio'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'luzes_painel',
          label: 'Luzes no Painel Acessas',
          type: 'checklist',
          options: ['Injeção', 'Freio ABS', 'Airbag', 'Bateria', 'Óleo'],
          required: false,
          allowPhotos: true,
        },
        {
          id: 'pertences',
          label: 'Pertences no Veículo',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'revisao_basica',
      title: 'Checklist de Revisão Básica',
      description: 'Itens obrigatórios na troca de óleo e filtros.',
      isActive: true,
      items: [
        {
          id: 'oleo_motor',
          label: 'Óleo do Motor Trocado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'filtro_oleo',
          label: 'Filtro de Óleo Trocado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'filtro_ar',
          label: 'Filtro de Ar Verificado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
      ],
    },
  ],
  hvac: [
    {
      id: 'laudo_instalacao',
      title: 'Laudo de Instalação',
      description: 'Registro fotográfico e técnico da instalação.',
      isActive: true,
      items: [
        {
          id: 'foto_evaporadora',
          label: 'Foto da Evaporadora (Interna)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'foto_condensadora',
          label: 'Foto da Condensadora (Externa)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'teste_dreno',
          label: 'Teste de Dreno Realizado?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'vacuo_sistema',
          label: 'Vácuo no Sistema Realizado?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pressao_gas',
          label: 'Pressão do Gás (PSI)',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
      ],
    },
  ],
  smartphones: [
    {
      id: 'checklist_entrada_cel',
      title: 'Checklist de Entrada (Celular)',
      description: 'Verificação inicial do estado do aparelho.',
      isActive: true,
      items: [
        {
          id: 'tela_quebrada',
          label: 'Tela Quebrada/Trincada?',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'liga',
          label: 'Aparelho Liga?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'touch_id',
          label: 'Touch ID / Face ID Funciona?',
          type: 'boolean',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'senha_desbloqueio',
          label: 'Senha de Desbloqueio',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
  ],
};

async function seedForms() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  POPULANDO FORMULÁRIOS GLOBAIS (SEGMENTOS)');
  console.log('════════════════════════════════════════════════════════════\n');

  try {
    let created = 0;
    let updated = 0;

    for (const [segmentId, forms] of Object.entries(GLOBAL_FORMS)) {
      console.log(`📂 Processando segmento: ${segmentId}`);
      
      const segmentRef = db.collection('segments').doc(segmentId);
      // Garante que o segmento existe (apenas check rápido)
      const segDoc = await segmentRef.get();
      if (!segDoc.exists) {
        console.log(`⚠️  Segmento ${segmentId} não encontrado. Pulando...`);
        continue;
      }

      for (const form of forms) {
        const { id, ...data } = form;
        const formRef = segmentRef.collection('forms').doc(id);
        const formDoc = await formRef.get();

        if (formDoc.exists) {
            console.log(`   ↻ Atualizando form: ${data.title}`);
            await formRef.set({
                ...data,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            updated++;
        } else {
            console.log(`   + Criando form: ${data.title}`);
            await formRef.set({
                ...data,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            created++;
        }
      }
    }

    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  ✅ SEED DE FORMULÁRIOS CONCLUÍDO!');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  • Criados: ${created}`);
    console.log(`  • Atualizados: ${updated}`);
    console.log('════════════════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erro ao popular formulários:', error);
    process.exit(1);
  }
}

seedForms();
