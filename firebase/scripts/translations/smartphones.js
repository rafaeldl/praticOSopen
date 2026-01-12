// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - SMARTPHONES (Assistência Técnica de Celulares)
// ═══════════════════════════════════════════════════════════════════════════

const SMARTPHONES_TRANSLATIONS = {
  checklist_entrada_celular: {
    title: {
      pt: 'Entrada do Celular',
      en: 'Phone Check-in',
      es: 'Entrada del Celular',
    },
    description: {
      pt: 'Registra o estado inicial e os acessórios recebidos.',
      en: 'Records initial condition and received accessories.',
      es: 'Registra el estado inicial y los accesorios recibidos.',
    },
    items: {
      imei: {
        label: { pt: 'IMEI', en: 'IMEI', es: 'IMEI' },
      },
      foto_frontal: {
        label: {
          pt: 'Foto Frontal do Aparelho',
          en: 'Front Photo of Device',
          es: 'Foto Frontal del Dispositivo',
        },
      },
      foto_traseira: {
        label: {
          pt: 'Foto Traseira do Aparelho',
          en: 'Back Photo of Device',
          es: 'Foto Trasera del Dispositivo',
        },
      },
      estado_tela: {
        label: {
          pt: 'Estado da Tela',
          en: 'Screen Condition',
          es: 'Estado de la Pantalla',
        },
        options: {
          pt: ['Perfeita', 'Riscos leves', 'Trincada', 'Quebrada', 'Não liga'],
          en: ['Perfect', 'Light scratches', 'Cracked', 'Broken', 'Does not turn on'],
          es: ['Perfecta', 'Rayones leves', 'Rajada', 'Rota', 'No enciende'],
        },
      },
      estado_carcaca: {
        label: {
          pt: 'Estado da Carcaça',
          en: 'Case Condition',
          es: 'Estado de la Carcasa',
        },
        options: {
          pt: ['Perfeita', 'Riscos leves', 'Amassados', 'Quebrada'],
          en: ['Perfect', 'Light scratches', 'Dents', 'Broken'],
          es: ['Perfecta', 'Rayones leves', 'Abolladuras', 'Rota'],
        },
      },
      acessorios_recebidos: {
        label: {
          pt: 'Acessórios Recebidos',
          en: 'Accessories Received',
          es: 'Accesorios Recibidos',
        },
        options: {
          pt: ['Carregador', 'Cabo', 'Fone', 'Capinha', 'Película', 'Chip', 'Cartão SD', 'Nenhum'],
          en: ['Charger', 'Cable', 'Earphones', 'Case', 'Screen protector', 'SIM', 'SD Card', 'None'],
          es: ['Cargador', 'Cable', 'Audífonos', 'Funda', 'Protector de pantalla', 'Chip', 'Tarjeta SD', 'Ninguno'],
        },
      },
      senha_informada: {
        label: {
          pt: 'Senha/Padrão Informado',
          en: 'Password/Pattern Provided',
          es: 'Contraseña/Patrón Informado',
        },
      },
      defeito_relatado: {
        label: {
          pt: 'Defeito Relatado',
          en: 'Reported Issue',
          es: 'Defecto Reportado',
        },
      },
    },
  },

  diagnostico_celular: {
    title: {
      pt: 'Diagnóstico Completo do Celular',
      en: 'Complete Phone Diagnosis',
      es: 'Diagnóstico Completo del Celular',
    },
    description: {
      pt: 'Testa funções principais para identificar falhas.',
      en: 'Tests main functions to identify failures.',
      es: 'Prueba funciones principales para identificar fallas.',
    },
    items: {
      tela_touch: {
        label: { pt: 'Tela/Touch', en: 'Screen/Touch', es: 'Pantalla/Táctil' },
        options: {
          pt: ['OK', 'Falha parcial', 'Não funciona'],
          en: ['OK', 'Partial failure', 'Does not work'],
          es: ['OK', 'Falla parcial', 'No funciona'],
        },
      },
      bateria: {
        label: { pt: 'Bateria', en: 'Battery', es: 'Batería' },
        options: {
          pt: ['OK', 'Viciada', 'Estufada', 'Não carrega'],
          en: ['OK', 'Degraded', 'Swollen', 'Does not charge'],
          es: ['OK', 'Viciada', 'Hinchada', 'No carga'],
        },
      },
      camera_traseira: {
        label: { pt: 'Câmera Traseira', en: 'Rear Camera', es: 'Cámara Trasera' },
        options: {
          pt: ['OK', 'Embaçada', 'Não foca', 'Não funciona'],
          en: ['OK', 'Blurry', 'Does not focus', 'Does not work'],
          es: ['OK', 'Borrosa', 'No enfoca', 'No funciona'],
        },
      },
      camera_frontal: {
        label: { pt: 'Câmera Frontal', en: 'Front Camera', es: 'Cámara Frontal' },
        options: {
          pt: ['OK', 'Embaçada', 'Não foca', 'Não funciona'],
          en: ['OK', 'Blurry', 'Does not focus', 'Does not work'],
          es: ['OK', 'Borrosa', 'No enfoca', 'No funciona'],
        },
      },
      alto_falante: {
        label: { pt: 'Alto-falante', en: 'Speaker', es: 'Altavoz' },
        options: {
          pt: ['OK', 'Baixo', 'Chiando', 'Não funciona'],
          en: ['OK', 'Low', 'Crackling', 'Does not work'],
          es: ['OK', 'Bajo', 'Con ruido', 'No funciona'],
        },
      },
      microfone: {
        label: { pt: 'Microfone', en: 'Microphone', es: 'Micrófono' },
        options: {
          pt: ['OK', 'Baixo', 'Com ruído', 'Não funciona'],
          en: ['OK', 'Low', 'Noisy', 'Does not work'],
          es: ['OK', 'Bajo', 'Con ruido', 'No funciona'],
        },
      },
      wifi: {
        label: { pt: 'Wi-Fi', en: 'Wi-Fi', es: 'Wi-Fi' },
        options: {
          pt: ['OK', 'Sinal fraco', 'Não conecta'],
          en: ['OK', 'Weak signal', 'Does not connect'],
          es: ['OK', 'Señal débil', 'No conecta'],
        },
      },
      bluetooth: {
        label: { pt: 'Bluetooth', en: 'Bluetooth', es: 'Bluetooth' },
        options: {
          pt: ['OK', 'Falha intermitente', 'Não funciona'],
          en: ['OK', 'Intermittent failure', 'Does not work'],
          es: ['OK', 'Falla intermitente', 'No funciona'],
        },
      },
      biometria: {
        label: { pt: 'Biometria/Face ID', en: 'Biometrics/Face ID', es: 'Biometría/Face ID' },
        options: {
          pt: ['OK', 'Falha intermitente', 'Não funciona', 'Não possui'],
          en: ['OK', 'Intermittent failure', 'Does not work', 'Not available'],
          es: ['OK', 'Falla intermitente', 'No funciona', 'No posee'],
        },
      },
      botoes: {
        label: { pt: 'Botões Físicos', en: 'Physical Buttons', es: 'Botones Físicos' },
        options: {
          pt: ['Todos OK', 'Power com falha', 'Volume com falha', 'Outros'],
          en: ['All OK', 'Power failure', 'Volume failure', 'Others'],
          es: ['Todos OK', 'Power con falla', 'Volumen con falla', 'Otros'],
        },
      },
      conector_carga: {
        label: { pt: 'Conector de Carga', en: 'Charging Port', es: 'Puerto de Carga' },
        options: {
          pt: ['OK', 'Mau contato', 'Não carrega'],
          en: ['OK', 'Bad contact', 'Does not charge'],
          es: ['OK', 'Mal contacto', 'No carga'],
        },
      },
      diagnostico_tecnico: {
        label: { pt: 'Diagnóstico Técnico', en: 'Technical Diagnosis', es: 'Diagnóstico Técnico' },
      },
    },
  },

  troca_tela: {
    title: { pt: 'Troca de Tela', en: 'Screen Replacement', es: 'Cambio de Pantalla' },
    description: {
      pt: 'Confere peça instalada e testes após a troca do display.',
      en: 'Confirms installed part and tests after display replacement.',
      es: 'Confirma pieza instalada y pruebas después del cambio de pantalla.',
    },
    items: {
      modelo_tela: {
        label: { pt: 'Modelo da Tela Instalada', en: 'Installed Screen Model', es: 'Modelo de Pantalla Instalada' },
      },
      qualidade_tela: {
        label: { pt: 'Qualidade da Tela', en: 'Screen Quality', es: 'Calidad de Pantalla' },
        options: {
          pt: ['Original', 'Premium', 'Compatível'],
          en: ['Original', 'Premium', 'Compatible'],
          es: ['Original', 'Premium', 'Compatible'],
        },
      },
      touch_ok: {
        label: { pt: 'Touch Funcionando', en: 'Touch Working', es: 'Táctil Funcionando' },
      },
      display_ok: {
        label: { pt: 'Display sem Manchas/Falhas', en: 'Display without Spots/Defects', es: 'Pantalla sin Manchas/Fallas' },
      },
      sensor_proximidade: {
        label: { pt: 'Sensor de Proximidade OK', en: 'Proximity Sensor OK', es: 'Sensor de Proximidad OK' },
      },
      foto_tela_nova: {
        label: { pt: 'Foto da Tela Nova (ligada)', en: 'Photo of New Screen (on)', es: 'Foto de Pantalla Nueva (encendida)' },
      },
    },
  },

  troca_bateria: {
    title: { pt: 'Troca de Bateria', en: 'Battery Replacement', es: 'Cambio de Batería' },
    description: {
      pt: 'Registra a bateria instalada e testes de funcionamento.',
      en: 'Records installed battery and function tests.',
      es: 'Registra la batería instalada y pruebas de funcionamiento.',
    },
    items: {
      modelo_bateria: {
        label: { pt: 'Modelo da Bateria', en: 'Battery Model', es: 'Modelo de Batería' },
      },
      capacidade_mah: {
        label: { pt: 'Capacidade (mAh)', en: 'Capacity (mAh)', es: 'Capacidad (mAh)' },
      },
      origem: {
        label: { pt: 'Origem', en: 'Origin', es: 'Origen' },
        options: {
          pt: ['Original', 'Compatível', 'Recondicionada'],
          en: ['Original', 'Compatible', 'Refurbished'],
          es: ['Original', 'Compatible', 'Reacondicionada'],
        },
      },
      carregamento_ok: {
        label: { pt: 'Carregamento Normal', en: 'Normal Charging', es: 'Carga Normal' },
      },
      saude_bateria: {
        label: { pt: 'Saúde da Bateria (%)', en: 'Battery Health (%)', es: 'Salud de Batería (%)' },
      },
      foto_bateria: {
        label: { pt: 'Foto da Bateria Instalada', en: 'Photo of Installed Battery', es: 'Foto de Batería Instalada' },
      },
    },
  },

  termo_autorizacao_celular: {
    title: { pt: 'Autorização e Privacidade (Celular)', en: 'Authorization and Privacy (Phone)', es: 'Autorización y Privacidad (Celular)' },
    description: {
      pt: 'Consentimento para acesso, backup e registro do reparo.',
      en: 'Consent for access, backup and repair documentation.',
      es: 'Consentimiento para acceso, respaldo y registro de reparación.',
    },
    items: {
      autorizacao_acesso: {
        label: { pt: 'Autorizo acesso ao aparelho para diagnóstico', en: 'I authorize device access for diagnosis', es: 'Autorizo acceso al dispositivo para diagnóstico' },
      },
      ciencia_backup: {
        label: { pt: 'Ciente que backup é responsabilidade do cliente', en: 'Aware that backup is customer responsibility', es: 'Enterado que el respaldo es responsabilidad del cliente' },
      },
      ciencia_dados: {
        label: { pt: 'Ciente que dados podem ser perdidos em caso de dano severo', en: 'Aware that data may be lost in case of severe damage', es: 'Enterado que los datos pueden perderse en caso de daño severo' },
      },
      autorizacao_fotos: {
        label: { pt: 'Autorizo registro fotográfico do serviço', en: 'I authorize photographic documentation of service', es: 'Autorizo registro fotográfico del servicio' },
      },
    },
  },

  teste_final_celular: {
    title: { pt: 'Teste Final do Celular', en: 'Final Phone Test', es: 'Prueba Final del Celular' },
    description: {
      pt: 'Checklist final para garantir que tudo funciona.',
      en: 'Final checklist to ensure everything works.',
      es: 'Lista de verificación final para garantizar que todo funciona.',
    },
    items: {
      liga_normal: {
        label: { pt: 'Liga Normalmente', en: 'Turns On Normally', es: 'Enciende Normalmente' },
      },
      tela_touch_ok: {
        label: { pt: 'Tela/Touch OK', en: 'Screen/Touch OK', es: 'Pantalla/Táctil OK' },
      },
      cameras_ok: {
        label: { pt: 'Câmeras OK', en: 'Cameras OK', es: 'Cámaras OK' },
      },
      audio_ok: {
        label: { pt: 'Áudio OK (alto-falante/mic)', en: 'Audio OK (speaker/mic)', es: 'Audio OK (altavoz/mic)' },
      },
      carregamento_ok: {
        label: { pt: 'Carregamento OK', en: 'Charging OK', es: 'Carga OK' },
      },
      wifi_bluetooth_ok: {
        label: { pt: 'Wi-Fi/Bluetooth OK', en: 'Wi-Fi/Bluetooth OK', es: 'Wi-Fi/Bluetooth OK' },
      },
      sensores_ok: {
        label: { pt: 'Sensores OK', en: 'Sensors OK', es: 'Sensores OK' },
      },
      defeito_corrigido: {
        label: { pt: 'Defeito Original Corrigido', en: 'Original Issue Fixed', es: 'Defecto Original Corregido' },
      },
      foto_aparelho_final: {
        label: { pt: 'Foto do Aparelho (final)', en: 'Device Photo (final)', es: 'Foto del Dispositivo (final)' },
      },
      observacoes: {
        label: { pt: 'Observações', en: 'Notes', es: 'Observaciones' },
      },
    },
  },
};

module.exports = { SMARTPHONES_TRANSLATIONS };
