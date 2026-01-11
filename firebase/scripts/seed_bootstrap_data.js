const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════
// DADOS DE BOOTSTRAP POR SEGMENTO/SUBCATEGORIA
// ═══════════════════════════════════════════════════════════════════════════
// Estrutura: { segmentId: { subspecialtyId: { services, products, devices, customer } } }
// Para segmentos sem subspecialties, usar '_default' como chave

const BOOTSTRAP_DATA = {
  // ═══════════════════════════════════════════════════════════
  // AUTOMOTIVO
  // ═══════════════════════════════════════════════════════════
  automotive: {
    // Cliente compartilhado para todas as subspecialties do automotivo
    _customer: {
      name: 'João da Silva (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 123',
    },

    mechanical: {
      services: [
        { name: 'Troca de óleo', value: 80.00, description: 'Troca de óleo do motor com filtro' },
        { name: 'Alinhamento', value: 120.00, description: 'Alinhamento de direção computadorizado' },
        { name: 'Balanceamento', value: 60.00, description: 'Balanceamento das 4 rodas' },
        { name: 'Revisão de freios', value: 150.00, description: 'Inspeção e ajuste do sistema de freios' },
        { name: 'Diagnóstico eletrônico', value: 100.00, description: 'Scanner e diagnóstico de falhas' },
        { name: 'Troca de pastilhas de freio', value: 180.00, description: 'Substituição de pastilhas dianteiras' },
        { name: 'Higienização do ar', value: 90.00, description: 'Limpeza do sistema de ar condicionado' },
        { name: 'Troca de correia dentada', value: 350.00, description: 'Substituição de correia e tensionadores' },
      ],
      products: [
        { name: 'Óleo 5W30 Sintético (1L)', value: 45.00 },
        { name: 'Filtro de óleo', value: 35.00 },
        { name: 'Filtro de ar', value: 55.00 },
        { name: 'Filtro de combustível', value: 65.00 },
        { name: 'Pastilha de freio dianteira (jogo)', value: 120.00 },
        { name: 'Lâmpada farol H7', value: 25.00 },
        { name: 'Fluido de freio DOT 4 (500ml)', value: 35.00 },
        { name: 'Vela de ignição', value: 28.00 },
      ],
      devices: [
        { name: 'Onix 1.0', manufacturer: 'Chevrolet', category: 'Hatch', customFields: { year: 2022, mileage: 45000, color: 'Prata' } },
        { name: 'HB20 1.6', manufacturer: 'Hyundai', category: 'Hatch', customFields: { year: 2021, mileage: 38000, color: 'Branco' } },
      ],
    },

    carwash: {
      services: [
        { name: 'Lavagem simples', value: 40.00, description: 'Lavagem externa básica' },
        { name: 'Lavagem completa', value: 70.00, description: 'Lavagem externa + interna' },
        { name: 'Lavagem detalhada', value: 120.00, description: 'Lavagem completa + motor + porta-malas' },
        { name: 'Higienização interna', value: 150.00, description: 'Limpeza profunda de estofados e carpetes' },
        { name: 'Lavagem de motor', value: 80.00, description: 'Limpeza e desengraxe do motor' },
        { name: 'Enceramento', value: 100.00, description: 'Aplicação de cera protetora' },
        { name: 'Cristalização de vidros', value: 80.00, description: 'Tratamento hidrofóbico nos vidros' },
        { name: 'Hidratação de couro', value: 90.00, description: 'Tratamento de bancos de couro' },
      ],
      products: [
        { name: 'Shampoo automotivo (5L)', value: 35.00 },
        { name: 'Cera líquida (500ml)', value: 45.00 },
        { name: 'Pretinho para pneus (1L)', value: 25.00 },
        { name: 'Limpa vidros (500ml)', value: 18.00 },
        { name: 'Aromatizante (unidade)', value: 12.00 },
        { name: 'Silicone para painel (300ml)', value: 22.00 },
        { name: 'Desengraxante (1L)', value: 28.00 },
        { name: 'Hidratante de couro (500ml)', value: 55.00 },
      ],
      devices: [
        { name: 'Corolla XEi', manufacturer: 'Toyota', category: 'Sedan', customFields: { year: 2023, color: 'Preto' } },
        { name: 'Tracker LT', manufacturer: 'Chevrolet', category: 'SUV', customFields: { year: 2022, color: 'Branco' } },
      ],
    },

    painting: {
      services: [
        { name: 'Pintura de para-choque', value: 450.00, description: 'Pintura completa de para-choque' },
        { name: 'Pintura de porta', value: 600.00, description: 'Pintura completa de porta' },
        { name: 'Pintura de capô', value: 700.00, description: 'Pintura completa de capô' },
        { name: 'Polimento técnico', value: 250.00, description: 'Polimento para remoção de riscos' },
        { name: 'Vitrificação', value: 800.00, description: 'Proteção cerâmica da pintura' },
        { name: 'Retoque de pintura', value: 150.00, description: 'Correção de pequenas avarias' },
        { name: 'Reparo de para-choque', value: 300.00, description: 'Reparo de trincas e furos' },
        { name: 'Envelopamento parcial', value: 500.00, description: 'Aplicação de película em peças' },
      ],
      products: [
        { name: 'Tinta automotiva (lata)', value: 180.00 },
        { name: 'Verniz automotivo (1L)', value: 120.00 },
        { name: 'Massa plástica (kg)', value: 35.00 },
        { name: 'Lixa d\'água (pacote)', value: 15.00 },
        { name: 'Primer (1L)', value: 65.00 },
        { name: 'Thinner (1L)', value: 28.00 },
        { name: 'Cera de polimento (500g)', value: 85.00 },
        { name: 'Fita crepe automotiva', value: 18.00 },
      ],
      devices: [
        { name: 'Civic Touring', manufacturer: 'Honda', category: 'Sedan', customFields: { year: 2022, color: 'Cinza' } },
        { name: 'Kicks Advance', manufacturer: 'Nissan', category: 'SUV', customFields: { year: 2021, color: 'Vermelho' } },
      ],
    },

    bodywork: {
      services: [
        { name: 'Martelinho de ouro', value: 200.00, description: 'Reparo de amassados sem pintura (PDR)' },
        { name: 'Desamassar porta', value: 350.00, description: 'Reparo de amassado em porta' },
        { name: 'Desamassar capô', value: 400.00, description: 'Reparo de amassado em capô' },
        { name: 'Desamassar teto', value: 500.00, description: 'Reparo de amassado por granizo' },
        { name: 'Troca de para-lama', value: 250.00, description: 'Substituição de para-lama' },
        { name: 'Alinhamento de carroceria', value: 600.00, description: 'Correção estrutural de carroceria' },
        { name: 'Reparo de paralama', value: 300.00, description: 'Reparo de amassado em paralama' },
        { name: 'Solda de lataria', value: 180.00, description: 'Serviço de solda em peças' },
      ],
      products: [
        { name: 'Kit ferramentas PDR', value: 450.00 },
        { name: 'Cola para PDR (kg)', value: 85.00 },
        { name: 'Ventosa profissional', value: 120.00 },
        { name: 'Martelo de borracha', value: 45.00 },
        { name: 'Tas de repuxo (jogo)', value: 180.00 },
        { name: 'Eletrodo de solda (kg)', value: 35.00 },
        { name: 'Esmerilhadeira (disco)', value: 15.00 },
        { name: 'Removedor de cola', value: 28.00 },
      ],
      devices: [
        { name: 'Creta Attitude', manufacturer: 'Hyundai', category: 'SUV', customFields: { year: 2023, color: 'Prata' } },
        { name: 'Polo TSI', manufacturer: 'Volkswagen', category: 'Hatch', customFields: { year: 2022, color: 'Azul' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // HVAC
  // ═══════════════════════════════════════════════════════════
  hvac: {
    _customer: {
      name: 'Maria Santos (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Av. Exemplo, 456',
    },

    residential: {
      services: [
        { name: 'Instalação de split', value: 350.00, description: 'Instalação completa de ar split' },
        { name: 'Manutenção preventiva', value: 180.00, description: 'Limpeza e verificação geral' },
        { name: 'Higienização', value: 120.00, description: 'Limpeza profunda com produtos específicos' },
        { name: 'Carga de gás', value: 250.00, description: 'Recarga de gás refrigerante' },
        { name: 'Reparo de vazamento', value: 200.00, description: 'Detecção e reparo de vazamentos' },
        { name: 'Troca de capacitor', value: 150.00, description: 'Substituição de capacitor queimado' },
        { name: 'Desinstalação', value: 150.00, description: 'Remoção segura do equipamento' },
        { name: 'Instalação de suporte', value: 120.00, description: 'Instalação de suporte para condensadora' },
      ],
      products: [
        { name: 'Gás R410A (kg)', value: 120.00 },
        { name: 'Gás R32 (kg)', value: 130.00 },
        { name: 'Capacitor 35μF', value: 45.00 },
        { name: 'Capacitor 25μF', value: 40.00 },
        { name: 'Filtro de ar (universal)', value: 25.00 },
        { name: 'Suporte para condensadora', value: 85.00 },
        { name: 'Tubo de cobre 1/4 (metro)', value: 35.00 },
        { name: 'Fita térmica (rolo)', value: 18.00 },
      ],
      devices: [
        { name: 'Split 12000 BTUs', manufacturer: 'Samsung', category: 'Split', customFields: { btus: '12000', voltage: '220V', gasType: 'R-410A' } },
        { name: 'Split 9000 BTUs', manufacturer: 'LG', category: 'Split', customFields: { btus: '9000', voltage: '220V', gasType: 'R-32' } },
      ],
    },

    commercial: {
      services: [
        { name: 'Instalação de VRF', value: 2500.00, description: 'Instalação de sistema VRF' },
        { name: 'Manutenção de chiller', value: 800.00, description: 'Manutenção preventiva de chiller' },
        { name: 'Manutenção de câmara fria', value: 600.00, description: 'Verificação e ajustes de câmara fria' },
        { name: 'Carga de gás industrial', value: 450.00, description: 'Recarga de gás em equipamentos comerciais' },
        { name: 'Limpeza de dutos', value: 350.00, description: 'Limpeza de sistema de dutos' },
        { name: 'Balanceamento de vazão', value: 400.00, description: 'Ajuste de vazão de ar em ambientes' },
        { name: 'Manutenção preventiva predial', value: 500.00, description: 'Contrato de manutenção mensal' },
        { name: 'Reparo de fancoil', value: 300.00, description: 'Manutenção de fancoil' },
      ],
      products: [
        { name: 'Gás R410A (kg)', value: 120.00 },
        { name: 'Gás R404A (kg)', value: 150.00 },
        { name: 'Compressor rotativo', value: 1200.00 },
        { name: 'Motor ventilador', value: 450.00 },
        { name: 'Filtro de ar industrial', value: 85.00 },
        { name: 'Termostato digital', value: 180.00 },
        { name: 'Válvula de expansão', value: 350.00 },
        { name: 'Pressostato', value: 120.00 },
      ],
      devices: [
        { name: 'Cassete 36000 BTUs', manufacturer: 'Daikin', category: 'Cassete', customFields: { btus: '30000', voltage: '220V', gasType: 'R-410A' } },
        { name: 'Split Piso Teto 48000 BTUs', manufacturer: 'Carrier', category: 'Piso Teto', customFields: { btus: '30000', voltage: 'Bifásico', gasType: 'R-410A' } },
        { name: 'Câmara Fria 10m³', manufacturer: 'Elgin', category: 'Câmara Fria', customFields: { voltage: '220V', gasType: 'R-404A' } },
      ],
    },

    automotive_ac: {
      services: [
        { name: 'Recarga de gás', value: 200.00, description: 'Recarga de gás R134a' },
        { name: 'Higienização do sistema', value: 120.00, description: 'Limpeza do sistema de ar' },
        { name: 'Troca de filtro de cabine', value: 80.00, description: 'Substituição do filtro antipólen' },
        { name: 'Reparo de compressor', value: 450.00, description: 'Reparo ou substituição do compressor' },
        { name: 'Troca de condensador', value: 350.00, description: 'Substituição do condensador' },
        { name: 'Troca de evaporador', value: 400.00, description: 'Substituição do evaporador' },
        { name: 'Diagnóstico de vazamento', value: 100.00, description: 'Detecção de vazamentos no sistema' },
        { name: 'Troca de válvula de expansão', value: 250.00, description: 'Substituição da válvula de expansão' },
      ],
      products: [
        { name: 'Gás R134a (kg)', value: 100.00 },
        { name: 'Gás R1234yf (kg)', value: 350.00 },
        { name: 'Filtro secador', value: 85.00 },
        { name: 'Óleo PAG (250ml)', value: 65.00 },
        { name: 'Filtro de cabine', value: 45.00 },
        { name: 'Válvula de expansão universal', value: 180.00 },
        { name: 'Pressostato automotivo', value: 95.00 },
        { name: 'Anel de vedação (kit)', value: 35.00 },
      ],
      devices: [
        { name: 'Civic EXL', manufacturer: 'Honda', category: 'Sedan', customFields: { year: 2022, mileage: 35000, gasType: 'R-134a' } },
        { name: 'Hilux SRV', manufacturer: 'Toyota', category: 'Pickup', customFields: { year: 2021, mileage: 62000, gasType: 'R-134a' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // SMARTPHONES (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  smartphones: {
    _customer: {
      name: 'Pedro Oliveira (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 789',
    },

    _default: {
      services: [
        { name: 'Troca de tela', value: 250.00, description: 'Substituição de display LCD/OLED' },
        { name: 'Troca de bateria', value: 120.00, description: 'Substituição de bateria' },
        { name: 'Troca de conector de carga', value: 100.00, description: 'Reparo do conector USB/Lightning' },
        { name: 'Reparo de placa', value: 200.00, description: 'Micro soldagem em placa' },
        { name: 'Atualização de software', value: 50.00, description: 'Atualização do sistema operacional' },
        { name: 'Backup de dados', value: 80.00, description: 'Backup completo do dispositivo' },
        { name: 'Limpeza interna', value: 60.00, description: 'Limpeza de poeira e oxidação' },
      ],
      products: [
        { name: 'Tela iPhone 11', value: 350.00 },
        { name: 'Tela Samsung A54', value: 280.00 },
        { name: 'Bateria iPhone (genérica)', value: 80.00 },
        { name: 'Bateria Samsung (genérica)', value: 70.00 },
        { name: 'Conector de carga USB-C', value: 25.00 },
        { name: 'Película de vidro', value: 15.00 },
        { name: 'Capinha de silicone', value: 20.00 },
      ],
      devices: [
        { name: 'iPhone 13', manufacturer: 'Apple', category: 'Smartphone', customFields: { storage: '128GB', color: 'Azul' } },
        { name: 'Galaxy S23', manufacturer: 'Samsung', category: 'Smartphone', customFields: { storage: '256GB', color: 'Preto' } },
        { name: 'Moto G84', manufacturer: 'Motorola', category: 'Smartphone', customFields: { storage: '128GB', color: 'Grafite' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // INFORMÁTICA
  // ═══════════════════════════════════════════════════════════
  computers: {
    _customer: {
      name: 'Ana Costa (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Av. Exemplo, 321',
    },

    desktop: {
      services: [
        { name: 'Formatação e instalação', value: 150.00, description: 'Formatação com instalação de SO' },
        { name: 'Limpeza interna', value: 80.00, description: 'Limpeza de poeira e troca de pasta' },
        { name: 'Remoção de vírus', value: 100.00, description: 'Scan e remoção de malware' },
        { name: 'Upgrade de memória', value: 80.00, description: 'Instalação de memória RAM' },
        { name: 'Instalação de SSD', value: 100.00, description: 'Migração de HD para SSD' },
        { name: 'Montagem de PC', value: 250.00, description: 'Montagem de computador completo' },
        { name: 'Troca de fonte', value: 120.00, description: 'Substituição de fonte de alimentação' },
        { name: 'Upgrade de placa de vídeo', value: 100.00, description: 'Instalação de GPU' },
      ],
      products: [
        { name: 'Memória RAM DDR4 8GB', value: 180.00 },
        { name: 'Memória RAM DDR4 16GB', value: 320.00 },
        { name: 'SSD 240GB', value: 200.00 },
        { name: 'SSD 480GB', value: 320.00 },
        { name: 'Fonte 500W 80 Plus', value: 280.00 },
        { name: 'Pasta térmica (5g)', value: 25.00 },
        { name: 'Cabo SATA', value: 15.00 },
        { name: 'Cooler para processador', value: 120.00 },
      ],
      devices: [
        { name: 'Desktop OptiPlex 3080', manufacturer: 'Dell', category: 'Desktop', customFields: { processor: 'Intel i5-10500', ram: '8GB', storage: 'SSD 256GB' } },
        { name: 'PC Gamer Custom', manufacturer: 'Montado', category: 'Desktop', customFields: { processor: 'AMD Ryzen 5 5600', ram: '16GB', storage: 'SSD 512GB' } },
      ],
    },

    notebook: {
      services: [
        { name: 'Formatação e instalação', value: 150.00, description: 'Formatação com instalação de SO' },
        { name: 'Troca de tela', value: 450.00, description: 'Substituição de display LCD/LED' },
        { name: 'Troca de teclado', value: 200.00, description: 'Substituição de teclado' },
        { name: 'Troca de bateria', value: 250.00, description: 'Substituição de bateria' },
        { name: 'Reparo de dobradiça', value: 180.00, description: 'Reparo ou troca de dobradiças' },
        { name: 'Troca de conector DC', value: 150.00, description: 'Reparo do conector de energia' },
        { name: 'Upgrade de memória', value: 80.00, description: 'Instalação de RAM' },
        { name: 'Troca de cooler', value: 120.00, description: 'Substituição do sistema de refrigeração' },
      ],
      products: [
        { name: 'Tela 15.6" HD', value: 380.00 },
        { name: 'Tela 14" Full HD', value: 450.00 },
        { name: 'Bateria universal 6 células', value: 200.00 },
        { name: 'Teclado notebook (compatível)', value: 150.00 },
        { name: 'SSD M.2 NVMe 256GB', value: 250.00 },
        { name: 'Memória DDR4 SODIMM 8GB', value: 190.00 },
        { name: 'Cooler para notebook', value: 85.00 },
        { name: 'Pasta térmica (5g)', value: 25.00 },
      ],
      devices: [
        { name: 'IdeaPad 3i', manufacturer: 'Lenovo', category: 'Notebook', customFields: { processor: 'Intel i5-1135G7', ram: '8GB', storage: 'SSD 256GB' } },
        { name: 'MacBook Air M1', manufacturer: 'Apple', category: 'Notebook', customFields: { processor: 'Apple M1', ram: '8GB', storage: 'SSD 256GB' } },
        { name: 'Inspiron 15', manufacturer: 'Dell', category: 'Notebook', customFields: { processor: 'Intel i7-1165G7', ram: '16GB', storage: 'SSD 512GB' } },
      ],
    },

    networks: {
      services: [
        { name: 'Instalação de rede cabeada', value: 350.00, description: 'Instalação de pontos de rede' },
        { name: 'Configuração de roteador', value: 100.00, description: 'Setup de roteador Wi-Fi' },
        { name: 'Instalação de rack', value: 250.00, description: 'Montagem de rack de rede' },
        { name: 'Crimpagem de cabos (ponto)', value: 25.00, description: 'Conectorização de cabo UTP' },
        { name: 'Configuração de switch', value: 150.00, description: 'Setup de switch gerenciável' },
        { name: 'Passagem de cabos (metro)', value: 15.00, description: 'Instalação de infraestrutura' },
        { name: 'Configuração de Access Point', value: 120.00, description: 'Setup de AP Wi-Fi' },
        { name: 'Diagnóstico de rede', value: 100.00, description: 'Análise de problemas de conectividade' },
      ],
      products: [
        { name: 'Cabo UTP Cat5e (metro)', value: 3.50 },
        { name: 'Cabo UTP Cat6 (metro)', value: 5.00 },
        { name: 'Conector RJ45 (pacote 100)', value: 45.00 },
        { name: 'Switch 8 portas', value: 150.00 },
        { name: 'Switch 16 portas', value: 280.00 },
        { name: 'Roteador Wi-Fi 6', value: 350.00 },
        { name: 'Access Point', value: 280.00 },
        { name: 'Patch panel 24 portas', value: 180.00 },
      ],
      devices: [
        { name: 'Switch SG1008D', manufacturer: 'TP-Link', category: 'Switch' },
        { name: 'Roteador Archer AX23', manufacturer: 'TP-Link', category: 'Roteador' },
        { name: 'Access Point EAP225', manufacturer: 'TP-Link', category: 'Access Point' },
      ],
    },

    servers: {
      services: [
        { name: 'Instalação de servidor', value: 500.00, description: 'Setup completo de servidor' },
        { name: 'Configuração de RAID', value: 250.00, description: 'Configuração de array de discos' },
        { name: 'Instalação de Windows Server', value: 300.00, description: 'Instalação e configuração de SO' },
        { name: 'Instalação de Linux Server', value: 250.00, description: 'Instalação e configuração de SO' },
        { name: 'Configuração de backup', value: 200.00, description: 'Setup de rotina de backup' },
        { name: 'Manutenção preventiva', value: 350.00, description: 'Limpeza e verificação de hardware' },
        { name: 'Expansão de storage', value: 200.00, description: 'Instalação de discos adicionais' },
        { name: 'Virtualização (por VM)', value: 150.00, description: 'Configuração de máquina virtual' },
      ],
      products: [
        { name: 'HD Enterprise 1TB', value: 450.00 },
        { name: 'HD Enterprise 4TB', value: 850.00 },
        { name: 'SSD Enterprise 480GB', value: 550.00 },
        { name: 'Memória ECC 16GB', value: 450.00 },
        { name: 'Controladora RAID', value: 800.00 },
        { name: 'Fonte redundante', value: 650.00 },
        { name: 'Nobreak 1500VA', value: 950.00 },
        { name: 'Cabo de rede Cat6 (patch cord)', value: 25.00 },
      ],
      devices: [
        { name: 'PowerEdge T140', manufacturer: 'Dell', category: 'Servidor Torre', customFields: { processor: 'Intel Xeon E-2224', ram: '16GB ECC', storage: 'HD 1TB' } },
        { name: 'ProLiant ML30', manufacturer: 'HPE', category: 'Servidor Torre', customFields: { processor: 'Intel Xeon E-2224', ram: '8GB ECC', storage: 'HD 1TB' } },
        { name: 'Storage NAS 4 baias', manufacturer: 'Synology', category: 'Storage', customFields: { storage: '4x 4TB' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // ELETRODOMÉSTICOS (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  appliances: {
    _customer: {
      name: 'Carlos Ferreira (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 654',
    },

    _default: {
      services: [
        { name: 'Diagnóstico', value: 80.00, description: 'Avaliação técnica do problema' },
        { name: 'Troca de resistência', value: 150.00, description: 'Substituição de resistência' },
        { name: 'Troca de termostato', value: 120.00, description: 'Substituição de termostato' },
        { name: 'Troca de timer', value: 180.00, description: 'Substituição do timer mecânico' },
        { name: 'Troca de motor', value: 250.00, description: 'Substituição do motor' },
        { name: 'Reparo de placa', value: 200.00, description: 'Conserto de placa eletrônica' },
        { name: 'Recarga de gás (geladeira)', value: 300.00, description: 'Recarga de gás refrigerante' },
      ],
      products: [
        { name: 'Resistência para chuveiro', value: 35.00 },
        { name: 'Termostato universal', value: 65.00 },
        { name: 'Timer mecânico', value: 120.00 },
        { name: 'Capacitor para motor', value: 45.00 },
        { name: 'Borracha de geladeira (metro)', value: 50.00 },
        { name: 'Gás R134a (kg)', value: 100.00 },
        { name: 'Mangueira de entrada', value: 30.00 },
      ],
      devices: [
        { name: 'Geladeira Frost Free 400L', manufacturer: 'Brastemp', category: 'Refrigerador', customFields: { voltage: '220V' } },
        { name: 'Máquina de Lavar 12kg', manufacturer: 'Electrolux', category: 'Lavadora', customFields: { voltage: '220V' } },
        { name: 'Micro-ondas 30L', manufacturer: 'Panasonic', category: 'Micro-ondas', customFields: { voltage: '220V' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // SEGURANÇA ELETRÔNICA
  // ═══════════════════════════════════════════════════════════
  security: {
    _customer: {
      name: 'Roberto Lima (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 999',
    },

    cctv: {
      services: [
        { name: 'Instalação de câmera', value: 150.00, description: 'Instalação de câmera com passagem de cabo' },
        { name: 'Instalação de DVR/NVR', value: 200.00, description: 'Configuração de gravador digital' },
        { name: 'Configuração de acesso remoto', value: 100.00, description: 'Setup de visualização pelo celular' },
        { name: 'Manutenção preventiva', value: 180.00, description: 'Limpeza e verificação do sistema' },
        { name: 'Troca de HD do DVR', value: 150.00, description: 'Substituição de disco de gravação' },
        { name: 'Instalação de cabo (metro)', value: 12.00, description: 'Passagem de cabo coaxial/rede' },
        { name: 'Configuração de detecção', value: 80.00, description: 'Setup de detecção de movimento' },
        { name: 'Reparo de câmera', value: 120.00, description: 'Diagnóstico e reparo de câmera' },
      ],
      products: [
        { name: 'Câmera Bullet HD', value: 180.00 },
        { name: 'Câmera Dome HD', value: 200.00 },
        { name: 'Câmera IP 2MP', value: 280.00 },
        { name: 'DVR 8 canais', value: 450.00 },
        { name: 'NVR 8 canais', value: 550.00 },
        { name: 'HD 1TB Surveillance', value: 350.00 },
        { name: 'HD 2TB Surveillance', value: 480.00 },
        { name: 'Cabo coaxial (rolo 100m)', value: 180.00 },
        { name: 'Fonte 12V 5A', value: 45.00 },
        { name: 'Conector BNC (pacote 10)', value: 25.00 },
      ],
      devices: [
        { name: 'DVR 8CH MHDX 1108', manufacturer: 'Intelbras', category: 'DVR', customFields: { channels: '8', systemType: 'CFTV' } },
        { name: 'Câmera VHD 1120 B', manufacturer: 'Intelbras', category: 'Câmera', customFields: { systemType: 'CFTV' } },
      ],
    },

    alarms: {
      services: [
        { name: 'Instalação de central', value: 250.00, description: 'Instalação de central de alarme' },
        { name: 'Instalação de sensor', value: 80.00, description: 'Instalação de sensor magnético/infra' },
        { name: 'Configuração de monitoramento', value: 150.00, description: 'Setup com central de monitoramento' },
        { name: 'Manutenção preventiva', value: 120.00, description: 'Teste e verificação do sistema' },
        { name: 'Troca de bateria', value: 100.00, description: 'Substituição de bateria da central' },
        { name: 'Instalação de sirene', value: 80.00, description: 'Instalação de sirene interna/externa' },
        { name: 'Configuração de app', value: 80.00, description: 'Setup de controle pelo celular' },
        { name: 'Expansão de zonas', value: 150.00, description: 'Adição de zonas na central' },
      ],
      products: [
        { name: 'Central de alarme 8 zonas', value: 350.00 },
        { name: 'Central de alarme monitorada', value: 480.00 },
        { name: 'Sensor infravermelho', value: 65.00 },
        { name: 'Sensor magnético', value: 35.00 },
        { name: 'Sensor de presença PET', value: 95.00 },
        { name: 'Sirene 120dB', value: 85.00 },
        { name: 'Controle remoto', value: 45.00 },
        { name: 'Bateria 12V 7Ah', value: 90.00 },
        { name: 'Teclado para central', value: 120.00 },
        { name: 'Cabo de alarme 4 vias (100m)', value: 85.00 },
      ],
      devices: [
        { name: 'Central AMT 2018 E', manufacturer: 'Intelbras', category: 'Central de Alarme', customFields: { channels: '8', systemType: 'Alarme' } },
        { name: 'Sensor IVP 3000', manufacturer: 'Intelbras', category: 'Sensor', customFields: { systemType: 'Alarme' } },
      ],
    },

    access: {
      services: [
        { name: 'Instalação de controle de acesso', value: 300.00, description: 'Instalação completa de equipamento' },
        { name: 'Configuração de biometria', value: 150.00, description: 'Cadastro de digitais' },
        { name: 'Instalação de fechadura', value: 200.00, description: 'Instalação de fechadura eletrônica' },
        { name: 'Configuração de software', value: 180.00, description: 'Setup de software de gestão' },
        { name: 'Instalação de catraca', value: 450.00, description: 'Instalação de catraca de acesso' },
        { name: 'Manutenção preventiva', value: 150.00, description: 'Verificação e ajustes do sistema' },
        { name: 'Cadastro de usuários', value: 80.00, description: 'Cadastro em massa de usuários' },
        { name: 'Integração com CFTV', value: 200.00, description: 'Integração com sistema de câmeras' },
      ],
      products: [
        { name: 'Controlador de acesso biométrico', value: 650.00 },
        { name: 'Controlador de acesso facial', value: 1200.00 },
        { name: 'Fechadura eletroímã', value: 280.00 },
        { name: 'Fechadura elétrica', value: 150.00 },
        { name: 'Leitor de cartão RFID', value: 180.00 },
        { name: 'Cartão RFID (pacote 100)', value: 120.00 },
        { name: 'Botão de saída', value: 35.00 },
        { name: 'Fonte 12V 3A', value: 55.00 },
        { name: 'Botoeira antipânico', value: 85.00 },
        { name: 'Nobreak para controle de acesso', value: 350.00 },
      ],
      devices: [
        { name: 'SS 3430 BIO', manufacturer: 'Intelbras', category: 'Controle de Acesso', customFields: { systemType: 'Controle de acesso' } },
        { name: 'XPE 1001 FACE', manufacturer: 'Intelbras', category: 'Controle de Acesso', customFields: { systemType: 'Controle de acesso' } },
      ],
    },

    fence: {
      services: [
        { name: 'Instalação de cerca (metro)', value: 45.00, description: 'Instalação de fios e hastes' },
        { name: 'Instalação de central', value: 250.00, description: 'Instalação de central de choque' },
        { name: 'Manutenção preventiva', value: 150.00, description: 'Verificação de voltagem e isoladores' },
        { name: 'Reparo de cerca', value: 120.00, description: 'Conserto de fios rompidos' },
        { name: 'Instalação de haste', value: 25.00, description: 'Instalação de haste isoladora' },
        { name: 'Configuração de alarme', value: 100.00, description: 'Integração com sistema de alarme' },
        { name: 'Troca de central', value: 200.00, description: 'Substituição de central de choque' },
        { name: 'Regulagem de voltagem', value: 80.00, description: 'Ajuste de tensão da cerca' },
      ],
      products: [
        { name: 'Central de cerca elétrica', value: 380.00 },
        { name: 'Central com alarme integrado', value: 520.00 },
        { name: 'Haste M 75cm (4 isoladores)', value: 35.00 },
        { name: 'Haste M 100cm (6 isoladores)', value: 45.00 },
        { name: 'Fio de aço inox (100m)', value: 65.00 },
        { name: 'Fio de aço galvanizado (250m)', value: 85.00 },
        { name: 'Isolador castanha (pacote 100)', value: 55.00 },
        { name: 'Bateria 12V 7Ah', value: 90.00 },
        { name: 'Sirene para cerca', value: 75.00 },
        { name: 'Placa de advertência', value: 15.00 },
      ],
      devices: [
        { name: 'Central ELC 5002', manufacturer: 'JFL', category: 'Cerca Elétrica', customFields: { systemType: 'Cerca elétrica' } },
        { name: 'Central Shock Control', manufacturer: 'Genno', category: 'Cerca Elétrica', customFields: { systemType: 'Cerca elétrica' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // ELÉTRICA (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  electrical: {
    _customer: {
      name: 'José Souza (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 111',
    },

    _default: {
      services: [
        { name: 'Instalação de tomada', value: 80.00, description: 'Instalação de tomada nova' },
        { name: 'Instalação de disjuntor', value: 100.00, description: 'Instalação de disjuntor no quadro' },
        { name: 'Troca de fiação', value: 150.00, description: 'Substituição de fiação antiga' },
        { name: 'Instalação de chuveiro', value: 120.00, description: 'Instalação elétrica de chuveiro' },
        { name: 'Instalação de lustre', value: 80.00, description: 'Instalação de luminária/lustre' },
        { name: 'Manutenção de quadro', value: 200.00, description: 'Revisão do quadro de distribuição' },
        { name: 'Aterramento', value: 350.00, description: 'Instalação de sistema de aterramento' },
      ],
      products: [
        { name: 'Tomada 20A', value: 25.00 },
        { name: 'Disjuntor 20A', value: 35.00 },
        { name: 'Disjuntor 40A', value: 45.00 },
        { name: 'Fio 2,5mm (100m)', value: 180.00 },
        { name: 'Fio 4mm (100m)', value: 250.00 },
        { name: 'DR 40A', value: 120.00 },
        { name: 'Quadro de distribuição 12 disjuntores', value: 85.00 },
      ],
      devices: [
        { name: 'Residência - Quadro Principal', manufacturer: 'Genérico', category: 'Instalação', customFields: { voltage: '220V', mainBreaker: 50 } },
        { name: 'Comércio - Quadro de Força', manufacturer: 'Genérico', category: 'Instalação', customFields: { voltage: 'Trifásico', mainBreaker: 100 } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // HIDRÁULICA (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  plumbing: {
    _customer: {
      name: 'Marcos Almeida (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 222',
    },

    _default: {
      services: [
        { name: 'Desentupimento', value: 150.00, description: 'Desentupimento de ralos e pias' },
        { name: 'Troca de torneira', value: 80.00, description: 'Substituição de torneira' },
        { name: 'Reparo de vazamento', value: 120.00, description: 'Conserto de vazamentos' },
        { name: 'Instalação de caixa d\'água', value: 250.00, description: 'Instalação de reservatório' },
        { name: 'Troca de válvula de descarga', value: 150.00, description: 'Substituição de válvula' },
        { name: 'Instalação de aquecedor', value: 200.00, description: 'Instalação de aquecedor de água' },
        { name: 'Caça vazamento', value: 180.00, description: 'Detecção de vazamentos ocultos' },
      ],
      products: [
        { name: 'Torneira para pia', value: 65.00 },
        { name: 'Válvula de descarga', value: 120.00 },
        { name: 'Sifão sanfonado', value: 25.00 },
        { name: 'Tubo PVC 50mm (metro)', value: 15.00 },
        { name: 'Joelho 90º 50mm', value: 8.00 },
        { name: 'Fita veda rosca', value: 12.00 },
        { name: 'Registro de pressão 3/4', value: 45.00 },
      ],
      devices: [
        { name: 'Residência - Sistema Hidráulico', manufacturer: 'Genérico', category: 'Instalação', customFields: { waterType: 'Ambas', pressure: 'Normal' } },
        { name: 'Apartamento - Banheiro Social', manufacturer: 'Genérico', category: 'Instalação', customFields: { waterType: 'Ambas', pressure: 'Baixa' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // ENERGIA SOLAR (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  solar: {
    _customer: {
      name: 'Fernando Ribeiro (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 333',
    },

    _default: {
      services: [
        { name: 'Instalação de sistema', value: 3500.00, description: 'Instalação completa do sistema solar' },
        { name: 'Manutenção preventiva', value: 350.00, description: 'Limpeza e verificação do sistema' },
        { name: 'Limpeza de painéis', value: 200.00, description: 'Limpeza de módulos fotovoltaicos' },
        { name: 'Substituição de inversor', value: 800.00, description: 'Troca de inversor solar' },
        { name: 'Monitoramento remoto', value: 150.00, description: 'Configuração de app de monitoramento' },
        { name: 'Expansão do sistema', value: 1500.00, description: 'Adição de módulos ao sistema' },
        { name: 'Reparo de string box', value: 250.00, description: 'Manutenção de caixa de junção' },
      ],
      products: [
        { name: 'Módulo fotovoltaico 550W', value: 950.00 },
        { name: 'Inversor 5kW', value: 4500.00 },
        { name: 'String box', value: 350.00 },
        { name: 'Cabo solar 6mm (metro)', value: 12.00 },
        { name: 'Conector MC4 (par)', value: 25.00 },
        { name: 'Estrutura de fixação (kit)', value: 450.00 },
        { name: 'DPS para sistema solar', value: 180.00 },
      ],
      devices: [
        { name: 'Sistema 5kWp', manufacturer: 'Canadian Solar', category: 'Sistema Fotovoltaico', customFields: { kwp: 5, panelCount: 10 } },
        { name: 'Sistema 10kWp', manufacturer: 'JA Solar', category: 'Sistema Fotovoltaico', customFields: { kwp: 10, panelCount: 20 } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // IMPRESSORAS (sem subspecialties)
  // ═══════════════════════════════════════════════════════════
  printers: {
    _customer: {
      name: 'Patrícia Mendes (Exemplo)',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Rua Exemplo, 444',
    },

    _default: {
      services: [
        { name: 'Manutenção preventiva', value: 150.00, description: 'Limpeza e verificação geral' },
        { name: 'Troca de cartucho/toner', value: 80.00, description: 'Substituição de suprimento' },
        { name: 'Reparo de fusor', value: 250.00, description: 'Manutenção do sistema de fusão' },
        { name: 'Troca de cabeça de impressão', value: 200.00, description: 'Substituição de cabeça jato de tinta' },
        { name: 'Limpeza de trilhos', value: 100.00, description: 'Limpeza do sistema de transporte' },
        { name: 'Configuração de rede', value: 80.00, description: 'Setup de impressora em rede' },
        { name: 'Reparo de placa', value: 300.00, description: 'Conserto de placa lógica' },
      ],
      products: [
        { name: 'Toner HP 85A', value: 120.00 },
        { name: 'Toner Brother TN-1060', value: 95.00 },
        { name: 'Cartucho HP 664 Preto', value: 65.00 },
        { name: 'Cartucho HP 664 Colorido', value: 75.00 },
        { name: 'Kit fusor (genérico)', value: 180.00 },
        { name: 'Rolete de captação', value: 45.00 },
        { name: 'Cilindro fotossensível', value: 85.00 },
      ],
      devices: [
        { name: 'LaserJet Pro M15w', manufacturer: 'HP', category: 'Impressora Laser', customFields: { technology: 'Laser', isColor: 'Não' } },
        { name: 'DCP-L2540DW', manufacturer: 'Brother', category: 'Multifuncional Laser', customFields: { technology: 'Laser', isColor: 'Não' } },
        { name: 'EcoTank L3250', manufacturer: 'Epson', category: 'Multifuncional Jato de Tinta', customFields: { technology: 'Jato de tinta', isColor: 'Sim' } },
      ],
    },
  },

  // ═══════════════════════════════════════════════════════════
  // OUTRO (genérico)
  // ═══════════════════════════════════════════════════════════
  other: {
    _customer: {
      name: 'Cliente Exemplo',
      phone: '(11) 99999-0000',
      email: 'exemplo@praticos.app',
      address: 'Endereço de Exemplo, 123',
    },

    _default: {
      services: [
        { name: 'Serviço básico', value: 100.00, description: 'Serviço padrão' },
        { name: 'Serviço intermediário', value: 200.00, description: 'Serviço de complexidade média' },
        { name: 'Serviço avançado', value: 350.00, description: 'Serviço de alta complexidade' },
        { name: 'Diagnóstico', value: 80.00, description: 'Avaliação técnica' },
        { name: 'Manutenção preventiva', value: 150.00, description: 'Manutenção programada' },
      ],
      products: [
        { name: 'Peça genérica A', value: 50.00 },
        { name: 'Peça genérica B', value: 80.00 },
        { name: 'Consumível padrão', value: 30.00 },
        { name: 'Kit de reparo', value: 120.00 },
      ],
      devices: [
        { name: 'Equipamento Exemplo', manufacturer: 'Genérico', category: 'Geral' },
      ],
    },
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// FUNÇÃO DE SEED
// ═══════════════════════════════════════════════════════════════════════════

async function seedBootstrapData() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  POPULANDO DADOS DE BOOTSTRAP NO FIRESTORE');
  console.log('════════════════════════════════════════════════════════════\n');

  try {
    let created = 0;
    let updated = 0;
    let errors = 0;

    for (const [segmentId, subspecialties] of Object.entries(BOOTSTRAP_DATA)) {
      console.log(`\n📦 Processando segmento: ${segmentId}`);

      // Verifica se o segmento existe
      const segmentRef = db.collection('segments').doc(segmentId);
      const segmentDoc = await segmentRef.get();

      if (!segmentDoc.exists) {
        console.log(`  ⚠️  Segmento '${segmentId}' não existe - pulando...`);
        errors++;
        continue;
      }

      // Pega o cliente compartilhado do segmento
      const sharedCustomer = subspecialties._customer;

      // Itera sobre as subspecialties
      for (const [subspecialtyId, data] of Object.entries(subspecialties)) {
        // Pula _customer (é apenas metadata)
        if (subspecialtyId === '_customer') continue;

        const bootstrapRef = segmentRef.collection('bootstrap').doc(subspecialtyId);
        const bootstrapDoc = await bootstrapRef.get();

        // Monta o documento de bootstrap
        const bootstrapData = {
          services: data.services || [],
          products: data.products || [],
          devices: data.devices || [],
          customer: sharedCustomer || data.customer || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (bootstrapDoc.exists) {
          console.log(`  ⚠️  ${segmentId}/${subspecialtyId} já existe - atualizando...`);
          await bootstrapRef.set(bootstrapData, { merge: true });
          updated++;
        } else {
          console.log(`  ✅ Criando ${segmentId}/${subspecialtyId}`);
          bootstrapData.createdAt = admin.firestore.FieldValue.serverTimestamp();
          await bootstrapRef.set(bootstrapData);
          created++;
        }
      }
    }

    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  ✅ SEED DE BOOTSTRAP CONCLUÍDO COM SUCESSO!');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  • Documentos criados: ${created}`);
    console.log(`  • Documentos atualizados: ${updated}`);
    console.log(`  • Erros (segmentos não encontrados): ${errors}`);
    console.log('════════════════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erro ao popular dados de bootstrap:', error);
    process.exit(1);
  }
}

// Executar seed
seedBootstrapData();
