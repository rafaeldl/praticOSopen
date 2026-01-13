// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - COMPUTADORES (Assistência Técnica de PCs/Notebooks)
// ═══════════════════════════════════════════════════════════════════════════

const COMPUTERS_TRANSLATIONS = {
  checklist_entrada_computador: {
    title: { pt: 'Entrada do Computador', en: 'Computer Check-in', es: 'Entrada del Computador' },
    description: {
      pt: 'Registra o estado inicial e os acessórios recebidos.',
      en: 'Records initial condition and received accessories.',
      es: 'Registra el estado inicial y los accesorios recibidos.',
    },
    items: {
      tipo_equipamento: {
        label: { pt: 'Tipo de Equipamento', en: 'Equipment Type', es: 'Tipo de Equipo' },
        options: {
          pt: ['Notebook', 'Desktop', 'All-in-One', 'Mac'],
          en: ['Laptop', 'Desktop', 'All-in-One', 'Mac'],
          es: ['Notebook', 'Desktop', 'All-in-One', 'Mac'],
        },
      },
      marca_modelo: { label: { pt: 'Marca/Modelo', en: 'Brand/Model', es: 'Marca/Modelo' } },
      serial_number: { label: { pt: 'Número de Série', en: 'Serial Number', es: 'Número de Serie' } },
      foto_equipamento: { label: { pt: 'Foto do Equipamento', en: 'Equipment Photo', es: 'Foto del Equipo' } },
      estado_fisico: {
        label: { pt: 'Estado Físico', en: 'Physical Condition', es: 'Estado Físico' },
        options: {
          pt: ['Bom', 'Riscos leves', 'Amassados', 'Quebrado'],
          en: ['Good', 'Light scratches', 'Dents', 'Broken'],
          es: ['Bueno', 'Rayones leves', 'Abolladuras', 'Roto'],
        },
      },
      acessorios_recebidos: {
        label: { pt: 'Acessórios Recebidos', en: 'Accessories Received', es: 'Accesorios Recibidos' },
        options: {
          pt: ['Carregador', 'Mouse', 'Teclado', 'Cabo de força', 'Bolsa', 'Nenhum'],
          en: ['Charger', 'Mouse', 'Keyboard', 'Power cable', 'Bag', 'None'],
          es: ['Cargador', 'Mouse', 'Teclado', 'Cable de poder', 'Bolsa', 'Ninguno'],
        },
      },
      senha_sistema: { label: { pt: 'Senha do Sistema (se houver)', en: 'System Password (if any)', es: 'Contraseña del Sistema (si hay)' } },
      defeito_relatado: { label: { pt: 'Defeito Relatado', en: 'Reported Issue', es: 'Defecto Reportado' } },
    },
  },

  diagnostico_hardware: {
    title: { pt: 'Diagnóstico de Hardware', en: 'Hardware Diagnosis', es: 'Diagnóstico de Hardware' },
    description: {
      pt: 'Testa componentes para identificar o defeito.',
      en: 'Tests components to identify the defect.',
      es: 'Prueba componentes para identificar el defecto.',
    },
    items: {
      liga: {
        label: { pt: 'Equipamento Liga', en: 'Equipment Turns On', es: 'Equipo Enciende' },
        options: { pt: ['Sim', 'Não', 'Intermitente'], en: ['Yes', 'No', 'Intermittent'], es: ['Sí', 'No', 'Intermitente'] },
      },
      tela_video: {
        label: { pt: 'Tela/Vídeo', en: 'Screen/Video', es: 'Pantalla/Video' },
        options: {
          pt: ['OK', 'Manchas', 'Linhas', 'Não exibe', 'Tela quebrada'],
          en: ['OK', 'Spots', 'Lines', 'No display', 'Broken screen'],
          es: ['OK', 'Manchas', 'Líneas', 'No muestra', 'Pantalla rota'],
        },
      },
      teclado: {
        label: { pt: 'Teclado', en: 'Keyboard', es: 'Teclado' },
        options: { pt: ['OK', 'Teclas falhando', 'Não funciona'], en: ['OK', 'Keys failing', 'Does not work'], es: ['OK', 'Teclas fallando', 'No funciona'] },
      },
      touchpad: {
        label: { pt: 'Touchpad/Mouse', en: 'Touchpad/Mouse', es: 'Touchpad/Mouse' },
        options: { pt: ['OK', 'Falha parcial', 'Não funciona', 'N/A'], en: ['OK', 'Partial failure', 'Does not work', 'N/A'], es: ['OK', 'Falla parcial', 'No funciona', 'N/A'] },
      },
      hd_ssd: {
        label: { pt: 'HD/SSD', en: 'HDD/SSD', es: 'HD/SSD' },
        options: {
          pt: ['OK', 'Setores defeituosos', 'Não reconhecido', 'Barulho anormal'],
          en: ['OK', 'Bad sectors', 'Not recognized', 'Abnormal noise'],
          es: ['OK', 'Sectores defectuosos', 'No reconocido', 'Ruido anormal'],
        },
      },
      memoria_ram: {
        label: { pt: 'Memória RAM', en: 'RAM Memory', es: 'Memoria RAM' },
        options: { pt: ['OK', 'Teste com falhas', 'Slot defeituoso'], en: ['OK', 'Test failed', 'Defective slot'], es: ['OK', 'Prueba con fallas', 'Slot defectuoso'] },
      },
      bateria_note: {
        label: { pt: 'Bateria (Notebook)', en: 'Battery (Laptop)', es: 'Batería (Notebook)' },
        options: { pt: ['OK', 'Viciada', 'Estufada', 'Não carrega', 'N/A'], en: ['OK', 'Degraded', 'Swollen', 'Does not charge', 'N/A'], es: ['OK', 'Viciada', 'Hinchada', 'No carga', 'N/A'] },
      },
      usb_portas: {
        label: { pt: 'Portas USB', en: 'USB Ports', es: 'Puertos USB' },
        options: { pt: ['Todas OK', 'Algumas com falha', 'Nenhuma funciona'], en: ['All OK', 'Some failing', 'None working'], es: ['Todas OK', 'Algunas con falla', 'Ninguna funciona'] },
      },
      diagnostico_final: { label: { pt: 'Diagnóstico Final', en: 'Final Diagnosis', es: 'Diagnóstico Final' } },
    },
  },

  formatacao_instalacao: {
    title: { pt: 'Formatação e Instalação do Sistema', en: 'Format and OS Installation', es: 'Formateo e Instalación del Sistema' },
    description: {
      pt: 'Registra backup, instalação e configurações básicas.',
      en: 'Records backup, installation and basic settings.',
      es: 'Registra respaldo, instalación y configuraciones básicas.',
    },
    items: {
      backup_realizado: {
        label: { pt: 'Backup Realizado', en: 'Backup Completed', es: 'Respaldo Realizado' },
        options: { pt: ['Sim', 'Não necessário', 'Cliente dispensou'], en: ['Yes', 'Not necessary', 'Customer declined'], es: ['Sí', 'No necesario', 'Cliente declinó'] },
      },
      sistema_instalado: {
        label: { pt: 'Sistema Instalado', en: 'OS Installed', es: 'Sistema Instalado' },
        options: { pt: ['Windows 10', 'Windows 11', 'Linux', 'macOS', 'Outro'], en: ['Windows 10', 'Windows 11', 'Linux', 'macOS', 'Other'], es: ['Windows 10', 'Windows 11', 'Linux', 'macOS', 'Otro'] },
      },
      drivers_instalados: { label: { pt: 'Drivers Instalados', en: 'Drivers Installed', es: 'Drivers Instalados' } },
      programas_basicos: {
        label: { pt: 'Programas Básicos Instalados', en: 'Basic Programs Installed', es: 'Programas Básicos Instalados' },
        options: { pt: ['Navegador', 'Antivírus', 'Office', 'PDF Reader', 'Compactador'], en: ['Browser', 'Antivirus', 'Office', 'PDF Reader', 'Archiver'], es: ['Navegador', 'Antivirus', 'Office', 'Lector PDF', 'Compresor'] },
      },
      atualizacoes_ok: { label: { pt: 'Atualizações do Sistema OK', en: 'System Updates OK', es: 'Actualizaciones del Sistema OK' } },
      dados_restaurados: {
        label: { pt: 'Dados do Cliente Restaurados', en: 'Customer Data Restored', es: 'Datos del Cliente Restaurados' },
        options: { pt: ['Sim', 'Não necessário', 'Parcialmente'], en: ['Yes', 'Not necessary', 'Partially'], es: ['Sí', 'No necesario', 'Parcialmente'] },
      },
    },
  },

  limpeza_interna: {
    title: { pt: 'Limpeza Interna', en: 'Internal Cleaning', es: 'Limpieza Interna' },
    description: {
      pt: 'Checklist de limpeza e troca de pasta térmica.',
      en: 'Cleaning checklist and thermal paste replacement.',
      es: 'Lista de limpieza y cambio de pasta térmica.',
    },
    items: {
      foto_antes: { label: { pt: 'Foto Antes da Limpeza', en: 'Photo Before Cleaning', es: 'Foto Antes de Limpieza' } },
      cooler_limpo: { label: { pt: 'Cooler/Ventoinha Limpo', en: 'Fan/Cooler Cleaned', es: 'Cooler/Ventilador Limpio' } },
      dissipador_limpo: { label: { pt: 'Dissipador de Calor Limpo', en: 'Heatsink Cleaned', es: 'Disipador de Calor Limpio' } },
      pasta_termica: {
        label: { pt: 'Pasta Térmica Aplicada', en: 'Thermal Paste Applied', es: 'Pasta Térmica Aplicada' },
        options: { pt: ['Nova aplicada', 'Mantida', 'N/A'], en: ['New applied', 'Kept', 'N/A'], es: ['Nueva aplicada', 'Mantenida', 'N/A'] },
      },
      interior_limpo: { label: { pt: 'Interior Geral Limpo', en: 'General Interior Cleaned', es: 'Interior General Limpio' } },
      foto_depois: { label: { pt: 'Foto Após a Limpeza', en: 'Photo After Cleaning', es: 'Foto Después de Limpieza' } },
      temp_antes: { label: { pt: 'Temperatura Antes (°C)', en: 'Temperature Before (°C)', es: 'Temperatura Antes (°C)' } },
      temp_depois: { label: { pt: 'Temperatura Depois (°C)', en: 'Temperature After (°C)', es: 'Temperatura Después (°C)' } },
    },
  },

  upgrade_hardware: {
    title: { pt: 'Upgrade de Hardware', en: 'Hardware Upgrade', es: 'Upgrade de Hardware' },
    description: {
      pt: 'Registra componentes trocados e testes realizados.',
      en: 'Records replaced components and tests performed.',
      es: 'Registra componentes cambiados y pruebas realizadas.',
    },
    items: {
      componente_upgrade: {
        label: { pt: 'Componente do Upgrade', en: 'Upgrade Component', es: 'Componente del Upgrade' },
        options: { pt: ['RAM', 'SSD', 'HD', 'Placa de Vídeo', 'Processador', 'Fonte', 'Outro'], en: ['RAM', 'SSD', 'HDD', 'Graphics Card', 'Processor', 'PSU', 'Other'], es: ['RAM', 'SSD', 'HD', 'Tarjeta de Video', 'Procesador', 'Fuente', 'Otro'] },
      },
      especificacao_nova: { label: { pt: 'Especificação do Novo Componente', en: 'New Component Specification', es: 'Especificación del Nuevo Componente' } },
      componente_reconhecido: { label: { pt: 'Componente Reconhecido pelo Sistema', en: 'Component Recognized by System', es: 'Componente Reconocido por el Sistema' } },
      teste_stress: { label: { pt: 'Teste de Stress Realizado', en: 'Stress Test Performed', es: 'Prueba de Stress Realizada' } },
      foto_upgrade: { label: { pt: 'Foto do Upgrade Instalado', en: 'Photo of Installed Upgrade', es: 'Foto del Upgrade Instalado' } },
    },
  },

  termo_privacidade_computador: {
    title: { pt: 'Privacidade e Backup (Computador)', en: 'Privacy and Backup (Computer)', es: 'Privacidad y Respaldo (Computador)' },
    description: {
      pt: 'Autoriza acesso a dados e testes quando necessário.',
      en: 'Authorizes data access and tests when necessary.',
      es: 'Autoriza acceso a datos y pruebas cuando sea necesario.',
    },
    items: {
      autorizacao_acesso: { label: { pt: 'Autorizo acesso ao sistema para diagnóstico', en: 'I authorize system access for diagnosis', es: 'Autorizo acceso al sistema para diagnóstico' } },
      ciencia_backup: { label: { pt: 'Ciente que backup é responsabilidade do cliente', en: 'Aware that backup is customer responsibility', es: 'Enterado que el respaldo es responsabilidad del cliente' } },
      ciencia_formatacao: { label: { pt: 'Ciente que formatação apaga todos os dados', en: 'Aware that formatting erases all data', es: 'Enterado que el formateo borra todos los datos' } },
    },
  },

  qualidade_entrega_computador: {
    title: { pt: 'Qualidade na Entrega (Computador)', en: 'Delivery Quality (Computer)', es: 'Calidad en la Entrega (Computador)' },
    description: {
      pt: 'Verificações finais antes de entregar o equipamento.',
      en: 'Final checks before delivering the equipment.',
      es: 'Verificaciones finales antes de entregar el equipo.',
    },
    items: {
      sistema_funcionando: { label: { pt: 'Sistema Operacional Funcionando', en: 'Operating System Working', es: 'Sistema Operativo Funcionando' } },
      defeito_corrigido: { label: { pt: 'Defeito Original Corrigido', en: 'Original Issue Fixed', es: 'Defecto Original Corregido' } },
      hardware_ok: { label: { pt: 'Hardware Testado e OK', en: 'Hardware Tested and OK', es: 'Hardware Probado y OK' } },
      acessorios_devolvidos: { label: { pt: 'Acessórios Devolvidos', en: 'Accessories Returned', es: 'Accesorios Devueltos' } },
      equipamento_limpo: { label: { pt: 'Equipamento Limpo Externamente', en: 'Equipment Externally Cleaned', es: 'Equipo Limpio Externamente' } },
      cliente_orientado: { label: { pt: 'Cliente Orientado sobre o Serviço', en: 'Customer Informed about Service', es: 'Cliente Orientado sobre el Servicio' } },
      foto_entrega: { label: { pt: 'Foto na Entrega', en: 'Delivery Photo', es: 'Foto en la Entrega' } },
    },
  },
};

module.exports = { COMPUTERS_TRANSLATIONS };
