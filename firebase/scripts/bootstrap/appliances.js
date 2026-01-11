const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Carlos Ferreira (Exemplo)', 'Charles Miller (Example)', 'Carlos Hernández (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 654', '654 Example Street', 'Calle Ejemplo, 654'),
  },

  _default: {
    services: [
      { name: t('Diagnóstico', 'Diagnosis', 'Diagnóstico'), value: 80.00, description: t('Avaliação técnica do problema', 'Technical problem assessment', 'Evaluación técnica del problema') },
      { name: t('Troca de resistência', 'Heating Element Replacement', 'Cambio de resistencia'), value: 150.00, description: t('Substituição de resistência', 'Heating element replacement', 'Sustitución de resistencia') },
      { name: t('Troca de termostato', 'Thermostat Replacement', 'Cambio de termostato'), value: 120.00, description: t('Substituição de termostato', 'Thermostat replacement', 'Sustitución de termostato') },
      { name: t('Troca de timer', 'Timer Replacement', 'Cambio de timer'), value: 180.00, description: t('Substituição do timer mecânico', 'Mechanical timer replacement', 'Sustitución del timer mecánico') },
      { name: t('Troca de motor', 'Motor Replacement', 'Cambio de motor'), value: 250.00, description: t('Substituição do motor', 'Motor replacement', 'Sustitución del motor') },
      { name: t('Reparo de placa', 'Board Repair', 'Reparación de placa'), value: 200.00, description: t('Conserto de placa eletrônica', 'Electronic board repair', 'Reparación de placa electrónica') },
      { name: t('Recarga de gás (geladeira)', 'Gas Recharge (refrigerator)', 'Recarga de gas (refrigerador)'), value: 300.00, description: t('Recarga de gás refrigerante', 'Refrigerant gas recharge', 'Recarga de gas refrigerante') },
    ],
    products: [
      { name: t('Resistência para chuveiro', 'Shower Heating Element', 'Resistencia para ducha'), value: 35.00 },
      { name: t('Termostato universal', 'Universal Thermostat', 'Termostato universal'), value: 65.00 },
      { name: t('Timer mecânico', 'Mechanical Timer', 'Timer mecánico'), value: 120.00 },
      { name: t('Capacitor para motor', 'Motor Capacitor', 'Capacitor para motor'), value: 45.00 },
      { name: t('Borracha de geladeira (metro)', 'Refrigerator Gasket (meter)', 'Empaque de refrigerador (metro)'), value: 50.00 },
      { name: t('Gás R134a (kg)', 'R134a Gas (kg)', 'Gas R134a (kg)'), value: 100.00 },
      { name: t('Mangueira de entrada', 'Inlet Hose', 'Manguera de entrada'), value: 30.00 },
    ],
    devices: [
      { name: t('Geladeira Frost Free 400L', 'Frost Free Refrigerator 400L', 'Refrigerador Frost Free 400L'), manufacturer: 'Brastemp', category: t('Refrigerador', 'Refrigerator', 'Refrigerador'), customFields: { voltage: '220V' } },
      { name: t('Máquina de Lavar 12kg', 'Washing Machine 12kg', 'Lavadora 12kg'), manufacturer: 'Electrolux', category: t('Lavadora', 'Washer', 'Lavadora'), customFields: { voltage: '220V' } },
      { name: t('Micro-ondas 30L', 'Microwave 30L', 'Microondas 30L'), manufacturer: 'Panasonic', category: t('Micro-ondas', 'Microwave', 'Microondas'), customFields: { voltage: '220V' } },
    ],
  },
};
