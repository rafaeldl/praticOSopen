// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - ELÉTRICA
// ═══════════════════════════════════════════════════════════════════════════

const ELECTRICAL_TRANSLATIONS = {
  checklist_seguranca_eletrica: {
    title: { pt: 'Segurança do Serviço Elétrico (NR10)', en: 'Electrical Service Safety (NR10)', es: 'Seguridad del Servicio Eléctrico (NR10)' },
    description: {
      pt: 'Checklist antes de iniciar para evitar acidentes.',
      en: 'Checklist before starting to avoid accidents.',
      es: 'Lista de verificación antes de comenzar para evitar accidentes.',
    },
    items: {
      desenergizado: { label: { pt: 'Circuito desenergizado e bloqueado/identificado', en: 'Circuit de-energized and locked/identified', es: 'Circuito desenergizado y bloqueado/identificado' } },
      teste_ausencia_tensao: { label: { pt: 'Teste de ausência de tensão realizado', en: 'Absence of voltage test performed', es: 'Prueba de ausencia de tensión realizada' } },
      epi: {
        label: { pt: 'EPI utilizado', en: 'PPE used', es: 'EPP utilizado' },
        options: {
          pt: ['Luvas isolantes', 'Óculos', 'Botina', 'Capacete', 'Máscara', 'Não aplicável'],
          en: ['Insulating gloves', 'Safety glasses', 'Safety boots', 'Hard hat', 'Mask', 'Not applicable'],
          es: ['Guantes aislantes', 'Gafas', 'Botas', 'Casco', 'Máscara', 'No aplicable'],
        },
      },
      area_sinalizada: { label: { pt: 'Área sinalizada/protegida', en: 'Area marked/protected', es: 'Área señalizada/protegida' } },
      foto_quadro: { label: { pt: 'Foto do quadro/instalação antes', en: 'Photo of panel/installation before', es: 'Foto del tablero/instalación antes' } },
      observacoes: { label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' } },
    },
  },

  laudo_servico_eletrico: {
    title: { pt: 'Registro do Serviço Elétrico', en: 'Electrical Service Record', es: 'Registro del Servicio Eléctrico' },
    description: {
      pt: 'Resumo do serviço e medições realizadas.',
      en: 'Summary of service and measurements performed.',
      es: 'Resumen del servicio y mediciones realizadas.',
    },
    items: {
      servico_executado: { label: { pt: 'Serviço executado', en: 'Service performed', es: 'Servicio ejecutado' } },
      tensao_medida: { label: { pt: 'Tensão medida (V)', en: 'Measured voltage (V)', es: 'Tensión medida (V)' } },
      corrente_medida: { label: { pt: 'Corrente medida (A)', en: 'Measured current (A)', es: 'Corriente medida (A)' } },
      dr_testado: {
        label: { pt: 'DR testado (quando aplicável)', en: 'GFCI tested (when applicable)', es: 'DR probado (cuando aplique)' },
        options: {
          pt: ['OK', 'Falha', 'Não aplicável'],
          en: ['OK', 'Failure', 'Not applicable'],
          es: ['OK', 'Falla', 'No aplicable'],
        },
      },
      aterramento: {
        label: { pt: 'Aterramento', en: 'Grounding', es: 'Conexión a Tierra' },
        options: {
          pt: ['OK', 'Ausente', 'Não aplicável'],
          en: ['OK', 'Absent', 'Not applicable'],
          es: ['OK', 'Ausente', 'No aplicable'],
        },
      },
      foto_depois: { label: { pt: 'Foto do quadro/instalação após', en: 'Photo of panel/installation after', es: 'Foto del tablero/instalación después' } },
    },
  },

  checklist_qualidade_eletrica: {
    title: { pt: 'Qualidade na Entrega (Elétrica)', en: 'Delivery Quality (Electrical)', es: 'Calidad en la Entrega (Eléctrica)' },
    description: {
      pt: 'Verificações finais de segurança e organização.',
      en: 'Final safety and organization checks.',
      es: 'Verificaciones finales de seguridad y organización.',
    },
    items: {
      aperto_conexoes: {
        label: { pt: 'Aperto/conferência de conexões (se aplicável)', en: 'Tightening/checking connections (if applicable)', es: 'Apriete/revisión de conexiones (si aplica)' },
        options: {
          pt: ['OK', 'Não aplicável', 'Não realizado'],
          en: ['OK', 'Not applicable', 'Not performed'],
          es: ['OK', 'No aplicable', 'No realizado'],
        },
      },
      identificacao_circuitos: {
        label: { pt: 'Circuitos identificados/etiquetados', en: 'Circuits identified/labeled', es: 'Circuitos identificados/etiquetados' },
        options: {
          pt: ['OK', 'Parcial', 'Não aplicável'],
          en: ['OK', 'Partial', 'Not applicable'],
          es: ['OK', 'Parcial', 'No aplicable'],
        },
      },
      teste_funcional: { label: { pt: 'Teste funcional (pontos atendidos)', en: 'Functional test (points served)', es: 'Prueba funcional (puntos atendidos)' } },
      limpeza: { label: { pt: 'Local limpo e organizado', en: 'Location clean and organized', es: 'Local limpio y organizado' } },
      observacoes: { label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' } },
    },
  },
};

module.exports = { ELECTRICAL_TRANSLATIONS };
