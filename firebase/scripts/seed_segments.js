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
  // GLOBAL LABELS (aplicáveis a todos os segmentos)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'global',
    name: 'Global',
    nameI18n: { 'pt-BR': 'Global', 'en-US': 'Global', 'es-ES': 'Global' },
    icon: '🌍',
    active: true,
    customFields: [
      // Entidades globais
      {
        key: 'customer._entity',
        type: 'label',
        labels: { 'pt-BR': 'Cliente', 'en-US': 'Customer', 'es-ES': 'Cliente' }
      },
      {
        key: 'customer._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Clientes', 'en-US': 'Customers', 'es-ES': 'Clientes' }
      },
      {
        key: 'service_order._entity',
        type: 'label',
        labels: { 'pt-BR': 'Ordem de Serviço', 'en-US': 'Work Order', 'es-ES': 'Orden de Servicio' }
      },
      {
        key: 'service_order._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Ordens de Serviço', 'en-US': 'Work Orders', 'es-ES': 'Órdenes de Servicio' }
      },
      // Campos comuns de device
      {
        key: 'device.description',
        type: 'label',
        labels: { 'pt-BR': 'Descrição', 'en-US': 'Description', 'es-ES': 'Descripción' }
      },
      {
        key: 'device.notes',
        type: 'label',
        labels: { 'pt-BR': 'Observações', 'en-US': 'Notes', 'es-ES': 'Notas' }
      },
      // Campos comuns de customer
      {
        key: 'customer.name',
        type: 'label',
        labels: { 'pt-BR': 'Nome', 'en-US': 'Name', 'es-ES': 'Nombre' }
      },
      {
        key: 'customer.phone',
        type: 'text',
        labels: { 'pt-BR': 'Telefone', 'en-US': 'Phone', 'es-ES': 'Teléfono' },
        masksByCountry: {
          'BR': ['(99) 9999-9999', '(99) 99999-9999'],
          'US': ['(999) 999-9999'],
          'PT': ['999 999 999'],
          'ES': ['999 99 99 99'],
          'MX': ['99 9999 9999']
        },
        keyboardType: 'phone'
      },
      {
        key: 'customer.email',
        type: 'label',
        labels: { 'pt-BR': 'Email', 'en-US': 'Email', 'es-ES': 'Correo' }
      },
      {
        key: 'customer.address',
        type: 'label',
        labels: { 'pt-BR': 'Endereço', 'en-US': 'Address', 'es-ES': 'Dirección' }
      },
      // Configuração de máscaras de telefone por país
      {
        key: 'company.phone',
        type: 'text',
        labels: { 'pt-BR': 'Telefone', 'en-US': 'Phone', 'es-ES': 'Teléfono' },
        masksByCountry: {
          'BR': ['(99) 9999-9999', '(99) 99999-9999'],
          'US': ['(999) 999-9999'],
          'PT': ['999 999 999'],
          'ES': ['999 99 99 99'],
          'MX': ['99 9999 9999']
        },
        keyboardType: 'phone'
      },
      // Configuração de máscaras de CEP/ZIP por país
      {
        key: 'company.zipCode',
        type: 'text',
        labels: { 'pt-BR': 'CEP', 'en-US': 'ZIP Code', 'es-ES': 'Código Postal' },
        masksByCountry: {
          'BR': ['99999-999'],
          'US': ['99999', '99999-9999'],
          'PT': ['9999-999'],
          'ES': ['99999'],
          'MX': ['99999']
        },
        placeholder: '12345-678',
        keyboardType: 'number'
      },
      // Ações globais (device)
      {
        key: 'actions.delete_device',
        type: 'label',
        labels: { 'pt-BR': 'Excluir Dispositivo', 'en-US': 'Delete Device', 'es-ES': 'Eliminar Dispositivo' }
      },
      // Ações globais (customer)
      {
        key: 'actions.create_customer',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Cliente', 'en-US': 'Add Customer', 'es-ES': 'Agregar Cliente' }
      },
      {
        key: 'actions.edit_customer',
        type: 'label',
        labels: { 'pt-BR': 'Editar Cliente', 'en-US': 'Edit Customer', 'es-ES': 'Editar Cliente' }
      },
      // Ações globais (service order)
      {
        key: 'actions.create_service_order',
        type: 'label',
        labels: { 'pt-BR': 'Nova Ordem de Serviço', 'en-US': 'New Service Order', 'es-ES': 'Nueva Orden de Servicio' }
      },
      {
        key: 'actions.edit_service_order',
        type: 'label',
        labels: { 'pt-BR': 'Editar Ordem de Serviço', 'en-US': 'Edit Service Order', 'es-ES': 'Editar Orden de Servicio' }
      },
      // Ações globais (serviço)
      {
        key: 'actions.create_service',
        type: 'label',
        labels: { 'pt-BR': 'Novo Serviço', 'en-US': 'New Service', 'es-ES': 'Nuevo Servicio' }
      },
      {
        key: 'actions.edit_service',
        type: 'label',
        labels: { 'pt-BR': 'Editar Serviço', 'en-US': 'Edit Service', 'es-ES': 'Editar Servicio' }
      },
      // Ações globais (produto)
      {
        key: 'actions.create_product',
        type: 'label',
        labels: { 'pt-BR': 'Novo Produto', 'en-US': 'New Product', 'es-ES': 'Nuevo Producto' }
      },
      {
        key: 'actions.edit_product',
        type: 'label',
        labels: { 'pt-BR': 'Editar Produto', 'en-US': 'Edit Product', 'es-ES': 'Editar Producto' }
      },
      {
        key: 'actions.remove',
        type: 'label',
        labels: { 'pt-BR': 'Remover', 'en-US': 'Remove', 'es-ES': 'Quitar' }
      },
      {
        key: 'actions.confirm_deletion',
        type: 'label',
        labels: { 'pt-BR': 'Confirmar exclusão', 'en-US': 'Confirm deletion', 'es-ES': 'Confirmar eliminación' }
      },
      {
        key: 'actions.retry_again',
        type: 'label',
        labels: { 'pt-BR': 'Tentar novamente', 'en-US': 'Try again', 'es-ES': 'Intentar de nuevo' }
      },
      // Status globais
      {
        key: 'status.pending',
        type: 'label',
        labels: { 'pt-BR': 'Pendente', 'en-US': 'Pending', 'es-ES': 'Pendiente' }
      },
      {
        key: 'status.cancelled',
        type: 'label',
        labels: { 'pt-BR': 'Cancelado', 'en-US': 'Cancelled', 'es-ES': 'Cancelado' }
      },
      // Mensagens globais
      {
        key: 'messages.no_results_found',
        type: 'label',
        labels: { 'pt-BR': 'Nenhum resultado encontrado', 'en-US': 'No results found', 'es-ES': 'No se encontraron resultados' }
      },
      {
        key: 'messages.required',
        type: 'label',
        labels: { 'pt-BR': 'Obrigatório', 'en-US': 'Required', 'es-ES': 'Requerido' }
      },
      // Fotos
      {
        key: 'photos.change',
        type: 'label',
        labels: { 'pt-BR': 'Alterar Foto', 'en-US': 'Change Photo', 'es-ES': 'Cambiar Foto' }
      },
      {
        key: 'photos.add',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Foto', 'en-US': 'Add Photo', 'es-ES': 'Agregar Foto' }
      },
      {
        key: 'photos.delete',
        type: 'label',
        labels: { 'pt-BR': 'Excluir Foto', 'en-US': 'Delete Photo', 'es-ES': 'Eliminar Foto' }
      },
      {
        key: 'photos.set_as_cover',
        type: 'label',
        labels: { 'pt-BR': 'Definir como Capa', 'en-US': 'Set as Cover', 'es-ES': 'Establecer como Portada' }
      },
      // Produtos
      {
        key: 'product.quantity',
        type: 'label',
        labels: { 'pt-BR': 'Quantidade', 'en-US': 'Quantity', 'es-ES': 'Cantidad' }
      },
      {
        key: 'product.unit_value',
        type: 'label',
        labels: { 'pt-BR': 'Valor unitário', 'en-US': 'Unit value', 'es-ES': 'Valor unitario' }
      },
      {
        key: 'product.total',
        type: 'label',
        labels: { 'pt-BR': 'Total', 'en-US': 'Total', 'es-ES': 'Total' }
      },
      // Comum
      {
        key: 'common.save',
        type: 'label',
        labels: { 'pt-BR': 'Salvar', 'en-US': 'Save', 'es-ES': 'Guardar' }
      },
      {
        key: 'common.cancel',
        type: 'label',
        labels: { 'pt-BR': 'Cancelar', 'en-US': 'Cancel', 'es-ES': 'Cancelar' }
      },
      {
        key: 'common.confirm',
        type: 'label',
        labels: { 'pt-BR': 'Confirmar', 'en-US': 'Confirm', 'es-ES': 'Confirmar' }
      },
      {
        key: 'common.delete',
        type: 'label',
        labels: { 'pt-BR': 'Excluir', 'en-US': 'Delete', 'es-ES': 'Eliminar' }
      },
      {
        key: 'common.edit',
        type: 'label',
        labels: { 'pt-BR': 'Editar', 'en-US': 'Edit', 'es-ES': 'Editar' }
      },
      {
        key: 'common.search',
        type: 'label',
        labels: { 'pt-BR': 'Buscar', 'en-US': 'Search', 'es-ES': 'Buscar' }
      },
      {
        key: 'common.filter',
        type: 'label',
        labels: { 'pt-BR': 'Filtrar', 'en-US': 'Filter', 'es-ES': 'Filtrar' }
      },
      {
        key: 'common.sort',
        type: 'label',
        labels: { 'pt-BR': 'Ordenar', 'en-US': 'Sort', 'es-ES': 'Ordenar' }
      },
      {
        key: 'common.export',
        type: 'label',
        labels: { 'pt-BR': 'Exportar', 'en-US': 'Export', 'es-ES': 'Exportar' }
      },
      {
        key: 'common.import',
        type: 'label',
        labels: { 'pt-BR': 'Importar', 'en-US': 'Import', 'es-ES': 'Importar' }
      },
      {
        key: 'common.print',
        type: 'label',
        labels: { 'pt-BR': 'Imprimir', 'en-US': 'Print', 'es-ES': 'Imprimir' }
      },
      {
        key: 'common.notes',
        type: 'label',
        labels: { 'pt-BR': 'Observações', 'en-US': 'Notes', 'es-ES': 'Notas' }
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // AUTOMOTIVO
  // ═══════════════════════════════════════════════════════════
  {
    id: 'automotive',
    name: 'Automotivo',
    nameI18n: { 'pt-BR': 'Automotivo', 'en-US': 'Automotive', 'es-ES': 'Automotriz' },
    icon: '🚗',
    active: true,
    fieldService: false, // Workshop: cliente traz o veículo
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
        labels: { 'pt-BR': 'Veículo', 'en-US': 'Vehicle', 'es-ES': 'Vehículo' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Veículos', 'en-US': 'Vehicles', 'es-ES': 'Vehículos' }
      },
      {
        key: 'device.brand',
        type: 'label',
        labels: { 'pt-BR': 'Montadora', 'en-US': 'Manufacturer', 'es-ES': 'Fabricante' }
      },
      {
        key: 'device.model',
        type: 'label',
        labels: { 'pt-BR': 'Modelo', 'en-US': 'Model', 'es-ES': 'Modelo' }
      },
      // Configuração de máscara para placa/serial de veículo por país
      {
        key: 'device.serial',
        type: 'text',
        labels: { 'pt-BR': 'Placa', 'en-US': 'License Plate', 'es-ES': 'Placa' },
        masksByCountry: {
          'BR': ['AAA-9999', 'AAA9N99'], // Padrão antigo e Mercosul (Brasil)
          'US': ['AAA-9999', 'AAA 9999'], // Padrões variados nos EUA
          'PT': ['AA-99-AA', '99-AA-99'], // Portugal
          'ES': ['9999-AAA'], // Espanha
          'MX': ['AAA-99-99', 'AAA-999-A'] // México
        },
        textCapitalization: 'characters',
        required: true
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Veículo', 'en-US': 'Add Vehicle', 'es-ES': 'Agregar Vehículo' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Veículo', 'en-US': 'Edit Vehicle', 'es-ES': 'Editar Vehículo' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Conserto', 'en-US': 'Under Repair', 'es-ES': 'En Reparación' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Pronto para Retirada', 'en-US': 'Ready for Pickup', 'es-ES': 'Listo para Retiro' }
      },

      // Campos customizados (campos reais do form)
      {
        key: 'device.year',
        type: 'number',
        labels: { 'pt-BR': 'Ano', 'en-US': 'Year', 'es-ES': 'Año' },
        min: 1900,
        max: 2030,
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 1,
      },
      {
        key: 'device.mileage',
        type: 'number',
        labels: { 'pt-BR': 'Quilometragem', 'en-US': 'Mileage', 'es-ES': 'Kilometraje' },
        suffix: 'km',
        section: 'Estado',
        sectionI18n: { 'pt-BR': 'Estado', 'en-US': 'Condition', 'es-ES': 'Estado' },
        order: 2,
      },
      {
        key: 'device.color',
        type: 'text',
        labels: { 'pt-BR': 'Cor', 'en-US': 'Color', 'es-ES': 'Color' },
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 3,
      },
      {
        key: 'device.chassis',
        type: 'text',
        labels: { 'pt-BR': 'Chassi', 'en-US': 'Chassis', 'es-ES': 'Chasis' },
        maxLength: 17,
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 4,
      },

      // Campos customizados da OS
      {
        key: 'service_order.observation',
        type: 'textarea',
        labels: { 'pt-BR': 'Observação', 'en-US': 'Observation', 'es-ES': 'Observación' },
        placeholder: 'Ex: Cliente relata barulho no motor',
        section: 'Detalhes',
        sectionI18n: { 'pt-BR': 'Detalhes', 'en-US': 'Details', 'es-ES': 'Detalles' },
        order: 1,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // HVAC (Ar Condicionado / Refrigeração)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'hvac',
    name: 'Ar Condicionado / Refrigeração',
    nameI18n: {
      'pt-BR': 'Ar Condicionado / Refrigeração',
      'en-US': 'HVAC / Refrigeration',
      'es-ES': 'Aire Acondicionado / Refrigeración'
    },
    icon: '❄️',
    active: true,
    fieldService: true, // Atendimento no local do cliente
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
        labels: { 'pt-BR': 'Equipamento', 'en-US': 'Equipment', 'es-ES': 'Equipo' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Equipamentos', 'en-US': 'Equipment', 'es-ES': 'Equipos' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Equipamento', 'en-US': 'Add Equipment', 'es-ES': 'Agregar Equipo' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Equipamento', 'en-US': 'Edit Equipment', 'es-ES': 'Editar Equipo' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Manutenção', 'en-US': 'Under Maintenance', 'es-ES': 'En Mantenimiento' }
      },

      // Campos customizados
      {
        key: 'device.btus',
        type: 'select',
        labels: { 'pt-BR': 'BTUs', 'en-US': 'BTUs', 'es-ES': 'BTUs' },
        options: ['7000', '9000', '12000', '18000', '22000', '24000', '30000'],
        optionsI18n: [
          { value: '7000', labels: { 'pt-BR': '7000', 'en-US': '7000', 'es-ES': '7000' } },
          { value: '9000', labels: { 'pt-BR': '9000', 'en-US': '9000', 'es-ES': '9000' } },
          { value: '12000', labels: { 'pt-BR': '12000', 'en-US': '12000', 'es-ES': '12000' } },
          { value: '18000', labels: { 'pt-BR': '18000', 'en-US': '18000', 'es-ES': '18000' } },
          { value: '22000', labels: { 'pt-BR': '22000', 'en-US': '22000', 'es-ES': '22000' } },
          { value: '24000', labels: { 'pt-BR': '24000', 'en-US': '24000', 'es-ES': '24000' } },
          { value: '30000', labels: { 'pt-BR': '30000', 'en-US': '30000', 'es-ES': '30000' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Voltagem', 'en-US': 'Voltage', 'es-ES': 'Voltaje' },
        options: ['110V', '220V', 'two_phase'],
        optionsI18n: [
          { value: '110V', labels: { 'pt-BR': '110V', 'en-US': '110V', 'es-ES': '110V' } },
          { value: '220V', labels: { 'pt-BR': '220V', 'en-US': '220V', 'es-ES': '220V' } },
          { value: 'two_phase', labels: { 'pt-BR': 'Bifásico', 'en-US': 'Two-phase', 'es-ES': 'Bifásico' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
      {
        key: 'device.gasType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Gás', 'en-US': 'Gas Type', 'es-ES': 'Tipo de Gas' },
        options: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A'],
        optionsI18n: [
          { value: 'R-22', labels: { 'pt-BR': 'R-22', 'en-US': 'R-22', 'es-ES': 'R-22' } },
          { value: 'R-410A', labels: { 'pt-BR': 'R-410A', 'en-US': 'R-410A', 'es-ES': 'R-410A' } },
          { value: 'R-32', labels: { 'pt-BR': 'R-32', 'en-US': 'R-32', 'es-ES': 'R-32' } },
          { value: 'R-134a', labels: { 'pt-BR': 'R-134a', 'en-US': 'R-134a', 'es-ES': 'R-134a' } },
          { value: 'R-404A', labels: { 'pt-BR': 'R-404A', 'en-US': 'R-404A', 'es-ES': 'R-404A' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 3,
      },
      {
        key: 'device.installationDate',
        type: 'date',
        labels: { 'pt-BR': 'Data de Instalação', 'en-US': 'Installation Date', 'es-ES': 'Fecha de Instalación' },
        section: 'Instalação',
        sectionI18n: { 'pt-BR': 'Instalação', 'en-US': 'Installation', 'es-ES': 'Instalación' },
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
    nameI18n: { 'pt-BR': 'Assistência Técnica - Celulares', 'en-US': 'Phone Repair', 'es-ES': 'Servicio Técnico - Celulares' },
    icon: '📱',
    active: true,
    fieldService: false, // Workshop: cliente traz o aparelho
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Aparelho', 'en-US': 'Device', 'es-ES': 'Dispositivo' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Aparelhos', 'en-US': 'Devices', 'es-ES': 'Dispositivos' }
      },
      {
        key: 'device.brand',
        type: 'label',
        labels: { 'pt-BR': 'Fabricante', 'en-US': 'Manufacturer', 'es-ES': 'Fabricante' }
      },
      {
        key: 'device.serial',
        type: 'text',
        labels: { 'pt-BR': 'IMEI', 'en-US': 'IMEI', 'es-ES': 'IMEI' },
        masks: ['999999999999999'], // IMEI padrão (15 dígitos)
        placeholder: '123456789012345',
        keyboardType: 'number',
        maxLength: 15
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Aparelho', 'en-US': 'Add Device', 'es-ES': 'Agregar Dispositivo' }
      },
      {
        key: 'actions.edit_device',
        type: 'label',
        labels: { 'pt-BR': 'Editar Aparelho', 'en-US': 'Edit Device', 'es-ES': 'Editar Dispositivo' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Reparo', 'en-US': 'Under Repair', 'es-ES': 'En Reparación' }
      },
      {
        key: 'status.pending',
        type: 'label',
        labels: { 'pt-BR': 'Aguardando Orçamento', 'en-US': 'Awaiting Quote', 'es-ES': 'Esperando Presupuesto' }
      },

      // Campos customizados
      {
        key: 'device.storage',
        type: 'select',
        labels: { 'pt-BR': 'Armazenamento', 'en-US': 'Storage', 'es-ES': 'Almacenamiento' },
        options: ['64GB', '128GB', '256GB', '512GB', '1TB'],
        optionsI18n: [
          { value: '64GB', labels: { 'pt-BR': '64GB', 'en-US': '64GB', 'es-ES': '64GB' } },
          { value: '128GB', labels: { 'pt-BR': '128GB', 'en-US': '128GB', 'es-ES': '128GB' } },
          { value: '256GB', labels: { 'pt-BR': '256GB', 'en-US': '256GB', 'es-ES': '256GB' } },
          { value: '512GB', labels: { 'pt-BR': '512GB', 'en-US': '512GB', 'es-ES': '512GB' } },
          { value: '1TB', labels: { 'pt-BR': '1TB', 'en-US': '1TB', 'es-ES': '1TB' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
      {
        key: 'device.color',
        type: 'text',
        labels: { 'pt-BR': 'Cor', 'en-US': 'Color', 'es-ES': 'Color' },
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 3,
      },
      {
        key: 'device.batteryHealth',
        type: 'number',
        labels: { 'pt-BR': 'Saúde da Bateria', 'en-US': 'Battery Health', 'es-ES': 'Salud de la Batería' },
        suffix: '%',
        min: 0,
        max: 100,
        section: 'Diagnóstico',
        sectionI18n: { 'pt-BR': 'Diagnóstico', 'en-US': 'Diagnostics', 'es-ES': 'Diagnóstico' },
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
    nameI18n: { 'pt-BR': 'Informática', 'en-US': 'Computers', 'es-ES': 'Informática' },
    icon: '💻',
    active: true,
    fieldService: false, // Workshop: cliente traz o equipamento
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
        labels: { 'pt-BR': 'Computador', 'en-US': 'Computer', 'es-ES': 'Computadora' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Computadores', 'en-US': 'Computers', 'es-ES': 'Computadoras' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Computador', 'en-US': 'Add Computer', 'es-ES': 'Agregar Computadora' }
      },

      // Campos customizados
      {
        key: 'device.processor',
        type: 'text',
        labels: { 'pt-BR': 'Processador', 'en-US': 'Processor', 'es-ES': 'Procesador' },
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.ram',
        type: 'text',
        labels: { 'pt-BR': 'Memória RAM', 'en-US': 'RAM Memory', 'es-ES': 'Memoria RAM' },
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
      {
        key: 'device.storage',
        type: 'text',
        labels: { 'pt-BR': 'Armazenamento', 'en-US': 'Storage', 'es-ES': 'Almacenamiento' },
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
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
    nameI18n: { 'pt-BR': 'Eletrodomésticos', 'en-US': 'Appliances', 'es-ES': 'Electrodomésticos' },
    icon: '🔌',
    active: true,
    fieldService: true, // Assistência busca/atende no local do cliente
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Eletrodoméstico', 'en-US': 'Appliance', 'es-ES': 'Electrodoméstico' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Eletrodomésticos', 'en-US': 'Appliances', 'es-ES': 'Electrodomésticos' }
      },

      // Campos customizados
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Voltagem', 'en-US': 'Voltage', 'es-ES': 'Voltaje' },
        options: ['110V', '220V', 'dual_voltage'],
        optionsI18n: [
          { value: '110V', labels: { 'pt-BR': '110V', 'en-US': '110V', 'es-ES': '110V' } },
          { value: '220V', labels: { 'pt-BR': '220V', 'en-US': '220V', 'es-ES': '220V' } },
          { value: 'dual_voltage', labels: { 'pt-BR': 'Bivolt', 'en-US': 'Dual Voltage', 'es-ES': 'Doble Voltaje' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
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
    nameI18n: {
      'pt-BR': 'Elétrica (Residencial/Predial)',
      'en-US': 'Electrical (Residential/Building)',
      'es-ES': 'Eléctrica (Residencial/Edificios)'
    },
    icon: '⚡️',
    active: true,
    fieldService: true, // Atendimento no local do cliente
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Instalação', 'en-US': 'Installation', 'es-ES': 'Instalación' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Instalações', 'en-US': 'Installations', 'es-ES': 'Instalaciones' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Instalação', 'en-US': 'Add Installation', 'es-ES': 'Agregar Instalación' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Execução', 'en-US': 'In Progress', 'es-ES': 'En Progreso' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Liberado', 'en-US': 'Released', 'es-ES': 'Liberado' }
      },

      // Campos (para evolução futura de campos dinâmicos)
      {
        key: 'device.voltage',
        type: 'select',
        labels: { 'pt-BR': 'Tensão do Local', 'en-US': 'Site Voltage', 'es-ES': 'Voltaje del Lugar' },
        options: ['110V', '220V', 'dual_voltage', 'three_phase'],
        optionsI18n: [
          { value: '110V', labels: { 'pt-BR': '110V', 'en-US': '110V', 'es-ES': '110V' } },
          { value: '220V', labels: { 'pt-BR': '220V', 'en-US': '220V', 'es-ES': '220V' } },
          { value: 'dual_voltage', labels: { 'pt-BR': 'Bivolt', 'en-US': 'Dual Voltage', 'es-ES': 'Doble Voltaje' } },
          { value: 'three_phase', labels: { 'pt-BR': 'Trifásico', 'en-US': 'Three-phase', 'es-ES': 'Trifásico' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.mainBreaker',
        type: 'number',
        labels: { 'pt-BR': 'Disjuntor Geral (A)', 'en-US': 'Main Breaker (A)', 'es-ES': 'Interruptor General (A)' },
        min: 1,
        max: 400,
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
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
    nameI18n: { 'pt-BR': 'Hidráulica (Encanador)', 'en-US': 'Plumbing', 'es-ES': 'Fontanería (Fontanero)' },
    icon: '💧',
    active: true,
    fieldService: true, // Atendimento no local do cliente
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Instalação', 'en-US': 'Installation', 'es-ES': 'Instalación' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Instalações', 'en-US': 'Installations', 'es-ES': 'Instalaciones' }
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Instalação', 'en-US': 'Add Installation', 'es-ES': 'Agregar Instalación' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Atendimento', 'en-US': 'In Service', 'es-ES': 'En Servicio' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Resolvido', 'en-US': 'Resolved', 'es-ES': 'Resuelto' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.waterType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Água', 'en-US': 'Water Type', 'es-ES': 'Tipo de Agua' },
        options: ['cold', 'hot', 'both'],
        optionsI18n: [
          { value: 'cold', labels: { 'pt-BR': 'Fria', 'en-US': 'Cold', 'es-ES': 'Fría' } },
          { value: 'hot', labels: { 'pt-BR': 'Quente', 'en-US': 'Hot', 'es-ES': 'Caliente' } },
          { value: 'both', labels: { 'pt-BR': 'Ambas', 'en-US': 'Both', 'es-ES': 'Ambas' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.pressure',
        type: 'select',
        labels: { 'pt-BR': 'Pressão', 'en-US': 'Pressure', 'es-ES': 'Presión' },
        options: ['low', 'normal', 'high', 'not_assessed'],
        optionsI18n: [
          { value: 'low', labels: { 'pt-BR': 'Baixa', 'en-US': 'Low', 'es-ES': 'Baja' } },
          { value: 'normal', labels: { 'pt-BR': 'Normal', 'en-US': 'Normal', 'es-ES': 'Normal' } },
          { value: 'high', labels: { 'pt-BR': 'Alta', 'en-US': 'High', 'es-ES': 'Alta' } },
          { value: 'not_assessed', labels: { 'pt-BR': 'Não avaliada', 'en-US': 'Not assessed', 'es-ES': 'No evaluada' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
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
    nameI18n: { 'pt-BR': 'Segurança Eletrônica', 'en-US': 'Electronic Security', 'es-ES': 'Seguridad Electrónica' },
    icon: '📹',
    active: true,
    fieldService: true, // Atendimento no local do cliente
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
        labels: { 'pt-BR': 'Sistema', 'en-US': 'System', 'es-ES': 'Sistema' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Sistemas', 'en-US': 'Systems', 'es-ES': 'Sistemas' }
      },
      {
        key: 'device.serial',
        type: 'label',
        labels: { 'pt-BR': 'Identificador', 'en-US': 'Identifier', 'es-ES': 'Identificador' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Instalação', 'en-US': 'Installing', 'es-ES': 'En Instalación' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Operacional', 'en-US': 'Operational', 'es-ES': 'Operativo' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.systemType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Sistema', 'en-US': 'System Type', 'es-ES': 'Tipo de Sistema' },
        options: ['cctv', 'alarm', 'electric_fence', 'access_control', 'intercom'],
        optionsI18n: [
          { value: 'cctv', labels: { 'pt-BR': 'CFTV', 'en-US': 'CCTV', 'es-ES': 'CCTV' } },
          { value: 'alarm', labels: { 'pt-BR': 'Alarme', 'en-US': 'Alarm', 'es-ES': 'Alarma' } },
          { value: 'electric_fence', labels: { 'pt-BR': 'Cerca elétrica', 'en-US': 'Electric Fence', 'es-ES': 'Cerca eléctrica' } },
          { value: 'access_control', labels: { 'pt-BR': 'Controle de acesso', 'en-US': 'Access Control', 'es-ES': 'Control de acceso' } },
          { value: 'intercom', labels: { 'pt-BR': 'Interfonia', 'en-US': 'Intercom', 'es-ES': 'Intercomunicador' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.channels',
        type: 'select',
        labels: { 'pt-BR': 'Canais', 'en-US': 'Channels', 'es-ES': 'Canales' },
        options: ['4', '8', '16', '32'],
        optionsI18n: [
          { value: '4', labels: { 'pt-BR': '4', 'en-US': '4', 'es-ES': '4' } },
          { value: '8', labels: { 'pt-BR': '8', 'en-US': '8', 'es-ES': '8' } },
          { value: '16', labels: { 'pt-BR': '16', 'en-US': '16', 'es-ES': '16' } },
          { value: '32', labels: { 'pt-BR': '32', 'en-US': '32', 'es-ES': '32' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
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
    nameI18n: { 'pt-BR': 'Energia Solar', 'en-US': 'Solar Energy', 'es-ES': 'Energía Solar' },
    icon: '☀️',
    active: true,
    fieldService: true, // Atendimento no local do cliente
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Sistema', 'en-US': 'System', 'es-ES': 'Sistema' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Sistemas', 'en-US': 'Systems', 'es-ES': 'Sistemas' }
      },
      {
        key: 'device.serial',
        type: 'label',
        labels: { 'pt-BR': 'Nº do Inversor', 'en-US': 'Inverter Serial', 'es-ES': 'Nº del Inversor' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Instalação', 'en-US': 'Installing', 'es-ES': 'En Instalación' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Gerando', 'en-US': 'Generating', 'es-ES': 'Generando' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.kwp',
        type: 'number',
        labels: { 'pt-BR': 'Potência do Sistema (kWp)', 'en-US': 'System Power (kWp)', 'es-ES': 'Potencia del Sistema (kWp)' },
        min: 0,
        max: 999,
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.panelCount',
        type: 'number',
        labels: { 'pt-BR': 'Qtd. de Placas', 'en-US': 'Panel Count', 'es-ES': 'Cantidad de Paneles' },
        min: 0,
        max: 999,
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
      {
        key: 'device.installationDate',
        type: 'date',
        labels: { 'pt-BR': 'Data de Instalação', 'en-US': 'Installation Date', 'es-ES': 'Fecha de Instalación' },
        section: 'Instalação',
        sectionI18n: { 'pt-BR': 'Instalação', 'en-US': 'Installation', 'es-ES': 'Instalación' },
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
    nameI18n: { 'pt-BR': 'Impressoras / Copiadoras', 'en-US': 'Printers / Copiers', 'es-ES': 'Impresoras / Fotocopiadoras' },
    icon: '🖨️',
    active: true,
    fieldService: false, // Workshop: cliente traz a impressora
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Impressora', 'en-US': 'Printer', 'es-ES': 'Impresora' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Impressoras', 'en-US': 'Printers', 'es-ES': 'Impresoras' }
      },
      {
        key: 'device.serial',
        type: 'label',
        labels: { 'pt-BR': 'Número de Série', 'en-US': 'Serial Number', 'es-ES': 'Número de Serie' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Manutenção', 'en-US': 'Under Maintenance', 'es-ES': 'En Mantenimiento' }
      },

      // Campos (para evolução futura)
      {
        key: 'device.technology',
        type: 'select',
        labels: { 'pt-BR': 'Tecnologia', 'en-US': 'Technology', 'es-ES': 'Tecnología' },
        options: ['laser', 'inkjet', 'thermal', 'dot_matrix', 'other'],
        optionsI18n: [
          { value: 'laser', labels: { 'pt-BR': 'Laser', 'en-US': 'Laser', 'es-ES': 'Láser' } },
          { value: 'inkjet', labels: { 'pt-BR': 'Jato de tinta', 'en-US': 'Inkjet', 'es-ES': 'Inyección de tinta' } },
          { value: 'thermal', labels: { 'pt-BR': 'Térmica', 'en-US': 'Thermal', 'es-ES': 'Térmica' } },
          { value: 'dot_matrix', labels: { 'pt-BR': 'Matricial', 'en-US': 'Dot Matrix', 'es-ES': 'Matricial' } },
          { value: 'other', labels: { 'pt-BR': 'Outra', 'en-US': 'Other', 'es-ES': 'Otra' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 1,
      },
      {
        key: 'device.isColor',
        type: 'select',
        labels: { 'pt-BR': 'Colorida?', 'en-US': 'Color?', 'es-ES': '¿Color?' },
        options: ['yes', 'no'],
        optionsI18n: [
          { value: 'yes', labels: { 'pt-BR': 'Sim', 'en-US': 'Yes', 'es-ES': 'Sí' } },
          { value: 'no', labels: { 'pt-BR': 'Não', 'en-US': 'No', 'es-ES': 'No' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // MANUTENÇÃO PREDIAL (Construtoras + Administradoras + Facilities)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'building_maintenance',
    name: 'Manutenção Predial',
    nameI18n: { 'pt-BR': 'Manutenção Predial', 'en-US': 'Building Maintenance', 'es-ES': 'Mantenimiento de Edificios' },
    icon: '🏢',
    active: true,
    subspecialties: [
      {
        id: 'post_delivery_warranty',
        icon: '🏗️',
        name: { 'pt-BR': 'Garantia Pós-Entrega', 'en-US': 'Post-Delivery Warranty', 'es-ES': 'Garantía Post-Entrega' },
        description: { 'pt-BR': 'Assistência técnica de construtoras (NBR 15575)', 'en-US': 'Builder technical assistance (warranty)', 'es-ES': 'Asistencia técnica de constructoras (garantía)' },
      },
      {
        id: 'corrective_maintenance',
        icon: '🔧',
        name: { 'pt-BR': 'Manutenção Corretiva', 'en-US': 'Corrective Maintenance', 'es-ES': 'Mantenimiento Correctivo' },
        description: { 'pt-BR': 'Reparos em unidades e áreas comuns', 'en-US': 'Repairs in units and common areas', 'es-ES': 'Reparaciones en unidades y áreas comunes' },
      },
      {
        id: 'preventive_maintenance',
        icon: '📋',
        name: { 'pt-BR': 'Manutenção Preventiva', 'en-US': 'Preventive Maintenance', 'es-ES': 'Mantenimiento Preventivo' },
        description: { 'pt-BR': 'Inspeções programadas (NBR 5674)', 'en-US': 'Scheduled inspections', 'es-ES': 'Inspecciones programadas' },
      },
      {
        id: 'common_areas',
        icon: '🏊',
        name: { 'pt-BR': 'Áreas Comuns', 'en-US': 'Common Areas', 'es-ES': 'Áreas Comunes' },
        description: { 'pt-BR': 'Piscina, salão, playground, garagem', 'en-US': 'Pool, lounge, playground, garage', 'es-ES': 'Piscina, salón, playground, cochera' },
      },
    ],
    customFields: [
      // Labels customizados
      {
        key: 'device._entity',
        type: 'label',
        labels: { 'pt-BR': 'Unidade', 'en-US': 'Unit', 'es-ES': 'Unidad' }
      },
      {
        key: 'device._entity_plural',
        type: 'label',
        labels: { 'pt-BR': 'Unidades', 'en-US': 'Units', 'es-ES': 'Unidades' }
      },
      {
        key: 'device.brand',
        type: 'label',
        labels: { 'pt-BR': 'Empreendimento/Condomínio', 'en-US': 'Development/Building', 'es-ES': 'Proyecto/Condominio' }
      },
      {
        key: 'device.model',
        type: 'label',
        labels: { 'pt-BR': 'Bloco/Torre', 'en-US': 'Block/Tower', 'es-ES': 'Bloque/Torre' }
      },
      {
        key: 'device.serial',
        type: 'label',
        labels: { 'pt-BR': 'Nº da Unidade', 'en-US': 'Unit Number', 'es-ES': 'Nº de Unidad' }
      },
      {
        key: 'device.serial.mask',
        type: 'config',
        value: 'none',
      },
      {
        key: 'actions.create_device',
        type: 'label',
        labels: { 'pt-BR': 'Adicionar Unidade', 'en-US': 'Add Unit', 'es-ES': 'Agregar Unidad' }
      },
      {
        key: 'status.in_progress',
        type: 'label',
        labels: { 'pt-BR': 'Em Reparo', 'en-US': 'Under Repair', 'es-ES': 'En Reparación' }
      },
      {
        key: 'status.completed',
        type: 'label',
        labels: { 'pt-BR': 'Resolvido', 'en-US': 'Resolved', 'es-ES': 'Resuelto' }
      },

      // Campos customizados do domínio
      {
        key: 'device.unitType',
        type: 'select',
        labels: { 'pt-BR': 'Tipo de Unidade', 'en-US': 'Unit Type', 'es-ES': 'Tipo de Unidad' },
        options: ['apartment', 'garage', 'storage_unit', 'commercial_office', 'common_area'],
        optionsI18n: [
          { value: 'apartment', labels: { 'pt-BR': 'Apartamento', 'en-US': 'Apartment', 'es-ES': 'Departamento' } },
          { value: 'garage', labels: { 'pt-BR': 'Garagem', 'en-US': 'Garage', 'es-ES': 'Cochera' } },
          { value: 'storage_unit', labels: { 'pt-BR': 'Hobby Box', 'en-US': 'Storage Unit', 'es-ES': 'Depósito' } },
          { value: 'commercial_office', labels: { 'pt-BR': 'Sala Comercial', 'en-US': 'Commercial Office', 'es-ES': 'Oficina Comercial' } },
          { value: 'common_area', labels: { 'pt-BR': 'Área Comum', 'en-US': 'Common Area', 'es-ES': 'Área Común' } },
        ],
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 1,
      },
      {
        key: 'device.affectedSystem',
        type: 'select',
        labels: { 'pt-BR': 'Sistema Afetado', 'en-US': 'Affected System', 'es-ES': 'Sistema Afectado' },
        options: ['plumbing', 'electrical', 'structural', 'waterproofing', 'finishing', 'frames_windows', 'painting'],
        optionsI18n: [
          { value: 'plumbing', labels: { 'pt-BR': 'Hidráulico', 'en-US': 'Plumbing', 'es-ES': 'Hidráulico' } },
          { value: 'electrical', labels: { 'pt-BR': 'Elétrico', 'en-US': 'Electrical', 'es-ES': 'Eléctrico' } },
          { value: 'structural', labels: { 'pt-BR': 'Estrutural', 'en-US': 'Structural', 'es-ES': 'Estructural' } },
          { value: 'waterproofing', labels: { 'pt-BR': 'Impermeabilização', 'en-US': 'Waterproofing', 'es-ES': 'Impermeabilización' } },
          { value: 'finishing', labels: { 'pt-BR': 'Acabamento', 'en-US': 'Finishing', 'es-ES': 'Acabado' } },
          { value: 'frames_windows', labels: { 'pt-BR': 'Esquadrias', 'en-US': 'Frames & Windows', 'es-ES': 'Carpintería' } },
          { value: 'painting', labels: { 'pt-BR': 'Pintura', 'en-US': 'Painting', 'es-ES': 'Pintura' } },
        ],
        section: 'Especificações',
        sectionI18n: { 'pt-BR': 'Especificações', 'en-US': 'Specifications', 'es-ES': 'Especificaciones' },
        order: 2,
      },
      {
        key: 'device.deliveryDate',
        type: 'date',
        labels: { 'pt-BR': 'Data de Entrega', 'en-US': 'Delivery Date', 'es-ES': 'Fecha de Entrega' },
        section: 'Garantia',
        sectionI18n: { 'pt-BR': 'Garantia', 'en-US': 'Warranty', 'es-ES': 'Garantía' },
        order: 3,
      },
      {
        key: 'device.floor',
        type: 'number',
        labels: { 'pt-BR': 'Andar', 'en-US': 'Floor', 'es-ES': 'Piso' },
        min: -5,
        max: 99,
        section: 'Identificação',
        sectionI18n: { 'pt-BR': 'Identificação', 'en-US': 'Identification', 'es-ES': 'Identificación' },
        order: 4,
      },
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // OUTRO (Genérico)
  // ═══════════════════════════════════════════════════════════
  {
    id: 'other',
    name: 'Outro',
    nameI18n: { 'pt-BR': 'Outro', 'en-US': 'Other', 'es-ES': 'Otro' },
    icon: '🔧',
    active: true,
    fieldService: true, // Default: assume atendimento externo
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
