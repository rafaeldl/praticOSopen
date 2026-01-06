const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// Segmentos iniciais do sistema com labels dinâmicos e campos customizados
const SEGMENTS = [
  // ═══════════════════════════════════════════════════════════
  // AUTOMOTIVO
  // ═══════════════════════════════════════════════════════════
  {
    id: 'automotive',
    name: 'Oficina Mecânica',
    icon: '🚗',
    active: true,
    customFields: [
      // Labels customizados (type: "label")
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Veículo', 'en-US': 'Vehicle' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Veículos', 'en-US': 'Vehicles' }
      },
      {
        key: 'device.brand',
        type: 'label',
        labels: { 'pt-BR': 'Montadora', 'en-US': 'Manufacturer' }
      },
      {
        key: 'device.model',
        type: 'label',
        labels: { 'pt-BR': 'Modelo', 'en-US': 'Model' }
      },
      {
        key: 'device.serialNumber',
        type: 'label',
        labels: { 'pt-BR': 'Placa', 'en-US': 'License Plate' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Veículo', 'en-US': 'Add Vehicle' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Veículo', 'en-US': 'Edit Vehicle' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Conserto', 'en-US': 'Under Repair' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Pronto para Retirada', 'en-US': 'Ready for Pickup' }
      },

      // Campos customizados (campos reais do form)
      {
        key: 'device.year',
        type: 'number',
        labels: { 'pt-BR': 'Ano', 'en-US': 'Year' },
        required: true,
        min: 1900,
        max: 2030,
        section: 'Identificação',
        order: 1,
      },
      {
        key: 'device.mileage',
        type: 'number',
        labels: { 'pt-BR': 'Quilometragem', 'en-US': 'Mileage' },
        suffix: 'km',
        section: 'Estado',
        order: 2,
      },
      {
        key: 'device.color',
        type: 'text',
        labels: { 'pt-BR': 'Cor', 'en-US': 'Color' },
        section: 'Identificação',
        order: 3,
      },
      {
        key: 'device.chassis',
        type: 'text',
        labels: { 'pt-BR': 'Chassi', 'en-US': 'Chassis' },
        maxLength: 17,
        section: 'Identificação',
        order: 4,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // HVAC (Ar Condicionado / Refrigeração)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'hvac',
    name: 'Ar Condicionado / Refrigeração',
    icon: '❄️',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Equipamento', 'en-US': 'Equipment' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Equipamentos', 'en-US': 'Equipment' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Equipamento', 'en-US': 'Add Equipment' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Equipamento', 'en-US': 'Edit Equipment' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Manutenção', 'en-US': 'Under Maintenance' }
      },

      // Campos customizados
      {
        key: 'device.btus',
        type: 'select',
        labels: { 'pt-BR': 'BTUs', 'en-US': 'BTUs' },
        required: true,
        options: ['7000', '9000', '12000', '18000', '22000', '24000', '30000'],
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Voltagem', 'en-US': 'Voltage' },
        required: true,
        options: ['110V', '220V', 'Bifásico'],
        section: 'Especificações',
        order: 2,
      },
      {
        key: 'device.gasType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Gás', 'en-US': 'Gas Type' },
        options: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A'],
        section: 'Especificações',
        order: 3,
      },
      {
        key: 'device.installationDate',
        type: 'date',
        labels: { 'pt-BR': 'Data de Instalação', 'en-US': 'Installation Date' },
        section: 'Instalação',
        order: 4,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // SMARTPHONES
  // ═══════════════════════════════════════════════════════════
  {
    id: 'smartphones',
    name: 'Assistência Técnica - Celulares',
    icon: '📱',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Aparelho', 'en-US': 'Device' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Aparelhos', 'en-US': 'Devices' }
      },
      {
        key: 'device.brand',
        type: 'label',
        labels: { 'pt-BR': 'Fabricante', 'en-US': 'Manufacturer' }
      },
      {
        key: 'device.serialNumber',
        type: 'label',
        labels: { 'pt-BR': 'IMEI', 'en-US': 'IMEI' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Aparelho', 'en-US': 'Add Device' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Aparelho', 'en-US': 'Edit Device' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Reparo', 'en-US': 'Under Repair' }
      },
      {
        key: 'status.pending',
        type: 'label',
        labels: { 'pt-BR': 'Aguardando Orçamento', 'en-US': 'Awaiting Quote' }
      },

      // Campos customizados
      {
        key: 'device.imei',
        type: 'text',
        labels: { 'pt-BR': 'IMEI', 'en-US': 'IMEI' },
        required: true,
        maxLength: 15,
        pattern: '^[0-9]{15}$',
        placeholder: '123456789012345',
        section: 'Identificação',
        order: 1,
      },
      {
        key: 'device.storage',
        type: 'select',
        labels: { 'pt-BR': 'Armazenamento', 'en-US': 'Storage' },
        options: ['64GB', '128GB', '256GB', '512GB', '1TB'],
        section: 'Especificações',
        order: 2,
      },
      {
        key: 'device.color',
        type: 'text',
        labels: { 'pt-BR': 'Cor', 'en-US': 'Color' },
        section: 'Identificação',
        order: 3,
      },
      {
        key: 'device.batteryHealth',
        type: 'number',
        labels: { 'pt-BR': 'Saúde da Bateria', 'en-US': 'Battery Health' },
        suffix: '%',
        min: 0,
        max: 100,
        section: 'Diagnóstico',
        order: 4,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // INFORMÁTICA
  // ═══════════════════════════════════════════════════════════
  {
    id: 'computers',
    name: 'Informática',
    icon: '💻',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Computador', 'en-US': 'Computer' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Computadores', 'en-US': 'Computers' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Computador', 'en-US': 'Add Computer' }
      },

      // Campos customizados
      {
        key: 'device.processor',
        type: 'text',
        labels: { 'pt-BR': 'Processador', 'en-US': 'Processor' },
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.ram',
        type: 'text',
        labels: { 'pt-BR': 'Memória RAM', 'en-US': 'RAM Memory' },
        section: 'Especificações',
        order: 2,
      },
      {
        key: 'device.storage',
        type: 'text',
        labels: { 'pt-BR': 'Armazenamento', 'en-US': 'Storage' },
        section: 'Especificações',
        order: 3,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // ELETRODOMÉSTICOS
  // ═══════════════════════════════════════════════════════════
  {
    id: 'appliances',
    name: 'Eletrodomésticos',
    icon: '🔌',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Eletrodoméstico', 'en-US': 'Appliance' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Eletrodomésticos', 'en-US': 'Appliances' }
      },

      // Campos customizados
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Voltagem', 'en-US': 'Voltage' },
        required: true,
        options: ['110V', '220V', 'Bivolt'],
        section: 'Especificações',
        order: 1,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // OUTRO (Genérico)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'other',
    name: 'Outro',
    icon: '🔧',
    active: true,
    customFields: [], // Sem customizações, usa padrões do sistema
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
