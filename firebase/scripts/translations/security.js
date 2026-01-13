// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - SEGURANÇA ELETRÔNICA
// ═══════════════════════════════════════════════════════════════════════════

const SECURITY_TRANSLATIONS = {
  vistoria_pre_instalacao_seguranca: {
    title: { pt: 'Vistoria Pré-Instalação', en: 'Pre-Installation Survey', es: 'Inspección Pre-Instalación' },
    description: {
      pt: 'Avalia local, energia e pontos de instalação.',
      en: 'Evaluates location, power and installation points.',
      es: 'Evalúa local, energía y puntos de instalación.',
    },
    items: {
      tipo_sistema: {
        label: { pt: 'Tipo de sistema', en: 'System Type', es: 'Tipo de sistema' },
        options: {
          pt: ['CFTV', 'Alarme', 'Controle de acesso', 'Interfonia', 'Outro'],
          en: ['CCTV', 'Alarm', 'Access Control', 'Intercom', 'Other'],
          es: ['CCTV', 'Alarma', 'Control de acceso', 'Intercomunicador', 'Otro'],
        },
      },
      internet_disponivel: {
        label: { pt: 'Internet disponível no local', en: 'Internet available at location', es: 'Internet disponible en el local' },
        options: {
          pt: ['Sim', 'Não', 'Parcial'],
          en: ['Yes', 'No', 'Partial'],
          es: ['Sí', 'No', 'Parcial'],
        },
      },
      energia_local: {
        label: { pt: 'Pontos de energia disponíveis', en: 'Power points available', es: 'Puntos de energía disponibles' },
        options: {
          pt: ['OK', 'Insuficiente', 'Não avaliado'],
          en: ['OK', 'Insufficient', 'Not evaluated'],
          es: ['OK', 'Insuficiente', 'No evaluado'],
        },
      },
      pontos_instalacao: { label: { pt: 'Pontos de instalação (resumo)', en: 'Installation points (summary)', es: 'Puntos de instalación (resumen)' } },
      foto_local: { label: { pt: 'Fotos do local/pontos', en: 'Photos of location/points', es: 'Fotos del local/puntos' } },
    },
  },

  comissionamento_seguranca: {
    title: { pt: 'Comissionamento do Sistema', en: 'System Commissioning', es: 'Comisionamiento del Sistema' },
    description: {
      pt: 'Testes finais e acesso remoto configurado.',
      en: 'Final tests and remote access configured.',
      es: 'Pruebas finales y acceso remoto configurado.',
    },
    items: {
      gravacao_ok: {
        label: { pt: 'Gravação/armazenamento funcionando (CFTV)', en: 'Recording/storage working (CCTV)', es: 'Grabación/almacenamiento funcionando (CCTV)' },
        options: {
          pt: ['OK', 'Falha', 'Não aplicável'],
          en: ['OK', 'Failure', 'Not applicable'],
          es: ['OK', 'Falla', 'No aplicable'],
        },
      },
      acesso_remoto: {
        label: { pt: 'Acesso remoto configurado', en: 'Remote access configured', es: 'Acceso remoto configurado' },
        options: {
          pt: ['OK', 'Não solicitado', 'Falha'],
          en: ['OK', 'Not requested', 'Failure'],
          es: ['OK', 'No solicitado', 'Falla'],
        },
      },
      senhas_alteradas: { label: { pt: 'Senhas padrão alteradas', en: 'Default passwords changed', es: 'Contraseñas predeterminadas cambiadas' } },
      testes: {
        label: { pt: 'Testes realizados', en: 'Tests performed', es: 'Pruebas realizadas' },
        options: {
          pt: ['Visualização ao vivo', 'Playback', 'Notificações', 'Sirene/Sensor', 'Zona/Partição', 'N/A'],
          en: ['Live view', 'Playback', 'Notifications', 'Siren/Sensor', 'Zone/Partition', 'N/A'],
          es: ['Visualización en vivo', 'Reproducción', 'Notificaciones', 'Sirena/Sensor', 'Zona/Partición', 'N/A'],
        },
      },
      foto_app: { label: { pt: 'Foto do app/configuração (evidência)', en: 'App/configuration photo (evidence)', es: 'Foto de la app/configuración (evidencia)' } },
    },
  },

  termo_privacidade_seguranca: {
    title: { pt: 'Autorização e Privacidade (Segurança)', en: 'Authorization and Privacy (Security)', es: 'Autorización y Privacidad (Seguridad)' },
    description: {
      pt: 'Registra credenciais, acesso remoto e responsabilidades.',
      en: 'Records credentials, remote access and responsibilities.',
      es: 'Registra credenciales, acceso remoto y responsabilidades.',
    },
    items: {
      responsavel_cliente: { label: { pt: 'Responsável do cliente (nome)', en: 'Customer responsible (name)', es: 'Responsable del cliente (nombre)' } },
      ciencia_senhas: { label: { pt: 'Ciente que senhas devem ser guardadas pelo cliente', en: 'Aware that passwords must be kept by customer', es: 'Enterado que las contraseñas deben ser guardadas por el cliente' } },
      ciencia_gravacao: { label: { pt: 'Ciente sobre uso/gravação e obrigações legais', en: 'Aware about use/recording and legal obligations', es: 'Enterado sobre uso/grabación y obligaciones legales' } },
    },
  },
};

module.exports = { SECURITY_TRANSLATIONS };
