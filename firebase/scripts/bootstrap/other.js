const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Cliente Exemplo', 'Example Customer', 'Cliente Ejemplo'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Endereço de Exemplo, 123', '123 Example Address', 'Dirección de Ejemplo, 123'),
  },

  _default: {
    services: [
      { name: t('Serviço básico', 'Basic Service', 'Servicio básico'), value: 100.00, description: t('Serviço padrão', 'Standard service', 'Servicio estándar') },
      { name: t('Serviço intermediário', 'Intermediate Service', 'Servicio intermedio'), value: 200.00, description: t('Serviço de complexidade média', 'Medium complexity service', 'Servicio de complejidad media') },
      { name: t('Serviço avançado', 'Advanced Service', 'Servicio avanzado'), value: 350.00, description: t('Serviço de alta complexidade', 'High complexity service', 'Servicio de alta complejidad') },
      { name: t('Diagnóstico', 'Diagnosis', 'Diagnóstico'), value: 80.00, description: t('Avaliação técnica', 'Technical assessment', 'Evaluación técnica') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 150.00, description: t('Manutenção programada', 'Scheduled maintenance', 'Mantenimiento programado') },
    ],
    products: [
      { name: t('Peça genérica A', 'Generic Part A', 'Pieza genérica A'), value: 50.00 },
      { name: t('Peça genérica B', 'Generic Part B', 'Pieza genérica B'), value: 80.00 },
      { name: t('Consumível padrão', 'Standard Consumable', 'Consumible estándar'), value: 30.00 },
      { name: t('Kit de reparo', 'Repair Kit', 'Kit de reparación'), value: 120.00 },
    ],
    devices: [
      { name: t('Equipamento Exemplo', 'Example Equipment', 'Equipo Ejemplo'), manufacturer: t('Genérico', 'Generic', 'Genérico'), category: t('Geral', 'General', 'General') },
    ],
  },
};
