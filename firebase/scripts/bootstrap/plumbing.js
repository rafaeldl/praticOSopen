const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Marcos Almeida (Exemplo)', 'Mark Taylor (Example)', 'Marcos Sánchez (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 222', '222 Example Street', 'Calle Ejemplo, 222'),
  },

  _default: {
    services: [
      { name: t('Desentupimento', 'Unclogging', 'Desatasco'), value: 150.00, description: t('Desentupimento de ralos e pias', 'Drain and sink unclogging', 'Desatasco de desagües y fregaderos') },
      { name: t('Troca de torneira', 'Faucet Replacement', 'Cambio de grifo'), value: 80.00, description: t('Substituição de torneira', 'Faucet replacement', 'Sustitución de grifo') },
      { name: t('Reparo de vazamento', 'Leak Repair', 'Reparación de fugas'), value: 120.00, description: t('Conserto de vazamentos', 'Leak repair', 'Reparación de fugas') },
      { name: t('Instalação de caixa d\'água', 'Water Tank Installation', 'Instalación de tanque de agua'), value: 250.00, description: t('Instalação de reservatório', 'Reservoir installation', 'Instalación de depósito') },
      { name: t('Troca de válvula de descarga', 'Flush Valve Replacement', 'Cambio de válvula de descarga'), value: 150.00, description: t('Substituição de válvula', 'Valve replacement', 'Sustitución de válvula') },
      { name: t('Instalação de aquecedor', 'Water Heater Installation', 'Instalación de calentador'), value: 200.00, description: t('Instalação de aquecedor de água', 'Water heater installation', 'Instalación de calentador de agua') },
      { name: t('Caça vazamento', 'Leak Detection', 'Detección de fugas'), value: 180.00, description: t('Detecção de vazamentos ocultos', 'Hidden leak detection', 'Detección de fugas ocultas') },
    ],
    products: [
      { name: t('Torneira para pia', 'Sink Faucet', 'Grifo para fregadero'), value: 65.00 },
      { name: t('Válvula de descarga', 'Flush Valve', 'Válvula de descarga'), value: 120.00 },
      { name: t('Sifão sanfonado', 'Flexible Trap', 'Sifón flexible'), value: 25.00 },
      { name: t('Tubo PVC 50mm (metro)', 'PVC Pipe 50mm (meter)', 'Tubo PVC 50mm (metro)'), value: 15.00 },
      { name: t('Joelho 90º 50mm', '90º Elbow 50mm', 'Codo 90º 50mm'), value: 8.00 },
      { name: t('Fita veda rosca', 'Thread Seal Tape', 'Cinta de teflón'), value: 12.00 },
      { name: t('Registro de pressão 3/4', '3/4 Pressure Valve', 'Válvula de presión 3/4'), value: 45.00 },
    ],
    devices: [
      { name: t('Residência - Sistema Hidráulico', 'Residence - Plumbing System', 'Residencia - Sistema Hidráulico'), manufacturer: t('Genérico', 'Generic', 'Genérico'), category: t('Instalação', 'Installation', 'Instalación'), customFields: { waterType: t('Ambas', 'Both', 'Ambas'), pressure: 'Normal' } },
      { name: t('Apartamento - Banheiro Social', 'Apartment - Guest Bathroom', 'Apartamento - Baño Social'), manufacturer: t('Genérico', 'Generic', 'Genérico'), category: t('Instalação', 'Installation', 'Instalación'), customFields: { waterType: t('Ambas', 'Both', 'Ambas'), pressure: t('Baixa', 'Low', 'Baja') } },
    ],
  },
};
