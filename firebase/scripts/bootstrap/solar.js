const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Fernando Ribeiro (Exemplo)', 'Frank Anderson (Example)', 'Fernando Díaz (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 333', '333 Example Street', 'Calle Ejemplo, 333'),
  },

  _default: {
    services: [
      { name: t('Instalação de sistema', 'System Installation', 'Instalación de sistema'), value: 3500.00, description: t('Instalação completa do sistema solar', 'Complete solar system installation', 'Instalación completa del sistema solar') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 350.00, description: t('Limpeza e verificação do sistema', 'System cleaning and inspection', 'Limpieza y verificación del sistema') },
      { name: t('Limpeza de painéis', 'Panel Cleaning', 'Limpieza de paneles'), value: 200.00, description: t('Limpeza de módulos fotovoltaicos', 'Photovoltaic module cleaning', 'Limpieza de módulos fotovoltaicos') },
      { name: t('Substituição de inversor', 'Inverter Replacement', 'Sustitución de inversor'), value: 800.00, description: t('Troca de inversor solar', 'Solar inverter replacement', 'Cambio de inversor solar') },
      { name: t('Monitoramento remoto', 'Remote Monitoring', 'Monitoreo remoto'), value: 150.00, description: t('Configuração de app de monitoramento', 'Monitoring app setup', 'Configuración de app de monitoreo') },
      { name: t('Expansão do sistema', 'System Expansion', 'Expansión del sistema'), value: 1500.00, description: t('Adição de módulos ao sistema', 'Adding modules to system', 'Adición de módulos al sistema') },
      { name: t('Reparo de string box', 'String Box Repair', 'Reparación de caja de conexiones'), value: 250.00, description: t('Manutenção de caixa de junção', 'Junction box maintenance', 'Mantenimiento de caja de conexiones') },
    ],
    products: [
      { name: t('Módulo fotovoltaico 550W', '550W Photovoltaic Module', 'Módulo fotovoltaico 550W'), value: 950.00 },
      { name: t('Inversor 5kW', '5kW Inverter', 'Inversor 5kW'), value: 4500.00 },
      { name: 'String box', value: 350.00 },
      { name: t('Cabo solar 6mm (metro)', '6mm Solar Cable (meter)', 'Cable solar 6mm (metro)'), value: 12.00 },
      { name: t('Conector MC4 (par)', 'MC4 Connector (pair)', 'Conector MC4 (par)'), value: 25.00 },
      { name: t('Estrutura de fixação (kit)', 'Mounting Structure (kit)', 'Estructura de fijación (kit)'), value: 450.00 },
      { name: t('DPS para sistema solar', 'Solar System SPD', 'DPS para sistema solar'), value: 180.00 },
    ],
    devices: [
      { name: t('Sistema 5kWp', '5kWp System', 'Sistema 5kWp'), manufacturer: 'Canadian Solar', category: t('Sistema Fotovoltaico', 'Photovoltaic System', 'Sistema Fotovoltaico'), customFields: { kwp: 5, panelCount: 10 } },
      { name: t('Sistema 10kWp', '10kWp System', 'Sistema 10kWp'), manufacturer: 'JA Solar', category: t('Sistema Fotovoltaico', 'Photovoltaic System', 'Sistema Fotovoltaico'), customFields: { kwp: 10, panelCount: 20 } },
    ],
  },
};
