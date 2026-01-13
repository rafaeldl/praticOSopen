// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - IMPRESSORAS
// ═══════════════════════════════════════════════════════════════════════════

const PRINTERS_TRANSLATIONS = {
  checklist_entrada_printers: {
    title: { pt: 'Entrada da Impressora', en: 'Printer Check-in', es: 'Entrada de la Impresora' },
    description: {
      pt: 'Registra estado, contador e defeito relatado.',
      en: 'Records condition, counter and reported issue.',
      es: 'Registra estado, contador y defecto reportado.',
    },
    items: {
      fotos: { label: { pt: 'Fotos do equipamento', en: 'Equipment Photos', es: 'Fotos del equipo' } },
      tipo: {
        label: { pt: 'Tipo', en: 'Type', es: 'Tipo' },
        options: {
          pt: ['Laser', 'Jato de tinta', 'Térmica', 'Matricial', 'Outra'],
          en: ['Laser', 'Inkjet', 'Thermal', 'Dot matrix', 'Other'],
          es: ['Láser', 'Inyección de tinta', 'Térmica', 'Matricial', 'Otra'],
        },
      },
      contador_paginas: { label: { pt: 'Contador de páginas', en: 'Page counter', es: 'Contador de páginas' } },
      defeito: { label: { pt: 'Defeito relatado', en: 'Reported issue', es: 'Defecto reportado' } },
      acessorios: {
        label: { pt: 'Acessórios deixados', en: 'Accessories left', es: 'Accesorios dejados' },
        options: {
          pt: ['Fonte', 'Cabo USB', 'Cabo de força', 'Bandeja', 'Nenhum'],
          en: ['Power adapter', 'USB cable', 'Power cable', 'Tray', 'None'],
          es: ['Fuente', 'Cable USB', 'Cable de poder', 'Bandeja', 'Ninguno'],
        },
      },
    },
  },

  manutencao_preventiva_printers: {
    title: { pt: 'Manutenção Preventiva', en: 'Preventive Maintenance', es: 'Mantenimiento Preventivo' },
    description: {
      pt: 'Limpeza e ajustes para reduzir retorno.',
      en: 'Cleaning and adjustments to reduce returns.',
      es: 'Limpieza y ajustes para reducir retornos.',
    },
    items: {
      limpeza: {
        label: { pt: 'Limpeza interna/externa', en: 'Internal/external cleaning', es: 'Limpieza interna/externa' },
        options: {
          pt: ['Realizada', 'Parcial', 'Não realizada'],
          en: ['Completed', 'Partial', 'Not performed'],
          es: ['Realizada', 'Parcial', 'No realizada'],
        },
      },
      roletes: {
        label: { pt: 'Roletes/Separadores', en: 'Rollers/Separators', es: 'Rodillos/Separadores' },
        options: {
          pt: ['OK', 'Desgastado', 'Substituído', 'Não aplicável'],
          en: ['OK', 'Worn', 'Replaced', 'Not applicable'],
          es: ['OK', 'Desgastado', 'Reemplazado', 'No aplicable'],
        },
      },
      firmware: {
        label: { pt: 'Firmware/driver atualizado (quando aplicável)', en: 'Firmware/driver updated (when applicable)', es: 'Firmware/driver actualizado (cuando aplique)' },
        options: {
          pt: ['Atualizado', 'Já estava', 'Não aplicável', 'Não realizado'],
          en: ['Updated', 'Already updated', 'Not applicable', 'Not performed'],
          es: ['Actualizado', 'Ya estaba', 'No aplicable', 'No realizado'],
        },
      },
      calibracao: {
        label: { pt: 'Calibração/Alinhamento', en: 'Calibration/Alignment', es: 'Calibración/Alineamiento' },
        options: {
          pt: ['OK', 'Não aplicável', 'Não realizado'],
          en: ['OK', 'Not applicable', 'Not performed'],
          es: ['OK', 'No aplicable', 'No realizado'],
        },
      },
    },
  },

  teste_pos_servico_printers: {
    title: { pt: 'Teste Final da Impressora', en: 'Printer Final Test', es: 'Prueba Final de la Impresora' },
    description: {
      pt: 'Testes finais para garantir a entrega.',
      en: 'Final tests to ensure delivery.',
      es: 'Pruebas finales para garantizar la entrega.',
    },
    items: {
      impressao_teste: {
        label: { pt: 'Impressão teste', en: 'Test print', es: 'Impresión de prueba' },
        options: {
          pt: ['OK', 'Falha', 'Não testado'],
          en: ['OK', 'Failure', 'Not tested'],
          es: ['OK', 'Falla', 'No probado'],
        },
      },
      scanner: {
        label: { pt: 'Scanner/Cópia (se aplicável)', en: 'Scanner/Copy (if applicable)', es: 'Escáner/Copia (si aplica)' },
        options: {
          pt: ['OK', 'Falha', 'Não aplicável', 'Não testado'],
          en: ['OK', 'Failure', 'Not applicable', 'Not tested'],
          es: ['OK', 'Falla', 'No aplicable', 'No probado'],
        },
      },
      rede: {
        label: { pt: 'Rede (Wi-Fi/Ethernet)', en: 'Network (Wi-Fi/Ethernet)', es: 'Red (Wi-Fi/Ethernet)' },
        options: {
          pt: ['OK', 'Falha', 'Não aplicável', 'Não testado'],
          en: ['OK', 'Failure', 'Not applicable', 'Not tested'],
          es: ['OK', 'Falla', 'No aplicable', 'No probado'],
        },
      },
      foto_pagina_teste: { label: { pt: 'Foto da página teste (evidência)', en: 'Test page photo (evidence)', es: 'Foto de la página de prueba (evidencia)' } },
      aprovado: { label: { pt: 'Aprovado para entrega', en: 'Approved for delivery', es: 'Aprobado para entrega' } },
    },
  },
};

module.exports = { PRINTERS_TRANSLATIONS };
