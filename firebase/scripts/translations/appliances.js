// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - ELETRODOMÉSTICOS
// ═══════════════════════════════════════════════════════════════════════════

const APPLIANCES_TRANSLATIONS = {
  checklist_entrada_eletro: {
    title: { pt: 'Entrada do Eletrodoméstico', en: 'Appliance Check-in', es: 'Entrada del Electrodoméstico' },
    description: {
      pt: 'Registra o estado inicial e o defeito relatado.',
      en: 'Records initial condition and reported issue.',
      es: 'Registra el estado inicial y el defecto reportado.',
    },
    items: {
      fotos_equipamento: { label: { pt: 'Fotos do Equipamento', en: 'Equipment Photos', es: 'Fotos del Equipo' } },
      tipo_equipamento: {
        label: { pt: 'Tipo de Equipamento', en: 'Equipment Type', es: 'Tipo de Equipo' },
        options: {
          pt: ['Geladeira', 'Máquina de Lavar', 'Micro-ondas', 'Fogão', 'Lava-louças', 'Outro'],
          en: ['Refrigerator', 'Washing Machine', 'Microwave', 'Stove', 'Dishwasher', 'Other'],
          es: ['Refrigerador', 'Lavadora', 'Microondas', 'Cocina', 'Lavavajillas', 'Otro'],
        },
      },
      liga: { label: { pt: 'Equipamento Liga?', en: 'Equipment Turns On?', es: '¿Equipo Enciende?' } },
      avarias_visiveis: {
        label: { pt: 'Avarias Visíveis', en: 'Visible Damage', es: 'Daños Visibles' },
        options: {
          pt: ['Amassados', 'Ferrugem', 'Botões quebrados', 'Vidro trincado', 'Nenhuma'],
          en: ['Dents', 'Rust', 'Broken buttons', 'Cracked glass', 'None'],
          es: ['Abolladuras', 'Óxido', 'Botones rotos', 'Vidrio rajado', 'Ninguno'],
        },
      },
      defeito_relatado: { label: { pt: 'Defeito Relatado', en: 'Reported Issue', es: 'Defecto Reportado' } },
    },
  },

  diagnostico_geladeira: {
    title: { pt: 'Diagnóstico de Geladeira/Freezer', en: 'Refrigerator/Freezer Diagnosis', es: 'Diagnóstico de Refrigerador/Congelador' },
    description: {
      pt: 'Testa refrigeração e componentes principais.',
      en: 'Tests cooling and main components.',
      es: 'Prueba refrigeración y componentes principales.',
    },
    items: {
      compressor_funciona: { label: { pt: 'Compressor Funciona?', en: 'Compressor Works?', es: '¿Compresor Funciona?' } },
      motor_ventilador: {
        label: { pt: 'Motor Ventilador', en: 'Fan Motor', es: 'Motor Ventilador' },
        options: {
          pt: ['OK', 'Ruidoso', 'Parado', 'Não possui'],
          en: ['OK', 'Noisy', 'Stopped', 'Does not have'],
          es: ['OK', 'Ruidoso', 'Parado', 'No tiene'],
        },
      },
      gas_ok: {
        label: { pt: 'Gás Refrigerante OK', en: 'Refrigerant Gas OK', es: 'Gas Refrigerante OK' },
        options: {
          pt: ['OK', 'Baixo', 'Zerado', 'Não verificado'],
          en: ['OK', 'Low', 'Empty', 'Not checked'],
          es: ['OK', 'Bajo', 'Vacío', 'No verificado'],
        },
      },
      termostato: {
        label: { pt: 'Termostato', en: 'Thermostat', es: 'Termostato' },
        options: {
          pt: ['OK', 'Defeituoso', 'Não testado'],
          en: ['OK', 'Defective', 'Not tested'],
          es: ['OK', 'Defectuoso', 'No probado'],
        },
      },
      borracha_porta: {
        label: { pt: 'Borracha da Porta', en: 'Door Seal', es: 'Goma de la Puerta' },
        options: {
          pt: ['OK', 'Ressecada', 'Rasgada', 'Solta'],
          en: ['OK', 'Dried out', 'Torn', 'Loose'],
          es: ['OK', 'Reseca', 'Rasgada', 'Suelta'],
        },
      },
      degelo: {
        label: { pt: 'Sistema de Degelo', en: 'Defrost System', es: 'Sistema de Descongelación' },
        options: {
          pt: ['OK', 'Resistência queimada', 'Timer defeituoso', 'N/A'],
          en: ['OK', 'Burned heater', 'Defective timer', 'N/A'],
          es: ['OK', 'Resistencia quemada', 'Timer defectuoso', 'N/A'],
        },
      },
      temperatura_interna: { label: { pt: 'Temperatura Interna (°C)', en: 'Internal Temperature (°C)', es: 'Temperatura Interna (°C)' } },
    },
  },

  diagnostico_maquina_lavar: {
    title: { pt: 'Diagnóstico de Máquina de Lavar', en: 'Washing Machine Diagnosis', es: 'Diagnóstico de Lavadora' },
    description: {
      pt: 'Testa enchimento, drenagem e componentes.',
      en: 'Tests filling, draining and components.',
      es: 'Prueba llenado, drenaje y componentes.',
    },
    items: {
      enche_agua: { label: { pt: 'Enche Água Normalmente?', en: 'Fills Water Normally?', es: '¿Llena Agua Normalmente?' } },
      drena_agua: { label: { pt: 'Drena Água Normalmente?', en: 'Drains Water Normally?', es: '¿Drena Agua Normalmente?' } },
      centrifuga: { label: { pt: 'Centrifuga Normalmente?', en: 'Spins Normally?', es: '¿Centrifuga Normalmente?' } },
      motor: {
        label: { pt: 'Motor', en: 'Motor', es: 'Motor' },
        options: {
          pt: ['OK', 'Ruidoso', 'Travado', 'Queimado'],
          en: ['OK', 'Noisy', 'Jammed', 'Burned'],
          es: ['OK', 'Ruidoso', 'Trabado', 'Quemado'],
        },
      },
      bomba_drenagem: {
        label: { pt: 'Bomba de Drenagem', en: 'Drain Pump', es: 'Bomba de Drenaje' },
        options: {
          pt: ['OK', 'Entupida', 'Queimada'],
          en: ['OK', 'Clogged', 'Burned'],
          es: ['OK', 'Obstruida', 'Quemada'],
        },
      },
      placa_eletronica: {
        label: { pt: 'Placa Eletrônica', en: 'Electronic Board', es: 'Placa Electrónica' },
        options: {
          pt: ['OK', 'Com defeito', 'Não testada'],
          en: ['OK', 'Defective', 'Not tested'],
          es: ['OK', 'Con defecto', 'No probada'],
        },
      },
      rolamentos: {
        label: { pt: 'Rolamentos/Retentores', en: 'Bearings/Seals', es: 'Rodamientos/Retenes' },
        options: {
          pt: ['OK', 'Ruidoso', 'Vazando', 'Não verificado'],
          en: ['OK', 'Noisy', 'Leaking', 'Not checked'],
          es: ['OK', 'Ruidoso', 'Con fuga', 'No verificado'],
        },
      },
      vazamento: { label: { pt: 'Vazamento Detectado?', en: 'Leak Detected?', es: '¿Fuga Detectada?' } },
    },
  },

  diagnostico_microondas: {
    title: { pt: 'Diagnóstico de Micro-ondas', en: 'Microwave Diagnosis', es: 'Diagnóstico de Microondas' },
    description: {
      pt: 'Testa painel, aquecimento e segurança.',
      en: 'Tests panel, heating and safety.',
      es: 'Prueba panel, calentamiento y seguridad.',
    },
    items: {
      painel_funciona: { label: { pt: 'Painel Funciona?', en: 'Panel Works?', es: '¿Panel Funciona?' } },
      prato_gira: { label: { pt: 'Prato Giratório Funciona?', en: 'Turntable Works?', es: '¿Plato Giratorio Funciona?' } },
      aquece: { label: { pt: 'Aquece Normalmente?', en: 'Heats Normally?', es: '¿Calienta Normalmente?' } },
      magnetron: {
        label: { pt: 'Magnetron', en: 'Magnetron', es: 'Magnetrón' },
        options: {
          pt: ['OK', 'Fraco', 'Queimado', 'Não testado'],
          en: ['OK', 'Weak', 'Burned', 'Not tested'],
          es: ['OK', 'Débil', 'Quemado', 'No probado'],
        },
      },
      capacitor: {
        label: { pt: 'Capacitor', en: 'Capacitor', es: 'Capacitor' },
        options: {
          pt: ['OK', 'Descarregado', 'Queimado', 'Não testado'],
          en: ['OK', 'Discharged', 'Burned', 'Not tested'],
          es: ['OK', 'Descargado', 'Quemado', 'No probado'],
        },
      },
      trava_porta: {
        label: { pt: 'Trava da Porta', en: 'Door Latch', es: 'Traba de la Puerta' },
        options: {
          pt: ['OK', 'Defeituosa', 'Quebrada'],
          en: ['OK', 'Defective', 'Broken'],
          es: ['OK', 'Defectuosa', 'Rota'],
        },
      },
      faz_barulho: { label: { pt: 'Ruídos Anormais?', en: 'Abnormal Noises?', es: '¿Ruidos Anormales?' } },
    },
  },

  entrega_eletro: {
    title: { pt: 'Entrega do Eletrodoméstico', en: 'Appliance Delivery', es: 'Entrega del Electrodoméstico' },
    description: {
      pt: 'Confere serviço executado e orientações ao cliente.',
      en: 'Reviews service performed and customer guidance.',
      es: 'Revisa servicio ejecutado y orientaciones al cliente.',
    },
    items: {
      servico_executado: { label: { pt: 'Serviço Executado', en: 'Service Performed', es: 'Servicio Ejecutado' } },
      teste_final: { label: { pt: 'Teste Final Realizado', en: 'Final Test Performed', es: 'Prueba Final Realizada' } },
      equipamento_limpo: { label: { pt: 'Equipamento Limpo', en: 'Equipment Cleaned', es: 'Equipo Limpio' } },
      pecas_trocadas: { label: { pt: 'Peças Trocadas', en: 'Parts Replaced', es: 'Piezas Cambiadas' } },
      orientacoes: { label: { pt: 'Orientações ao Cliente', en: 'Customer Guidance', es: 'Orientaciones al Cliente' } },
      garantia: {
        label: { pt: 'Garantia do Serviço', en: 'Service Warranty', es: 'Garantía del Servicio' },
        options: {
          pt: ['30 dias', '60 dias', '90 dias', 'Sem garantia'],
          en: ['30 days', '60 days', '90 days', 'No warranty'],
          es: ['30 días', '60 días', '90 días', 'Sin garantía'],
        },
      },
    },
  },

  checklist_seguranca_appliances: {
    title: { pt: 'Segurança do Equipamento', en: 'Equipment Safety', es: 'Seguridad del Equipo' },
    description: {
      pt: 'Confere riscos elétricos/gás antes e após o serviço.',
      en: 'Checks electrical/gas risks before and after service.',
      es: 'Verifica riesgos eléctricos/gas antes y después del servicio.',
    },
    items: {
      desligado_rede: { label: { pt: 'Equipamento desconectado/desenergizado antes do serviço', en: 'Equipment disconnected/de-energized before service', es: 'Equipo desconectado/desenergizado antes del servicio' } },
      aterramento: {
        label: { pt: 'Aterramento', en: 'Grounding', es: 'Conexión a Tierra' },
        options: {
          pt: ['OK', 'Ausente', 'Não aplicável'],
          en: ['OK', 'Absent', 'Not applicable'],
          es: ['OK', 'Ausente', 'No aplicable'],
        },
      },
      teste_fuga: {
        label: { pt: 'Teste de fuga/isolação', en: 'Leakage/Insulation Test', es: 'Prueba de fuga/aislamiento' },
        options: {
          pt: ['OK', 'Falha', 'Não aplicável'],
          en: ['OK', 'Failure', 'Not applicable'],
          es: ['OK', 'Falla', 'No aplicable'],
        },
      },
      vazamento_gas: {
        label: { pt: 'Teste de vazamento de gás (quando aplicável)', en: 'Gas leak test (when applicable)', es: 'Prueba de fuga de gas (cuando aplique)' },
        options: {
          pt: ['Sem vazamento', 'Vazamento identificado', 'Não aplicável'],
          en: ['No leak', 'Leak identified', 'Not applicable'],
          es: ['Sin fuga', 'Fuga identificada', 'No aplicable'],
        },
      },
      foto_instalacao: { label: { pt: 'Foto da instalação/local', en: 'Installation/Location Photo', es: 'Foto de la instalación/local' } },
    },
  },

  teste_pos_reparo_appliances: {
    title: { pt: 'Teste Final do Equipamento', en: 'Equipment Final Test', es: 'Prueba Final del Equipo' },
    description: {
      pt: 'Valida funcionamento após o reparo.',
      en: 'Validates operation after repair.',
      es: 'Valida funcionamiento después de la reparación.',
    },
    items: {
      ciclo_teste: {
        label: { pt: 'Ciclo de teste', en: 'Test Cycle', es: 'Ciclo de prueba' },
        options: {
          pt: ['Realizado (completo)', 'Parcial', 'Não realizado'],
          en: ['Completed (full)', 'Partial', 'Not performed'],
          es: ['Realizado (completo)', 'Parcial', 'No realizado'],
        },
      },
      ruidos: {
        label: { pt: 'Ruídos', en: 'Noises', es: 'Ruidos' },
        options: {
          pt: ['Normal', 'Anormal', 'Não testado'],
          en: ['Normal', 'Abnormal', 'Not tested'],
          es: ['Normal', 'Anormal', 'No probado'],
        },
      },
      vazamentos: {
        label: { pt: 'Vazamentos', en: 'Leaks', es: 'Fugas' },
        options: {
          pt: ['Sem vazamentos', 'Vazamento identificado', 'Não aplicável'],
          en: ['No leaks', 'Leak identified', 'Not applicable'],
          es: ['Sin fugas', 'Fuga identificada', 'No aplicable'],
        },
      },
      aprovado: { label: { pt: 'Aprovado para entrega', en: 'Approved for delivery', es: 'Aprobado para entrega' } },
      foto_final: { label: { pt: 'Foto final', en: 'Final Photo', es: 'Foto final' } },
    },
  },
};

module.exports = { APPLIANCES_TRANSLATIONS };
