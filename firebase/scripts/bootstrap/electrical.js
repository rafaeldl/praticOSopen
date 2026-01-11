const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('José Souza (Exemplo)', 'Joseph Wilson (Example)', 'José González (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 111', '111 Example Street', 'Calle Ejemplo, 111'),
  },

  _default: {
    services: [
      { name: t('Instalação de tomada', 'Outlet Installation', 'Instalación de tomacorriente'), value: 80.00, description: t('Instalação de tomada nova', 'New outlet installation', 'Instalación de tomacorriente nuevo') },
      { name: t('Instalação de disjuntor', 'Breaker Installation', 'Instalación de interruptor'), value: 100.00, description: t('Instalação de disjuntor no quadro', 'Breaker installation in panel', 'Instalación de interruptor en tablero') },
      { name: t('Troca de fiação', 'Wiring Replacement', 'Cambio de cableado'), value: 150.00, description: t('Substituição de fiação antiga', 'Old wiring replacement', 'Sustitución de cableado antiguo') },
      { name: t('Instalação de chuveiro', 'Shower Installation', 'Instalación de ducha eléctrica'), value: 120.00, description: t('Instalação elétrica de chuveiro', 'Electric shower installation', 'Instalación eléctrica de ducha') },
      { name: t('Instalação de lustre', 'Light Fixture Installation', 'Instalación de lámpara'), value: 80.00, description: t('Instalação de luminária/lustre', 'Light fixture/chandelier installation', 'Instalación de luminaria/lámpara') },
      { name: t('Manutenção de quadro', 'Panel Maintenance', 'Mantenimiento de tablero'), value: 200.00, description: t('Revisão do quadro de distribuição', 'Distribution panel revision', 'Revisión del tablero de distribución') },
      { name: t('Aterramento', 'Grounding', 'Puesta a tierra'), value: 350.00, description: t('Instalação de sistema de aterramento', 'Grounding system installation', 'Instalación de sistema de puesta a tierra') },
    ],
    products: [
      { name: t('Tomada 20A', '20A Outlet', 'Tomacorriente 20A'), value: 25.00 },
      { name: t('Disjuntor 20A', '20A Breaker', 'Interruptor 20A'), value: 35.00 },
      { name: t('Disjuntor 40A', '40A Breaker', 'Interruptor 40A'), value: 45.00 },
      { name: t('Fio 2,5mm (100m)', '2.5mm Wire (100m)', 'Cable 2,5mm (100m)'), value: 180.00 },
      { name: t('Fio 4mm (100m)', '4mm Wire (100m)', 'Cable 4mm (100m)'), value: 250.00 },
      { name: 'DR 40A', value: 120.00 },
      { name: t('Quadro de distribuição 12 disjuntores', '12-Breaker Distribution Panel', 'Tablero de distribución 12 interruptores'), value: 85.00 },
    ],
    devices: [
      { name: t('Residência - Quadro Principal', 'Residence - Main Panel', 'Residencia - Tablero Principal'), manufacturer: t('Genérico', 'Generic', 'Genérico'), category: t('Instalação', 'Installation', 'Instalación'), customFields: { voltage: '220V', mainBreaker: 50 } },
      { name: t('Comércio - Quadro de Força', 'Business - Power Panel', 'Comercio - Tablero de Fuerza'), manufacturer: t('Genérico', 'Generic', 'Genérico'), category: t('Instalação', 'Installation', 'Instalación'), customFields: { voltage: t('Trifásico', 'Three-phase', 'Trifásico'), mainBreaker: 100 } },
    ],
  },
};
