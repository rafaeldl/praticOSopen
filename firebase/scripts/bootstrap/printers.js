const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Patrícia Mendes (Exemplo)', 'Patricia White (Example)', 'Patricia Morales (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 444', '444 Example Street', 'Calle Ejemplo, 444'),
  },

  _default: {
    services: [
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 150.00, description: t('Limpeza e verificação geral', 'General cleaning and inspection', 'Limpieza y verificación general') },
      { name: t('Troca de cartucho/toner', 'Cartridge/Toner Replacement', 'Cambio de cartucho/tóner'), value: 80.00, description: t('Substituição de suprimento', 'Supply replacement', 'Sustitución de suministro') },
      { name: t('Reparo de fusor', 'Fuser Repair', 'Reparación de fusor'), value: 250.00, description: t('Manutenção do sistema de fusão', 'Fuser system maintenance', 'Mantenimiento del sistema de fusión') },
      { name: t('Troca de cabeça de impressão', 'Print Head Replacement', 'Cambio de cabezal de impresión'), value: 200.00, description: t('Substituição de cabeça jato de tinta', 'Inkjet head replacement', 'Sustitución de cabezal de inyección') },
      { name: t('Limpeza de trilhos', 'Rail Cleaning', 'Limpieza de rieles'), value: 100.00, description: t('Limpeza do sistema de transporte', 'Transport system cleaning', 'Limpieza del sistema de transporte') },
      { name: t('Configuração de rede', 'Network Configuration', 'Configuración de red'), value: 80.00, description: t('Setup de impressora em rede', 'Network printer setup', 'Configuración de impresora en red') },
      { name: t('Reparo de placa', 'Board Repair', 'Reparación de placa'), value: 300.00, description: t('Conserto de placa lógica', 'Logic board repair', 'Reparación de placa lógica') },
    ],
    products: [
      { name: 'Toner HP 85A', value: 120.00 },
      { name: 'Toner Brother TN-1060', value: 95.00 },
      { name: t('Cartucho HP 664 Preto', 'HP 664 Black Cartridge', 'Cartucho HP 664 Negro'), value: 65.00 },
      { name: t('Cartucho HP 664 Colorido', 'HP 664 Color Cartridge', 'Cartucho HP 664 Color'), value: 75.00 },
      { name: t('Kit fusor (genérico)', 'Fuser Kit (generic)', 'Kit fusor (genérico)'), value: 180.00 },
      { name: t('Rolete de captação', 'Pickup Roller', 'Rodillo de alimentación'), value: 45.00 },
      { name: t('Cilindro fotossensível', 'Drum Unit', 'Cilindro fotosensible'), value: 85.00 },
    ],
    devices: [
      { name: 'LaserJet Pro M15w', manufacturer: 'HP', category: t('Impressora Laser', 'Laser Printer', 'Impresora Láser'), customFields: { technology: 'Laser', isColor: t('Não', 'No', 'No') } },
      { name: 'DCP-L2540DW', manufacturer: 'Brother', category: t('Multifuncional Laser', 'Laser Multifunction', 'Multifuncional Láser'), customFields: { technology: 'Laser', isColor: t('Não', 'No', 'No') } },
      { name: 'EcoTank L3250', manufacturer: 'Epson', category: t('Multifuncional Jato de Tinta', 'Inkjet Multifunction', 'Multifuncional de Inyección'), customFields: { technology: t('Jato de tinta', 'Inkjet', 'Inyección de tinta'), isColor: t('Sim', 'Yes', 'Sí') } },
    ],
  },
};
