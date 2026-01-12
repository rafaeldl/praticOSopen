const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('João da Silva (Exemplo)', 'John Smith (Example)', 'Juan García (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 123', '123 Example Street', 'Calle Ejemplo, 123'),
  },

  mechanical: {
    services: [
      { name: t('Troca de óleo', 'Oil Change', 'Cambio de aceite'), value: 80.00, description: t('Troca de óleo do motor com filtro', 'Engine oil change with filter', 'Cambio de aceite del motor con filtro') },
      { name: t('Alinhamento', 'Wheel Alignment', 'Alineación'), value: 120.00, description: t('Alinhamento de direção computadorizado', 'Computerized wheel alignment', 'Alineación de dirección computarizada') },
      { name: t('Balanceamento', 'Wheel Balancing', 'Balanceo'), value: 60.00, description: t('Balanceamento das 4 rodas', '4-wheel balancing', 'Balanceo de las 4 ruedas') },
      { name: t('Revisão de freios', 'Brake Inspection', 'Revisión de frenos'), value: 150.00, description: t('Inspeção e ajuste do sistema de freios', 'Brake system inspection and adjustment', 'Inspección y ajuste del sistema de frenos') },
      { name: t('Diagnóstico eletrônico', 'Electronic Diagnosis', 'Diagnóstico electrónico'), value: 100.00, description: t('Scanner e diagnóstico de falhas', 'Scanner and fault diagnosis', 'Escáner y diagnóstico de fallas') },
      { name: t('Troca de pastilhas de freio', 'Brake Pad Replacement', 'Cambio de pastillas de freno'), value: 180.00, description: t('Substituição de pastilhas dianteiras', 'Front brake pad replacement', 'Sustitución de pastillas delanteras') },
      { name: t('Higienização do ar', 'AC Sanitization', 'Higienización del aire'), value: 90.00, description: t('Limpeza do sistema de ar condicionado', 'Air conditioning system cleaning', 'Limpieza del sistema de aire acondicionado') },
      { name: t('Troca de correia dentada', 'Timing Belt Replacement', 'Cambio de correa de distribución'), value: 350.00, description: t('Substituição de correia e tensionadores', 'Belt and tensioner replacement', 'Sustitución de correa y tensores') },
    ],
    products: [
      { name: t('Óleo 5W30 Sintético (1L)', '5W30 Synthetic Oil (1L)', 'Aceite 5W30 Sintético (1L)'), value: 45.00 },
      { name: t('Filtro de óleo', 'Oil Filter', 'Filtro de aceite'), value: 35.00 },
      { name: t('Filtro de ar', 'Air Filter', 'Filtro de aire'), value: 55.00 },
      { name: t('Filtro de combustível', 'Fuel Filter', 'Filtro de combustible'), value: 65.00 },
      { name: t('Pastilha de freio dianteira (jogo)', 'Front Brake Pads (set)', 'Pastillas de freno delanteras (juego)'), value: 120.00 },
      { name: t('Lâmpada farol H7', 'H7 Headlight Bulb', 'Bombilla faro H7'), value: 25.00 },
      { name: t('Fluido de freio DOT 4 (500ml)', 'DOT 4 Brake Fluid (500ml)', 'Líquido de frenos DOT 4 (500ml)'), value: 35.00 },
      { name: t('Vela de ignição', 'Spark Plug', 'Bujía'), value: 28.00 },
    ],
    devices: [
      { name: 'Onix 1.0', manufacturer: 'Chevrolet', category: 'Hatch', customFields: { year: 2022, mileage: 45000, color: t('Prata', 'Silver', 'Plata') } },
      { name: 'HB20 1.6', manufacturer: 'Hyundai', category: 'Hatch', customFields: { year: 2021, mileage: 38000, color: t('Branco', 'White', 'Blanco') } },
    ],
  },

  carwash: {
    services: [
      { name: t('Lavagem simples', 'Basic Wash', 'Lavado simple'), value: 40.00, description: t('Lavagem externa básica', 'Basic exterior wash', 'Lavado exterior básico') },
      { name: t('Lavagem completa', 'Full Wash', 'Lavado completo'), value: 70.00, description: t('Lavagem externa + interna', 'Exterior + interior wash', 'Lavado exterior + interior') },
      { name: t('Lavagem detalhada', 'Detailed Wash', 'Lavado detallado'), value: 120.00, description: t('Lavagem completa + motor + porta-malas', 'Full wash + engine + trunk', 'Lavado completo + motor + maletero') },
      { name: t('Higienização interna', 'Interior Sanitization', 'Higienización interior'), value: 150.00, description: t('Limpeza profunda de estofados e carpetes', 'Deep cleaning of upholstery and carpets', 'Limpieza profunda de tapizados y alfombras') },
      { name: t('Lavagem de motor', 'Engine Wash', 'Lavado de motor'), value: 80.00, description: t('Limpeza e desengraxe do motor', 'Engine cleaning and degreasing', 'Limpieza y desengrase del motor') },
      { name: t('Enceramento', 'Waxing', 'Encerado'), value: 100.00, description: t('Aplicação de cera protetora', 'Protective wax application', 'Aplicación de cera protectora') },
      { name: t('Cristalização de vidros', 'Glass Coating', 'Cristalización de vidrios'), value: 80.00, description: t('Tratamento hidrofóbico nos vidros', 'Hydrophobic glass treatment', 'Tratamiento hidrofóbico en vidrios') },
      { name: t('Hidratação de couro', 'Leather Conditioning', 'Hidratación de cuero'), value: 90.00, description: t('Tratamento de bancos de couro', 'Leather seat treatment', 'Tratamiento de asientos de cuero') },
    ],
    products: [
      { name: t('Shampoo automotivo (5L)', 'Car Shampoo (5L)', 'Champú automotriz (5L)'), value: 35.00 },
      { name: t('Cera líquida (500ml)', 'Liquid Wax (500ml)', 'Cera líquida (500ml)'), value: 45.00 },
      { name: t('Pretinho para pneus (1L)', 'Tire Shine (1L)', 'Abrillantador de llantas (1L)'), value: 25.00 },
      { name: t('Limpa vidros (500ml)', 'Glass Cleaner (500ml)', 'Limpiavidrios (500ml)'), value: 18.00 },
      { name: t('Aromatizante (unidade)', 'Air Freshener (unit)', 'Aromatizante (unidad)'), value: 12.00 },
      { name: t('Silicone para painel (300ml)', 'Dashboard Silicone (300ml)', 'Silicona para tablero (300ml)'), value: 22.00 },
      { name: t('Desengraxante (1L)', 'Degreaser (1L)', 'Desengrasante (1L)'), value: 28.00 },
      { name: t('Hidratante de couro (500ml)', 'Leather Conditioner (500ml)', 'Acondicionador de cuero (500ml)'), value: 55.00 },
    ],
    devices: [
      { name: 'Corolla XEi', manufacturer: 'Toyota', category: 'Sedan', customFields: { year: 2023, color: t('Preto', 'Black', 'Negro') } },
      { name: 'Tracker LT', manufacturer: 'Chevrolet', category: 'SUV', customFields: { year: 2022, color: t('Branco', 'White', 'Blanco') } },
    ],
  },

  painting: {
    services: [
      { name: t('Pintura de para-choque', 'Bumper Painting', 'Pintura de parachoques'), value: 450.00, description: t('Pintura completa de para-choque', 'Complete bumper painting', 'Pintura completa de parachoques') },
      { name: t('Pintura de porta', 'Door Painting', 'Pintura de puerta'), value: 600.00, description: t('Pintura completa de porta', 'Complete door painting', 'Pintura completa de puerta') },
      { name: t('Pintura de capô', 'Hood Painting', 'Pintura de capó'), value: 700.00, description: t('Pintura completa de capô', 'Complete hood painting', 'Pintura completa de capó') },
      { name: t('Polimento técnico', 'Technical Polishing', 'Pulido técnico'), value: 250.00, description: t('Polimento para remoção de riscos', 'Polishing for scratch removal', 'Pulido para eliminación de rayones') },
      { name: t('Vitrificação', 'Ceramic Coating', 'Vitrificación'), value: 800.00, description: t('Proteção cerâmica da pintura', 'Ceramic paint protection', 'Protección cerámica de pintura') },
      { name: t('Retoque de pintura', 'Touch-up Painting', 'Retoque de pintura'), value: 150.00, description: t('Correção de pequenas avarias', 'Minor damage correction', 'Corrección de pequeños daños') },
      { name: t('Reparo de para-choque', 'Bumper Repair', 'Reparación de parachoques'), value: 300.00, description: t('Reparo de trincas e furos', 'Crack and hole repair', 'Reparación de grietas y agujeros') },
      { name: t('Envelopamento parcial', 'Partial Wrap', 'Vinilado parcial'), value: 500.00, description: t('Aplicação de película em peças', 'Film application on parts', 'Aplicación de película en piezas') },
    ],
    products: [
      { name: t('Tinta automotiva (lata)', 'Automotive Paint (can)', 'Pintura automotriz (lata)'), value: 180.00 },
      { name: t('Verniz automotivo (1L)', 'Automotive Clear Coat (1L)', 'Barniz automotriz (1L)'), value: 120.00 },
      { name: t('Massa plástica (kg)', 'Body Filler (kg)', 'Masilla plástica (kg)'), value: 35.00 },
      { name: t('Lixa d\'água (pacote)', 'Wet Sandpaper (pack)', 'Lija al agua (paquete)'), value: 15.00 },
      { name: t('Primer (1L)', 'Primer (1L)', 'Imprimación (1L)'), value: 65.00 },
      { name: t('Thinner (1L)', 'Thinner (1L)', 'Diluyente (1L)'), value: 28.00 },
      { name: t('Cera de polimento (500g)', 'Polishing Wax (500g)', 'Cera de pulido (500g)'), value: 85.00 },
      { name: t('Fita crepe automotiva', 'Automotive Masking Tape', 'Cinta de enmascarar automotriz'), value: 18.00 },
    ],
    devices: [
      { name: 'Civic Touring', manufacturer: 'Honda', category: 'Sedan', customFields: { year: 2022, color: t('Cinza', 'Gray', 'Gris') } },
      { name: 'Kicks Advance', manufacturer: 'Nissan', category: 'SUV', customFields: { year: 2021, color: t('Vermelho', 'Red', 'Rojo') } },
    ],
  },

  bodywork: {
    services: [
      { name: t('Martelinho de ouro', 'Paintless Dent Repair', 'Desabollado sin pintura'), value: 200.00, description: t('Reparo de amassados sem pintura (PDR)', 'Paintless dent repair (PDR)', 'Reparación de abolladuras sin pintura (PDR)') },
      { name: t('Desamassar porta', 'Door Dent Repair', 'Desabollar puerta'), value: 350.00, description: t('Reparo de amassado em porta', 'Door dent repair', 'Reparación de abolladura en puerta') },
      { name: t('Desamassar capô', 'Hood Dent Repair', 'Desabollar capó'), value: 400.00, description: t('Reparo de amassado em capô', 'Hood dent repair', 'Reparación de abolladura en capó') },
      { name: t('Desamassar teto', 'Roof Dent Repair', 'Desabollar techo'), value: 500.00, description: t('Reparo de amassado por granizo', 'Hail damage dent repair', 'Reparación de abolladuras por granizo') },
      { name: t('Troca de para-lama', 'Fender Replacement', 'Cambio de guardabarros'), value: 250.00, description: t('Substituição de para-lama', 'Fender replacement', 'Sustitución de guardabarros') },
      { name: t('Alinhamento de carroceria', 'Body Alignment', 'Alineación de carrocería'), value: 600.00, description: t('Correção estrutural de carroceria', 'Structural body correction', 'Corrección estructural de carrocería') },
      { name: t('Reparo de paralama', 'Fender Repair', 'Reparación de guardabarros'), value: 300.00, description: t('Reparo de amassado em paralama', 'Fender dent repair', 'Reparación de abolladura en guardabarros') },
      { name: t('Solda de lataria', 'Body Welding', 'Soldadura de carrocería'), value: 180.00, description: t('Serviço de solda em peças', 'Part welding service', 'Servicio de soldadura en piezas') },
    ],
    products: [
      { name: t('Kit ferramentas PDR', 'PDR Tool Kit', 'Kit de herramientas PDR'), value: 450.00 },
      { name: t('Cola para PDR (kg)', 'PDR Glue (kg)', 'Pegamento para PDR (kg)'), value: 85.00 },
      { name: t('Ventosa profissional', 'Professional Suction Cup', 'Ventosa profesional'), value: 120.00 },
      { name: t('Martelo de borracha', 'Rubber Mallet', 'Martillo de goma'), value: 45.00 },
      { name: t('Tas de repuxo (jogo)', 'Dolly Set', 'Juego de sufrideras'), value: 180.00 },
      { name: t('Eletrodo de solda (kg)', 'Welding Electrode (kg)', 'Electrodo de soldadura (kg)'), value: 35.00 },
      { name: t('Esmerilhadeira (disco)', 'Grinder Disc', 'Disco de amoladora'), value: 15.00 },
      { name: t('Removedor de cola', 'Glue Remover', 'Removedor de pegamento'), value: 28.00 },
    ],
    devices: [
      { name: 'Creta Attitude', manufacturer: 'Hyundai', category: 'SUV', customFields: { year: 2023, color: t('Prata', 'Silver', 'Plata') } },
      { name: 'Polo TSI', manufacturer: 'Volkswagen', category: 'Hatch', customFields: { year: 2022, color: t('Azul', 'Blue', 'Azul') } },
    ],
  },
};
