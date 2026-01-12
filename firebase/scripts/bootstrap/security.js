const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Roberto Lima (Exemplo)', 'Robert Williams (Example)', 'Roberto Martínez (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Rua Exemplo, 999', '999 Example Street', 'Calle Ejemplo, 999'),
  },

  cctv: {
    services: [
      { name: t('Instalação de câmera', 'Camera Installation', 'Instalación de cámara'), value: 150.00, description: t('Instalação de câmera com passagem de cabo', 'Camera installation with cable routing', 'Instalación de cámara con pasada de cable') },
      { name: t('Instalação de DVR/NVR', 'DVR/NVR Installation', 'Instalación de DVR/NVR'), value: 200.00, description: t('Configuração de gravador digital', 'Digital recorder configuration', 'Configuración de grabador digital') },
      { name: t('Configuração de acesso remoto', 'Remote Access Configuration', 'Configuración de acceso remoto'), value: 100.00, description: t('Setup de visualização pelo celular', 'Mobile viewing setup', 'Configuración de visualización por celular') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 180.00, description: t('Limpeza e verificação do sistema', 'System cleaning and inspection', 'Limpieza y verificación del sistema') },
      { name: t('Troca de HD do DVR', 'DVR HDD Replacement', 'Cambio de HD del DVR'), value: 150.00, description: t('Substituição de disco de gravação', 'Recording disk replacement', 'Sustitución de disco de grabación') },
      { name: t('Instalação de cabo (metro)', 'Cable Installation (meter)', 'Instalación de cable (metro)'), value: 12.00, description: t('Passagem de cabo coaxial/rede', 'Coaxial/network cable routing', 'Pasada de cable coaxial/red') },
      { name: t('Configuração de detecção', 'Detection Configuration', 'Configuración de detección'), value: 80.00, description: t('Setup de detecção de movimento', 'Motion detection setup', 'Configuración de detección de movimiento') },
      { name: t('Reparo de câmera', 'Camera Repair', 'Reparación de cámara'), value: 120.00, description: t('Diagnóstico e reparo de câmera', 'Camera diagnosis and repair', 'Diagnóstico y reparación de cámara') },
    ],
    products: [
      { name: t('Câmera Bullet HD', 'HD Bullet Camera', 'Cámara Bullet HD'), value: 180.00 },
      { name: t('Câmera Dome HD', 'HD Dome Camera', 'Cámara Dome HD'), value: 200.00 },
      { name: t('Câmera IP 2MP', '2MP IP Camera', 'Cámara IP 2MP'), value: 280.00 },
      { name: t('DVR 8 canais', '8-Channel DVR', 'DVR 8 canales'), value: 450.00 },
      { name: t('NVR 8 canais', '8-Channel NVR', 'NVR 8 canales'), value: 550.00 },
      { name: t('HD 1TB Surveillance', '1TB Surveillance HDD', 'HD 1TB Vigilancia'), value: 350.00 },
      { name: t('HD 2TB Surveillance', '2TB Surveillance HDD', 'HD 2TB Vigilancia'), value: 480.00 },
      { name: t('Cabo coaxial (rolo 100m)', 'Coaxial Cable (100m roll)', 'Cable coaxial (rollo 100m)'), value: 180.00 },
      { name: t('Fonte 12V 5A', '12V 5A Power Supply', 'Fuente 12V 5A'), value: 45.00 },
      { name: t('Conector BNC (pacote 10)', 'BNC Connector (pack 10)', 'Conector BNC (paquete 10)'), value: 25.00 },
    ],
    devices: [
      { name: 'DVR 8CH MHDX 1108', manufacturer: 'Intelbras', category: 'DVR', customFields: { channels: '8', systemType: t('CFTV', 'CCTV', 'CCTV') } },
      { name: 'VHD 1120 B', manufacturer: 'Intelbras', category: t('Câmera', 'Camera', 'Cámara'), customFields: { systemType: t('CFTV', 'CCTV', 'CCTV') } },
    ],
  },

  alarms: {
    services: [
      { name: t('Instalação de central', 'Panel Installation', 'Instalación de central'), value: 250.00, description: t('Instalação de central de alarme', 'Alarm panel installation', 'Instalación de central de alarma') },
      { name: t('Instalação de sensor', 'Sensor Installation', 'Instalación de sensor'), value: 80.00, description: t('Instalação de sensor magnético/infra', 'Magnetic/PIR sensor installation', 'Instalación de sensor magnético/infra') },
      { name: t('Configuração de monitoramento', 'Monitoring Configuration', 'Configuración de monitoreo'), value: 150.00, description: t('Setup com central de monitoramento', 'Monitoring center setup', 'Configuración con central de monitoreo') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 120.00, description: t('Teste e verificação do sistema', 'System testing and inspection', 'Prueba y verificación del sistema') },
      { name: t('Troca de bateria', 'Battery Replacement', 'Cambio de batería'), value: 100.00, description: t('Substituição de bateria da central', 'Panel battery replacement', 'Sustitución de batería de la central') },
      { name: t('Instalação de sirene', 'Siren Installation', 'Instalación de sirena'), value: 80.00, description: t('Instalação de sirene interna/externa', 'Indoor/outdoor siren installation', 'Instalación de sirena interior/exterior') },
      { name: t('Configuração de app', 'App Configuration', 'Configuración de app'), value: 80.00, description: t('Setup de controle pelo celular', 'Mobile control setup', 'Configuración de control por celular') },
      { name: t('Expansão de zonas', 'Zone Expansion', 'Expansión de zonas'), value: 150.00, description: t('Adição de zonas na central', 'Adding zones to panel', 'Adición de zonas en la central') },
    ],
    products: [
      { name: t('Central de alarme 8 zonas', '8-Zone Alarm Panel', 'Central de alarma 8 zonas'), value: 350.00 },
      { name: t('Central de alarme monitorada', 'Monitored Alarm Panel', 'Central de alarma monitoreada'), value: 480.00 },
      { name: t('Sensor infravermelho', 'PIR Sensor', 'Sensor infrarrojo'), value: 65.00 },
      { name: t('Sensor magnético', 'Magnetic Sensor', 'Sensor magnético'), value: 35.00 },
      { name: t('Sensor de presença PET', 'Pet-Immune PIR Sensor', 'Sensor de presencia PET'), value: 95.00 },
      { name: t('Sirene 120dB', '120dB Siren', 'Sirena 120dB'), value: 85.00 },
      { name: t('Controle remoto', 'Remote Control', 'Control remoto'), value: 45.00 },
      { name: t('Bateria 12V 7Ah', '12V 7Ah Battery', 'Batería 12V 7Ah'), value: 90.00 },
      { name: t('Teclado para central', 'Keypad for Panel', 'Teclado para central'), value: 120.00 },
      { name: t('Cabo de alarme 4 vias (100m)', '4-Wire Alarm Cable (100m)', 'Cable de alarma 4 vías (100m)'), value: 85.00 },
    ],
    devices: [
      { name: 'AMT 2018 E', manufacturer: 'Intelbras', category: t('Central de Alarme', 'Alarm Panel', 'Central de Alarma'), customFields: { channels: '8', systemType: t('Alarme', 'Alarm', 'Alarma') } },
      { name: 'IVP 3000', manufacturer: 'Intelbras', category: 'Sensor', customFields: { systemType: t('Alarme', 'Alarm', 'Alarma') } },
    ],
  },

  access: {
    services: [
      { name: t('Instalação de controle de acesso', 'Access Control Installation', 'Instalación de control de acceso'), value: 300.00, description: t('Instalação completa de equipamento', 'Complete equipment installation', 'Instalación completa de equipo') },
      { name: t('Configuração de biometria', 'Biometric Configuration', 'Configuración de biometría'), value: 150.00, description: t('Cadastro de digitais', 'Fingerprint registration', 'Registro de huellas dactilares') },
      { name: t('Instalação de fechadura', 'Lock Installation', 'Instalación de cerradura'), value: 200.00, description: t('Instalação de fechadura eletrônica', 'Electronic lock installation', 'Instalación de cerradura electrónica') },
      { name: t('Configuração de software', 'Software Configuration', 'Configuración de software'), value: 180.00, description: t('Setup de software de gestão', 'Management software setup', 'Configuración de software de gestión') },
      { name: t('Instalação de catraca', 'Turnstile Installation', 'Instalación de torniquete'), value: 450.00, description: t('Instalação de catraca de acesso', 'Access turnstile installation', 'Instalación de torniquete de acceso') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 150.00, description: t('Verificação e ajustes do sistema', 'System inspection and adjustments', 'Verificación y ajustes del sistema') },
      { name: t('Cadastro de usuários', 'User Registration', 'Registro de usuarios'), value: 80.00, description: t('Cadastro em massa de usuários', 'Bulk user registration', 'Registro masivo de usuarios') },
      { name: t('Integração com CFTV', 'CCTV Integration', 'Integración con CCTV'), value: 200.00, description: t('Integração com sistema de câmeras', 'Camera system integration', 'Integración con sistema de cámaras') },
    ],
    products: [
      { name: t('Controlador de acesso biométrico', 'Biometric Access Controller', 'Controlador de acceso biométrico'), value: 650.00 },
      { name: t('Controlador de acesso facial', 'Facial Access Controller', 'Controlador de acceso facial'), value: 1200.00 },
      { name: t('Fechadura eletroímã', 'Electromagnetic Lock', 'Cerradura electromagnética'), value: 280.00 },
      { name: t('Fechadura elétrica', 'Electric Strike', 'Cerradura eléctrica'), value: 150.00 },
      { name: t('Leitor de cartão RFID', 'RFID Card Reader', 'Lector de tarjeta RFID'), value: 180.00 },
      { name: t('Cartão RFID (pacote 100)', 'RFID Card (pack 100)', 'Tarjeta RFID (paquete 100)'), value: 120.00 },
      { name: t('Botão de saída', 'Exit Button', 'Botón de salida'), value: 35.00 },
      { name: t('Fonte 12V 3A', '12V 3A Power Supply', 'Fuente 12V 3A'), value: 55.00 },
      { name: t('Botoeira antipânico', 'Panic Button', 'Botón de pánico'), value: 85.00 },
      { name: t('Nobreak para controle de acesso', 'Access Control UPS', 'UPS para control de acceso'), value: 350.00 },
    ],
    devices: [
      { name: 'SS 3430 BIO', manufacturer: 'Intelbras', category: t('Controle de Acesso', 'Access Control', 'Control de Acceso'), customFields: { systemType: t('Controle de acesso', 'Access control', 'Control de acceso') } },
      { name: 'XPE 1001 FACE', manufacturer: 'Intelbras', category: t('Controle de Acesso', 'Access Control', 'Control de Acceso'), customFields: { systemType: t('Controle de acesso', 'Access control', 'Control de acceso') } },
    ],
  },

  fence: {
    services: [
      { name: t('Instalação de cerca (metro)', 'Fence Installation (meter)', 'Instalación de cerca (metro)'), value: 45.00, description: t('Instalação de fios e hastes', 'Wire and rod installation', 'Instalación de alambres y varillas') },
      { name: t('Instalação de central', 'Energizer Installation', 'Instalación de central'), value: 250.00, description: t('Instalação de central de choque', 'Energizer installation', 'Instalación de energizador') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 150.00, description: t('Verificação de voltagem e isoladores', 'Voltage and insulator inspection', 'Verificación de voltaje y aisladores') },
      { name: t('Reparo de cerca', 'Fence Repair', 'Reparación de cerca'), value: 120.00, description: t('Conserto de fios rompidos', 'Broken wire repair', 'Reparación de alambres rotos') },
      { name: t('Instalação de haste', 'Rod Installation', 'Instalación de varilla'), value: 25.00, description: t('Instalação de haste isoladora', 'Insulating rod installation', 'Instalación de varilla aisladora') },
      { name: t('Configuração de alarme', 'Alarm Configuration', 'Configuración de alarma'), value: 100.00, description: t('Integração com sistema de alarme', 'Alarm system integration', 'Integración con sistema de alarma') },
      { name: t('Troca de central', 'Energizer Replacement', 'Cambio de central'), value: 200.00, description: t('Substituição de central de choque', 'Energizer replacement', 'Sustitución de energizador') },
      { name: t('Regulagem de voltagem', 'Voltage Adjustment', 'Regulación de voltaje'), value: 80.00, description: t('Ajuste de tensão da cerca', 'Fence voltage adjustment', 'Ajuste de tensión de la cerca') },
    ],
    products: [
      { name: t('Central de cerca elétrica', 'Electric Fence Energizer', 'Central de cerca eléctrica'), value: 380.00 },
      { name: t('Central com alarme integrado', 'Energizer with Integrated Alarm', 'Central con alarma integrada'), value: 520.00 },
      { name: t('Haste M 75cm (4 isoladores)', '75cm Rod (4 insulators)', 'Varilla M 75cm (4 aisladores)'), value: 35.00 },
      { name: t('Haste M 100cm (6 isoladores)', '100cm Rod (6 insulators)', 'Varilla M 100cm (6 aisladores)'), value: 45.00 },
      { name: t('Fio de aço inox (100m)', 'Stainless Steel Wire (100m)', 'Alambre de acero inox (100m)'), value: 65.00 },
      { name: t('Fio de aço galvanizado (250m)', 'Galvanized Steel Wire (250m)', 'Alambre de acero galvanizado (250m)'), value: 85.00 },
      { name: t('Isolador castanha (pacote 100)', 'Chestnut Insulator (pack 100)', 'Aislador castaña (paquete 100)'), value: 55.00 },
      { name: t('Bateria 12V 7Ah', '12V 7Ah Battery', 'Batería 12V 7Ah'), value: 90.00 },
      { name: t('Sirene para cerca', 'Fence Siren', 'Sirena para cerca'), value: 75.00 },
      { name: t('Placa de advertência', 'Warning Sign', 'Placa de advertencia'), value: 15.00 },
    ],
    devices: [
      { name: 'ELC 5002', manufacturer: 'JFL', category: t('Cerca Elétrica', 'Electric Fence', 'Cerca Eléctrica'), customFields: { systemType: t('Cerca elétrica', 'Electric fence', 'Cerca eléctrica') } },
      { name: 'Shock Control', manufacturer: 'Genno', category: t('Cerca Elétrica', 'Electric Fence', 'Cerca Eléctrica'), customFields: { systemType: t('Cerca elétrica', 'Electric fence', 'Cerca eléctrica') } },
    ],
  },
};
