// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - HIDRÁULICA
// ═══════════════════════════════════════════════════════════════════════════

const PLUMBING_TRANSLATIONS = {
  checklist_seguranca_hidraulica: {
    title: { pt: 'Segurança do Serviço Hidráulico', en: 'Plumbing Service Safety', es: 'Seguridad del Servicio Hidráulico' },
    description: {
      pt: 'Prepara o local para evitar danos e acidentes.',
      en: 'Prepares the location to avoid damage and accidents.',
      es: 'Prepara el local para evitar daños y accidentes.',
    },
    items: {
      registro_fechado: { label: { pt: 'Registro fechado/isolamento da linha', en: 'Valve closed/line isolation', es: 'Registro cerrado/aislamiento de la línea' } },
      epi: {
        label: { pt: 'EPI utilizado', en: 'PPE used', es: 'EPP utilizado' },
        options: {
          pt: ['Luvas', 'Óculos', 'Máscara', 'Botina', 'Não aplicável'],
          en: ['Gloves', 'Safety glasses', 'Mask', 'Safety boots', 'Not applicable'],
          es: ['Guantes', 'Gafas', 'Máscara', 'Botas', 'No aplicable'],
        },
      },
      protecao_area: { label: { pt: 'Área protegida (piso/móveis) e pano/balde preparados', en: 'Area protected (floor/furniture) and cloth/bucket prepared', es: 'Área protegida (piso/muebles) y paño/balde preparados' } },
      foto_local: { label: { pt: 'Foto do local antes', en: 'Photo of location before', es: 'Foto del local antes' } },
    },
  },

  teste_estanqueidade: {
    title: { pt: 'Teste de Estanqueidade', en: 'Leak Test', es: 'Prueba de Estanqueidad' },
    description: {
      pt: 'Confirma ausência de vazamentos após o serviço.',
      en: 'Confirms absence of leaks after service.',
      es: 'Confirma ausencia de fugas después del servicio.',
    },
    items: {
      metodo: {
        label: { pt: 'Método do teste', en: 'Test Method', es: 'Método de prueba' },
        options: {
          pt: ['Pressurização', 'Observação', 'Corante', 'Outro'],
          en: ['Pressurization', 'Observation', 'Dye', 'Other'],
          es: ['Presurización', 'Observación', 'Colorante', 'Otro'],
        },
      },
      tempo_min: { label: { pt: 'Tempo de observação (min)', en: 'Observation time (min)', es: 'Tiempo de observación (min)' } },
      resultado: {
        label: { pt: 'Resultado', en: 'Result', es: 'Resultado' },
        options: {
          pt: ['Sem vazamentos', 'Vazamento identificado', 'Não concluído'],
          en: ['No leaks', 'Leak identified', 'Not completed'],
          es: ['Sin fugas', 'Fuga identificada', 'No concluido'],
        },
      },
      foto_teste: { label: { pt: 'Foto/evidência do teste', en: 'Test photo/evidence', es: 'Foto/evidencia de la prueba' } },
      observacoes: { label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' } },
    },
  },

  entrega_hidraulica: {
    title: { pt: 'Entrega do Serviço Hidráulico', en: 'Plumbing Service Delivery', es: 'Entrega del Servicio Hidráulico' },
    description: {
      pt: 'Checklist final e orientações ao cliente.',
      en: 'Final checklist and customer guidance.',
      es: 'Lista de verificación final y orientaciones al cliente.',
    },
    items: {
      servico_executado: { label: { pt: 'Serviço executado', en: 'Service performed', es: 'Servicio ejecutado' } },
      teste_funcional: { label: { pt: 'Teste funcional realizado', en: 'Functional test performed', es: 'Prueba funcional realizada' } },
      orientacoes: { label: { pt: 'Orientações ao cliente', en: 'Customer guidance', es: 'Orientaciones al cliente' } },
      foto_final: { label: { pt: 'Foto final', en: 'Final Photo', es: 'Foto final' } },
    },
  },
};

module.exports = { PLUMBING_TRANSLATIONS };
