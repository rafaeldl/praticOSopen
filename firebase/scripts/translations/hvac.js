// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - HVAC (Ar Condicionado / Refrigeração)
// ═══════════════════════════════════════════════════════════════════════════

const HVAC_TRANSLATIONS = {
  laudo_instalacao: {
    title: {
      pt: 'Registro da Instalação',
      en: 'Installation Record',
      es: 'Registro de Instalación',
    },
    description: {
      pt: 'Fotos e medições básicas para comprovar a instalação.',
      en: 'Photos and basic measurements to prove the installation.',
      es: 'Fotos y mediciones básicas para comprobar la instalación.',
    },
    items: {
      foto_evaporadora: {
        label: {
          pt: 'Foto da Evaporadora (Interna)',
          en: 'Evaporator Photo (Indoor Unit)',
          es: 'Foto del Evaporador (Unidad Interna)',
        },
      },
      foto_condensadora: {
        label: {
          pt: 'Foto da Condensadora (Externa)',
          en: 'Condenser Photo (Outdoor Unit)',
          es: 'Foto del Condensador (Unidad Externa)',
        },
      },
      teste_dreno: {
        label: {
          pt: 'Teste de Dreno Realizado?',
          en: 'Drain Test Performed?',
          es: '¿Prueba de Drenaje Realizada?',
        },
      },
      vacuo_sistema: {
        label: {
          pt: 'Vácuo no Sistema Realizado?',
          en: 'System Vacuum Performed?',
          es: '¿Vacío del Sistema Realizado?',
        },
      },
      pressao_gas: {
        label: {
          pt: 'Pressão do Gás (PSI)',
          en: 'Gas Pressure (PSI)',
          es: 'Presión del Gas (PSI)',
        },
      },
      temp_saida: {
        label: {
          pt: 'Temperatura de Saída (°C)',
          en: 'Output Temperature (°C)',
          es: 'Temperatura de Salida (°C)',
        },
      },
    },
  },

  manutencao_preventiva: {
    title: {
      pt: 'Manutenção Preventiva',
      en: 'Preventive Maintenance',
      es: 'Mantenimiento Preventivo',
    },
    description: {
      pt: 'Checklist de limpeza e verificação periódica do equipamento.',
      en: 'Cleaning checklist and periodic equipment verification.',
      es: 'Lista de limpieza y verificación periódica del equipo.',
    },
    items: {
      filtros_limpos: {
        label: {
          pt: 'Filtros Limpos/Trocados',
          en: 'Filters Cleaned/Replaced',
          es: 'Filtros Limpios/Cambiados',
        },
      },
      evaporadora_limpa: {
        label: {
          pt: 'Evaporadora Higienizada',
          en: 'Evaporator Sanitized',
          es: 'Evaporador Higienizado',
        },
      },
      condensadora_limpa: {
        label: {
          pt: 'Condensadora Limpa',
          en: 'Condenser Cleaned',
          es: 'Condensador Limpio',
        },
      },
      dreno_desobstruido: {
        label: {
          pt: 'Dreno Desobstruído',
          en: 'Drain Unclogged',
          es: 'Drenaje Desobstruido',
        },
      },
      bandeja_limpa: {
        label: {
          pt: 'Bandeja de Drenagem Limpa',
          en: 'Drain Pan Cleaned',
          es: 'Bandeja de Drenaje Limpia',
        },
      },
      verificacao_eletrica: {
        label: {
          pt: 'Verificação Elétrica',
          en: 'Electrical Check',
          es: 'Verificación Eléctrica',
        },
        options: {
          pt: ['Disjuntor OK', 'Fiação OK', 'Conexões OK', 'Aterramento OK'],
          en: ['Breaker OK', 'Wiring OK', 'Connections OK', 'Grounding OK'],
          es: ['Disyuntor OK', 'Cableado OK', 'Conexiones OK', 'Tierra OK'],
        },
      },
      teste_funcionamento: {
        label: {
          pt: 'Teste de Funcionamento OK',
          en: 'Function Test OK',
          es: 'Prueba de Funcionamiento OK',
        },
      },
    },
  },

  diagnostico_tecnico: {
    title: {
      pt: 'Diagnóstico do Equipamento',
      en: 'Equipment Diagnosis',
      es: 'Diagnóstico del Equipo',
    },
    description: {
      pt: 'Registre sintomas e testes para identificar o problema.',
      en: 'Record symptoms and tests to identify the problem.',
      es: 'Registre síntomas y pruebas para identificar el problema.',
    },
    items: {
      sintoma_relatado: {
        label: {
          pt: 'Sintoma Relatado pelo Cliente',
          en: 'Symptom Reported by Customer',
          es: 'Síntoma Reportado por el Cliente',
        },
      },
      equipamento_liga: {
        label: {
          pt: 'Equipamento Liga?',
          en: 'Equipment Turns On?',
          es: '¿El Equipo Enciende?',
        },
      },
      compressor_funciona: {
        label: {
          pt: 'Compressor Funciona?',
          en: 'Compressor Works?',
          es: '¿El Compresor Funciona?',
        },
      },
      nivel_gas: {
        label: {
          pt: 'Nível de Gás',
          en: 'Gas Level',
          es: 'Nivel de Gas',
        },
        options: {
          pt: ['OK', 'Baixo', 'Zerado', 'Não verificado'],
          en: ['OK', 'Low', 'Empty', 'Not checked'],
          es: ['OK', 'Bajo', 'Vacío', 'No verificado'],
        },
      },
      vazamento: {
        label: {
          pt: 'Vazamento Detectado?',
          en: 'Leak Detected?',
          es: '¿Fuga Detectada?',
        },
      },
      capacitor: {
        label: {
          pt: 'Estado do Capacitor',
          en: 'Capacitor Condition',
          es: 'Estado del Capacitor',
        },
        options: {
          pt: ['OK', 'Fraco', 'Queimado', 'Não verificado'],
          en: ['OK', 'Weak', 'Burned', 'Not checked'],
          es: ['OK', 'Débil', 'Quemado', 'No verificado'],
        },
      },
      diagnostico_final: {
        label: {
          pt: 'Diagnóstico Final',
          en: 'Final Diagnosis',
          es: 'Diagnóstico Final',
        },
      },
    },
  },

  recarga_gas: {
    title: {
      pt: 'Recarga de Gás',
      en: 'Gas Recharge',
      es: 'Recarga de Gas',
    },
    description: {
      pt: 'Anote tipo e quantidade de gás e medições antes/depois.',
      en: 'Note gas type and quantity and measurements before/after.',
      es: 'Anote tipo y cantidad de gas y mediciones antes/después.',
    },
    items: {
      tipo_gas: {
        label: {
          pt: 'Tipo de Gás',
          en: 'Gas Type',
          es: 'Tipo de Gas',
        },
        options: {
          pt: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A', 'R-407C'],
          en: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A', 'R-407C'],
          es: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A', 'R-407C'],
        },
      },
      quantidade_gas: {
        label: {
          pt: 'Quantidade Utilizada (g)',
          en: 'Quantity Used (g)',
          es: 'Cantidad Utilizada (g)',
        },
      },
      pressao_antes: {
        label: {
          pt: 'Pressão Antes (PSI)',
          en: 'Pressure Before (PSI)',
          es: 'Presión Antes (PSI)',
        },
      },
      pressao_depois: {
        label: {
          pt: 'Pressão Depois (PSI)',
          en: 'Pressure After (PSI)',
          es: 'Presión Después (PSI)',
        },
      },
      temp_saida_final: {
        label: {
          pt: 'Temperatura de Saída Final (°C)',
          en: 'Final Output Temperature (°C)',
          es: 'Temperatura de Salida Final (°C)',
        },
      },
      teste_vazamento: {
        label: {
          pt: 'Teste de Vazamento Realizado',
          en: 'Leak Test Performed',
          es: 'Prueba de Fuga Realizada',
        },
      },
    },
  },

  checklist_seguranca_hvac: {
    title: {
      pt: 'Segurança do Técnico (NR10/NR35)',
      en: 'Technician Safety (Electrical/Height)',
      es: 'Seguridad del Técnico (Eléctrica/Altura)',
    },
    description: {
      pt: 'Confere EPIs e segurança do local antes de iniciar.',
      en: 'Checks PPE and site safety before starting.',
      es: 'Verifica EPP y seguridad del lugar antes de iniciar.',
    },
    items: {
      energia_bloqueada: {
        label: {
          pt: 'Energia desligada e bloqueada/identificada',
          en: 'Power off and locked out/tagged',
          es: 'Energía desconectada y bloqueada/identificada',
        },
      },
      epi_utilizado: {
        label: {
          pt: 'EPI utilizado',
          en: 'PPE used',
          es: 'EPP utilizado',
        },
        options: {
          pt: ['Luvas', 'Óculos', 'Botina', 'Máscara', 'Cinto/Trava-quedas', 'Não aplicável'],
          en: ['Gloves', 'Safety glasses', 'Safety boots', 'Mask', 'Harness/Fall arrest', 'Not applicable'],
          es: ['Guantes', 'Gafas', 'Botas', 'Máscara', 'Arnés/Anticaídas', 'No aplica'],
        },
      },
      area_sinalizada: {
        label: {
          pt: 'Área sinalizada e protegida',
          en: 'Area marked and protected',
          es: 'Área señalizada y protegida',
        },
      },
      escada_ancorada: {
        label: {
          pt: 'Escada/andaime seguro (quando aplicável)',
          en: 'Ladder/scaffold secure (when applicable)',
          es: 'Escalera/andamio seguro (cuando aplica)',
        },
        options: {
          pt: ['OK', 'Não aplicável', 'Não conforme'],
          en: ['OK', 'Not applicable', 'Non-compliant'],
          es: ['OK', 'No aplica', 'No conforme'],
        },
      },
      foto_area: {
        label: {
          pt: 'Foto da área de trabalho',
          en: 'Work area photo',
          es: 'Foto del área de trabajo',
        },
      },
      observacoes: {
        label: {
          pt: 'Observações',
          en: 'Notes',
          es: 'Observaciones',
        },
      },
    },
  },

  comissionamento_pos_servico_hvac: {
    title: {
      pt: 'Comissionamento Pós-Serviço',
      en: 'Post-Service Commissioning',
      es: 'Comisionamiento Post-Servicio',
    },
    description: {
      pt: 'Medições finais para validar desempenho e reduzir retorno.',
      en: 'Final measurements to validate performance and reduce callbacks.',
      es: 'Mediciones finales para validar desempeño y reducir retornos.',
    },
    items: {
      tensao: {
        label: {
          pt: 'Tensão (V)',
          en: 'Voltage (V)',
          es: 'Tensión (V)',
        },
      },
      corrente: {
        label: {
          pt: 'Corrente (A)',
          en: 'Current (A)',
          es: 'Corriente (A)',
        },
      },
      delta_t: {
        label: {
          pt: 'Diferença de temperatura (ΔT °C)',
          en: 'Temperature difference (ΔT °C)',
          es: 'Diferencia de temperatura (ΔT °C)',
        },
      },
      dreno_ok: {
        label: {
          pt: 'Dreno testado e ok',
          en: 'Drain tested and OK',
          es: 'Drenaje probado y OK',
        },
      },
      isolamento_tubulacao: {
        label: {
          pt: 'Isolamento da tubulação',
          en: 'Pipe insulation',
          es: 'Aislamiento de tubería',
        },
        options: {
          pt: ['OK', 'Parcial', 'Ausente'],
          en: ['OK', 'Partial', 'Missing'],
          es: ['OK', 'Parcial', 'Ausente'],
        },
      },
      teste_vazamento: {
        label: {
          pt: 'Teste de vazamento realizado',
          en: 'Leak test performed',
          es: 'Prueba de fuga realizada',
        },
      },
      foto_instalacao_final: {
        label: {
          pt: 'Foto da instalação final',
          en: 'Final installation photo',
          es: 'Foto de instalación final',
        },
      },
    },
  },
};

module.exports = { HVAC_TRANSLATIONS };
