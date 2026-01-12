// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - GENÉRICO (Para todos os segmentos)
// ═══════════════════════════════════════════════════════════════════════════

const GENERIC_TRANSLATIONS = {
  checklist_entrada_generico: {
    title: { pt: 'Entrada do Item', en: 'Item Check-in', es: 'Entrada del Artículo' },
    description: {
      pt: 'Registra condição inicial e defeito relatado.',
      en: 'Records initial condition and reported issue.',
      es: 'Registra condición inicial y defecto reportado.',
    },
    items: {
      foto_item: { label: { pt: 'Foto do Item', en: 'Item Photo', es: 'Foto del Artículo' } },
      estado_geral: {
        label: { pt: 'Estado Geral', en: 'General Condition', es: 'Estado General' },
        options: { pt: ['Bom', 'Regular', 'Ruim'], en: ['Good', 'Fair', 'Poor'], es: ['Bueno', 'Regular', 'Malo'] },
      },
      acessorios: { label: { pt: 'Acessórios Recebidos', en: 'Accessories Received', es: 'Accesorios Recibidos' } },
      defeito_relatado: { label: { pt: 'Defeito Relatado', en: 'Reported Issue', es: 'Defecto Reportado' } },
      observacoes: { label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' } },
    },
  },

  diagnostico_generico: {
    title: { pt: 'Diagnóstico do Item', en: 'Item Diagnosis', es: 'Diagnóstico del Artículo' },
    description: {
      pt: 'Análise técnica para identificar o problema.',
      en: 'Technical analysis to identify the problem.',
      es: 'Análisis técnico para identificar el problema.',
    },
    items: {
      item_funciona: {
        label: { pt: 'Item Funciona', en: 'Item Works', es: 'Artículo Funciona' },
        options: { pt: ['Sim', 'Parcialmente', 'Não'], en: ['Yes', 'Partially', 'No'], es: ['Sí', 'Parcialmente', 'No'] },
      },
      problema_identificado: { label: { pt: 'Problema Identificado', en: 'Problem Identified', es: 'Problema Identificado' } },
      solucao_proposta: { label: { pt: 'Solução Proposta', en: 'Proposed Solution', es: 'Solución Propuesta' } },
      foto_diagnostico: { label: { pt: 'Foto do Diagnóstico', en: 'Diagnosis Photo', es: 'Foto del Diagnóstico' } },
    },
  },

  registro_servico_generico: {
    title: { pt: 'Registro do Serviço', en: 'Service Record', es: 'Registro del Servicio' },
    description: {
      pt: 'Resumo do que foi feito e evidências.',
      en: 'Summary of what was done and evidence.',
      es: 'Resumen de lo que se hizo y evidencias.',
    },
    items: {
      servico_executado: { label: { pt: 'Serviço Executado', en: 'Service Performed', es: 'Servicio Ejecutado' } },
      pecas_utilizadas: { label: { pt: 'Peças/Materiais Utilizados', en: 'Parts/Materials Used', es: 'Piezas/Materiales Utilizados' } },
      foto_servico: { label: { pt: 'Foto do Serviço', en: 'Service Photo', es: 'Foto del Servicio' } },
      tempo_execucao: { label: { pt: 'Tempo de Execução (min)', en: 'Execution Time (min)', es: 'Tiempo de Ejecución (min)' } },
      observacoes: { label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' } },
    },
  },

  entrega_cliente_generico: {
    title: { pt: 'Entrega ao Cliente', en: 'Customer Delivery', es: 'Entrega al Cliente' },
    description: {
      pt: 'Confirma entrega, funcionamento e garantia.',
      en: 'Confirms delivery, functionality and warranty.',
      es: 'Confirma entrega, funcionamiento y garantía.',
    },
    items: {
      item_funciona: { label: { pt: 'Item Funcionando', en: 'Item Working', es: 'Artículo Funcionando' } },
      servico_conferido: { label: { pt: 'Serviço Conferido com Cliente', en: 'Service Reviewed with Customer', es: 'Servicio Revisado con el Cliente' } },
      acessorios_devolvidos: { label: { pt: 'Acessórios Devolvidos', en: 'Accessories Returned', es: 'Accesorios Devueltos' } },
      garantia_informada: { label: { pt: 'Garantia Informada', en: 'Warranty Informed', es: 'Garantía Informada' } },
      cliente_satisfeito: { label: { pt: 'Cliente Satisfeito', en: 'Customer Satisfied', es: 'Cliente Satisfecho' } },
      foto_entrega: { label: { pt: 'Foto na Entrega', en: 'Delivery Photo', es: 'Foto en la Entrega' } },
    },
  },

  termo_autorizacao_generico: {
    title: { pt: 'Autorização e Privacidade', en: 'Authorization and Privacy', es: 'Autorización y Privacidad' },
    description: {
      pt: 'Consentimento para execução e registro do serviço.',
      en: 'Consent for service execution and documentation.',
      es: 'Consentimiento para ejecución y registro del servicio.',
    },
    items: {
      autorizacao_servico: { label: { pt: 'Autorizo a execução do serviço', en: 'I authorize the service execution', es: 'Autorizo la ejecución del servicio' } },
      ciencia_valor: { label: { pt: 'Ciente do valor aprovado', en: 'Aware of approved value', es: 'Enterado del valor aprobado' } },
      ciencia_prazo: { label: { pt: 'Ciente do prazo estimado', en: 'Aware of estimated deadline', es: 'Enterado del plazo estimado' } },
      autorizacao_fotos: { label: { pt: 'Autorizo registro fotográfico', en: 'I authorize photographic documentation', es: 'Autorizo registro fotográfico' } },
      observacoes: { label: { pt: 'Observações do Cliente', en: 'Customer Notes', es: 'Observaciones del Cliente' } },
    },
  },

  pesquisa_satisfacao: {
    title: { pt: 'Pesquisa de Satisfação', en: 'Satisfaction Survey', es: 'Encuesta de Satisfacción' },
    description: {
      pt: 'Avalia a experiência do cliente após o serviço.',
      en: 'Evaluates customer experience after service.',
      es: 'Evalúa la experiencia del cliente después del servicio.',
    },
    items: {
      nota_geral: { label: { pt: 'Nota Geral (1-10)', en: 'Overall Score (1-10)', es: 'Nota General (1-10)' } },
      qualidade_servico: {
        label: { pt: 'Qualidade do Serviço', en: 'Service Quality', es: 'Calidad del Servicio' },
        options: { pt: ['Excelente', 'Bom', 'Regular', 'Ruim'], en: ['Excellent', 'Good', 'Fair', 'Poor'], es: ['Excelente', 'Bueno', 'Regular', 'Malo'] },
      },
      atendimento: {
        label: { pt: 'Atendimento', en: 'Customer Service', es: 'Atención' },
        options: { pt: ['Excelente', 'Bom', 'Regular', 'Ruim'], en: ['Excellent', 'Good', 'Fair', 'Poor'], es: ['Excelente', 'Bueno', 'Regular', 'Malo'] },
      },
      prazo: {
        label: { pt: 'Cumprimento do Prazo', en: 'Deadline Compliance', es: 'Cumplimiento del Plazo' },
        options: { pt: ['Antes do prazo', 'No prazo', 'Com atraso'], en: ['Before deadline', 'On time', 'Delayed'], es: ['Antes del plazo', 'A tiempo', 'Con atraso'] },
      },
      recomendaria: {
        label: { pt: 'Recomendaria para amigos?', en: 'Would recommend to friends?', es: '¿Recomendaría a amigos?' },
        options: { pt: ['Com certeza', 'Provavelmente', 'Talvez', 'Não'], en: ['Definitely', 'Probably', 'Maybe', 'No'], es: ['Seguramente', 'Probablemente', 'Quizás', 'No'] },
      },
      sugestoes: { label: { pt: 'Sugestões ou Comentários', en: 'Suggestions or Comments', es: 'Sugerencias o Comentarios' } },
    },
  },
};

module.exports = { GENERIC_TRANSLATIONS };
