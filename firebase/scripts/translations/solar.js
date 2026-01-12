// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - ENERGIA SOLAR
// ═══════════════════════════════════════════════════════════════════════════

const SOLAR_TRANSLATIONS = {
  checklist_seguranca_solar: {
    title: { pt: 'Segurança do Técnico (NR10/NR35)', en: 'Technician Safety (NR10/NR35)', es: 'Seguridad del Técnico (NR10/NR35)' },
    description: {
      pt: 'Checklist de segurança em altura e elétrica.',
      en: 'Height and electrical safety checklist.',
      es: 'Lista de verificación de seguridad en altura y eléctrica.',
    },
    items: {
      epi: {
        label: { pt: 'EPI utilizado', en: 'PPE used', es: 'EPP utilizado' },
        options: {
          pt: ['Cinto/Trava-quedas', 'Capacete', 'Luvas', 'Óculos', 'Botina', 'Não aplicável'],
          en: ['Harness/Fall arrester', 'Hard hat', 'Gloves', 'Safety glasses', 'Safety boots', 'Not applicable'],
          es: ['Arnés/Anticaídas', 'Casco', 'Guantes', 'Gafas', 'Botas', 'No aplicable'],
        },
      },
      linha_vida: {
        label: { pt: 'Linha de vida/ancoragem verificada (quando aplicável)', en: 'Lifeline/anchor verified (when applicable)', es: 'Línea de vida/anclaje verificado (cuando aplique)' },
        options: {
          pt: ['OK', 'Não aplicável', 'Não conforme'],
          en: ['OK', 'Not applicable', 'Non-compliant'],
          es: ['OK', 'No aplicable', 'No conforme'],
        },
      },
      desligamento: {
        label: { pt: 'Desligamento seguro (CC/CA) realizado quando aplicável', en: 'Safe shutdown (DC/AC) performed when applicable', es: 'Desconexión segura (CC/CA) realizada cuando aplique' },
        options: {
          pt: ['OK', 'Não aplicável', 'Não realizado'],
          en: ['OK', 'Not applicable', 'Not performed'],
          es: ['OK', 'No aplicable', 'No realizado'],
        },
      },
      foto_area: { label: { pt: 'Foto da área de trabalho', en: 'Work area photo', es: 'Foto del área de trabajo' } },
    },
  },

  comissionamento_solar: {
    title: { pt: 'Comissionamento do Sistema Solar', en: 'Solar System Commissioning', es: 'Comisionamiento del Sistema Solar' },
    description: {
      pt: 'Medições finais e validação do monitoramento.',
      en: 'Final measurements and monitoring validation.',
      es: 'Mediciones finales y validación del monitoreo.',
    },
    items: {
      kwp: { label: { pt: 'Potência do sistema (kWp)', en: 'System power (kWp)', es: 'Potencia del sistema (kWp)' } },
      tensao_cc: { label: { pt: 'Tensão CC (V) (string principal)', en: 'DC Voltage (V) (main string)', es: 'Tensión CC (V) (string principal)' } },
      corrente_cc: { label: { pt: 'Corrente CC (A) (string principal)', en: 'DC Current (A) (main string)', es: 'Corriente CC (A) (string principal)' } },
      monitoramento: {
        label: { pt: 'Monitoramento/app configurado', en: 'Monitoring/app configured', es: 'Monitoreo/app configurado' },
        options: {
          pt: ['OK', 'Não solicitado', 'Pendência'],
          en: ['OK', 'Not requested', 'Pending'],
          es: ['OK', 'No solicitado', 'Pendiente'],
        },
      },
      foto_inversor: { label: { pt: 'Foto do inversor/quadros', en: 'Inverter/panels photo', es: 'Foto del inversor/tableros' } },
    },
  },

  entrega_solar: {
    title: { pt: 'Entrega e Orientações (Solar)', en: 'Delivery and Guidance (Solar)', es: 'Entrega y Orientaciones (Solar)' },
    description: {
      pt: 'Confirma orientações e acesso do cliente.',
      en: 'Confirms guidance and customer access.',
      es: 'Confirma orientaciones y acceso del cliente.',
    },
    items: {
      orientacoes: { label: { pt: 'Orientações repassadas (monitoramento, desligamento, manutenção)', en: 'Guidance provided (monitoring, shutdown, maintenance)', es: 'Orientaciones transmitidas (monitoreo, desconexión, mantenimiento)' } },
      acesso_cliente: {
        label: { pt: 'Acesso do cliente ao portal/app', en: 'Customer access to portal/app', es: 'Acceso del cliente al portal/app' },
        options: {
          pt: ['Ativo', 'Pendente', 'Não solicitado'],
          en: ['Active', 'Pending', 'Not requested'],
          es: ['Activo', 'Pendiente', 'No solicitado'],
        },
      },
      garantia: {
        label: { pt: 'Garantia/termos entregues', en: 'Warranty/terms delivered', es: 'Garantía/términos entregados' },
        options: {
          pt: ['Entregue', 'Pendente', 'N/A'],
          en: ['Delivered', 'Pending', 'N/A'],
          es: ['Entregado', 'Pendiente', 'N/A'],
        },
      },
    },
  },
};

module.exports = { SOLAR_TRANSLATIONS };
