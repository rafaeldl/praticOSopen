const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Ana Costa (Exemplo)', 'Anna Brown (Example)', 'Ana Rodríguez (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Av. Exemplo, 321', '321 Example Ave', 'Av. Ejemplo, 321'),
  },

  desktop: {
    services: [
      { name: t('Formatação e instalação', 'Format and Installation', 'Formateo e instalación'), value: 150.00, description: t('Formatação com instalação de SO', 'Format with OS installation', 'Formateo con instalación de SO') },
      { name: t('Limpeza interna', 'Internal Cleaning', 'Limpieza interna'), value: 80.00, description: t('Limpeza de poeira e troca de pasta', 'Dust cleaning and thermal paste replacement', 'Limpieza de polvo y cambio de pasta') },
      { name: t('Remoção de vírus', 'Virus Removal', 'Eliminación de virus'), value: 100.00, description: t('Scan e remoção de malware', 'Malware scan and removal', 'Escaneo y eliminación de malware') },
      { name: t('Upgrade de memória', 'Memory Upgrade', 'Upgrade de memoria'), value: 80.00, description: t('Instalação de memória RAM', 'RAM memory installation', 'Instalación de memoria RAM') },
      { name: t('Instalação de SSD', 'SSD Installation', 'Instalación de SSD'), value: 100.00, description: t('Migração de HD para SSD', 'HDD to SSD migration', 'Migración de HDD a SSD') },
      { name: t('Montagem de PC', 'PC Assembly', 'Ensamblaje de PC'), value: 250.00, description: t('Montagem de computador completo', 'Complete computer assembly', 'Ensamblaje completo de computadora') },
      { name: t('Troca de fonte', 'Power Supply Replacement', 'Cambio de fuente'), value: 120.00, description: t('Substituição de fonte de alimentação', 'Power supply replacement', 'Sustitución de fuente de alimentación') },
      { name: t('Upgrade de placa de vídeo', 'Graphics Card Upgrade', 'Upgrade de tarjeta gráfica'), value: 100.00, description: t('Instalação de GPU', 'GPU installation', 'Instalación de GPU') },
    ],
    products: [
      { name: t('Memória RAM DDR4 8GB', 'DDR4 8GB RAM', 'Memoria RAM DDR4 8GB'), value: 180.00 },
      { name: t('Memória RAM DDR4 16GB', 'DDR4 16GB RAM', 'Memoria RAM DDR4 16GB'), value: 320.00 },
      { name: 'SSD 240GB', value: 200.00 },
      { name: 'SSD 480GB', value: 320.00 },
      { name: t('Fonte 500W 80 Plus', '500W 80 Plus PSU', 'Fuente 500W 80 Plus'), value: 280.00 },
      { name: t('Pasta térmica (5g)', 'Thermal Paste (5g)', 'Pasta térmica (5g)'), value: 25.00 },
      { name: t('Cabo SATA', 'SATA Cable', 'Cable SATA'), value: 15.00 },
      { name: t('Cooler para processador', 'CPU Cooler', 'Cooler para procesador'), value: 120.00 },
    ],
    devices: [
      { name: 'Desktop OptiPlex 3080', manufacturer: 'Dell', category: 'Desktop', customFields: { processor: 'Intel i5-10500', ram: '8GB', storage: 'SSD 256GB' } },
      { name: t('PC Gamer Custom', 'Custom Gaming PC', 'PC Gamer Personalizado'), manufacturer: t('Montado', 'Custom Built', 'Ensamblado'), category: 'Desktop', customFields: { processor: 'AMD Ryzen 5 5600', ram: '16GB', storage: 'SSD 512GB' } },
    ],
  },

  notebook: {
    services: [
      { name: t('Formatação e instalação', 'Format and Installation', 'Formateo e instalación'), value: 150.00, description: t('Formatação com instalação de SO', 'Format with OS installation', 'Formateo con instalación de SO') },
      { name: t('Troca de tela', 'Screen Replacement', 'Cambio de pantalla'), value: 450.00, description: t('Substituição de display LCD/LED', 'LCD/LED display replacement', 'Sustitución de pantalla LCD/LED') },
      { name: t('Troca de teclado', 'Keyboard Replacement', 'Cambio de teclado'), value: 200.00, description: t('Substituição de teclado', 'Keyboard replacement', 'Sustitución de teclado') },
      { name: t('Troca de bateria', 'Battery Replacement', 'Cambio de batería'), value: 250.00, description: t('Substituição de bateria', 'Battery replacement', 'Sustitución de batería') },
      { name: t('Reparo de dobradiça', 'Hinge Repair', 'Reparación de bisagra'), value: 180.00, description: t('Reparo ou troca de dobradiças', 'Hinge repair or replacement', 'Reparación o cambio de bisagras') },
      { name: t('Troca de conector DC', 'DC Jack Replacement', 'Cambio de conector DC'), value: 150.00, description: t('Reparo do conector de energia', 'Power connector repair', 'Reparación del conector de energía') },
      { name: t('Upgrade de memória', 'Memory Upgrade', 'Upgrade de memoria'), value: 80.00, description: t('Instalação de RAM', 'RAM installation', 'Instalación de RAM') },
      { name: t('Troca de cooler', 'Cooler Replacement', 'Cambio de cooler'), value: 120.00, description: t('Substituição do sistema de refrigeração', 'Cooling system replacement', 'Sustitución del sistema de refrigeración') },
    ],
    products: [
      { name: t('Tela 15.6" HD', '15.6" HD Screen', 'Pantalla 15.6" HD'), value: 380.00 },
      { name: t('Tela 14" Full HD', '14" Full HD Screen', 'Pantalla 14" Full HD'), value: 450.00 },
      { name: t('Bateria universal 6 células', 'Universal 6-cell Battery', 'Batería universal 6 celdas'), value: 200.00 },
      { name: t('Teclado notebook (compatível)', 'Notebook Keyboard (compatible)', 'Teclado notebook (compatible)'), value: 150.00 },
      { name: 'SSD M.2 NVMe 256GB', value: 250.00 },
      { name: t('Memória DDR4 SODIMM 8GB', 'DDR4 SODIMM 8GB RAM', 'Memoria DDR4 SODIMM 8GB'), value: 190.00 },
      { name: t('Cooler para notebook', 'Notebook Cooler', 'Cooler para notebook'), value: 85.00 },
      { name: t('Pasta térmica (5g)', 'Thermal Paste (5g)', 'Pasta térmica (5g)'), value: 25.00 },
    ],
    devices: [
      { name: 'IdeaPad 3i', manufacturer: 'Lenovo', category: 'Notebook', customFields: { processor: 'Intel i5-1135G7', ram: '8GB', storage: 'SSD 256GB' } },
      { name: 'MacBook Air M1', manufacturer: 'Apple', category: 'Notebook', customFields: { processor: 'Apple M1', ram: '8GB', storage: 'SSD 256GB' } },
      { name: 'Inspiron 15', manufacturer: 'Dell', category: 'Notebook', customFields: { processor: 'Intel i7-1165G7', ram: '16GB', storage: 'SSD 512GB' } },
    ],
  },

  networks: {
    services: [
      { name: t('Instalação de rede cabeada', 'Wired Network Installation', 'Instalación de red cableada'), value: 350.00, description: t('Instalação de pontos de rede', 'Network point installation', 'Instalación de puntos de red') },
      { name: t('Configuração de roteador', 'Router Configuration', 'Configuración de router'), value: 100.00, description: t('Setup de roteador Wi-Fi', 'Wi-Fi router setup', 'Configuración de router Wi-Fi') },
      { name: t('Instalação de rack', 'Rack Installation', 'Instalación de rack'), value: 250.00, description: t('Montagem de rack de rede', 'Network rack assembly', 'Montaje de rack de red') },
      { name: t('Crimpagem de cabos (ponto)', 'Cable Crimping (point)', 'Crimpado de cables (punto)'), value: 25.00, description: t('Conectorização de cabo UTP', 'UTP cable termination', 'Terminación de cable UTP') },
      { name: t('Configuração de switch', 'Switch Configuration', 'Configuración de switch'), value: 150.00, description: t('Setup de switch gerenciável', 'Managed switch setup', 'Configuración de switch administrable') },
      { name: t('Passagem de cabos (metro)', 'Cable Running (meter)', 'Pasada de cables (metro)'), value: 15.00, description: t('Instalação de infraestrutura', 'Infrastructure installation', 'Instalación de infraestructura') },
      { name: t('Configuração de Access Point', 'Access Point Configuration', 'Configuración de Access Point'), value: 120.00, description: t('Setup de AP Wi-Fi', 'Wi-Fi AP setup', 'Configuración de AP Wi-Fi') },
      { name: t('Diagnóstico de rede', 'Network Diagnosis', 'Diagnóstico de red'), value: 100.00, description: t('Análise de problemas de conectividade', 'Connectivity problem analysis', 'Análisis de problemas de conectividad') },
    ],
    products: [
      { name: t('Cabo UTP Cat5e (metro)', 'Cat5e UTP Cable (meter)', 'Cable UTP Cat5e (metro)'), value: 3.50 },
      { name: t('Cabo UTP Cat6 (metro)', 'Cat6 UTP Cable (meter)', 'Cable UTP Cat6 (metro)'), value: 5.00 },
      { name: t('Conector RJ45 (pacote 100)', 'RJ45 Connector (pack 100)', 'Conector RJ45 (paquete 100)'), value: 45.00 },
      { name: t('Switch 8 portas', '8-Port Switch', 'Switch 8 puertos'), value: 150.00 },
      { name: t('Switch 16 portas', '16-Port Switch', 'Switch 16 puertos'), value: 280.00 },
      { name: t('Roteador Wi-Fi 6', 'Wi-Fi 6 Router', 'Router Wi-Fi 6'), value: 350.00 },
      { name: 'Access Point', value: 280.00 },
      { name: t('Patch panel 24 portas', '24-Port Patch Panel', 'Patch panel 24 puertos'), value: 180.00 },
    ],
    devices: [
      { name: 'Switch SG1008D', manufacturer: 'TP-Link', category: 'Switch' },
      { name: 'Roteador Archer AX23', manufacturer: 'TP-Link', category: t('Roteador', 'Router', 'Router') },
      { name: 'Access Point EAP225', manufacturer: 'TP-Link', category: 'Access Point' },
    ],
  },

  servers: {
    services: [
      { name: t('Instalação de servidor', 'Server Installation', 'Instalación de servidor'), value: 500.00, description: t('Setup completo de servidor', 'Complete server setup', 'Configuración completa de servidor') },
      { name: t('Configuração de RAID', 'RAID Configuration', 'Configuración de RAID'), value: 250.00, description: t('Configuração de array de discos', 'Disk array configuration', 'Configuración de arreglo de discos') },
      { name: t('Instalação de Windows Server', 'Windows Server Installation', 'Instalación de Windows Server'), value: 300.00, description: t('Instalação e configuração de SO', 'OS installation and configuration', 'Instalación y configuración de SO') },
      { name: t('Instalação de Linux Server', 'Linux Server Installation', 'Instalación de Linux Server'), value: 250.00, description: t('Instalação e configuração de SO', 'OS installation and configuration', 'Instalación y configuración de SO') },
      { name: t('Configuração de backup', 'Backup Configuration', 'Configuración de backup'), value: 200.00, description: t('Setup de rotina de backup', 'Backup routine setup', 'Configuración de rutina de backup') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 350.00, description: t('Limpeza e verificação de hardware', 'Hardware cleaning and inspection', 'Limpieza y verificación de hardware') },
      { name: t('Expansão de storage', 'Storage Expansion', 'Expansión de almacenamiento'), value: 200.00, description: t('Instalação de discos adicionais', 'Additional disk installation', 'Instalación de discos adicionales') },
      { name: t('Virtualização (por VM)', 'Virtualization (per VM)', 'Virtualización (por VM)'), value: 150.00, description: t('Configuração de máquina virtual', 'Virtual machine configuration', 'Configuración de máquina virtual') },
    ],
    products: [
      { name: t('HD Enterprise 1TB', 'Enterprise HDD 1TB', 'HD Enterprise 1TB'), value: 450.00 },
      { name: t('HD Enterprise 4TB', 'Enterprise HDD 4TB', 'HD Enterprise 4TB'), value: 850.00 },
      { name: t('SSD Enterprise 480GB', 'Enterprise SSD 480GB', 'SSD Enterprise 480GB'), value: 550.00 },
      { name: t('Memória ECC 16GB', 'ECC Memory 16GB', 'Memoria ECC 16GB'), value: 450.00 },
      { name: t('Controladora RAID', 'RAID Controller', 'Controladora RAID'), value: 800.00 },
      { name: t('Fonte redundante', 'Redundant PSU', 'Fuente redundante'), value: 650.00 },
      { name: 'Nobreak 1500VA', value: 950.00 },
      { name: t('Cabo de rede Cat6 (patch cord)', 'Cat6 Patch Cord', 'Cable de red Cat6 (patch cord)'), value: 25.00 },
    ],
    devices: [
      { name: 'PowerEdge T140', manufacturer: 'Dell', category: t('Servidor Torre', 'Tower Server', 'Servidor Torre'), customFields: { processor: 'Intel Xeon E-2224', ram: '16GB ECC', storage: 'HD 1TB' } },
      { name: 'ProLiant ML30', manufacturer: 'HPE', category: t('Servidor Torre', 'Tower Server', 'Servidor Torre'), customFields: { processor: 'Intel Xeon E-2224', ram: '8GB ECC', storage: 'HD 1TB' } },
      { name: t('Storage NAS 4 baias', '4-Bay NAS Storage', 'Storage NAS 4 bahías'), manufacturer: 'Synology', category: 'Storage', customFields: { storage: '4x 4TB' } },
    ],
  },
};
