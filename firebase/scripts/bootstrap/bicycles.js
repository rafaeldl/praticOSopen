const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('João da Silva (Exemplo)', 'John Smith (Example)', 'Juan García (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 123', '123 Example Street', 'Calle Ejemplo, 123'),
  },

  general: {
    services: [
      { name: t('Revisão básica', 'Basic Tune-up', 'Revisión básica'), value: 120.00, description: t('Lubrificação, calibragem e ajuste geral', 'Lubrication, tire pressure and general adjustment', 'Lubricación, calibración y ajuste general') },
      { name: t('Revisão completa', 'Full Tune-up', 'Revisión completa'), value: 250.00, description: t('Revisão completa com desmontagem e limpeza', 'Full tune-up with disassembly and cleaning', 'Revisión completa con desmontaje y limpieza') },
      { name: t('Troca de câmara de ar', 'Inner Tube Replacement', 'Cambio de cámara de aire'), value: 30.00, description: t('Remoção e troca da câmara furada', 'Removal and replacement of punctured tube', 'Remoción y cambio de cámara pinchada') },
      { name: t('Regulagem de câmbio', 'Derailleur Adjustment', 'Ajuste de cambio'), value: 50.00, description: t('Ajuste fino do câmbio traseiro e dianteiro', 'Fine adjustment of front and rear derailleur', 'Ajuste fino del cambio trasero y delantero') },
      { name: t('Regulagem de freio', 'Brake Adjustment', 'Ajuste de freno'), value: 40.00, description: t('Ajuste e centralização dos freios', 'Brake adjustment and centering', 'Ajuste y centrado de frenos') },
      { name: t('Troca de pneu', 'Tire Replacement', 'Cambio de neumático'), value: 25.00, description: t('Mão de obra para troca de pneu', 'Labor for tire replacement', 'Mano de obra para cambio de neumático') },
      { name: t('Troca de corrente', 'Chain Replacement', 'Cambio de cadena'), value: 35.00, description: t('Remoção da corrente antiga e instalação da nova', 'Old chain removal and new chain installation', 'Remoción de cadena vieja e instalación de la nueva') },
      { name: t('Centrar roda (desempenar)', 'Wheel Truing', 'Centrado de rueda'), value: 45.00, description: t('Alinhamento e tensionamento dos raios', 'Spoke alignment and tensioning', 'Alineación y tensado de rayos') },
    ],
    products: [
      { name: t('Câmara de ar aro 29', '29" Inner Tube', 'Cámara de aire rodado 29'), value: 25.00 },
      { name: t('Pneu MTB 29x2.20', 'MTB Tire 29x2.20', 'Neumático MTB 29x2.20'), value: 90.00 },
      { name: t('Corrente 12v', '12 Speed Chain', 'Cadena 12v'), value: 60.00 },
      { name: t('Pastilha de freio a disco (par)', 'Disc Brake Pads (pair)', 'Pastilla de freno a disco (par)'), value: 35.00 },
      { name: t('Cabo de câmbio', 'Shift Cable', 'Cable de cambio'), value: 15.00 },
      { name: t('Cabo de freio', 'Brake Cable', 'Cable de freno'), value: 12.00 },
      { name: t('Fita de guidão', 'Bar Tape', 'Cinta de manillar'), value: 45.00 },
      { name: t('Lubrificante de corrente (100ml)', 'Chain Lube (100ml)', 'Lubricante de cadena (100ml)'), value: 28.00 },
    ],
    devices: [
      { name: 'Elite 29', manufacturer: 'Caloi', category: 'MTB', customFields: { year: 2023, color: t('Preto', 'Black', 'Negro') } },
      { name: 'Invictus Pro', manufacturer: 'Sense', category: 'MTB', customFields: { year: 2022, color: t('Azul', 'Blue', 'Azul') } },
    ],
  },

  mtb: {
    services: [
      { name: t('Revisão de suspensão dianteira', 'Fork Service', 'Revisión de suspensión delantera'), value: 180.00, description: t('Troca de óleo, retentores e limpeza da suspensão', 'Oil change, seals and fork cleaning', 'Cambio de aceite, retenes y limpieza de suspensión') },
      { name: t('Revisão de suspensão traseira', 'Rear Shock Service', 'Revisión de suspensión trasera'), value: 200.00, description: t('Manutenção completa do amortecedor', 'Complete rear shock maintenance', 'Mantenimiento completo del amortiguador') },
      { name: t('Sangria de freio hidráulico', 'Hydraulic Brake Bleed', 'Sangrado de freno hidráulico'), value: 60.00, description: t('Troca de fluido e sangria do sistema', 'Fluid change and system bleed', 'Cambio de fluido y sangrado del sistema') },
      { name: t('Troca de cassete', 'Cassette Replacement', 'Cambio de cassette'), value: 40.00, description: t('Remoção e instalação de cassete novo', 'Removal and installation of new cassette', 'Remoción e instalación de cassette nuevo') },
      { name: t('Troca de movimento central', 'Bottom Bracket Replacement', 'Cambio de caja pedalera'), value: 70.00, description: t('Remoção do central antigo e instalação do novo', 'Old BB removal and new BB installation', 'Remoción del central viejo e instalación del nuevo') },
      { name: t('Tubeless setup', 'Tubeless Setup', 'Montaje Tubeless'), value: 80.00, description: t('Conversão para pneu tubeless com selante', 'Tubeless tire conversion with sealant', 'Conversión a neumático tubeless con sellante') },
    ],
    products: [
      { name: t('Pneu MTB 29x2.40', 'MTB Tire 29x2.40', 'Neumático MTB 29x2.40'), value: 120.00 },
      { name: t('Cassete 12v (11-50T)', '12 Speed Cassette (11-50T)', 'Cassette 12v (11-50T)'), value: 280.00 },
      { name: t('Selante tubeless (250ml)', 'Tubeless Sealant (250ml)', 'Sellante tubeless (250ml)'), value: 45.00 },
      { name: t('Óleo de suspensão (500ml)', 'Fork Oil (500ml)', 'Aceite de suspensión (500ml)'), value: 55.00 },
      { name: t('Pastilha de freio Shimano', 'Shimano Brake Pad', 'Pastilla de freno Shimano'), value: 40.00 },
      { name: t('Retentores de suspensão', 'Fork Seals', 'Retenes de suspensión'), value: 65.00 },
    ],
    devices: [
      { name: 'Hype 60', manufacturer: 'Oggi', category: 'MTB', customFields: { year: 2023, color: t('Verde', 'Green', 'Verde') } },
      { name: 'Impact SL', manufacturer: 'Sense', category: 'MTB', customFields: { year: 2024, color: t('Carbono', 'Carbon', 'Carbono') } },
    ],
  },

  road: {
    services: [
      { name: t('Bike fit básico', 'Basic Bike Fit', 'Bike fit básico'), value: 200.00, description: t('Ajuste de selim, guidão e tacos', 'Saddle, handlebar and cleat adjustment', 'Ajuste de sillín, manillar y calas') },
      { name: t('Troca de fita de guidão', 'Bar Tape Replacement', 'Cambio de cinta de manillar'), value: 30.00, description: t('Remoção e aplicação de fita nova', 'Removal and application of new tape', 'Remoción y aplicación de cinta nueva') },
      { name: t('Troca de grupo completo', 'Full Groupset Install', 'Cambio de grupo completo'), value: 350.00, description: t('Desmontagem e montagem de grupo novo', 'Old groupset removal and new groupset install', 'Desmontaje y montaje de grupo nuevo') },
      { name: t('Regulagem de STI', 'STI Adjustment', 'Ajuste de STI'), value: 50.00, description: t('Ajuste de manetes de câmbio/freio integrados', 'Integrated shifter/brake lever adjustment', 'Ajuste de manetas de cambio/freno integradas') },
      { name: t('Centrar roda speed', 'Road Wheel Truing', 'Centrado de rueda ruta'), value: 55.00, description: t('Alinhamento de roda 700c com precisão', 'Precision 700c wheel truing', 'Alineación de rueda 700c con precisión') },
      { name: t('Revisão de pedal clip', 'Clipless Pedal Service', 'Revisión de pedal automático'), value: 40.00, description: t('Limpeza, lubrificação e ajuste de tensão', 'Cleaning, lubrication and tension adjustment', 'Limpieza, lubricación y ajuste de tensión') },
    ],
    products: [
      { name: t('Pneu 700x25c', 'Tire 700x25c', 'Neumático 700x25c'), value: 110.00 },
      { name: t('Câmara de ar 700c', '700c Inner Tube', 'Cámara de aire 700c'), value: 20.00 },
      { name: t('Fita de guidão cortiça', 'Cork Bar Tape', 'Cinta de manillar corcho'), value: 55.00 },
      { name: t('Corrente 11v Shimano', 'Shimano 11 Speed Chain', 'Cadena 11v Shimano'), value: 85.00 },
      { name: t('Taco de pedal (par)', 'Cleats (pair)', 'Calas (par)'), value: 50.00 },
      { name: t('Câmbio traseiro 105', 'Shimano 105 Rear Derailleur', 'Cambio trasero 105'), value: 450.00 },
    ],
    devices: [
      { name: 'Strattos S7', manufacturer: 'Caloi', category: 'Road', customFields: { year: 2023, color: t('Branco', 'White', 'Blanco') } },
      { name: 'Prologue Comp', manufacturer: 'Sense', category: 'Road', customFields: { year: 2024, color: t('Preto/Vermelho', 'Black/Red', 'Negro/Rojo') } },
    ],
  },

  ebike: {
    services: [
      { name: t('Diagnóstico elétrico', 'Electric Diagnosis', 'Diagnóstico eléctrico'), value: 100.00, description: t('Diagnóstico do sistema elétrico (motor, bateria, display)', 'Electric system diagnosis (motor, battery, display)', 'Diagnóstico del sistema eléctrico (motor, batería, display)') },
      { name: t('Revisão completa e-bike', 'Full E-bike Tune-up', 'Revisión completa e-bike'), value: 350.00, description: t('Revisão mecânica + verificação do sistema elétrico', 'Mechanical tune-up + electric system check', 'Revisión mecánica + verificación del sistema eléctrico') },
      { name: t('Troca de bateria', 'Battery Replacement', 'Cambio de batería'), value: 80.00, description: t('Remoção e instalação de bateria nova', 'Old battery removal and new battery installation', 'Remoción e instalación de batería nueva') },
      { name: t('Atualização de firmware', 'Firmware Update', 'Actualización de firmware'), value: 60.00, description: t('Atualização do software do controlador', 'Controller software update', 'Actualización del software del controlador') },
      { name: t('Reparo de fiação', 'Wiring Repair', 'Reparación de cableado'), value: 90.00, description: t('Reparo de conectores e fiação do sistema', 'System connector and wiring repair', 'Reparación de conectores y cableado del sistema') },
      { name: t('Regulagem de assistência', 'Pedal Assist Adjustment', 'Ajuste de asistencia'), value: 50.00, description: t('Calibração dos níveis de assistência ao pedal', 'Pedal assist levels calibration', 'Calibración de los niveles de asistencia al pedaleo') },
    ],
    products: [
      { name: t('Bateria 36V 10Ah', '36V 10Ah Battery', 'Batería 36V 10Ah'), value: 850.00 },
      { name: t('Carregador 36V', '36V Charger', 'Cargador 36V'), value: 180.00 },
      { name: t('Display LCD', 'LCD Display', 'Display LCD'), value: 220.00 },
      { name: t('Sensor de velocidade', 'Speed Sensor', 'Sensor de velocidad'), value: 75.00 },
      { name: t('Controlador 36V', '36V Controller', 'Controlador 36V'), value: 320.00 },
      { name: t('Sensor de torque', 'Torque Sensor', 'Sensor de torque'), value: 250.00 },
    ],
    devices: [
      { name: 'E-Vibe City Tour', manufacturer: 'Caloi', category: 'E-bike', customFields: { year: 2024, color: t('Cinza', 'Gray', 'Gris') } },
      { name: 'Impulse E-Trail', manufacturer: 'Sense', category: 'E-bike', customFields: { year: 2023, color: t('Preto/Verde', 'Black/Green', 'Negro/Verde') } },
    ],
  },
};
