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
    name: 'Automotivo',
    icon: '🚗',
    active: true,
    subspecialties: [
      {
        id: 'mechanical',
        icon: '🔧',
        name: { 'pt-BR': 'Oficina Mecânica', 'en-US': 'Auto Repair Shop', 'es-ES': 'Taller Mecánico' },
        description: { 'pt-BR': 'Manutenção e reparo mecânico de veículos', 'en-US': 'Vehicle maintenance and mechanical repair', 'es-ES': 'Mantenimiento y reparación mecánica de vehículos' },
      },
      {
        id: 'carwash',
        icon: '🚿',
        name: { 'pt-BR': 'Lava Car', 'en-US': 'Car Wash', 'es-ES': 'Lavado de Autos' },
        description: { 'pt-BR': 'Lavagem e limpeza de veículos', 'en-US': 'Vehicle washing and cleaning', 'es-ES': 'Lavado y limpieza de vehículos' },
      },
      {
        id: 'painting',
        icon: '🎨',
        name: { 'pt-BR': 'Funilaria e Pintura', 'en-US': 'Body & Paint Shop', 'es-ES': 'Carrocería y Pintura' },
        description: { 'pt-BR': 'Pintura, polimento e reparos estéticos', 'en-US': 'Painting, polishing and aesthetic repairs', 'es-ES': 'Pintura, pulido y reparaciones estéticas' },
      },
      {
        id: 'bodywork',
        icon: '🛠️',
        name: { 'pt-BR': 'Lanternagem / Reparos', 'en-US': 'Dent Repair', 'es-ES': 'Reparación de Abolladuras' },
        description: { 'pt-BR': 'Reparos de lataria e martelinho de ouro', 'en-US': 'Body panel repair and paintless dent removal', 'es-ES': 'Reparación de paneles y desabollado sin pintura' },
      },
    ],
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
    subspecialties: [
      {
        id: 'residential',
        icon: '🏠',
        name: { 'pt-BR': 'Residencial', 'en-US': 'Residential', 'es-ES': 'Residencial' },
        description: { 'pt-BR': 'Split, janela, residências', 'en-US': 'Split, window units, residential', 'es-ES': 'Split, ventana, residencial' },
      },
      {
        id: 'commercial',
        icon: '🏢',
        name: { 'pt-BR': 'Comercial/Industrial', 'en-US': 'Commercial/Industrial', 'es-ES': 'Comercial/Industrial' },
        description: { 'pt-BR': 'VRF, chiller, câmaras frias', 'en-US': 'VRF, chiller, cold rooms', 'es-ES': 'VRF, chiller, cámaras frigoríficas' },
      },
      {
        id: 'automotive_ac',
        icon: '🚗',
        name: { 'pt-BR': 'Ar Automotivo', 'en-US': 'Automotive AC', 'es-ES': 'AC Automotriz' },
        description: { 'pt-BR': 'Ar condicionado veicular', 'en-US': 'Vehicle air conditioning', 'es-ES': 'Aire acondicionado vehicular' },
      },
    ],
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
    subspecialties: [
      {
        id: 'desktop',
        icon: '🖥️',
        name: { 'pt-BR': 'Desktop/PC', 'en-US': 'Desktop/PC', 'es-ES': 'Desktop/PC' },
        description: { 'pt-BR': 'Montagem, upgrade, formatação', 'en-US': 'Assembly, upgrade, formatting', 'es-ES': 'Ensamblaje, actualización, formateo' },
      },
      {
        id: 'notebook',
        icon: '💻',
        name: { 'pt-BR': 'Notebooks', 'en-US': 'Laptops', 'es-ES': 'Portátiles' },
        description: { 'pt-BR': 'Reparo de tela, teclado, bateria', 'en-US': 'Screen, keyboard, battery repair', 'es-ES': 'Reparación de pantalla, teclado, batería' },
      },
      {
        id: 'networks',
        icon: '🌐',
        name: { 'pt-BR': 'Redes', 'en-US': 'Networks', 'es-ES': 'Redes' },
        description: { 'pt-BR': 'Cabeamento, switches, Wi-Fi', 'en-US': 'Cabling, switches, Wi-Fi', 'es-ES': 'Cableado, switches, Wi-Fi' },
      },
      {
        id: 'servers',
        icon: '🖧',
        name: { 'pt-BR': 'Servidores', 'en-US': 'Servers', 'es-ES': 'Servidores' },
        description: { 'pt-BR': 'RAID, backup, virtualização', 'en-US': 'RAID, backup, virtualization', 'es-ES': 'RAID, backup, virtualización' },
      },
    ],
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
  // ELÉTRICA (Residencial/Predial)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'electrical',
    name: 'Elétrica (Residencial/Predial)',
    icon: '⚡️',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Instalação', 'en-US': 'Installation' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Instalações', 'en-US': 'Installations' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Instalação', 'en-US': 'Add Installation' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Execução', 'en-US': 'In Progress' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Liberado', 'en-US': 'Released' }
      },

      // Campos (para evolução futura de campos dinâmicos)
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Tensão do Local', 'en-US': 'Site Voltage' },
        options: ['110V', '220V', 'Bivolt', 'Trifásico'],
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.mainBreaker',
        type: 'number',
        labels: { 'pt-BR': 'Disjuntor Geral (A)', 'en-US': 'Main Breaker (A)' },
        min: 1,
        max: 400,
        section: 'Especificações',
        order: 2,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // HIDRÁULICA (Encanador)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'plumbing',
    name: 'Hidráulica (Encanador)',
    icon: '💧',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Instalação', 'en-US': 'Installation' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Instalações', 'en-US': 'Installations' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Instalação', 'en-US': 'Add Installation' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Atendimento', 'en-US': 'In Service' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Resolvido', 'en-US': 'Resolved' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.waterType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Água', 'en-US': 'Water Type' },
        options: ['Fria', 'Quente', 'Ambas'],
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.pressure',
        type: 'select',
        labels: { 'pt-BR': 'Pressão', 'en-US': 'Pressure' },
        options: ['Baixa', 'Normal', 'Alta', 'Não avaliada'],
        section: 'Especificações',
        order: 2,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // SEGURANÇA ELETRÔNICA (CFTV/Alarmes)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'security',
    name: 'Segurança Eletrônica',
    icon: '📹',
    active: true,
    subspecialties: [
      {
        id: 'cctv',
        icon: '📹',
        name: { 'pt-BR': 'CFTV', 'en-US': 'CCTV', 'es-ES': 'CCTV' },
        description: { 'pt-BR': 'Câmeras, DVR/NVR, monitoramento', 'en-US': 'Cameras, DVR/NVR, monitoring', 'es-ES': 'Cámaras, DVR/NVR, monitoreo' },
      },
      {
        id: 'alarms',
        icon: '🚨',
        name: { 'pt-BR': 'Alarmes', 'en-US': 'Alarms', 'es-ES': 'Alarmas' },
        description: { 'pt-BR': 'Sensores, centrais, monitoramento 24h', 'en-US': 'Sensors, panels, 24h monitoring', 'es-ES': 'Sensores, centrales, monitoreo 24h' },
      },
      {
        id: 'access',
        icon: '🔐',
        name: { 'pt-BR': 'Controle de Acesso', 'en-US': 'Access Control', 'es-ES': 'Control de Acceso' },
        description: { 'pt-BR': 'Biometria, catracas, RFID', 'en-US': 'Biometrics, turnstiles, RFID', 'es-ES': 'Biometría, torniquetes, RFID' },
      },
      {
        id: 'fence',
        icon: '⚡',
        name: { 'pt-BR': 'Cerca Elétrica', 'en-US': 'Electric Fence', 'es-ES': 'Cerca Eléctrica' },
        description: { 'pt-BR': 'Central de choque, hastes', 'en-US': 'Energizers, rods', 'es-ES': 'Energizadores, varillas' },
      },
    ],
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Sistema', 'en-US': 'System' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Sistemas', 'en-US': 'Systems' }
      },
      {
        key: 'device.serialNumber',
        type: 'label',
        labels: { 'pt-BR': 'Identificador', 'en-US': 'Identifier' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Instalação', 'en-US': 'Installing' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Operacional', 'en-US': 'Operational' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.systemType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Sistema', 'en-US': 'System Type' },
        options: ['CFTV', 'Alarme', 'Cerca elétrica', 'Controle de acesso', 'Interfonia'],
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.channels',
        type: 'select',
        labels: { 'pt-BR': 'Canais', 'en-US': 'Channels' },
        options: ['4', '8', '16', '32'],
        section: 'Especificações',
        order: 2,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // ENERGIA SOLAR
  // ═══════════════════════════════════════════════════════════
  {
    id: 'solar',
    name: 'Energia Solar',
    icon: '☀️',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Sistema', 'en-US': 'System' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Sistemas', 'en-US': 'Systems' }
      },
      {
        key: 'device.serialNumber',
        type: 'label',
        labels: { 'pt-BR': 'Nº do Inversor', 'en-US': 'Inverter Serial' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Instalação', 'en-US': 'Installing' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Gerando', 'en-US': 'Generating' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.kwp',
        type: 'number',
        labels: { 'pt-BR': 'Potência do Sistema (kWp)', 'en-US': 'System Power (kWp)' },
        min: 0,
        max: 999,
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.panelCount',
        type: 'number',
        labels: { 'pt-BR': 'Qtd. de Placas', 'en-US': 'Panel Count' },
        min: 0,
        max: 999,
        section: 'Especificações',
        order: 2,
      },
      {
        key: 'device.installationDate',
        type: 'date',
        labels: { 'pt-BR': 'Data de Instalação', 'en-US': 'Installation Date' },
        section: 'Instalação',
        order: 3,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // IMPRESSORAS / COPIADORAS
  // ═══════════════════════════════════════════════════════════
  {
    id: 'printers',
    name: 'Impressoras / Copiadoras',
    icon: '🖨️',
    active: true,
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Impressora', 'en-US': 'Printer' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Impressoras', 'en-US': 'Printers' }
      },
      {
        key: 'device.serialNumber',
        type: 'label',
        labels: { 'pt-BR': 'Número de Série', 'en-US': 'Serial Number' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Manutenção', 'en-US': 'Under Maintenance' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.technology',
        type: 'select',
        labels: { 'pt-BR': 'Tecnologia', 'en-US': 'Technology' },
        options: ['Laser', 'Jato de tinta', 'Térmica', 'Matricial', 'Outra'],
        section: 'Especificações',
        order: 1,
      },
      {
        key: 'device.isColor',
        type: 'select',
        labels: { 'pt-BR': 'Colorida?', 'en-US': 'Color?' },
        options: ['Sim', 'Não'],
        section: 'Especificações',
        order: 2,
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
