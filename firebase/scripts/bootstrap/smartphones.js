const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Pedro Oliveira (Exemplo)', 'Peter Davis (Example)', 'Pedro Fernández (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 789', '789 Example Street', 'Calle Ejemplo, 789'),
  },

  _default: {
    services: [
      { name: t('Troca de tela', 'Screen Replacement', 'Cambio de pantalla'), value: 250.00, description: t('Substituição de display LCD/OLED', 'LCD/OLED display replacement', 'Sustitución de pantalla LCD/OLED') },
      { name: t('Troca de bateria', 'Battery Replacement', 'Cambio de batería'), value: 120.00, description: t('Substituição de bateria', 'Battery replacement', 'Sustitución de batería') },
      { name: t('Troca de conector de carga', 'Charging Port Replacement', 'Cambio de conector de carga'), value: 100.00, description: t('Reparo do conector USB/Lightning', 'USB/Lightning connector repair', 'Reparación del conector USB/Lightning') },
      { name: t('Reparo de placa', 'Board Repair', 'Reparación de placa'), value: 200.00, description: t('Micro soldagem em placa', 'Micro soldering on board', 'Microsoldadura en placa') },
      { name: t('Atualização de software', 'Software Update', 'Actualización de software'), value: 50.00, description: t('Atualização do sistema operacional', 'Operating system update', 'Actualización del sistema operativo') },
      { name: t('Backup de dados', 'Data Backup', 'Copia de seguridad'), value: 80.00, description: t('Backup completo do dispositivo', 'Complete device backup', 'Copia de seguridad completa del dispositivo') },
      { name: t('Limpeza interna', 'Internal Cleaning', 'Limpieza interna'), value: 60.00, description: t('Limpeza de poeira e oxidação', 'Dust and oxidation cleaning', 'Limpieza de polvo y oxidación') },
    ],
    products: [
      { name: t('Tela iPhone 11', 'iPhone 11 Screen', 'Pantalla iPhone 11'), value: 350.00 },
      { name: t('Tela Samsung A54', 'Samsung A54 Screen', 'Pantalla Samsung A54'), value: 280.00 },
      { name: t('Bateria iPhone (genérica)', 'iPhone Battery (generic)', 'Batería iPhone (genérica)'), value: 80.00 },
      { name: t('Bateria Samsung (genérica)', 'Samsung Battery (generic)', 'Batería Samsung (genérica)'), value: 70.00 },
      { name: t('Conector de carga USB-C', 'USB-C Charging Port', 'Conector de carga USB-C'), value: 25.00 },
      { name: t('Película de vidro', 'Tempered Glass', 'Vidrio templado'), value: 15.00 },
      { name: t('Capinha de silicone', 'Silicone Case', 'Funda de silicona'), value: 20.00 },
    ],
    devices: [
      { name: 'iPhone 13', manufacturer: 'Apple', category: 'Smartphone', customFields: { storage: '128GB', color: t('Azul', 'Blue', 'Azul') } },
      { name: 'Galaxy S23', manufacturer: 'Samsung', category: 'Smartphone', customFields: { storage: '256GB', color: t('Preto', 'Black', 'Negro') } },
      { name: 'Moto G84', manufacturer: 'Motorola', category: 'Smartphone', customFields: { storage: '128GB', color: t('Grafite', 'Graphite', 'Grafito') } },
    ],
  },
};
