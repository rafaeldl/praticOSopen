const { initializeFirebase, admin } = require('./firebase-init');

// Inicializar Firebase (aceita caminho do service account como argumento)
try {
  initializeFirebase(process.argv[2]);
} catch (error) {
  process.exit(1);
}

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════
// DEFINIÇÃO DOS FORMULÁRIOS GLOBAIS POR SEGMENTO
// Path: /segments/{segmentId}/forms/{formId}
// ═══════════════════════════════════════════════════════════════════════════

const GLOBAL_FORMS = {
  // ═══════════════════════════════════════════════════════════
  // AUTOMOTIVO - Oficina Mecânica
  // ═══════════════════════════════════════════════════════════
  automotive: [
    {
      id: 'checklist_entrada_auto',
      title: 'Vistoria de Entrada (Veículo)',
      description: 'Checklist visual do estado do veículo na recepção.',
      isActive: true,
      items: [
        {
          id: 'lataria_fotos',
          label: 'Fotos da Lataria (Avarias)',
          type: 'photo_only',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'nivel_combustivel',
          label: 'Nível de Combustível',
          type: 'select',
          options: ['Reserva', '1/4', '1/2', '3/4', 'Cheio'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'luzes_painel',
          label: 'Luzes no Painel Acesas',
          type: 'checklist',
          options: ['Injeção', 'Freio ABS', 'Airbag', 'Bateria', 'Óleo', 'Motor', 'Temperatura'],
          required: false,
          allowPhotos: true,
        },
        {
          id: 'km_atual',
          label: 'Quilometragem Atual',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'pertences',
          label: 'Pertences no Veículo',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'revisao_basica',
      title: 'Checklist de Revisão Básica',
      description: 'Itens obrigatórios na troca de óleo e filtros.',
      isActive: true,
      items: [
        {
          id: 'oleo_motor',
          label: 'Óleo do Motor Trocado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'filtro_oleo',
          label: 'Filtro de Óleo Trocado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'filtro_ar',
          label: 'Filtro de Ar Verificado',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'filtro_cabine',
          label: 'Filtro de Cabine Verificado',
          type: 'boolean',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'nivel_liquidos',
          label: 'Verificação dos Níveis',
          type: 'checklist',
          options: ['Arrefecimento', 'Freio', 'Direção Hidráulica', 'Limpador'],
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'inspecao_freios',
      title: 'Inspeção do Sistema de Freios',
      description: 'Checklist completo do sistema de frenagem.',
      isActive: true,
      items: [
        {
          id: 'pastilhas_dianteiras',
          label: 'Estado das Pastilhas Dianteiras',
          type: 'select',
          options: ['Bom (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Trocar'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'pastilhas_traseiras',
          label: 'Estado das Pastilhas Traseiras',
          type: 'select',
          options: ['Bom (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Trocar'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'discos_dianteiros',
          label: 'Discos Dianteiros',
          type: 'select',
          options: ['OK', 'Empenado', 'Desgastado', 'Trocar'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'fluido_freio',
          label: 'Fluido de Freio',
          type: 'select',
          options: ['OK', 'Baixo', 'Contaminado', 'Trocar'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'freio_mao',
          label: 'Freio de Mão Funcionando',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'observacoes_freios',
          label: 'Observações',
          type: 'text',
          required: false,
          allowPhotos: true,
        },
      ],
    },
    {
      id: 'teste_rodagem',
      title: 'Teste de Rodagem',
      description: 'Checklist pós-serviço para validação em rodagem.',
      isActive: true,
      items: [
        {
          id: 'km_teste',
          label: 'Quilometragem do Teste',
          type: 'number',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'ruidos',
          label: 'Ruídos Identificados',
          type: 'checklist',
          options: ['Motor', 'Suspensão', 'Freios', 'Câmbio', 'Direção', 'Nenhum'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'vibracao',
          label: 'Vibração no Volante',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'freio_ok',
          label: 'Frenagem Normal',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'direcao_ok',
          label: 'Direção Alinhada',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'aprovado',
          label: 'Veículo Aprovado no Teste',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'entrega_veiculo',
      title: 'Entrega do Veículo',
      description: 'Checklist de conferência na entrega ao cliente.',
      isActive: true,
      items: [
        {
          id: 'veiculo_limpo',
          label: 'Veículo Lavado/Limpo',
          type: 'boolean',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'servicos_conferidos',
          label: 'Serviços Conferidos com Cliente',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'itens_devolvidos',
          label: 'Itens Devolvidos',
          type: 'checklist',
          options: ['Documentos', 'Chaves', 'Estepe', 'Triângulo', 'Macaco'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'foto_painel',
          label: 'Foto do Painel (km final)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'assinatura_cliente',
          label: 'Assinatura do Cliente',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
      ],
    },
  ],

  // ═══════════════════════════════════════════════════════════
  // HVAC - Ar Condicionado / Refrigeração
  // ═══════════════════════════════════════════════════════════
  hvac: [
    {
      id: 'laudo_instalacao',
      title: 'Laudo de Instalação',
      description: 'Registro fotográfico e técnico da instalação.',
      isActive: true,
      items: [
        {
          id: 'foto_evaporadora',
          label: 'Foto da Evaporadora (Interna)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'foto_condensadora',
          label: 'Foto da Condensadora (Externa)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'teste_dreno',
          label: 'Teste de Dreno Realizado?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'vacuo_sistema',
          label: 'Vácuo no Sistema Realizado?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pressao_gas',
          label: 'Pressão do Gás (PSI)',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'temp_saida',
          label: 'Temperatura de Saída (°C)',
          type: 'number',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'manutencao_preventiva',
      title: 'Manutenção Preventiva',
      description: 'Checklist de limpeza e verificação periódica.',
      isActive: true,
      items: [
        {
          id: 'filtros_limpos',
          label: 'Filtros Limpos/Trocados',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'evaporadora_limpa',
          label: 'Evaporadora Higienizada',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'condensadora_limpa',
          label: 'Condensadora Limpa',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'dreno_desobstruido',
          label: 'Dreno Desobstruído',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'bandeja_limpa',
          label: 'Bandeja de Drenagem Limpa',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'verificacao_eletrica',
          label: 'Verificação Elétrica',
          type: 'checklist',
          options: ['Disjuntor OK', 'Fiação OK', 'Conexões OK', 'Aterramento OK'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_funcionamento',
          label: 'Teste de Funcionamento OK',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_tecnico',
      title: 'Diagnóstico Técnico',
      description: 'Análise detalhada de problemas no equipamento.',
      isActive: true,
      items: [
        {
          id: 'sintoma_relatado',
          label: 'Sintoma Relatado pelo Cliente',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'equipamento_liga',
          label: 'Equipamento Liga?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'compressor_funciona',
          label: 'Compressor Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'nivel_gas',
          label: 'Nível de Gás',
          type: 'select',
          options: ['OK', 'Baixo', 'Zerado', 'Não verificado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'vazamento',
          label: 'Vazamento Detectado?',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'capacitor',
          label: 'Estado do Capacitor',
          type: 'select',
          options: ['OK', 'Fraco', 'Queimado', 'Não verificado'],
          required: false,
          allowPhotos: true,
        },
        {
          id: 'diagnostico_final',
          label: 'Diagnóstico Final',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'recarga_gas',
      title: 'Recarga de Gás',
      description: 'Registro de recarga de gás refrigerante.',
      isActive: true,
      items: [
        {
          id: 'tipo_gas',
          label: 'Tipo de Gás',
          type: 'select',
          options: ['R-22', 'R-410A', 'R-32', 'R-134a', 'R-404A', 'R-407C'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'quantidade_gas',
          label: 'Quantidade Utilizada (g)',
          type: 'number',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pressao_antes',
          label: 'Pressão Antes (PSI)',
          type: 'number',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pressao_depois',
          label: 'Pressão Depois (PSI)',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'temp_saida_final',
          label: 'Temperatura de Saída Final (°C)',
          type: 'number',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_vazamento',
          label: 'Teste de Vazamento Realizado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
      ],
    },
  ],

  // ═══════════════════════════════════════════════════════════
  // SMARTPHONES - Assistência Técnica - Celulares
  // ═══════════════════════════════════════════════════════════
  smartphones: [
    {
      id: 'checklist_entrada_cel',
      title: 'Checklist de Entrada (Celular)',
      description: 'Verificação inicial do estado do aparelho.',
      isActive: true,
      items: [
        {
          id: 'fotos_aparelho',
          label: 'Fotos do Aparelho (Frente/Verso)',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'tela_quebrada',
          label: 'Tela Quebrada/Trincada?',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'liga',
          label: 'Aparelho Liga?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'touch_funciona',
          label: 'Touch Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'biometria',
          label: 'Touch ID / Face ID Funciona?',
          type: 'select',
          options: ['Funciona', 'Não funciona', 'Não possui', 'Não testado'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'avarias_visiveis',
          label: 'Avarias Visíveis',
          type: 'checklist',
          options: ['Riscos na Tela', 'Amassados', 'Botões danificados', 'Câmera riscada', 'Nenhuma'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'senha_desbloqueio',
          label: 'Senha de Desbloqueio',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'acessorios',
          label: 'Acessórios Deixados',
          type: 'checklist',
          options: ['Carregador', 'Cabo', 'Capinha', 'Película', 'Caixa', 'Nenhum'],
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_cel',
      title: 'Diagnóstico Completo',
      description: 'Teste de todas as funcionalidades do aparelho.',
      isActive: true,
      items: [
        {
          id: 'teste_display',
          label: 'Display',
          type: 'select',
          options: ['OK', 'Manchas', 'Linhas', 'Não funciona'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'teste_touch',
          label: 'Touch',
          type: 'select',
          options: ['OK', 'Pontos mortos', 'Ghost touch', 'Não funciona'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_bateria',
          label: 'Saúde da Bateria (%)',
          type: 'number',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'teste_camera_traseira',
          label: 'Câmera Traseira',
          type: 'select',
          options: ['OK', 'Desfocada', 'Não funciona'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_camera_frontal',
          label: 'Câmera Frontal',
          type: 'select',
          options: ['OK', 'Desfocada', 'Não funciona'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_audio',
          label: 'Alto-falante / Microfone',
          type: 'select',
          options: ['OK', 'Baixo', 'Chiando', 'Não funciona'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_wifi',
          label: 'Wi-Fi',
          type: 'select',
          options: ['OK', 'Sinal fraco', 'Não conecta'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_bluetooth',
          label: 'Bluetooth',
          type: 'select',
          options: ['OK', 'Não encontra', 'Não pareia'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'teste_carregamento',
          label: 'Carregamento',
          type: 'select',
          options: ['OK', 'Lento', 'Só wireless', 'Não carrega'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_botoes',
          label: 'Botões Físicos',
          type: 'checklist',
          options: ['Power OK', 'Volume OK', 'Home OK', 'Mute OK'],
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'troca_tela',
      title: 'Troca de Tela',
      description: 'Checklist para serviço de troca de display.',
      isActive: true,
      items: [
        {
          id: 'tipo_tela',
          label: 'Tipo de Tela Instalada',
          type: 'select',
          options: ['Original', 'Compatível Premium', 'Compatível Standard'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'cola_aplicada',
          label: 'Cola/Vedação Aplicada',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_touch_pos',
          label: 'Teste de Touch Pós-Troca',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_true_tone',
          label: 'True Tone Funcionando (iOS)',
          type: 'select',
          options: ['Sim', 'Não', 'Não aplicável'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'teste_face_id',
          label: 'Face ID Funcionando (iOS)',
          type: 'select',
          options: ['Sim', 'Não', 'Não aplicável'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'foto_final',
          label: 'Foto do Aparelho Finalizado',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
      ],
    },
    {
      id: 'troca_bateria',
      title: 'Troca de Bateria',
      description: 'Checklist para substituição de bateria.',
      isActive: true,
      items: [
        {
          id: 'saude_antes',
          label: 'Saúde da Bateria Antes (%)',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'tipo_bateria',
          label: 'Tipo de Bateria',
          type: 'select',
          options: ['Original', 'Compatível Premium', 'Compatível Standard'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'vedacao_aplicada',
          label: 'Vedação/Adesivo Aplicado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'calibracao',
          label: 'Ciclo de Calibração Orientado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'saude_depois',
          label: 'Saúde da Bateria Nova (%)',
          type: 'number',
          required: true,
          allowPhotos: true,
        },
      ],
    },
  ],

  // ═══════════════════════════════════════════════════════════
  // COMPUTADORES - Informática
  // ═══════════════════════════════════════════════════════════
  computers: [
    {
      id: 'checklist_entrada_pc',
      title: 'Checklist de Entrada (PC)',
      description: 'Verificação inicial do estado do computador.',
      isActive: true,
      items: [
        {
          id: 'fotos_equipamento',
          label: 'Fotos do Equipamento',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'tipo_equipamento',
          label: 'Tipo',
          type: 'select',
          options: ['Desktop', 'Notebook', 'All-in-One', 'Monitor', 'Outro'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'liga',
          label: 'Equipamento Liga?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'tela_ok',
          label: 'Tela Funciona?',
          type: 'select',
          options: ['OK', 'Manchas', 'Linhas', 'Não funciona', 'N/A'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'avarias',
          label: 'Avarias Visíveis',
          type: 'checklist',
          options: ['Carcaça quebrada', 'Teclado danificado', 'Dobradiças', 'Portas danificadas', 'Nenhuma'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'acessorios',
          label: 'Acessórios Deixados',
          type: 'checklist',
          options: ['Carregador', 'Mouse', 'Teclado', 'Cabos', 'HD externo', 'Nenhum'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'senha',
          label: 'Senha de Acesso',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_hardware',
      title: 'Diagnóstico de Hardware',
      description: 'Teste completo de componentes de hardware.',
      isActive: true,
      items: [
        {
          id: 'teste_memoria',
          label: 'Memória RAM',
          type: 'select',
          options: ['OK', 'Erro detectado', 'Não reconhecida'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_hd',
          label: 'HD/SSD',
          type: 'select',
          options: ['OK', 'Setores ruins', 'Lento', 'Não detectado'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'saude_hd',
          label: 'Saúde do HD/SSD (%)',
          type: 'number',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'teste_fonte',
          label: 'Fonte de Alimentação',
          type: 'select',
          options: ['OK', 'Instável', 'Não funciona'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_placa_mae',
          label: 'Placa Mãe',
          type: 'select',
          options: ['OK', 'Capacitor estufado', 'Não liga', 'POST com erro'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'teste_cooler',
          label: 'Coolers/Ventilação',
          type: 'select',
          options: ['OK', 'Ruidoso', 'Parado', 'Não possui'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'temperatura',
          label: 'Temperatura CPU (°C)',
          type: 'number',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'diagnostico',
          label: 'Diagnóstico Final',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'formatacao',
      title: 'Formatação e Instalação de SO',
      description: 'Checklist de formatação e configuração.',
      isActive: true,
      items: [
        {
          id: 'backup_feito',
          label: 'Backup dos Dados Realizado',
          type: 'select',
          options: ['Sim', 'Não solicitado', 'Cliente recusou'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'sistema_instalado',
          label: 'Sistema Operacional Instalado',
          type: 'select',
          options: ['Windows 10', 'Windows 11', 'macOS', 'Linux', 'Outro'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'drivers_instalados',
          label: 'Drivers Instalados',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'atualizacoes',
          label: 'Atualizações do Sistema',
          type: 'select',
          options: ['Atualizadas', 'Parcial', 'Não atualizado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'programas_instalados',
          label: 'Programas Básicos Instalados',
          type: 'checklist',
          options: ['Navegador', 'Office', 'Antivírus', 'PDF Reader', 'Compactador'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'dados_restaurados',
          label: 'Dados Restaurados',
          type: 'select',
          options: ['Sim', 'Não tinha backup', 'Não solicitado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_geral',
          label: 'Teste Geral OK',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'limpeza_interna',
      title: 'Limpeza Interna',
      description: 'Checklist de limpeza e manutenção preventiva.',
      isActive: true,
      items: [
        {
          id: 'foto_antes',
          label: 'Foto Antes da Limpeza',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'limpeza_coolers',
          label: 'Coolers Limpos',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'limpeza_dissipador',
          label: 'Dissipador Limpo',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pasta_termica',
          label: 'Pasta Térmica Trocada',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'limpeza_geral',
          label: 'Limpeza Geral Interna',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'foto_depois',
          label: 'Foto Após a Limpeza',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'temp_antes',
          label: 'Temperatura Antes (°C)',
          type: 'number',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'temp_depois',
          label: 'Temperatura Depois (°C)',
          type: 'number',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'upgrade_hardware',
      title: 'Upgrade de Hardware',
      description: 'Registro de upgrades realizados.',
      isActive: true,
      items: [
        {
          id: 'componente_upgrade',
          label: 'Componente Alterado',
          type: 'checklist',
          options: ['Memória RAM', 'HD/SSD', 'Processador', 'Placa de Vídeo', 'Fonte', 'Outro'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'especificacao_antiga',
          label: 'Especificação Anterior',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'especificacao_nova',
          label: 'Especificação Nova',
          type: 'text',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'teste_stress',
          label: 'Teste de Stress Realizado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'sistema_reconhece',
          label: 'Sistema Reconhece Novo Hardware',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
      ],
    },
  ],

  // ═══════════════════════════════════════════════════════════
  // ELETRODOMÉSTICOS
  // ═══════════════════════════════════════════════════════════
  appliances: [
    {
      id: 'checklist_entrada_eletro',
      title: 'Checklist de Entrada (Eletrodoméstico)',
      description: 'Verificação inicial do estado do equipamento.',
      isActive: true,
      items: [
        {
          id: 'fotos_equipamento',
          label: 'Fotos do Equipamento',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'tipo_equipamento',
          label: 'Tipo de Equipamento',
          type: 'select',
          options: ['Geladeira', 'Máquina de Lavar', 'Micro-ondas', 'Fogão', 'Lava-louças', 'Outro'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'liga',
          label: 'Equipamento Liga?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'avarias_visiveis',
          label: 'Avarias Visíveis',
          type: 'checklist',
          options: ['Amassados', 'Ferrugem', 'Botões quebrados', 'Vidro trincado', 'Nenhuma'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'defeito_relatado',
          label: 'Defeito Relatado',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_geladeira',
      title: 'Diagnóstico de Geladeira/Freezer',
      description: 'Checklist de diagnóstico para refrigeradores.',
      isActive: true,
      items: [
        {
          id: 'compressor_funciona',
          label: 'Compressor Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'motor_ventilador',
          label: 'Motor Ventilador',
          type: 'select',
          options: ['OK', 'Ruidoso', 'Parado', 'Não possui'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'gas_ok',
          label: 'Gás Refrigerante OK',
          type: 'select',
          options: ['OK', 'Baixo', 'Zerado', 'Não verificado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'termostato',
          label: 'Termostato',
          type: 'select',
          options: ['OK', 'Defeituoso', 'Não testado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'borracha_porta',
          label: 'Borracha da Porta',
          type: 'select',
          options: ['OK', 'Ressecada', 'Rasgada', 'Solta'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'degelo',
          label: 'Sistema de Degelo',
          type: 'select',
          options: ['OK', 'Resistência queimada', 'Timer defeituoso', 'N/A'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'temperatura_interna',
          label: 'Temperatura Interna (°C)',
          type: 'number',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_maquina_lavar',
      title: 'Diagnóstico de Máquina de Lavar',
      description: 'Checklist de diagnóstico para lavadoras.',
      isActive: true,
      items: [
        {
          id: 'enche_agua',
          label: 'Enche Água Normalmente?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'drena_agua',
          label: 'Drena Água Normalmente?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'centrifuga',
          label: 'Centrifuga Normalmente?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'motor',
          label: 'Motor',
          type: 'select',
          options: ['OK', 'Ruidoso', 'Travado', 'Queimado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'bomba_drenagem',
          label: 'Bomba de Drenagem',
          type: 'select',
          options: ['OK', 'Entupida', 'Queimada'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'placa_eletronica',
          label: 'Placa Eletrônica',
          type: 'select',
          options: ['OK', 'Com defeito', 'Não testada'],
          required: true,
          allowPhotos: true,
        },
        {
          id: 'rolamentos',
          label: 'Rolamentos/Retentores',
          type: 'select',
          options: ['OK', 'Ruidoso', 'Vazando', 'Não verificado'],
          required: false,
          allowPhotos: false,
        },
        {
          id: 'vazamento',
          label: 'Vazamento Detectado?',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
      ],
    },
    {
      id: 'diagnostico_microondas',
      title: 'Diagnóstico de Micro-ondas',
      description: 'Checklist de diagnóstico para fornos micro-ondas.',
      isActive: true,
      items: [
        {
          id: 'painel_funciona',
          label: 'Painel Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'prato_gira',
          label: 'Prato Giratório Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'aquece',
          label: 'Aquece Normalmente?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'magnetron',
          label: 'Magnetron',
          type: 'select',
          options: ['OK', 'Fraco', 'Queimado', 'Não testado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'capacitor',
          label: 'Capacitor',
          type: 'select',
          options: ['OK', 'Descarregado', 'Queimado', 'Não testado'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'trava_porta',
          label: 'Trava da Porta',
          type: 'select',
          options: ['OK', 'Defeituosa', 'Quebrada'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'faz_barulho',
          label: 'Ruídos Anormais?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'entrega_eletro',
      title: 'Entrega do Eletrodoméstico',
      description: 'Checklist de conferência na entrega.',
      isActive: true,
      items: [
        {
          id: 'servico_executado',
          label: 'Serviço Executado',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'teste_final',
          label: 'Teste Final Realizado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'equipamento_limpo',
          label: 'Equipamento Limpo',
          type: 'boolean',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'pecas_trocadas',
          label: 'Peças Trocadas',
          type: 'text',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'orientacoes',
          label: 'Orientações ao Cliente',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'garantia',
          label: 'Garantia do Serviço',
          type: 'select',
          options: ['30 dias', '60 dias', '90 dias', 'Sem garantia'],
          required: true,
          allowPhotos: false,
        },
      ],
    },
  ],

  // ═══════════════════════════════════════════════════════════
  // OUTRO (Genérico)
  // ═══════════════════════════════════════════════════════════
  other: [
    {
      id: 'checklist_entrada_generico',
      title: 'Checklist de Entrada (Genérico)',
      description: 'Verificação inicial padrão.',
      isActive: true,
      items: [
        {
          id: 'fotos_item',
          label: 'Fotos do Item',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'descricao_item',
          label: 'Descrição do Item',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'funciona',
          label: 'Item Funciona?',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'avarias',
          label: 'Avarias Visíveis',
          type: 'text',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'defeito_relatado',
          label: 'Defeito Relatado',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'acessorios',
          label: 'Acessórios Deixados',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'diagnostico_generico',
      title: 'Diagnóstico Técnico',
      description: 'Análise técnica geral.',
      isActive: true,
      items: [
        {
          id: 'analise',
          label: 'Análise Realizada',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'problema_encontrado',
          label: 'Problema Identificado',
          type: 'text',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'solucao_proposta',
          label: 'Solução Proposta',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'fotos_diagnostico',
          label: 'Fotos do Diagnóstico',
          type: 'photo_only',
          required: false,
          allowPhotos: true,
        },
      ],
    },
    {
      id: 'laudo_servico',
      title: 'Laudo de Serviço',
      description: 'Registro do serviço executado.',
      isActive: true,
      items: [
        {
          id: 'servico_realizado',
          label: 'Serviço Realizado',
          type: 'text',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'pecas_utilizadas',
          label: 'Peças/Materiais Utilizados',
          type: 'text',
          required: false,
          allowPhotos: true,
        },
        {
          id: 'teste_final',
          label: 'Teste Final OK',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'fotos_servico',
          label: 'Fotos do Serviço',
          type: 'photo_only',
          required: true,
          allowPhotos: true,
        },
        {
          id: 'observacoes',
          label: 'Observações',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
      ],
    },
    {
      id: 'entrega_generico',
      title: 'Entrega ao Cliente',
      description: 'Checklist de entrega padrão.',
      isActive: true,
      items: [
        {
          id: 'item_conferido',
          label: 'Item Conferido com Cliente',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'funcionamento_ok',
          label: 'Funcionamento Demonstrado',
          type: 'boolean',
          required: true,
          allowPhotos: false,
        },
        {
          id: 'orientacoes',
          label: 'Orientações Passadas',
          type: 'text',
          required: false,
          allowPhotos: false,
        },
        {
          id: 'garantia',
          label: 'Prazo de Garantia',
          type: 'select',
          options: ['30 dias', '60 dias', '90 dias', 'Sem garantia'],
          required: true,
          allowPhotos: false,
        },
        {
          id: 'foto_entrega',
          label: 'Foto na Entrega',
          type: 'photo_only',
          required: false,
          allowPhotos: true,
        },
      ],
    },
  ],
};

// ═══════════════════════════════════════════════════════════════════════════
// FUNÇÃO DE SEED
// ═══════════════════════════════════════════════════════════════════════════

async function seedForms() {
  console.log('════════════════════════════════════════════════════════════');
  console.log('  POPULANDO FORMULÁRIOS GLOBAIS (SEGMENTOS)');
  console.log('  Path: /segments/{segmentId}/forms/{formId}');
  console.log('════════════════════════════════════════════════════════════\n');

  try {
    let created = 0;
    let updated = 0;
    let skipped = 0;

    for (const [segmentId, forms] of Object.entries(GLOBAL_FORMS)) {
      console.log(`\n📂 Processando segmento: ${segmentId}`);
      console.log(`   Formulários a processar: ${forms.length}`);

      const segmentRef = db.collection('segments').doc(segmentId);
      // Garante que o segmento existe (apenas check rápido)
      const segDoc = await segmentRef.get();
      if (!segDoc.exists) {
        console.log(`   ⚠️  Segmento ${segmentId} não encontrado. Pulando...`);
        skipped += forms.length;
        continue;
      }

      for (const form of forms) {
        const { id, ...data } = form;
        const formRef = segmentRef.collection('forms').doc(id);
        const formDoc = await formRef.get();

        if (formDoc.exists) {
          console.log(`   ↻ Atualizando: ${data.title}`);
          await formRef.set({
            ...data,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          updated++;
        } else {
          console.log(`   + Criando: ${data.title}`);
          await formRef.set({
            ...data,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          created++;
        }
      }
    }

    // Resumo final
    const totalForms = Object.values(GLOBAL_FORMS).reduce((acc, forms) => acc + forms.length, 0);

    console.log('\n════════════════════════════════════════════════════════════');
    console.log('  ✅ SEED DE FORMULÁRIOS CONCLUÍDO!');
    console.log('════════════════════════════════════════════════════════════');
    console.log(`  • Total de formulários definidos: ${totalForms}`);
    console.log(`  • Criados: ${created}`);
    console.log(`  • Atualizados: ${updated}`);
    console.log(`  • Pulados (segmento inexistente): ${skipped}`);
    console.log('════════════════════════════════════════════════════════════');
    console.log('\n📋 Resumo por segmento:');
    for (const [segmentId, forms] of Object.entries(GLOBAL_FORMS)) {
      console.log(`   • ${segmentId}: ${forms.length} formulários`);
    }
    console.log('════════════════════════════════════════════════════════════\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Erro ao popular formulários:', error);
    process.exit(1);
  }
}

seedForms();
