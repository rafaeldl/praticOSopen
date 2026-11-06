const { t } = require('./helpers');

// Software e TI: support, development and monthly fees. No specialties, so
// everything sits in `_default`. The "devices" are the customer's systems.
module.exports = {
  _customer: {
    name: t('Ana Costa (Exemplo)', 'Anna Brown (Example)', 'Ana Rodríguez (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Av. Exemplo, 321', '321 Example Ave', 'Av. Ejemplo, 321'),
  },

  _default: {
    services: [
      { name: t('Suporte técnico mensal', 'Monthly IT Support', 'Soporte técnico mensual'), value: 600.00, description: t('Atendimento remoto e chamados do mês', 'Remote help desk and tickets for the month', 'Atención remota y solicitudes del mes') },
      { name: t('Desenvolvimento de sistema (hora)', 'Software Development (hour)', 'Desarrollo de sistema (hora)'), value: 150.00, description: t('Nova tela, relatório ou integração', 'New screen, report or integration', 'Nueva pantalla, informe o integración') },
      { name: t('Manutenção de sistema mensal', 'Monthly System Maintenance', 'Mantenimiento de sistema mensual'), value: 400.00, description: t('Correções, atualizações e backup', 'Fixes, updates and backups', 'Correcciones, actualizaciones y copias de seguridad') },
      { name: t('Hospedagem mensal', 'Monthly Hosting', 'Hosting mensual'), value: 120.00, description: t('Servidor, domínio e e-mail no ar', 'Server, domain and email kept online', 'Servidor, dominio y correo en línea') },
      { name: t('Consultoria em TI (hora)', 'IT Consulting (hour)', 'Consultoría en TI (hora)'), value: 200.00, description: t('Análise, planejamento e orientação', 'Analysis, planning and advice', 'Análisis, planificación y orientación') },
      { name: t('Treinamento de usuários', 'User Training', 'Capacitación de usuarios'), value: 300.00, description: t('Turma de até 4 horas, remota ou no cliente', 'Session of up to 4 hours, remote or on site', 'Clase de hasta 4 horas, remota o en el cliente') },
    ],
    products: [
      { name: t('Licença Microsoft 365 (mês)', 'Microsoft 365 License (month)', 'Licencia Microsoft 365 (mes)'), value: 60.00 },
      { name: t('Licença de antivírus (ano)', 'Antivirus License (year)', 'Licencia de antivirus (año)'), value: 120.00 },
      { name: t('Certificado SSL (ano)', 'SSL Certificate (year)', 'Certificado SSL (año)'), value: 250.00 },
      { name: t('Registro de domínio (ano)', 'Domain Registration (year)', 'Registro de dominio (año)'), value: 40.00 },
    ],
    devices: [
      { name: t('Sistema de gestão (ERP)', 'Management System (ERP)', 'Sistema de gestión (ERP)'), manufacturer: 'Laravel', category: t('Sistema web', 'Web system', 'Sistema web') },
      { name: t('Site institucional', 'Company Website', 'Sitio institucional'), manufacturer: 'WordPress', category: t('Site', 'Website', 'Sitio') },
      { name: t('App de pedidos', 'Ordering App', 'App de pedidos'), manufacturer: 'Flutter', category: t('Aplicativo', 'Mobile app', 'Aplicación') },
    ],
  },
};
