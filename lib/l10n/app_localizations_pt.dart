// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get home => 'Início';

  @override
  String get orders => 'Ordens de Serviço';

  @override
  String get customers => 'Clientes';

  @override
  String get devices => 'Equipamentos';

  @override
  String get services => 'Serviços';

  @override
  String get products => 'Produtos';

  @override
  String get reports => 'Relatórios';

  @override
  String get settings => 'Configurações';

  @override
  String get profile => 'Perfil';

  @override
  String get company => 'Empresa';

  @override
  String get team => 'Equipe';

  @override
  String get collaborators => 'Colaboradores';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Excluir';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Adicionar';

  @override
  String get create => 'Criar';

  @override
  String get update => 'Atualizar';

  @override
  String get search => 'Buscar';

  @override
  String get searchOrAddNew => 'Buscar ou adicionar novo';

  @override
  String get filter => 'Filtrar';

  @override
  String get sort => 'Ordenar';

  @override
  String get refresh => 'Atualizar';

  @override
  String get close => 'Fechar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get back => 'Voltar';

  @override
  String get next => 'Próximo';

  @override
  String get previous => 'Anterior';

  @override
  String get done => 'Concluído';

  @override
  String get finish => 'Finalizar';

  @override
  String get loading => 'Carregando...';

  @override
  String get send => 'Enviar';

  @override
  String get share => 'Compartilhar';

  @override
  String get copy => 'Copiar';

  @override
  String get print => 'Imprimir';

  @override
  String get preview => 'Visualizar';

  @override
  String get export => 'Exportar';

  @override
  String get import => 'Importar';

  @override
  String get select => 'Selecionar';

  @override
  String get selectAll => 'Selecionar Tudo';

  @override
  String get clear => 'Limpar';

  @override
  String get reset => 'Redefinir';

  @override
  String get apply => 'Aplicar';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get more => 'Mais';

  @override
  String get less => 'Menos';

  @override
  String get details => 'Detalhes';

  @override
  String get options => 'Opções';

  @override
  String get actions => 'Ações';

  @override
  String get status => 'Status';

  @override
  String get statusPending => 'Pendente';

  @override
  String get statusApproved => 'Aprovado';

  @override
  String get statusInProgress => 'Em Andamento';

  @override
  String get statusCompleted => 'Concluído';

  @override
  String get statusCancelled => 'Cancelado';

  @override
  String get statusQuote => 'Orçamento';

  @override
  String get payments => 'Pagamentos';

  @override
  String get payment => 'Pagamento';

  @override
  String get paid => 'Pago';

  @override
  String get unpaid => 'Não Pago';

  @override
  String get toReceive => 'Falta receber';

  @override
  String get received => 'Recebido';

  @override
  String get pix => 'PIX';

  @override
  String get check => 'Cheque';

  @override
  String get installments => 'Parcelas';

  @override
  String get installment => 'Parcela';

  @override
  String get dueDate => 'Vencimento';

  @override
  String get paymentCannotExceedBalance =>
      'Pagamento não pode ser maior que o saldo';

  @override
  String get discountCannotExceedBalance =>
      'Desconto não pode ser maior que o saldo';

  @override
  String get asaasTransactionCannotBeRemoved =>
      'Pagamentos recebidos pelo Asaas não podem ser removidos aqui. Para desfazer, estorne a cobrança no Asaas.';

  @override
  String get paymentUpdateFailed =>
      'Não foi possível salvar o pagamento. Verifique sua conexão e tente novamente.';

  @override
  String get paymentRequiresConnection =>
      'Sem conexão. Tente de novo quando estiver online.';

  @override
  String get history => 'Histórico';

  @override
  String get valueMustBeGreaterThanZero => 'O valor deve ser maior que zero';

  @override
  String confirmRemoveTransaction(String type, String amount) {
    return 'Deseja remover este $type de $amount?';
  }

  @override
  String get invalidEmail => 'Email inválido';

  @override
  String get invalidPhone => 'Telefone inválido';

  @override
  String get invalidFormat => 'Formato inválido';

  @override
  String get minimum => 'Mínimo';

  @override
  String get maximum => 'Máximo';

  @override
  String get characters => 'caracteres';

  @override
  String get noValuesRegistered => 'Nenhum valor cadastrado';

  @override
  String get typeAboveToAdd => 'Digite no campo acima para adicionar';

  @override
  String minLength(int count) {
    return 'Mínimo de $count caracteres';
  }

  @override
  String maxLength(int count) {
    return 'Máximo de $count caracteres';
  }

  @override
  String get takePhoto => 'Tirar Foto';

  @override
  String get chooseFromGallery => 'Escolher da Galeria';

  @override
  String get changePhoto => 'Alterar Foto';

  @override
  String get removePhoto => 'Remover Foto';

  @override
  String get addPhoto => 'Adicionar Foto';

  @override
  String get photos => 'fotos';

  @override
  String get photo => 'Foto';

  @override
  String get camera => 'Câmera';

  @override
  String get gallery => 'Galeria';

  @override
  String get today => 'Hoje';

  @override
  String get yesterday => 'Ontem';

  @override
  String get tomorrow => 'Amanhã';

  @override
  String get scheduledDate => 'Agendado';

  @override
  String get updatedAt => 'Atualizado em';

  @override
  String get date => 'Data';

  @override
  String get time => 'Hora';

  @override
  String get startDate => 'Data de início';

  @override
  String get endDate => 'Data de término';

  @override
  String get period => 'Período';

  @override
  String get confirmDelete => 'Confirmar Exclusão';

  @override
  String confirmDeleteMessageNamed(String name) {
    return 'Deseja realmente excluir \"$name\"?';
  }

  @override
  String get confirmAction => 'Confirmar Ação';

  @override
  String get cannotUndo => 'Esta ação não pode ser desfeita.';

  @override
  String get discard => 'Descartar';

  @override
  String get leave => 'Sair';

  @override
  String get stay => 'Ficar';

  @override
  String get customer => 'Cliente';

  @override
  String get newCustomer => 'Novo cliente';

  @override
  String get editCustomer => 'Editar cliente';

  @override
  String get customerName => 'Nome do Cliente';

  @override
  String get customerList => 'Lista de Clientes';

  @override
  String get addCustomer => 'Adicionar Cliente';

  @override
  String get name => 'Nome';

  @override
  String get fullName => 'Nome Completo';

  @override
  String get phone => 'Telefone';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get email => 'E-mail';

  @override
  String get address => 'Endereço';

  @override
  String get number => 'Número';

  @override
  String get city => 'Cidade';

  @override
  String get state => 'Estado';

  @override
  String get country => 'País';

  @override
  String get notes => 'Observações';

  @override
  String get observation => 'Observação';

  @override
  String get description => 'Descrição';

  @override
  String get comments => 'Comentários';

  @override
  String get document => 'Documento';

  @override
  String get cpfCnpj => 'CPF/CNPJ';

  @override
  String get order => 'Ordem de Serviço';

  @override
  String get orderShort => 'OS';

  @override
  String get orderOverdue => 'Atrasada';

  @override
  String get newOrder => 'NOVA';

  @override
  String get orderNumber => 'Número da OS';

  @override
  String get orderList => 'Lista de OS';

  @override
  String get addOrder => 'Adicionar OS';

  @override
  String get createOrder => 'Criar OS';

  @override
  String get technician => 'Técnico';

  @override
  String get technicians => 'Técnicos';

  @override
  String get problem => 'Problema Relatado';

  @override
  String get warranty => 'Garantia';

  @override
  String get priority => 'Prioridade';

  @override
  String get device => 'Equipamento';

  @override
  String get deviceCategory => 'Categoria';

  @override
  String get editDevice => 'Editar Equipamento';

  @override
  String get deviceList => 'Lista de Equipamentos';

  @override
  String get addDevice => 'Adicionar Equipamento';

  @override
  String get brand => 'Marca';

  @override
  String get model => 'Modelo';

  @override
  String get serialNumber => 'Número de Série';

  @override
  String get color => 'Cor';

  @override
  String get condition => 'Condição';

  @override
  String get defects => 'Defeitos';

  @override
  String get service => 'Serviço';

  @override
  String get editService => 'Editar Serviço';

  @override
  String get serviceList => 'Lista de Serviços';

  @override
  String get searchService => 'Buscar Serviço';

  @override
  String get addService => 'Adicionar Serviço';

  @override
  String get product => 'Produto';

  @override
  String get editProduct => 'Editar Produto';

  @override
  String get productList => 'Lista de Produtos';

  @override
  String get searchProduct => 'Buscar Produto';

  @override
  String get addProduct => 'Adicionar Produto';

  @override
  String get barcode => 'Código de Barras';

  @override
  String get unit => 'Unidade';

  @override
  String get category => 'Categoria';

  @override
  String get categories => 'Categorias';

  @override
  String get total => 'Total';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Desconto';

  @override
  String get discountValue => 'Valor do Desconto';

  @override
  String get price => 'Preço';

  @override
  String get quantity => 'Quantidade';

  @override
  String get value => 'Valor';

  @override
  String get amount => 'Valor';

  @override
  String get tax => 'Imposto';

  @override
  String get balance => 'Saldo';

  @override
  String get totalPaid => 'Total Pago';

  @override
  String get remaining => 'Restante';

  @override
  String get change => 'Troco';

  @override
  String get errorOccurred => 'Ocorreu um erro';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get noInternetConnection => 'Sem conexão com a internet';

  @override
  String get permissionDenied => 'Permissão negada';

  @override
  String get timeout => 'Tempo esgotado';

  @override
  String get login => 'Entrar';

  @override
  String get logout => 'Sair';

  @override
  String get logoutConfirm => 'Deseja realmente sair?';

  @override
  String get signIn => 'Entrar';

  @override
  String get password => 'Senha';

  @override
  String get emailSent => 'E-mail enviado';

  @override
  String get continueWithGoogle => 'Continuar com Google';

  @override
  String get continueWithApple => 'Continuar com Apple';

  @override
  String get termsAndConditions => 'Termos e Condições';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get companyName => 'Nome da Empresa';

  @override
  String get skip => 'Pular';

  @override
  String get continue_ => 'Continuar';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar Idioma';

  @override
  String get english => 'Inglês';

  @override
  String get theme => 'Tema';

  @override
  String get notifications => 'Notificações';

  @override
  String get markAllAsRead => 'Marcar todas';

  @override
  String get sound => 'Som';

  @override
  String get about => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get support => 'Suporte';

  @override
  String get dashboard => 'Painel';

  @override
  String get analytics => 'Análises';

  @override
  String get revenue => 'Receita';

  @override
  String get recentOrders => 'OS recentes';

  @override
  String get role => 'Função';

  @override
  String get noRole => 'Sem perfil';

  @override
  String get roles => 'Funções';

  @override
  String get owner => 'Proprietário';

  @override
  String get admin => 'Administrador';

  @override
  String get manager => 'Gerente';

  @override
  String get viewer => 'Visualizador';

  @override
  String get permissions => 'Permissões';

  @override
  String get canCreate => 'Pode Criar';

  @override
  String get canEdit => 'Pode Editar';

  @override
  String get canDelete => 'Pode Excluir';

  @override
  String get canView => 'Pode Visualizar';

  @override
  String get checklist => 'Checklist';

  @override
  String get checklists => 'Checklists';

  @override
  String get customerSignature => 'Assinatura do Cliente';

  @override
  String get required => 'Obrigatório';

  @override
  String get optional => 'Opcional';

  @override
  String get complete => 'Concluir';

  @override
  String get answered => 'Respondido';

  @override
  String get notAnswered => 'Não Respondido';

  @override
  String get quote => 'Orçamento';

  @override
  String get quotes => 'Orçamentos';

  @override
  String expiresIn(int days) {
    return 'Expira em $days dias';
  }

  @override
  String get expired => 'Expirado';

  @override
  String get inactive => 'Inativo';

  @override
  String get enabled => 'Habilitado';

  @override
  String get disabled => 'Desabilitado';

  @override
  String get visible => 'Visível';

  @override
  String get hidden => 'Oculto';

  @override
  String get public => 'Público';

  @override
  String get private => 'Privado';

  @override
  String get draft => 'Rascunho';

  @override
  String get deleted => 'Excluído';

  @override
  String get all => 'Todos';

  @override
  String get none => 'Nenhum';

  @override
  String get other => 'Outro';

  @override
  String get others => 'Outros';

  @override
  String get custom => 'Personalizado';

  @override
  String get old => 'Antigo';

  @override
  String get recent => 'Recente';

  @override
  String get byContinuingYouAgree => 'Ao continuar, você concorda com nossa';

  @override
  String get error => 'Erro';

  @override
  String get companyNotFound => 'Empresa não encontrada';

  @override
  String get companyNoSegment => 'Empresa sem segmento definido';

  @override
  String get userNotFound => 'Usuário não encontrado';

  @override
  String get checkInboxResetPassword =>
      'Verifique sua caixa de entrada para redefinir sua senha.';

  @override
  String get user => 'Usuário';

  @override
  String get switchCompany => 'Trocar Empresa';

  @override
  String get management => 'Gerenciamento';

  @override
  String get integrations => 'Integrações';

  @override
  String get integrationsEmpty => 'Nenhuma conexão ainda';

  @override
  String get integrationsNew => 'Nova conexão';

  @override
  String get integrationsNameHint => 'Ex: Meu ChatGPT';

  @override
  String get integrationsUrlOnce =>
      'Copie esta URL agora. Ela não será exibida novamente.';

  @override
  String get integrationsCopy => 'Copiar URL';

  @override
  String get integrationsRevoke => 'Desligar conexão';

  @override
  String get integrationsRevokeConfirm =>
      'Revogar esta conexão? Quem estiver usando esta URL perde o acesso.';

  @override
  String get integrationsNeverUsed => 'Nunca usada';

  @override
  String integrationsLastUsed(String date) {
    return 'Último uso em $date';
  }

  @override
  String get integrationsErrorForbidden =>
      'Apenas o dono ou administradores podem gerenciar integrações.';

  @override
  String get integrationsErrorNotFound => 'Esta conexão não existe mais.';

  @override
  String get integrationsErrorGeneric =>
      'Não foi possível concluir. Tente novamente.';

  @override
  String get companyData => 'Dados da Empresa';

  @override
  String get account => 'Conta';

  @override
  String get deleteAccount => 'Excluir Conta';

  @override
  String get automatic => 'Automático';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Escuro';

  @override
  String get selectCompany => 'Selecionar Empresa';

  @override
  String get companyNoName => 'Empresa sem nome';

  @override
  String get deleteAccountWarning =>
      'Esta ação é permanente e não pode ser desfeita.\n\nTodos os seus dados, incluindo ordens de serviço, clientes e configurações serão removidos permanentemente.\n\nTem certeza que deseja continuar?';

  @override
  String get finalConfirmation => 'Confirmação Final';

  @override
  String get lastChanceCancel =>
      'Esta é sua última chance de cancelar.\n\nConfirma a exclusão permanente da sua conta?';

  @override
  String get permanentlyDelete => 'Excluir Permanentemente';

  @override
  String get errorDeletingAccount => 'Erro ao Excluir Conta';

  @override
  String get couldNotDeleteAccount => 'Não foi possível excluir sua conta.';

  @override
  String get accountDeletionTakingLong =>
      'A exclusão pode levar alguns minutos. Tente de novo em instantes.';

  @override
  String get requiresRecentLogin =>
      'Por segurança, o Firebase exige login recente antes de deletar a conta.\n\nPor favor:\n1. Faça logout da sua conta\n2. Faça login novamente\n3. Tente deletar a conta imediatamente após o login';

  @override
  String get noPermissionDelete =>
      'Você não tem permissão para deletar sua conta. Tente novamente mais tarde.';

  @override
  String get networkError =>
      'Erro de conexão. Verifique sua internet e tente novamente.';

  @override
  String get reauthenticationRequired => 'Re-autenticação Necessária';

  @override
  String get pleaseSignInAgainToDelete =>
      'Por motivos de segurança, você precisa fazer login novamente antes de deletar sua conta.';

  @override
  String get signInAgain => 'Entrar Novamente';

  @override
  String get authenticated => 'Autenticado';

  @override
  String get reauthenticationFailed => 'Falha na Re-autenticação';

  @override
  String get couldNotReauthenticate => 'Não foi possível autenticar novamente.';

  @override
  String get remove => 'Remover';

  @override
  String get noPermission => 'Sem Permissão';

  @override
  String get noPermissionToRemove =>
      'Você não tem permissão para remover este item.';

  @override
  String get noSegmentsAvailable => 'Nenhum segmento disponível';

  @override
  String get specialties => 'Especialidades';

  @override
  String get myCompany => 'Minha empresa';

  @override
  String get retryAgain => 'Tentar novamente';

  @override
  String get noResultsFound => 'Nenhum resultado encontrado';

  @override
  String get unitValue => 'Valor unitário';

  @override
  String get setAsCover => 'Definir como capa';

  @override
  String get roleDescAdmin =>
      'Acesso total. Configura a empresa, gerencia usuários e acessa todos os dados.';

  @override
  String get roleAdmin => 'Administrador';

  @override
  String get roleDescSupervisor =>
      'Coordena equipes e equipamentos. Não visualiza valores financeiros.';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleDescManager =>
      'Foco em resultados. Visualiza faturamento e custos, mas não executa serviços.';

  @override
  String get roleManager => 'Gerente';

  @override
  String get roleDescConsultant =>
      'Cria orçamentos. Vê preços, mas acessa apenas suas próprias Ordens de Serviço.';

  @override
  String get roleConsultant => 'Consultor';

  @override
  String get roleDescTechnician =>
      'Executa serviços. Não vê preços e tem edição limitada após aprovação da OS.';

  @override
  String get roleTechnician => 'Técnico';

  @override
  String get registered => 'cadastrado';

  @override
  String get errorLoading => 'Erro ao carregar';

  @override
  String get tapPlusToAddYourFirst => 'Toque em + para adicionar seu primeiro';

  @override
  String get doYouWantToRemoveThe => 'Deseja remover o';

  @override
  String get pending => 'Pendente';

  @override
  String get cancelInvite => 'Cancelar Convite';

  @override
  String get userWithoutName => 'Usuário sem nome';

  @override
  String get removeCollaborator => 'Remover Colaborador';

  @override
  String get emailNotProvided => 'Email não informado';

  @override
  String get emailPlaceholder => 'email@exemplo.com';

  @override
  String get collaboratorAdded => 'Colaborador Adicionado';

  @override
  String get financial => 'Financeiro';

  @override
  String get financialAccessDenied =>
      'Você não tem permissão para acessar o painel financeiro.\\n\\nApenas Administradores e Gerentes podem visualizar dados financeiros.';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mês';

  @override
  String get year => 'Ano';

  @override
  String get currentMonth => 'Mês atual';

  @override
  String get currentYear => 'Ano atual';

  @override
  String get start => 'Início';

  @override
  String get end => 'Fim';

  @override
  String get billing => 'Faturamento';

  @override
  String get composition => 'Composição';

  @override
  String get customersReceived => 'Clientes - Recebido';

  @override
  String get customersToReceive => 'Clientes - A Receber';

  @override
  String get customerWithoutName => 'Cliente sem nome';

  @override
  String get serviceWithoutName => 'Serviço sem nome';

  @override
  String get productWithoutName => 'Produto sem nome';

  @override
  String get seeLess => 'Ver menos';

  @override
  String seeAllCount(int count) {
    return 'Ver todos ($count)';
  }

  @override
  String get errorGeneratingReport => 'Erro ao gerar relatório';

  @override
  String get pendingPayment => 'Pendente';

  @override
  String get contacts => 'Contatos';

  @override
  String get preparing => 'Preparando...';

  @override
  String get changeLogo => 'Alterar Logo';

  @override
  String get companyNamePlaceholder => 'Nome da Empresa';

  @override
  String get companyEmailPlaceholder => 'contato@empresa.com';

  @override
  String get phonePlaceholder => '(00) 00000-0000';

  @override
  String get fullAddress => 'Endereço completo';

  @override
  String get websitePlaceholder => 'www.empresa.com.br';

  @override
  String get segment => 'Segmento';

  @override
  String get website => 'Site';

  @override
  String get noName => 'Sem nome';

  @override
  String get errorSendingPhoto => 'Erro ao Enviar Foto';

  @override
  String get couldNotSendPhoto =>
      'Não foi possível enviar a foto. Tente novamente.';

  @override
  String get errorSendingPhotos => 'Erro ao Enviar Fotos';

  @override
  String get couldNotSendPhotos =>
      'Não foi possível enviar as fotos. Tente novamente.';

  @override
  String get requiredFields => 'Campos Obrigatórios';

  @override
  String get pleaseFill => 'Por favor preencha:';

  @override
  String get couldNotCompleteForm =>
      'Não foi possível concluir o procedimento. Tente novamente.';

  @override
  String get noPermissionReopenForm =>
      'Apenas Administradores, Gerentes e Supervisores podem reabrir procedimentos concluídos.';

  @override
  String get couldNotReopenForm =>
      'Não foi possível reabrir o procedimento. Tente novamente.';

  @override
  String get type => 'Digitar';

  @override
  String get errorLoadingPhoto => 'Erro ao carregar foto';

  @override
  String get reopen => 'Reabrir';

  @override
  String get typeOneOptionPerLine => 'Digite uma opção por linha';

  @override
  String get searchProcedure => 'Buscar procedimento';

  @override
  String get noProceduresAvailable => 'Nenhum procedimento disponível';

  @override
  String get fromCompany => 'Da empresa';

  @override
  String get global => 'Globais';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'itens',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String importConfirmationMessage(String title) {
    return 'Deseja importar o procedimento \"$title\" para sua empresa?\n\nVocê poderá editá-lo após a importação.';
  }

  @override
  String get errorLoadingProcedures => 'Erro ao carregar procedimentos';

  @override
  String get importProcedure => 'Importar Procedimento';

  @override
  String get importForMyCompany => 'Importar para Minha Empresa';

  @override
  String get couldNotImportProcedure =>
      'Não foi possível importar o procedimento. Tente novamente.';

  @override
  String get procedureImportedSuccessfully =>
      'Procedimento importado com sucesso!';

  @override
  String get closeDialog => 'Fechar';

  @override
  String get companyLogo => 'Logo da Empresa';

  @override
  String get information => 'INFORMAÇÕES';

  @override
  String get pendingInvites => 'Convites Pendentes';

  @override
  String get noPendingInvites => 'Nenhum convite pendente';

  @override
  String get acceptInvite => 'Aceitar';

  @override
  String get rejectInvite => 'Recusar Convite';

  @override
  String get inviteAccepted => 'Convite Aceito';

  @override
  String youAreNowPartOf(String company) {
    return 'Agora você faz parte de $company!';
  }

  @override
  String areYouSureReject(String company) {
    return 'Tem certeza que deseja recusar o convite de $company?';
  }

  @override
  String get or => 'ou';

  @override
  String get reject => 'Recusar';

  @override
  String invitedBy(String name) {
    return 'Convidado por $name';
  }

  @override
  String roleLabel(String role) {
    return 'Cargo: $role';
  }

  @override
  String get inviteExpired => 'Este convite expirou';

  @override
  String get inviteCancelled => 'Este convite foi cancelado';

  @override
  String get inviteNotFound => 'Convite não encontrado';

  @override
  String get inviteAlreadyUsed => 'Este convite já foi utilizado';

  @override
  String get enterInviteCode => 'Digite o código do convite';

  @override
  String get enterCodeReceived =>
      'Digite o código que você recebeu para entrar na equipe';

  @override
  String get searchAnotherCode => 'Buscar outro código';

  @override
  String get inviteCodeCopied => 'Código do convite copiado!';

  @override
  String get emailOrPhone => 'Informe email ou telefone';

  @override
  String get thisWillRemoveAllPayments =>
      'Isso irá remover todos os pagamentos e descontos registrados. Deseja continuar?';

  @override
  String get attention => 'Atenção';

  @override
  String get financialReport => 'Relatório financeiro';

  @override
  String get totalBilling => 'Faturamento Total';

  @override
  String get financialSummary => 'Resumo Financeiro';

  @override
  String get averageTicket => 'Média por OS';

  @override
  String get customerRanking => 'Ranking de Clientes';

  @override
  String get serviceRanking => 'Ranking de Serviços';

  @override
  String get productRanking => 'Ranking de Produtos';

  @override
  String get paidOrders => 'Ordens Pagas';

  @override
  String get ordersToReceive => 'Ordens a Receber';

  @override
  String get vehicle => 'Veículo';

  @override
  String get valueColumn => 'Valor';

  @override
  String get statusColumn => 'Status';

  @override
  String get quantityShort => 'Qtd';

  @override
  String get noOrdersInPeriod => 'Nenhuma ordem neste período';

  @override
  String get notInformed => 'Não informado';

  @override
  String nOrdersCount(int count) {
    return '$count OS';
  }

  @override
  String nItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'itens',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String get orderSingular => 'ordem';

  @override
  String get orderPlural => 'ordens';

  @override
  String generatedAt(String date) {
    return 'Gerado em $date';
  }

  @override
  String pageOf(int current, int total) {
    return 'Pagina $current de $total';
  }

  @override
  String get preparingReport => 'Preparando relatorio...';

  @override
  String get appTagline => 'Sistema de Gestao de Ordens de Servico';

  @override
  String receivedWithPercent(String percent) {
    return 'Recebido ($percent%)';
  }

  @override
  String toReceiveWithPercent(String percent) {
    return 'A Receber ($percent%)';
  }

  @override
  String get generatedByPraticos => 'Gerado por PraticOS';

  @override
  String get serviceDescriptionColumn => 'DESCRICAO DO SERVICO';

  @override
  String get descriptionColumn => 'DESCRICAO';

  @override
  String get unitShort => 'UNIT.';

  @override
  String get alreadyPaid => 'Ja pago';

  @override
  String get remainingBalance => 'SALDO RESTANTE';

  @override
  String get totalToPay => 'TOTAL A PAGAR';

  @override
  String get photosAvailableDigitally => 'Fotos disponiveis no sistema digital';

  @override
  String attachedPhotosCount(int count) {
    return 'Fotos Anexadas ($count)';
  }

  @override
  String get photoRecord => 'REGISTRO FOTOGRAFICO';

  @override
  String get partsAndProducts => 'PECAS E PRODUTOS';

  @override
  String nPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fotos',
      one: 'foto',
    );
    return '$count $_temp0';
  }

  @override
  String get notSelected => 'Nao selecionado';

  @override
  String formLabelWithTitle(String title) {
    return 'Formulario: $title';
  }

  @override
  String get linked => 'Vinculado';

  @override
  String get linkWhatsApp => 'Vincular WhatsApp';

  @override
  String get linkWhatsAppDescription =>
      'Escaneie o QR code ou clique no botão para abrir o WhatsApp e enviar o código de vinculação ao bot PraticOS.';

  @override
  String linkExpiresIn(String time) {
    return 'Expira em $time';
  }

  @override
  String get openWhatsApp => 'Abrir WhatsApp';

  @override
  String get errorGeneratingToken => 'Erro ao gerar código de vinculação';

  @override
  String get copyLink => 'Copiar Link';

  @override
  String get shareLink => 'Compartilhar Link';

  @override
  String get linkCopied => 'Link copiado!';

  @override
  String viewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'visualizações',
      one: 'visualização',
    );
    return '$count $_temp0';
  }

  @override
  String get commentPlaceholder => 'Digite seu comentário...';

  @override
  String get commentFromCustomer => 'Cliente';

  @override
  String get commentFromTeam => 'Equipe';

  @override
  String get rejectionReason => 'Motivo da rejeição';

  @override
  String get days => 'dias';

  @override
  String get rating => 'Avaliação';

  @override
  String get ratings => 'Avaliações';

  @override
  String get noRatingsYet => 'Nenhuma avaliação ainda';

  @override
  String get notNow => 'Agora não';

  @override
  String get connectWhatsApp => 'Conecte seu WhatsApp';

  @override
  String get connectWhatsAppBannerDescription =>
      'Receba notificações, gerencie OS e envie atualizações para clientes pelo WhatsApp.';

  @override
  String get whatsappOnboardingTitle => 'Conecte seu WhatsApp';

  @override
  String get whatsappOnboardingSubtitle =>
      'Aproveite ao máximo o PraticOS conectando seu WhatsApp';

  @override
  String get whatsappBenefitNotifications => 'Receba notificações de novas OS';

  @override
  String get whatsappBenefitManage => 'Gerencie OS diretamente pelo chat';

  @override
  String get whatsappBenefitClients => 'Envie atualizações para clientes';

  @override
  String get linkNow => 'Vincular agora';

  @override
  String get maybeLater => 'Talvez depois';

  @override
  String inviteWhatsAppMessage(String code) {
    return 'Você foi convidado para a equipe no PraticOS!\n\nCódigo do convite: $code\n\nBaixe o app:\niOS: https://apps.apple.com/br/app/praticos/id1534604555\nAndroid: https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos';
  }

  @override
  String get cannotRemoveOnlyAdmin =>
      'Não é possível remover o único administrador da empresa. Promova outro colaborador a administrador antes de remover este.';

  @override
  String get cannotChangeOnlyAdminRole =>
      'Não é possível alterar o perfil do único administrador. Promova outro colaborador a administrador antes de alterar este.';

  @override
  String get cannotRemoveSelf => 'Você não pode remover a si mesmo da empresa.';

  @override
  String get invalidInviteCompanyNotFound =>
      'Convite inválido: empresa não encontrada.';

  @override
  String get duplicateInviteTitle => 'Convite Existente';

  @override
  String get duplicateInviteMessage =>
      'Já existe um convite pendente para este email/telefone.';

  @override
  String get resendExistingInvite => 'Reenviar Existente';

  @override
  String get cancelAndCreateNew => 'Cancelar e Criar Novo';

  @override
  String get agenda => 'Agenda';

  @override
  String get noScheduledOrders => 'Nenhuma OS agendada para este dia';

  @override
  String get allTeam => 'Toda a equipe';

  @override
  String get allDay => 'Dia todo';

  @override
  String get scheduleReminder => 'Lembrete de agendamento';

  @override
  String get reminderDisabled => 'Desativado';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min antes';
  }

  @override
  String get reminderHourBefore => '1 hora antes';

  @override
  String reminderHoursBefore(int hours) {
    return '$hours horas antes';
  }

  @override
  String get inviteWhatsAppSuccessTitle => 'Colaborador Convidado';

  @override
  String inviteWhatsAppSuccessMessage(String name) {
    return '$name receberá o convite automaticamente ao entrar em contato com o bot PraticOS no WhatsApp.';
  }

  @override
  String get serviceLocation => 'Local do Atendimento';

  @override
  String get openInMaps => 'Abrir no Mapa';

  @override
  String get addressPlaceholder => 'Rua, número, bairro, cidade';

  @override
  String get sendWhatsApp => 'Enviar WhatsApp';

  @override
  String inviteWhatsAppBotMessage(String company) {
    return 'Olá! Você foi adicionado à equipe da $company no PraticOS. Mande um \"oi\" para o bot para começar: https://wa.me/5548988794742';
  }

  @override
  String get removeDevice => 'Remover Equipamento';

  @override
  String get generalNoDevice => 'Geral';

  @override
  String get selectDeviceFor => 'Para qual equipamento?';

  @override
  String deviceCount(int count) {
    return '$count equipamentos';
  }

  @override
  String get features => 'Funcionalidades';

  @override
  String get contracts => 'Contratos';

  @override
  String get noContracts => 'Nenhum contrato';

  @override
  String get recurringContract => 'Contrato recorrente';

  @override
  String get contractNextDue => 'Próxima geração';

  @override
  String generatedOrdersCount(int count) {
    return 'OS geradas ($count)';
  }

  @override
  String get selectDate => 'Selecionar data';

  @override
  String get deviceStatusActive => 'Ativo';

  @override
  String get deviceStatusMaintenance => 'Em manutenção';

  @override
  String get deviceStatusInactive => 'Inativo';

  @override
  String get deviceStatusDecommissioned => 'Desativado';

  @override
  String get noOrderHistory => 'Nenhuma ordem de serviço registrada';

  @override
  String get configure => 'Configurar';

  @override
  String get interval => 'Intervalo';

  @override
  String get indefinite => 'Indefinido';

  @override
  String get noOrdersDueOnDate => 'Nenhuma OS com vencimento neste dia';

  @override
  String get documents => 'Documentos';

  @override
  String get addDocument => 'Adicionar Documento';

  @override
  String get receipt => 'Comprovante';

  @override
  String get invoice => 'Nota Fiscal';

  @override
  String get contract => 'Contrato';

  @override
  String get deleteDocument => 'Excluir Documento';

  @override
  String get confirmDeleteDocument =>
      'Tem certeza que deseja excluir este documento?';

  @override
  String get documentAdded => 'Documento adicionado';

  @override
  String get openDocument => 'Abrir';

  @override
  String get fromFiles => 'Arquivos';

  @override
  String get errorUploadingDocument => 'Erro ao enviar documento';

  @override
  String get engagementReminders => 'Lembretes';

  @override
  String get dailyNotificationTitle => 'Bom dia!';

  @override
  String get dailyNotificationBody => 'Registre as OS do dia no PraticOS';

  @override
  String get inactivity3dTitle => 'Sentimos sua falta!';

  @override
  String get inactivity3dBody =>
      'Você não abre o PraticOS há 3 dias. Que tal registrar suas OS?';

  @override
  String get inactivity5dTitle => 'Suas OS estão esperando!';

  @override
  String get inactivity5dBody =>
      'Já faz 5 dias! Não perca o controle das suas ordens de serviço.';

  @override
  String get inactivity7dTitle => 'Não deixe o PraticOS parado!';

  @override
  String get inactivity7dBody =>
      'Faz 1 semana que você não abre o app. Volte e organize suas OS!';

  @override
  String get pendingOsNotificationTitle => 'OS pendentes precisam de atenção';

  @override
  String pendingOsNotificationBody(int count) {
    return 'Você tem $count OS paradas há mais de 7 dias.';
  }

  @override
  String get termsOfService => 'Termos e Condições';

  @override
  String get termsOfServicePlaceholder =>
      'Ex: Equipamentos não retirados em 90 dias poderão ser descartados...';

  @override
  String get useDefaultTerms => 'Usar texto padrão do segmento';

  @override
  String get pdfTermsAndConditions => 'Termos e Condicoes';

  @override
  String get pdfCompanySignature => 'Responsavel';

  @override
  String get pdfClientSignature => 'Cliente';

  @override
  String get pdfTechnician => 'Tecnico';

  @override
  String get pdfCreatedDate => 'Criada';

  @override
  String get pdfCompletedDate => 'Concluida';

  @override
  String get pdfIssuedDate => 'Emitida';

  @override
  String get pdfServicesSubtotal => 'Subtotal Servicos';

  @override
  String get pdfPartsSubtotal => 'Subtotal Pecas';

  @override
  String get pdfPaid => 'Pago';

  @override
  String get pdfUnitValue => 'Valor Unit.';

  @override
  String get pdfServiceType => 'Servico';

  @override
  String get pdfProductType => 'Peca';

  @override
  String get pdfItemType => 'Tipo';

  @override
  String get pdfSummary => 'Resumo';

  @override
  String get pdfGeneral => 'Geral';

  @override
  String get pdfTrackOnline => 'Acompanhe online';

  @override
  String get pdfTrackOnlineDescription =>
      'Escaneie o QR Code para acompanhar esta ordem de servico';

  @override
  String get pdfEquipment => 'Equipamento';

  @override
  String get upgrade => 'Fazer upgrade';

  @override
  String get formTemplates => 'formulários';

  @override
  String featureGateNearLimit(int count, String feature) {
    return 'Restam $count $feature';
  }

  @override
  String featureGateLimitReached(String feature) {
    return 'Limite de $feature atingido';
  }

  @override
  String featureGateUpgradeSuggestion(String plan) {
    return 'Faça upgrade para o plano $plan para mais';
  }

  @override
  String featureGateUsageInfo(int current, int limit) {
    return 'Usado $current de $limit';
  }

  @override
  String get featureGateLimitModalTitle => 'Limite atingido';

  @override
  String get subscription => 'Assinatura';

  @override
  String get manageSubscription => 'Gerenciar assinatura';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get restorePurchasesSuccess => 'Compras restauradas com sucesso';

  @override
  String get restorePurchasesError =>
      'Erro ao restaurar compras. Tente novamente.';

  @override
  String get success => 'Sucesso';

  @override
  String get free => 'Gratuito';

  @override
  String renewsOn(String date) {
    return 'Renova em $date';
  }

  @override
  String get manageInStore => 'Gerenciar na loja de aplicativos';

  @override
  String get restore => 'Restaurar';

  @override
  String get currentPlan => 'Plano atual';

  @override
  String featureLimitReached(String feature) {
    return 'Você atingiu o limite de $feature';
  }

  @override
  String get photoLimitReachedMessage =>
      'Você atingiu o limite de fotos deste mês.';

  @override
  String get photoLimitUpgradeHint => 'Faça upgrade para adicionar mais fotos.';

  @override
  String get viewPlans => 'Ver planos';

  @override
  String get askAdminToChangePlanTitle => 'Fale com o administrador';

  @override
  String get askAdminToChangePlan =>
      'Peça ao administrador da empresa para mudar de plano.';

  @override
  String get subscriptionUnavailable =>
      'As assinaturas não estão disponíveis agora. Tente novamente mais tarde.';

  @override
  String get restorePurchasesNothingFound =>
      'Nenhuma assinatura ativa foi encontrada nesta conta da loja.';

  @override
  String get planLimitUpgradeHint =>
      'Assine um plano para aumentar este limite.';

  @override
  String get deleteAccountStoreSubscriptionWarning =>
      'Excluir a conta não cancela a assinatura da App Store ou do Google Play. Cancele antes nos ajustes da loja para não ser cobrado de novo.';

  @override
  String get asaasConnected => 'Conectado';

  @override
  String get asaasDisconnected => 'Não conectado';

  @override
  String get asaasConnectTitle => 'Conectar conta Asaas';

  @override
  String get asaasConnectStep1 =>
      '1. No painel do Asaas, abra Integrações > Chaves de API.';

  @override
  String get asaasConnectStep2 => '2. Gere uma nova chave e copie.';

  @override
  String get asaasConnectStep3 => '3. Cole a chave abaixo e toque em Conectar.';

  @override
  String get asaasOpenPanel => 'Abrir painel do Asaas';

  @override
  String get asaasOpenSandboxPanel => 'Abrir painel de teste (sandbox)';

  @override
  String get asaasApiKey => 'Chave de API';

  @override
  String get asaasApiKeyPlaceholder => 'Cole a chave aqui';

  @override
  String get asaasApiKeyHint =>
      'A chave fica guardada com criptografia no servidor e não aparece de novo no app.';

  @override
  String get asaasConnect => 'Conectar';

  @override
  String get asaasAccount => 'Conta';

  @override
  String get asaasEnvironment => 'Ambiente';

  @override
  String get asaasEnvironmentSandbox => 'Teste';

  @override
  String get asaasEnvironmentProduction => 'Produção';

  @override
  String get asaasDisconnect => 'Desconectar';

  @override
  String get asaasDisconnectConfirm =>
      'Desconectar a conta Asaas? As cobranças em aberto continuam no Asaas, mas os pagamentos deixam de dar baixa na OS.';

  @override
  String get asaasErrorInvalidKey =>
      'Chave de API inválida. Confira e tente de novo.';

  @override
  String get asaasErrorForbidden => 'Você não tem permissão para esta ação.';

  @override
  String get asaasErrorNotConnected =>
      'Conecte a conta Asaas em Configurações > Integrações.';

  @override
  String get asaasErrorExceedsBalance => 'O valor é maior que o saldo da OS.';

  @override
  String get asaasErrorTaxIdRequired => 'Informe o CPF ou CNPJ do cliente.';

  @override
  String get asaasErrorCustomerRequired =>
      'Adicione um cliente à OS antes de cobrar.';

  @override
  String get asaasErrorGeneric => 'Não foi possível concluir. Tente novamente.';

  @override
  String get invalidTaxId => 'CPF ou CNPJ inválido';

  @override
  String get chargeValue => 'Valor';

  @override
  String chargeBalanceHint(String value) {
    return 'Saldo da OS: $value';
  }

  @override
  String get chargeSingleHint => 'O cliente escolhe Pix, boleto ou cartão.';

  @override
  String chargeInstallmentOption(int count, String value) {
    return '${count}x de $value';
  }

  @override
  String get chargeDueDate => 'Vencimento';

  @override
  String get chargeTaxIdHint =>
      'O Asaas exige CPF ou CNPJ. Ele fica salvo no cadastro do cliente.';

  @override
  String get chargeStatusPending => 'Aguardando pagamento';

  @override
  String get chargeStatusOverdue => 'Vencida';

  @override
  String get chargeStatusPaid => 'Paga';

  @override
  String get chargeStatusCanceled => 'Cancelada';

  @override
  String get chargeStatusRefunded => 'Estornada';

  @override
  String get chargeCancelConfirm =>
      'O cliente não vai mais conseguir pagar por esse link.';

  @override
  String get chargeKeep => 'Manter';

  @override
  String get chargeReplaceTitle => 'Já existe uma cobrança em aberto';

  @override
  String get chargeReplaceConfirm =>
      'Gerar uma nova cobrança cancela a anterior no Asaas.';

  @override
  String get chargeReplace => 'Gerar nova';

  @override
  String get asaasErrorInstallmentsInProgress =>
      'Este parcelamento já tem parcelas pagas. Aguarde terminar ou estorne no Asaas.';

  @override
  String get asaasErrorCustomerChargeOpen =>
      'Esta OS já está num link de cobrança de várias OS do cliente. Cancele aquele link em Receber do cliente.';

  @override
  String get asaasErrorChargeSuperseded =>
      'Outro link para essas OS foi criado ao mesmo tempo e ficou valendo. Veja o link na OS ou no cliente.';

  @override
  String get asaasErrorPreviousLinkCanceled =>
      'Um link antigo foi cancelado, mas o novo não foi criado. Mande um link novo.';

  @override
  String get asaasErrorOrderNotPayable =>
      'Orçamento e OS cancelada não podem ser cobrados.';

  @override
  String get asaasErrorOrderCanceled =>
      'Esta OS está cancelada e não pode receber cobrança.';

  @override
  String get asaasErrorInvalidDueDate =>
      'Data de vencimento inválida. Escolha hoje ou uma data futura.';

  @override
  String get asaasErrorInvalidInstallmentCount =>
      'Número de parcelas inválido. Escolha de 2 a 12.';

  @override
  String get asaasErrorChargeNotOpen =>
      'Esta cobrança não está mais em aberto.';

  @override
  String get asaasErrorValidation =>
      'O Asaas recusou os dados da cobrança. Confira o CPF/CNPJ e o e-mail do cliente.';

  @override
  String get asaasErrorUnavailable =>
      'O Asaas está indisponível no momento. Tente novamente em instantes.';

  @override
  String get listLoadError =>
      'Não deu para carregar. Verifique a internet e tente de novo.';

  @override
  String get pickCustomerTitle => 'Quem é o cliente?';

  @override
  String get searchCustomerPlaceholder => 'Buscar por nome, telefone ou placa';

  @override
  String plateValue(String plate) {
    return 'Placa $plate';
  }

  @override
  String get customerNamePlaceholder => 'Ex.: Ana Ribeiro';

  @override
  String get customerNameRequired => 'Digite o nome do cliente';

  @override
  String get customerPhoneLabel => 'Telefone ou WhatsApp';

  @override
  String get customerPhoneHint =>
      'Usado para mandar o orçamento e o aviso de pronto.';

  @override
  String get moreCustomerData => 'Mais dados (e-mail, CPF ou CNPJ, endereço)';

  @override
  String get openInMap => 'Abrir no mapa';

  @override
  String get callAction => 'Ligar';

  @override
  String newOrderFor(String name) {
    return 'Nova OS para $name';
  }

  @override
  String devicesOfCustomer(String devices, String name) {
    return '$devices de $name';
  }

  @override
  String get totalSpent => 'Total gasto';

  @override
  String deleteCustomerTitle(String name) {
    return 'Apagar $name?';
  }

  @override
  String get deleteCustomerKeepsOrders => 'As OS continuam salvas.';

  @override
  String get deleteAction => 'Apagar';

  @override
  String get noCustomersYet => 'Você ainda não tem clientes';

  @override
  String get addFirstCustomer => 'Cadastrar o primeiro cliente';

  @override
  String noCustomerMatching(String query) {
    return 'Nenhum cliente com “$query”';
  }

  @override
  String customersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes',
      one: '1 cliente',
    );
    return '$_temp0';
  }

  @override
  String openOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS em aberto',
      one: '1 OS em aberto',
    );
    return '$_temp0';
  }

  @override
  String lateOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS atrasadas',
      one: '1 OS atrasada',
    );
    return '$_temp0';
  }

  @override
  String get customerActions => 'Mais ações do cliente';

  @override
  String get customerLookupError =>
      'Não deu para carregar os clientes. Tente de novo.';

  @override
  String get catalogTitle => 'Catálogo';

  @override
  String get catalogNewService => 'Novo serviço';

  @override
  String get catalogNewProduct => 'Novo produto';

  @override
  String get saveServiceButton => 'Salvar serviço';

  @override
  String get saveProductButton => 'Salvar produto';

  @override
  String get serviceNameHint => 'Ex.: Troca de óleo';

  @override
  String get productNameHint => 'Ex.: Filtro de óleo';

  @override
  String get serviceNameRequired => 'Digite o nome do serviço';

  @override
  String get productNameRequired => 'Digite o nome do produto';

  @override
  String get catalogPriceLabel => 'Preço';

  @override
  String get catalogPriceHint =>
      'Pode deixar em branco e combinar o preço em cada OS.';

  @override
  String get addServicePhoto => 'Foto do serviço';

  @override
  String get addProductPhoto => 'Foto do produto';

  @override
  String get catalogNoPrice => 'sem valor';

  @override
  String get catalogEmptyServices => 'Você ainda não tem serviços';

  @override
  String get catalogEmptyServicesHint =>
      'Cadastre os que você mais faz para montar a OS mais rápido.';

  @override
  String get catalogEmptyProducts => 'Você ainda não tem produtos';

  @override
  String get catalogEmptyProductsHint =>
      'Cadastre os que você mais usa para montar a OS mais rápido.';

  @override
  String catalogNoMatch(String query) {
    return 'Nada com “$query”';
  }

  @override
  String catalogDeleteTitle(String name) {
    return 'Apagar $name?';
  }

  @override
  String get catalogDeleteMessage =>
      'Ele sai do catálogo. As OS que já usam continuam salvas.';

  @override
  String get deleteServiceAction => 'Apagar serviço';

  @override
  String get deleteProductAction => 'Apagar produto';

  @override
  String get catalogItemActions => 'Mais ações do item';

  @override
  String get pickServiceTitle => 'Qual serviço?';

  @override
  String get pickProductTitle => 'Qual produto?';

  @override
  String get catalogLoadError =>
      'Não deu para carregar o catálogo. Tente de novo.';

  @override
  String newEntity(String entity) {
    return 'Novo $entity';
  }

  @override
  String get photoAndMoreData => 'Foto e mais dados';

  @override
  String fieldRequiredHint(String field) {
    return 'Preencha o campo $field';
  }

  @override
  String useValue(String value) {
    return 'Usar “$value”';
  }

  @override
  String get newOrderAction => 'Nova OS';

  @override
  String get deviceActions => 'Mais ações';

  @override
  String deleteDeviceTitle(String name) {
    return 'Apagar $name?';
  }

  @override
  String get deleteDeviceKeepsOrders => 'As OS continuam salvas.';

  @override
  String get deviceDetailsLabel => 'Dados';

  @override
  String orderNewTitle(String order) {
    return 'Nova $order';
  }

  @override
  String orderNumberTitle(String order, String number) {
    return '$order $number';
  }

  @override
  String get orderItemsSection => 'O que vai ser feito';

  @override
  String get orderItemSearchPlaceholder => 'Buscar serviço ou peça';

  @override
  String get orderCreateItemError => 'Não deu para criar. Tente de novo.';

  @override
  String get orderCatalogEmpty =>
      'Seu catálogo está vazio. Digite o nome na busca para criar.';

  @override
  String get orderMostUsed => 'Mais usados';

  @override
  String get orderAllItems => 'Todos';

  @override
  String get orderItemKindService => 'serviço';

  @override
  String get orderItemKindProduct => 'produto';

  @override
  String orderItemQuantityValue(String count) {
    return '$count unidades';
  }

  @override
  String get orderItemPrice => 'Preço';

  @override
  String get orderItemPriceHint =>
      'Pode deixar em branco: o item fica sem valor e fora do total.';

  @override
  String get orderItemQuantity => 'Quantidade';

  @override
  String get orderItemLess => 'Menos um';

  @override
  String get orderItemMore => 'Mais um';

  @override
  String get orderItemRemove => 'Tirar da OS';

  @override
  String get orderTotalLabel => 'Total';

  @override
  String orderRemainingToReceive(String amount) {
    return 'Falta receber $amount';
  }

  @override
  String get orderFullyPaid => 'Tudo pago';

  @override
  String get orderSaveNeedsCustomer => 'Escolha o cliente para salvar.';

  @override
  String get orderDiscardTitle => 'Sair sem salvar?';

  @override
  String get orderDiscardMessage => 'O que você preencheu vai ser perdido.';

  @override
  String get orderKeepEditing => 'Continuar';

  @override
  String orderPickDevice(String device) {
    return 'Escolher $device';
  }

  @override
  String get orderTalkAction => 'Falar o que fazer';

  @override
  String orderNextStepReceive(String amount) {
    return 'Receber $amount';
  }

  @override
  String orderMenuAddTo(String order) {
    return 'Adicionar à $order';
  }

  @override
  String get orderMenuSendToCustomer => 'Mandar para o cliente';

  @override
  String orderMenuCancel(String order) {
    return 'Cancelar $order';
  }

  @override
  String orderMenuDelete(String order) {
    return 'Apagar $order';
  }

  @override
  String get orderAddDueDate => 'Data de entrega';

  @override
  String orderAddAnotherDevice(String device) {
    return 'Outro $device';
  }

  @override
  String orderCancelConfirmTitle(String order) {
    return 'Cancelar $order?';
  }

  @override
  String get orderCancelConfirmMessage =>
      'Ela vai para as canceladas e pode ser reaberta.';

  @override
  String orderDeleteConfirmTitle(String order) {
    return 'Apagar $order?';
  }

  @override
  String get orderDeleteConfirmMessage => 'Não dá para desfazer.';

  @override
  String get orderPhotosSection => 'Fotos';

  @override
  String orderUnpricedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens sem valor, fora do total',
      one: '1 item sem valor, fora do total',
    );
    return '$_temp0';
  }

  @override
  String orderPendingChecklists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam terminar $count checklists',
      one: 'Falta terminar 1 checklist',
    );
    return '$_temp0';
  }

  @override
  String get orderMoreActions => 'Mais ações';

  @override
  String get filterOpen => 'Em aberto';

  @override
  String get filterAll => 'Todas';

  @override
  String get filterMine => 'Minhas';

  @override
  String get nextVisitLabel => 'Agora';

  @override
  String homeWithYouToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count com você hoje',
      one: '1 com você hoje',
    );
    return '$_temp0';
  }

  @override
  String homeWithYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count com você',
      one: '1 com você',
    );
    return '$_temp0';
  }

  @override
  String nextVisit(String customer, String time) {
    return 'Próximo: $customer, às $time.';
  }

  @override
  String nextVisitDevice(String customer, String device, String time) {
    return 'Próximo: $customer, $device, às $time.';
  }

  @override
  String openOrderNumber(String number) {
    return 'Abrir OS $number';
  }

  @override
  String get noOrdersWithYou => 'Nenhuma OS com você.';

  @override
  String homeOpenCount(int count) {
    return '$count em aberto';
  }

  @override
  String get seeAllOrders => 'Ver todas';

  @override
  String notificationsA11y(int count) {
    return 'Avisos, $count novos';
  }

  @override
  String get howItWorks => 'Como funciona';

  @override
  String get firstOrderLabel => 'Comece por aqui';

  @override
  String get homeNoOrdersYet => 'Nenhuma ainda';

  @override
  String get howItWorksStep1 => '1. Anote o que vai ser feito';

  @override
  String get howItWorksStep1Detail => 'cliente e serviços';

  @override
  String howItWorksStep1DetailDevice(String device) {
    return 'cliente, $device e serviços';
  }

  @override
  String get howItWorksStep2 => '2. Mande o orçamento';

  @override
  String get howItWorksStep2Detail => 'pelo WhatsApp, com um link';

  @override
  String get howItWorksStep3 => '3. Receba e entregue';

  @override
  String get howItWorksStep3Detail => 'o app lembra quem falta pagar';

  @override
  String get searchNotFoundLoaded => 'Não achei nas OS carregadas.';

  @override
  String get searchOlder => 'Buscar nas mais antigas';

  @override
  String get noOpenOrders => 'Nenhuma OS em aberto.';

  @override
  String get noOrdersInView => 'Nada por aqui.';

  @override
  String get loadOrdersError => 'Não deu para carregar as OS.';

  @override
  String orderLateMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada há $count meses',
      one: 'Atrasada há 1 mês',
    );
    return '$_temp0';
  }

  @override
  String orderLateYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada há $count anos',
      one: 'Atrasada há 1 ano',
    );
    return '$_temp0';
  }

  @override
  String orderLateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada $count dias',
      one: 'Atrasada 1 dia',
    );
    return '$_temp0';
  }

  @override
  String orderStatusDue(String status, String date) {
    return '$status · entrega $date';
  }

  @override
  String orderRowNumber(String number) {
    return 'OS $number';
  }

  @override
  String get yourAccount => 'Sua conta';

  @override
  String get yourCompany => 'Sua empresa';

  @override
  String get catalog => 'Catálogo';

  @override
  String get planTitle => 'Plano';

  @override
  String get advancedTitle => 'Avançado';

  @override
  String get deleteMyAccount => 'Apagar minha conta';

  @override
  String get howYouWork => 'Como você trabalha';

  @override
  String get valuesAndBilling => 'Valores e cobrança';

  @override
  String get valuesAndBillingHint => 'Preços na OS, receber e aba Financeiro';

  @override
  String get valuesAndBillingOffTitle => 'Desligar valores e cobrança?';

  @override
  String get valuesAndBillingOffMessage =>
      'Preços, total, receber e a aba Financeiro somem para toda a equipe. Nada é apagado: os valores voltam se você religar. Links de pagamento já enviados continuam valendo.';

  @override
  String get valuesAndBillingOffAction => 'Desligar';

  @override
  String get valuesAndBillingSaveError =>
      'Não deu para salvar. Confira a internet e tente de novo.';

  @override
  String get joinWithInviteCode => 'Entrar com código de convite';

  @override
  String get followsPhoneSettings =>
      'O idioma e a aparência seguem o ajuste do iPhone.';

  @override
  String get invitePerson => 'Convidar pessoa';

  @override
  String get inviteWhoLabel => 'Nome (opcional)';

  @override
  String get inviteWhoPlaceholder => 'Ex.: Lucas Silva';

  @override
  String get inviteEmailLabel => 'E-mail';

  @override
  String get inviteEmailHint =>
      'A pessoa entra com este e-mail e o convite aparece sozinho.';

  @override
  String get inviteWhatsAppLabel => 'WhatsApp (opcional)';

  @override
  String get inviteRoleLabel => 'O que pode fazer';

  @override
  String get inviteRoleQuestion => 'O que pode fazer?';

  @override
  String get createInvite => 'Criar convite';

  @override
  String get userWillReceiveInviteByWhatsAppHint =>
      'Depois você manda o código por esse número ou por outro app.';

  @override
  String get financialLoadError => 'Não deu para carregar o financeiro.';

  @override
  String financialEmptyMonth(String month) {
    return 'Nenhuma OS em $month.';
  }

  @override
  String get financialToReceive => 'Falta receber';

  @override
  String financialOrderSince(int number, String date) {
    return 'OS $number · desde $date';
  }

  @override
  String financialOrdersSince(int count, String date) {
    return '$count OS · desde $date';
  }

  @override
  String get financialOtherPeriod => 'Outro período';

  @override
  String get financialPreviousMonth => 'Mês anterior';

  @override
  String get financialNextMonth => 'Próximo mês';

  @override
  String financialNextStep(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes',
      one: '1 cliente',
    );
    return 'Falta receber $amount de $_temp0';
  }

  @override
  String financialOldestDebt(String name, String amount, String date) {
    return '$name deve há mais tempo: $amount desde $date.';
  }

  @override
  String financialSendChargeTo(String name) {
    return 'Mandar cobrança para $name';
  }

  @override
  String financialPickOrderTitle(String name) {
    return 'OS em aberto de $name';
  }

  @override
  String financialOrderOption(int number, String amount, String date) {
    return 'OS $number · $amount · desde $date';
  }

  @override
  String get receiveTitle => 'Receber';

  @override
  String get receiveMissing => 'Falta receber';

  @override
  String get receiveAllDone => 'Tudo recebido';

  @override
  String get receiveAttachReceipt => 'Anexar comprovante';

  @override
  String get receiveAlreadyReceived => 'Já recebido';

  @override
  String get receiveWithReceipt => 'com comprovante';

  @override
  String get receiveNoReceipt => 'sem comprovante';

  @override
  String get receiveViaPix => 'Pix pelo link';

  @override
  String get receiveViaBoleto => 'Boleto pelo link';

  @override
  String get receiveViaCard => 'Cartão pelo link';

  @override
  String get receiveViaLink => 'Pelo link';

  @override
  String get receiveGiveDiscount => 'Dar desconto';

  @override
  String get receiveUndoPayments => 'Desfazer pagamentos';

  @override
  String receiveDiscountNewTotal(String from, String to) {
    return 'O total passa de $from para $to';
  }

  @override
  String get receiveViewReceipt => 'Ver comprovante';

  @override
  String get receiveRemovePayment => 'Remover este pagamento';

  @override
  String receiveRecordedBy(String name, String date) {
    return 'Anotado por $name em $date';
  }

  @override
  String receiveRecordedAuto(String date) {
    return 'O app anotou sozinho em $date';
  }

  @override
  String get receiveMoreOptions => 'Mais opções';

  @override
  String get receiveRemoveReceipt => 'Tirar comprovante';

  @override
  String get receiveWhen => 'Quando';

  @override
  String get receiveConfirmButton => 'Confirmar recebimento';

  @override
  String receiveCustomerOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS em aberto. Marque as OS que foram pagas.',
      one: '1 OS em aberto.',
    );
    return '$_temp0';
  }

  @override
  String get receiveCustomerPartHint =>
      'Se recebeu só uma parte, digite quanto.';

  @override
  String get receiveCustomerPaying => 'Está pagando';

  @override
  String receiveCustomerOrderRow(int number, String description) {
    return 'OS $number · $description';
  }

  @override
  String get receiveCustomerRowSettles => 'Quita';

  @override
  String receiveCustomerRowPartial(String amount, String left) {
    return 'Recebe $amount · fica $left';
  }

  @override
  String get receiveCustomerRowLater => 'Fica para depois';

  @override
  String get receiveCustomerNoneChecked => 'Marque pelo menos uma OS.';

  @override
  String get receiveCustomerSendLink => 'Mandar link para pagar…';

  @override
  String receiveCustomerOpenOrder(int number) {
    return 'Abrir OS $number';
  }

  @override
  String get receiveAttach => 'Anexar';

  @override
  String receiveCustomerTitle(String name) {
    return 'Receber de $name';
  }

  @override
  String get receiveCustomerAmountLabel => 'Quanto recebeu';

  @override
  String get receiveCustomerOldestFirst =>
      'Se o valor não der para tudo, as mais antigas são pagas primeiro.';

  @override
  String get receiveCustomerZero => 'Digite quanto recebeu.';

  @override
  String receiveCustomerDone(String amount, String name) {
    return 'Recebido $amount de $name';
  }

  @override
  String get receiveCustomerUploadFailed =>
      'Não deu para enviar o comprovante. Confira a internet e tente de novo.';

  @override
  String receiveCustomerChargeIntro(String name, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'as OS $numbers',
      one: 'a OS $numbers',
    );
    return '$name recebe um link só para pagar $_temp0 por Pix, boleto ou cartão.';
  }

  @override
  String receiveCustomerChargeOwedHint(String value) {
    return 'Em aberto nessas OS: $value';
  }

  @override
  String receiveCustomerOpenCharge(String amount) {
    return 'Link aberto de $amount';
  }

  @override
  String receiveCustomerOpenChargeDetail(String numbers, String date) {
    return 'OS $numbers · vence $date';
  }

  @override
  String get receiveCustomerShareCharge => 'Mandar o link de novo';

  @override
  String receiveCustomerChargeCancelTitle(String amount) {
    return 'Cancelar o link de $amount?';
  }

  @override
  String get receiveCustomerChargeCanceled => 'Link cancelado';

  @override
  String receiveCustomerOthersTitle(String name) {
    return 'Outras OS de $name';
  }

  @override
  String get receiveCustomerOthersNote =>
      'Feitas por outra pessoa. Marque para incluir; para salvar, precisa de internet.';

  @override
  String get receiveCustomerOffline =>
      'Sem internet. Para receber em OS de outra pessoa, precisa estar conectado.';

  @override
  String receiveCustomerPickRow(int number) {
    return 'OS $number';
  }

  @override
  String receiveCustomerTooMuchChosen(String total) {
    return 'Passa do que falta nessas OS ($total).';
  }

  @override
  String get receiptTitle => 'Recebimento';

  @override
  String receiptRowSettled(int number, String amount) {
    return 'OS $number · $amount · quitada';
  }

  @override
  String receiptRowOpen(int number, String amount, String left) {
    return 'OS $number · $amount · falta $left';
  }

  @override
  String receiptSendTo(String name) {
    return 'Mandar recibo para $name';
  }

  @override
  String get receiptSend => 'Mandar recibo';

  @override
  String get receiptActions => 'Mais opções do recebimento';

  @override
  String get receiptUndo => 'Desfazer recebimento';

  @override
  String receiptUndoTitle(String amount) {
    return 'Desfazer o recebimento de $amount?';
  }

  @override
  String receiptUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS',
      one: '1 OS',
    );
    return 'O valor sai de $_temp0 e volta a faltar receber.';
  }

  @override
  String get receiptUndone => 'Recebimento desfeito';

  @override
  String get receiptCanceled => 'Este recebimento foi desfeito.';

  @override
  String get receiptPartOfGroup =>
      'Este pagamento faz parte de um recebimento de várias OS. Para desfazer, abra o recebimento.';

  @override
  String get receiptOpen => 'Abrir recebimento';

  @override
  String get receiptsSection => 'Recebimentos';

  @override
  String receiptListSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS',
      one: '1 OS',
    );
    return '$date · $_temp0';
  }

  @override
  String get receiptNotFound => 'Não achamos este recebimento.';

  @override
  String get pdfReceiptTitle => 'Recibo';

  @override
  String pdfReceiptNumber(String number) {
    return 'Nº $number';
  }

  @override
  String pdfReceiptSentence(String name, String amount, String date) {
    return 'Recebemos de $name a quantia de $amount em $date.';
  }

  @override
  String get pdfReceiptOrderColumn => 'OS';

  @override
  String get pdfReceiptPaidColumn => 'Pago agora';

  @override
  String get pdfReceiptOpenColumn => 'Ainda falta';

  @override
  String get pdfReceiptDescriptionColumn => 'Descrição';

  @override
  String get pdfReceiptTotal => 'Total recebido';

  @override
  String pdfReceiptRemaining(String amount) {
    return 'Falta receber $amount dessas OS.';
  }

  @override
  String pdfReceiptRecordedBy(String name) {
    return 'Registrado por $name';
  }

  @override
  String pdfReceiptFileName(String number) {
    return 'Recibo-$number';
  }

  @override
  String get loginTitle => 'Entre para começar';

  @override
  String get loginSubtitle => 'Suas OS ficam salvas e a equipe vê as mesmas.';

  @override
  String get loginWithEmailLink => 'Entrar com e-mail e senha';

  @override
  String get errorSignInAppleFriendly =>
      'Não deu para entrar com a Apple. Tente de novo.';

  @override
  String get errorSignInGoogleFriendly =>
      'Não deu para entrar com o Google. Tente de novo.';

  @override
  String get forgotPasswordQuestion => 'Esqueceu a senha?';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get hidePassword => 'Ocultar senha';

  @override
  String get onboardingSegmentTitle => 'Seu ramo';

  @override
  String get onboardingInviteCode => 'Recebi um código de convite';

  @override
  String get onboardingSegmentsError =>
      'Não deu para carregar os ramos. Confira a internet.';

  @override
  String get onboardingSpecialtiesTitle => 'Especialidades';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingBusinessTitle => 'Seu negócio';

  @override
  String get onboardingBusinessName => 'Como se chama o seu negócio?';

  @override
  String get onboardingBusinessNamePlaceholder => 'Ex.: Oficina do Zé';

  @override
  String get onboardingBusinessNameRequired => 'Diga o nome do seu negócio.';

  @override
  String get onboardingPhoneLabel => 'Telefone (opcional)';

  @override
  String get onboardingPhoneHint =>
      'Aparece no orçamento que o cliente recebe.';

  @override
  String get onboardingSamplesInfo =>
      'Vamos colocar umas OS de exemplo para você ver como fica. Você apaga quando quiser.';

  @override
  String get onboardingCreate => 'Criar meu PraticOS';

  @override
  String get onboardingStartWithoutSamples => 'Começar sem exemplos';

  @override
  String get onboardingPreparing => 'Preparando seu PraticOS…';

  @override
  String get onboardingCreateError =>
      'Não deu para terminar. Confira a internet e tente de novo.';

  @override
  String get receivedWhichOrder => 'Em qual OS?';

  @override
  String receivedPhotosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String receivedPdfsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDFs',
      one: '1 PDF',
    );
    return '$_temp0';
  }

  @override
  String receivedSummaryBoth(String photos, String pdfs) {
    return '$photos e $pdfs';
  }

  @override
  String receivedSavedInOrder(String number, String summary) {
    return 'Guardado na OS $number · $summary';
  }

  @override
  String get receivedSaveFailed => 'Não deu para guardar. Tente de novo.';

  @override
  String get receivedOpenOrder => 'Abrir a OS';

  @override
  String get sharedFileQuestion => 'O que é este arquivo?';

  @override
  String sharedFileReceiptOf(String amount, String date) {
    return 'Comprovante do pagamento de $amount · $date';
  }

  @override
  String get sharedFileNewPayment => 'Comprovante de um pagamento novo';

  @override
  String get sharedFileJustKeep => 'Só guardar na OS';

  @override
  String sharedFileReceiptSaved(String number) {
    return 'Comprovante guardado na OS $number';
  }

  @override
  String get inviteGenericError =>
      'Não deu para concluir. Confira a internet e tente de novo.';

  @override
  String get inviteLoadError =>
      'Não deu para carregar os convites. Confira a internet.';

  @override
  String inviteTitleOne(String company) {
    return '$company chamou você para a equipe';
  }

  @override
  String inviteInvitedByAs(String name, String role) {
    return 'Convidado por $name · você entra como $role';
  }

  @override
  String inviteEntersAs(String role) {
    return 'Você entra como $role';
  }

  @override
  String get inviteJoinTeam => 'Entrar na equipe';

  @override
  String get inviteDecline => 'Recusar convite';

  @override
  String get inviteHaveAnotherCode => 'Tenho outro código';

  @override
  String get inviteCreateOwnCompany => 'Criar minha própria empresa';

  @override
  String get inviteCodePlaceholder => 'Ex.: 7K2P9QXA';

  @override
  String get segmentLoadError =>
      'Não deu para abrir a sua empresa. Confira a internet e tente de novo.';

  @override
  String get orderAssistantAddPhoto => 'Tirar outra foto';

  @override
  String get orderAssistantTakePhoto => 'Tirar foto';

  @override
  String orderAssistantCustomerGuess(String name) {
    return 'Ouvi “$name”. Toque para escolher o cliente';
  }

  @override
  String orderAssistantDeviceGuess(String device) {
    return '“$device” não está no cadastro';
  }

  @override
  String get orderAssistantErrorDisabled =>
      'O assistente ainda não está liberado para a sua empresa.';

  @override
  String orderAssistantErrorQuota(String limit) {
    return 'Você já usou os $limit pedidos do assistente deste mês. Dá para continuar preenchendo à mão.';
  }

  @override
  String get orderAssistantErrorUnavailable =>
      'Não deu para ler agora. Tente de novo ou preencha à mão.';

  @override
  String get orderAssistantNothingFound =>
      'Não achei o que pôr. Tente de novo ou preencha à mão.';

  @override
  String get reportPreviousPeriod => 'Período anterior';

  @override
  String get reportNextPeriod => 'Próximo período';

  @override
  String get orderAddChecklist => 'Checklist';

  @override
  String get orderAddComment => 'Comentário';

  @override
  String get orderAddAddress => 'Endereço do atendimento';

  @override
  String get orderAddSchedule => 'Agendar dia e hora';

  @override
  String get orderAddDiscount => 'Desconto';

  @override
  String orderChecklistMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count perguntas',
      one: 'Falta 1 pergunta',
    );
    return '$_temp0';
  }

  @override
  String get orderAddressChange => 'Mudar endereço';

  @override
  String get orderAddressRemove => 'Tirar endereço';

  @override
  String get orderScheduleRemove => 'Tirar agendamento';

  @override
  String orderContractSummary(String frequency, String date) {
    return '$frequency · próxima em $date';
  }

  @override
  String get orderUploading => 'Enviando…';

  @override
  String otherDevicesSection(String devices) {
    return 'Outros $devices';
  }

  @override
  String accumulatedDeleteConfirm(String value) {
    return 'Apagar “$value”?';
  }

  @override
  String accumulatedUse(String value) {
    return 'Usar “$value”';
  }

  @override
  String get accumulatedLeaveBlank => 'Deixar em branco';

  @override
  String get moreSectionCompany => 'Empresa';

  @override
  String get moreSectionRecords => 'Cadastros';

  @override
  String get moreSectionYou => 'Você';

  @override
  String get moreCompanySubtitle => 'Dados na OS, ramo e recursos';

  @override
  String moreCatalogSubtitle(String products) {
    return 'Serviços e $products';
  }

  @override
  String planHeaderRenews(String plan, String date) {
    return '$plan · renova em $date';
  }

  @override
  String planHeaderValidUntil(String plan, String date) {
    return '$plan · válido até $date';
  }

  @override
  String planHeaderCourtesy(String plan, String date) {
    return '$plan · cortesia até $date';
  }

  @override
  String planHeaderPaymentIssue(String plan) {
    return '$plan · problema no pagamento';
  }

  @override
  String get planLimitLabel => 'Limite do plano';

  @override
  String planLimitTeam(String used, String limit) {
    return 'A equipe já tem $used de $limit pessoas. Para chamar mais alguém, mude de plano.';
  }

  @override
  String planLimitPhotos(String used, String limit) {
    return 'Já foram $used de $limit fotos este mês. Para tirar mais, mude de plano.';
  }

  @override
  String planLimitChecklists(String used, String limit) {
    return 'Você já tem $used de $limit checklists. Para criar outro, mude de plano.';
  }

  @override
  String get planUsageSection => 'O que você está usando';

  @override
  String get planUsageTeam => 'Pessoas na equipe';

  @override
  String get planUsagePhotos => 'Fotos este mês';

  @override
  String get planUsageChecklists => 'Checklists';

  @override
  String planUsageOf(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String get planUsageAtLimit => 'No limite';

  @override
  String get planUsageAtLimitInvites => 'No limite · conta o convite';

  @override
  String get planUsageNearLimit => 'Quase no limite';

  @override
  String get planUsageUnlimited => 'Sem limite';

  @override
  String get companyShownOnOrder => 'Aparece na OS do cliente';

  @override
  String get companyNameLogoContact => 'Nome, logo e contato';

  @override
  String get customerTerms => 'Termos para o cliente';

  @override
  String get customerTermsHint => 'Garantia e condições';

  @override
  String get segmentRow => 'Ramo';

  @override
  String get segmentRowHint => 'Muda serviços e checklists prontos';

  @override
  String get moreCompanyData => 'Mais dados (e-mail, site, país)';

  @override
  String get addLogo => 'Pôr logo';

  @override
  String get changeLogoLink => 'Trocar logo';

  @override
  String get pickSegmentTitle => 'Qual é o seu ramo?';

  @override
  String get pickSpecialtiesTitle => 'O que você atende?';

  @override
  String get specialtiesNone => 'Nenhuma marcada';

  @override
  String get pickCountryTitle => 'Qual é o país?';

  @override
  String get companyNameRequired => 'Escreva o nome da empresa';

  @override
  String get schedulingRow => 'Agenda';

  @override
  String get schedulingRowHint => 'Marcar dia e hora das OS';

  @override
  String get fieldServiceRow => 'Atendimento no local do cliente';

  @override
  String get fieldServiceRowHint => 'Endereço do cliente na OS';

  @override
  String get contractsRowHint => 'OS que se repetem sozinhas';

  @override
  String deviceControlRow(String devices) {
    return 'Controle de $devices';
  }

  @override
  String get deviceControlRowHint => 'Histórico e lista completa';

  @override
  String get companySettingSaveError =>
      'Não deu para salvar. Confira a internet e tente de novo.';

  @override
  String customerSpentValue(String value) {
    return 'gastou $value';
  }

  @override
  String customerOwesValue(String value) {
    return 'Falta receber $value';
  }

  @override
  String askOrderForCustomer(String name) {
    return 'Abrir uma OS para $name?';
  }

  @override
  String askOrderForDevice(String device) {
    return 'Abrir uma OS para este $device?';
  }

  @override
  String addAnotherDevice(String device) {
    return 'Cadastrar outro $device';
  }

  @override
  String get latestOrders => 'Últimas OS';

  @override
  String ordersOfDevice(String device) {
    return 'OS deste $device';
  }

  @override
  String orderCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS',
      one: '1 OS',
    );
    return '$_temp0';
  }

  @override
  String get deviceOwnerPrefix => 'da ';

  @override
  String get financialReportShort => 'Relatório';

  @override
  String financialReceivedIn(String month) {
    return 'Recebido em $month';
  }

  @override
  String financialReceivedSub(int count) {
    return '$count OS · ver todas';
  }

  @override
  String get financialSendReportPdf => 'Mandar relatório em PDF';

  @override
  String receiveSubtitle(String customer, String total) {
    return '$customer · total $total';
  }

  @override
  String receiveSubtitleNoCustomer(String total) {
    return 'total $total';
  }

  @override
  String receiveOrderLink(int number) {
    return 'OS $number';
  }

  @override
  String get receiveAmountHint =>
      'Recebeu só uma parte? Toque no valor e digite quanto.';

  @override
  String get orderAddContractMonthly => 'Repetir todo mês (contrato)';

  @override
  String get ratingsSubtitle => 'O que os clientes acharam';

  @override
  String get ratingsLatest => 'Últimas';

  @override
  String ratingScoreOf(String score) {
    return '$score de 5';
  }

  @override
  String ratingsAverageOf(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'avaliações',
      one: 'avaliação',
    );
    return 'média de $count $_temp0';
  }

  @override
  String ratingCommentOrder(String comment, int number) {
    return '“$comment” · OS $number';
  }

  @override
  String ratingNoCommentOrder(int number) {
    return 'Sem comentário · OS $number';
  }

  @override
  String get remindersSubtitle => 'Valem só neste celular';

  @override
  String get reminderBeforeTitle => 'Antes do horário marcado';

  @override
  String get reminderDailyTitle => 'Resumo do dia às 9h';

  @override
  String get reminderDailySubtitle => 'O que tem para hoje';

  @override
  String get reminderPendingTitle => 'OS paradas';

  @override
  String get reminderPendingSubtitle => 'Orçamentos sem resposta há 7 dias';

  @override
  String get reminderInactivityTitle => 'Se eu ficar dias sem abrir o app';

  @override
  String reminderMinutesValue(int minutes) {
    return '$minutes min';
  }

  @override
  String reminderHoursValue(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'horas',
      one: 'hora',
    );
    return '$hours $_temp0';
  }

  @override
  String get catalogSubtitle => 'O que você coloca nas OS';

  @override
  String catalogKindWithCount(String kind, int count) {
    return '$kind ($count)';
  }

  @override
  String get catalogTip =>
      'Dica: dá para cadastrar direto na OS, digitando o nome na busca.';

  @override
  String get teamTitle => 'Equipe';

  @override
  String teamSummary(String people, String invites) {
    return '$people e $invites';
  }

  @override
  String teamPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String teamInvitesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites',
      one: '1 convite',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteWaitingLabel => 'Convite esperando';

  @override
  String teamInviteWaitingText(String name, String expiry) {
    return '$name ainda não entrou. $expiry';
  }

  @override
  String teamInviteExpiresInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'O convite vence em $count dias.',
      one: 'O convite vence em 1 dia.',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteExpiresToday => 'O convite vence hoje.';

  @override
  String get teamInviteExpired => 'O convite venceu.';

  @override
  String get teamResendInvite => 'Reenviar convite';

  @override
  String get teamWaitingSection => 'Esperando entrar';

  @override
  String get teamMembersSection => 'Na equipe';

  @override
  String teamInviteSent(String expiry) {
    return 'Convite enviado · $expiry';
  }

  @override
  String teamInviteDueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vence em $count dias',
      one: 'vence em 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteDueToday => 'vence hoje';

  @override
  String get teamInviteDueExpired => 'venceu';

  @override
  String teamYou(String name) {
    return '$name (você)';
  }

  @override
  String get teamInviteAnother => 'Convidar outra pessoa';

  @override
  String get teamInviteFirst => 'Convidar uma pessoa';

  @override
  String get roleShortAdmin => 'vê e muda tudo';

  @override
  String get roleShortSupervisor => 'coordena a equipe, não vê preços';

  @override
  String get roleShortManager => 'vê faturamento e custos';

  @override
  String get roleShortConsultant => 'faz orçamentos, vê só as suas OS';

  @override
  String get roleShortTechnician => 'faz os serviços, não vê preços';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get checklistsSubtitle => 'Perguntas que o técnico responde na OS';

  @override
  String get checklistsYours => 'Seus checklists';

  @override
  String get checklistsReady => 'Prontos para usar';

  @override
  String checklistQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perguntas',
      one: '1 pergunta',
    );
    return '$_temp0';
  }

  @override
  String get checklistWithPhotos => 'com fotos';

  @override
  String get checklistOff => 'Desligado';

  @override
  String get checklistUse => 'Usar';

  @override
  String get checklistNew => 'Novo checklist';

  @override
  String get checklistsEmpty =>
      'Nenhum checklist ainda. Crie um ou use um pronto.';

  @override
  String get noticesTitle => 'Avisos';

  @override
  String noticesNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novos',
      one: '1 novo',
    );
    return '$_temp0';
  }

  @override
  String get noticesMarkAllRead => 'Marcar todos como lidos';

  @override
  String get noticesSectionNew => 'Novos';

  @override
  String get noticesSectionBefore => 'Antes';

  @override
  String get noticesEmpty => 'Nenhum aviso por enquanto.';

  @override
  String get timeAgoNow => 'agora';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count minutos',
      one: 'há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String contractsSubtitle(String order) {
    return '$order que se repetem sozinhas';
  }

  @override
  String get contractsTabActive => 'Ativos';

  @override
  String get contractsTabEnded => 'Encerrados';

  @override
  String contractEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A cada $count dias',
      one: 'Todo dia',
    );
    return '$_temp0';
  }

  @override
  String contractEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A cada $count semanas',
      one: 'Toda semana',
    );
    return '$_temp0';
  }

  @override
  String contractEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A cada $count meses',
      one: 'Todo mês',
    );
    return '$_temp0';
  }

  @override
  String contractEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A cada $count anos',
      one: 'Todo ano',
    );
    return '$_temp0';
  }

  @override
  String contractNextOrderOn(String date, String order) {
    return 'Próxima $order em $date';
  }

  @override
  String contractEndedOn(String date) {
    return 'Encerrado em $date';
  }

  @override
  String get contractEnded => 'Encerrado';

  @override
  String get contractsEmptyEnded => 'Nenhum contrato encerrado.';

  @override
  String contractsFooterHint(String order) {
    return 'Contratos nascem dentro de uma $order: ligue “Repetir esta $order”.';
  }

  @override
  String get orderAddResponsible => 'Responsável';

  @override
  String get orderResponsibleRemove => 'Tirar responsável';

  @override
  String get filterDone => 'Concluídas';

  @override
  String homeLateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count atrasadas',
      one: '1 atrasada',
    );
    return '$_temp0';
  }

  @override
  String get homeSearchHint => 'Buscar OS ou cliente';

  @override
  String homeSearchHintDevice(String device) {
    return 'Buscar OS, cliente ou $device';
  }

  @override
  String remainingToReceive(String amount) {
    return 'falta receber $amount';
  }

  @override
  String get firstOrderTapPlus =>
      'Toque no + para criar sua primeira OS. Leva menos de um minuto.';

  @override
  String profileButtonA11y(String company) {
    return '$company: clientes, catálogo, equipe e ajustes';
  }

  @override
  String get orderAssistantPhoto => 'Foto';

  @override
  String get orderAssistantTalkShort => 'Falar';

  @override
  String get orderCustomerRequestTitle => 'O que o cliente pediu';

  @override
  String get orderCustomerRequestPlaceholder => 'Ex.: barulho ao frear';

  @override
  String get orderDeliverySection => 'Entrega';

  @override
  String get orderDueLabel => 'Fica pronto';

  @override
  String get orderDueNone => 'Sem data';

  @override
  String get orderMoreOptions => 'Mais opções';

  @override
  String get orderMoreOptionsHint => 'Situação, visita, responsável, local';

  @override
  String get orderStatusLabel => 'Situação';

  @override
  String get orderScheduleLabel => 'Visita';

  @override
  String get orderAddressLabel => 'Local';

  @override
  String get speechHint => 'Fale o cliente, o veículo e o que vai ser feito.';

  @override
  String get speechListening => 'Ouvindo…';

  @override
  String get speechFill => 'Preencher a OS';

  @override
  String get speechUnavailable =>
      'O microfone não está liberado. Libere em Ajustes ou digite o serviço.';

  @override
  String get orderAddItemRow => 'Adicionar serviço ou peça';

  @override
  String get orderPickCustomerRow => 'Escolher cliente';

  @override
  String get newOrderButton => 'Nova OS';

  @override
  String get orderAssistantFilled =>
      'Preenchi o que está marcado. Confira e salve.';

  @override
  String get orderAssistantUndo => 'Desfazer';

  @override
  String orderNotifyNote(String status, String name) {
    return '$status. Avisar $name?';
  }

  @override
  String get orderNotifyFallbackName => 'o cliente';

  @override
  String get orderNotifyAction => 'Avisar';

  @override
  String get orderAssistantReadingPhotos => 'Lendo as fotos…';

  @override
  String get orderAssistantReadingSpeech => 'Lendo o que você falou…';

  @override
  String get orderAssistantMarked => 'Preenchido pela IA';

  @override
  String get speechCancel => 'Cancelar fala';

  @override
  String get speechStopAndFill => 'Parar e preencher a OS';

  @override
  String get speechTypeHint =>
      'Escreva o cliente, o veículo e o que vai ser feito';

  @override
  String get speechNothingHeard =>
      'Não ouvi nada. Toque em Falar e tente de novo.';

  @override
  String get orderServicesAndParts => 'Serviços e peças';

  @override
  String get orderItemKindPart => 'peça';

  @override
  String get orderActionApproveQuote => 'Aprovar orçamento';

  @override
  String get orderActionStartService => 'Começar serviço';

  @override
  String get orderActionMarkReady => 'Marcar como pronta';

  @override
  String orderDuePhrase(String when) {
    return 'Fica pronto $when';
  }

  @override
  String orderDueLatePhrase(String when) {
    return 'Era para ficar pronto $when';
  }

  @override
  String orderDayAtTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String orderChecklistProgress(int answered, int total) {
    return '$answered de $total respondidas';
  }

  @override
  String get orderCommentYou => 'Você';

  @override
  String get orderMenuChangeStatus => 'Mudar a situação';

  @override
  String get orderMenuViewPdf => 'Ver PDF';

  @override
  String get orderMenuCopyLink => 'Copiar link';

  @override
  String get orderPlaceOfService => 'Local do atendimento';

  @override
  String get orderAssistantApplied =>
      'Coloquei na OS o que está marcado. Confira.';

  @override
  String orderAssistantWhichLine(String name) {
    return 'Qual $name?';
  }

  @override
  String get orderAssistantChanged => 'Mudei a OS como você pediu. Confira.';

  @override
  String orderAssistantWhichCustomer(String name) {
    return 'Qual $name?';
  }

  @override
  String orderAssistantRegisterNewCustomer(String name) {
    return 'Cadastrar $name como cliente novo';
  }

  @override
  String get orderAssistantOtherCustomer => 'Outro cliente';

  @override
  String get orderAssistantNewCustomer => 'novo';

  @override
  String orderAssistantWhichDevice(String name) {
    return 'Qual $name?';
  }

  @override
  String orderAssistantRegisterNewDevice(String name) {
    return 'Cadastrar $name';
  }

  @override
  String orderAssistantOtherDevice(String label) {
    return 'Outro $label';
  }

  @override
  String get orderAssistantNewDevice => 'novo';

  @override
  String get pickerCustomerTitle => 'Qual cliente?';

  @override
  String pickerDeviceTitle(String device) {
    return 'Qual $device?';
  }

  @override
  String pickerDeviceSubtitle(String name) {
    return 'de $name';
  }

  @override
  String get pickerItemTitle => 'O que vai ser feito?';

  @override
  String get pickerChecklistTitle => 'Qual checklist?';

  @override
  String get pickerStatusTitle => 'Qual a situação?';

  @override
  String get pickerAssigneeTitle => 'Quem é o responsável?';

  @override
  String pickerDevicesTitle(String devices) {
    return 'Em quais $devices?';
  }

  @override
  String get pickerNewCustomer => 'Novo cliente';

  @override
  String pickerNewDevice(String device) {
    return 'Novo $device';
  }

  @override
  String get pickerNewItem => 'Novo serviço ou peça';

  @override
  String get pickerNewChecklist => 'Novo checklist';

  @override
  String pickerRegister(String query) {
    return 'Cadastrar “$query”';
  }

  @override
  String pickerNoDeviceWith(String device, String query) {
    return 'Nenhum $device com “$query”.';
  }

  @override
  String pickerNoItemWith(String query) {
    return 'Nenhum serviço ou peça com “$query”. Cadastre e ele já entra na OS.';
  }

  @override
  String pickerNoMatch(String query) {
    return 'Nada com “$query”.';
  }

  @override
  String get pickerRecent => 'Recentes';

  @override
  String get pickerAll => 'Todos';

  @override
  String get pickerSearch => 'Buscar';

  @override
  String pickerNoDevice(String device) {
    return 'Nenhum $device';
  }

  @override
  String get formMoreData => 'Mais dados';

  @override
  String get customerSaveNeedsName => 'Escreva o nome para salvar.';

  @override
  String get customerMoreDataHint => 'E-mail, CPF ou CNPJ, endereço';

  @override
  String deviceSaveNeedsField(String field) {
    return 'Preencha o campo $field para salvar.';
  }

  @override
  String deviceMoreDataHint(String brand, String category) {
    return 'Foto, $brand e $category';
  }

  @override
  String get catalogMoreDataHintFields => 'Foto e outros campos';

  @override
  String get inviteSaveNeedsContact =>
      'Escreva o e-mail ou o WhatsApp para salvar.';

  @override
  String get checklistNamePlaceholder => 'Ex.: Vistoria de entrada';

  @override
  String get checklistQuestionsTitle => 'Perguntas';

  @override
  String get checklistAddQuestion => 'Adicionar pergunta';

  @override
  String get checklistSaveNeedsNameAndQuestion =>
      'Escreva o nome e adicione uma pergunta para salvar.';

  @override
  String get checklistSaveNeedsQuestion => 'Adicione uma pergunta para salvar.';

  @override
  String get checklistNameLabel => 'Nome do checklist';

  @override
  String get checklistSave => 'Salvar checklist';

  @override
  String get checklistSaveError =>
      'Não deu para salvar o checklist. Tente de novo.';

  @override
  String get checklistStopUsing => 'Não usar na empresa';

  @override
  String get checklistUseAgain => 'Voltar a usar';

  @override
  String get checklistDelete => 'Apagar checklist';

  @override
  String get checklistDeleteTitle => 'Apagar este checklist?';

  @override
  String checklistDeleteMessage(String name) {
    return '“$name” sai da lista e não aparece mais nas OS novas.';
  }

  @override
  String get checklistQuestionNew => 'Nova pergunta';

  @override
  String get checklistQuestion => 'Pergunta';

  @override
  String get checklistQuestionPlaceholder => 'Ex.: Os pneus estão bons?';

  @override
  String get checklistAnswerType => 'Tipo de resposta';

  @override
  String get checklistOptions => 'Opções';

  @override
  String get checklistOptionsPlaceholder => 'Ex.: Bom\nRegular\nRuim';

  @override
  String get checklistQuestionRequiredHint =>
      'Não deixa concluir sem responder';

  @override
  String get checklistQuestionAllowPhotos => 'Pode pôr foto';

  @override
  String get checklistQuestionDelete => 'Apagar pergunta';

  @override
  String get checklistQuestionNeedsLabel =>
      'Escreva a pergunta para continuar.';

  @override
  String get checklistQuestionNeedsOptions =>
      'Escreva pelo menos 2 opções, uma por linha.';

  @override
  String get checklistQuestionRequiredShort => 'obrigatória';

  @override
  String get checklistQuestionWithPhoto => 'com foto';

  @override
  String get formItemTypeText => 'Texto';

  @override
  String get formItemTypeNumber => 'Número';

  @override
  String get formItemTypeBoolean => 'Sim ou não';

  @override
  String get formItemTypeSelect => 'Escolher uma opção';

  @override
  String get formItemTypeChecklist => 'Escolher várias opções';

  @override
  String get formItemTypePhoto => 'Só foto';

  @override
  String get pickerNewItemKind => 'O que vai cadastrar?';

  @override
  String get pickerNewItemServiceHint => 'Mão de obra que você faz';

  @override
  String get pickerNewItemProductHint => 'Peça ou material que você vende';

  @override
  String receiveSubtitleWithDiscount(
    String customer,
    String total,
    String discount,
  ) {
    return '$customer · total $total · desconto $discount';
  }

  @override
  String receiveSubtitleNoCustomerWithDiscount(String total, String discount) {
    return 'total $total · desconto $discount';
  }

  @override
  String chargeSendLinkTo(String customer) {
    return 'Mandar link para $customer pagar';
  }

  @override
  String get chargeSendLink => 'Mandar link para pagar';

  @override
  String chargeLinkSentOn(String date) {
    return 'Link mandado em $date';
  }

  @override
  String get chargeLinkSent => 'Link mandado';

  @override
  String chargeLinkExpiredOn(String date) {
    return 'O link venceu em $date';
  }

  @override
  String chargeNotPaidYet(String customer, String value) {
    return '$customer ainda não pagou os $value.';
  }

  @override
  String chargeNotPaidYetNoCustomer(String value) {
    return 'Os $value ainda não foram pagos.';
  }

  @override
  String chargeLinkValidUntil(String date) {
    return 'O link vale até $date.';
  }

  @override
  String get chargeRemindWhatsApp => 'Lembrar pelo WhatsApp também';

  @override
  String get chargeReceivedOtherWay => 'Recebi de outro jeito';

  @override
  String get chargeLinkSection => 'Link para pagar';

  @override
  String get chargePaymentLink => 'Link de pagamento';

  @override
  String chargeWaitingFor(String customer) {
    return 'Esperando $customer pagar';
  }

  @override
  String get chargeWaitingPayment => 'Esperando o pagamento';

  @override
  String chargeExpiredOn(String date) {
    return 'Venceu em $date';
  }

  @override
  String chargeMethodsUntil(String date) {
    return 'Pix, boleto ou cartão · até $date';
  }

  @override
  String chargeInstallmentsUntil(int count, String date) {
    return '${count}x no cartão · até $date';
  }

  @override
  String chargeInstallmentsPaid(int paid, int count) {
    return '$paid de $count parcelas pagas';
  }

  @override
  String chargeUntilReplaced(String date) {
    return 'até $date · o link novo cancela este';
  }

  @override
  String get chargeOrderChanged => 'A OS mudou de valor';

  @override
  String chargeNowMissing(String remaining, String value) {
    return 'Agora falta $remaining, mas o link ainda cobra $value.';
  }

  @override
  String chargeGenerateNew(String value) {
    return 'Gerar link novo de $value';
  }

  @override
  String chargeKeepLink(String value) {
    return 'Manter o link de $value';
  }

  @override
  String get chargeSendAgainWhatsApp => 'Mandar de novo pelo WhatsApp';

  @override
  String get chargeCopyLink => 'Copiar o link';

  @override
  String get chargeLinkCopied => 'Link copiado';

  @override
  String get chargeCancelLink => 'Cancelar o link';

  @override
  String get chargeLinkTitle => 'Link para pagar';

  @override
  String chargeLinkIntro(String name) {
    return '$name recebe o link e paga por Pix, boleto ou cartão.';
  }

  @override
  String get chargeLinkIntroNoName =>
      'O cliente recebe o link e paga por Pix, boleto ou cartão.';

  @override
  String get chargeSplitQuestion => 'Parcelar no cartão?';

  @override
  String get chargeSplitOnCard => 'Parcelar no cartão';

  @override
  String get chargeSplitNo => 'Não';

  @override
  String get profileEditTitle => 'Seu perfil';

  @override
  String get profileChangePhoto => 'Trocar foto';

  @override
  String profileSignedInAs(String email) {
    return 'Você entra com $email';
  }

  @override
  String get profileNameRequired => 'Digite seu nome';

  @override
  String get profileNamePlaceholder => 'Ex.: João da Silva';

  @override
  String get financialWhichOrder => 'Qual OS?';

  @override
  String get reportThisWeek => 'Esta semana';

  @override
  String get reportThisMonth => 'Este mês';

  @override
  String get reportThisYear => 'Este ano';

  @override
  String get reportPickDates => 'Escolher datas';

  @override
  String get reportSeeOtherPeriod => 'Ver outro período';

  @override
  String get reportStarts => 'Começa';

  @override
  String get reportEnds => 'Termina';

  @override
  String get reportWhichPeriod => 'Que período?';

  @override
  String get agendaShowMonth => 'Ver o mês';

  @override
  String get agendaShowWeek => 'Ver a semana';

  @override
  String agendaWhose(String name) {
    return 'De quem: $name';
  }

  @override
  String get agendaWhoseTitle => 'De quem mostrar?';

  @override
  String agendaOnlyOf(String name) {
    return 'Só de $name';
  }

  @override
  String get agendaShowAll => 'Mostrar todos';

  @override
  String agendaWithPerson(String name) {
    return 'com $name';
  }

  @override
  String agendaDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count marcados',
      one: '1 marcado',
    );
    return '$_temp0';
  }

  @override
  String agendaDayHasOrders(String day) {
    return '$day, tem serviço marcado';
  }

  @override
  String get agendaPreviousWeek => 'Semana anterior';

  @override
  String get agendaNextWeek => 'Próxima semana';

  @override
  String get agendaPreviousMonth => 'Mês anterior';

  @override
  String get agendaNextMonth => 'Próximo mês';

  @override
  String noticeCommented(String name, String text) {
    return '$name comentou: “$text”';
  }

  @override
  String noticePaymentReceived(String amount) {
    return 'Pagamento de $amount recebido';
  }

  @override
  String get contractNew => 'Novo contrato';

  @override
  String get orderRepeatRow => 'Repetir';

  @override
  String contractsEmptyAdd(String order) {
    return 'Toque em + para criar uma $order que se repete sozinha.';
  }

  @override
  String get contractRepeats => 'Repete';

  @override
  String get contractRepeatsTitle => 'Com que frequência?';

  @override
  String get contractStarts => 'Começa';

  @override
  String get contractEnds => 'Termina';

  @override
  String get contractNeverEnds => 'Nunca';

  @override
  String get contractNoEndDate => 'Sem data para terminar';

  @override
  String contractAutoCreate(String order) {
    return 'Criar a $order sozinha';
  }

  @override
  String contractAutoCreateHint(String order) {
    return 'Ligado, a $order nova aparece sozinha na data. Desligado, você só recebe o aviso.';
  }

  @override
  String get contractRemind => 'Avisar antes';

  @override
  String get contractRemindTitle => 'Avisar quanto tempo antes?';

  @override
  String contractRemindDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias antes',
      one: '1 dia antes',
      zero: 'No dia',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSegmentHint =>
      'Assim o app já vem com os serviços e checklists do seu trabalho.';

  @override
  String get onboardingSpecialtiesHint =>
      'Marque o que fizer sentido. Dá para mudar depois.';

  @override
  String get emailLoginTitle => 'Entrar com e-mail';

  @override
  String get emailLoginEmailRequired => 'Escreva o seu e-mail.';

  @override
  String get emailLoginEmailInvalid => 'Esse e-mail não parece certo. Confira.';

  @override
  String get emailLoginPasswordRequired => 'Escreva a sua senha.';

  @override
  String get emailLoginWrongCredentials =>
      'E-mail ou senha não conferem. Confira e tente de novo.';

  @override
  String get emailLoginNoInternet =>
      'Sem internet. Confira a conexão e tente de novo.';

  @override
  String get emailLoginTooManyAttempts =>
      'Muitas tentativas. Espere um pouco e tente de novo.';

  @override
  String get emailLoginGenericError => 'Não deu para entrar. Tente de novo.';

  @override
  String get emailLoginSigningIn => 'Entrando…';

  @override
  String get resetPasswordTitle => 'Trocar a senha';

  @override
  String get resetPasswordMessage => 'Vamos mandar um link para o seu e-mail.';

  @override
  String get resetPasswordError =>
      'Não deu para mandar o e-mail. Confira o endereço e tente de novo.';

  @override
  String get inviteTitleMany => 'Você recebeu convites';

  @override
  String get inviteManyHint => 'Toque num convite para ver e entrar na equipe.';

  @override
  String get inviteCodeTitle => 'Qual é o código do convite?';

  @override
  String checklistRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count',
      one: 'Falta 1',
      zero: 'Tudo respondido',
    );
    return '$_temp0';
  }

  @override
  String get checklistQuestionNext => 'Próxima';

  @override
  String get checklistQuestionDone => 'Pronto';

  @override
  String get checklistSkipForNow => 'Pular por agora';

  @override
  String get checklistPreviousQuestion => 'Voltar à anterior';

  @override
  String get checklistQuestionRequired => 'Obrigatória';

  @override
  String get checklistPickFromGallery => 'Escolher da galeria';

  @override
  String get checklistTextPlaceholder => 'Escreva aqui';

  @override
  String get checklistStart => 'Começar';

  @override
  String get checklistFinish => 'Concluir checklist';

  @override
  String get checklistFinishAnyway => 'Concluir assim mesmo';

  @override
  String get checklistStatusDone => 'Completo';

  @override
  String get checklistNoAnswer => 'Sem resposta';

  @override
  String checklistPhotoPosition(int current, int total) {
    return '$current de $total';
  }

  @override
  String get shareTitle => 'Mandar para o cliente';

  @override
  String shareCanAll(String name, String order) {
    return '$name abre a $order pelo link, aprova e comenta.';
  }

  @override
  String shareCanApprove(String name, String order) {
    return '$name abre a $order pelo link e aprova.';
  }

  @override
  String shareCanComment(String name, String order) {
    return '$name abre a $order pelo link e comenta.';
  }

  @override
  String shareCanView(String name, String order) {
    return '$name abre a $order pelo link.';
  }

  @override
  String get shareTheCustomer => 'O cliente';

  @override
  String shareValidUntil(String date) {
    return 'Vale até $date.';
  }

  @override
  String get shareSendWhatsApp => 'Mandar pelo WhatsApp';

  @override
  String get shareSendLink => 'Mandar o link';

  @override
  String get shareSendOtherWay => 'Mandar de outro jeito';

  @override
  String get shareCopyLink => 'Copiar o link';

  @override
  String get shareLinkCopied => 'Link copiado';

  @override
  String get sharePreparing => 'Preparando o link…';

  @override
  String get shareError => 'Não deu para criar o link.';

  @override
  String get shareValidity => 'Mudar a validade';

  @override
  String get shareValidityTitle => 'Vale por quanto tempo?';

  @override
  String shareValidityDays(int count) {
    return '$count dias';
  }

  @override
  String get sharePermissionsTitle => 'O que o cliente pode fazer?';

  @override
  String get sharePermAll => 'Ver, aprovar e comentar';

  @override
  String get sharePermApprove => 'Ver e aprovar';

  @override
  String get sharePermComment => 'Ver e comentar';

  @override
  String get sharePermView => 'Só ver';

  @override
  String get shareNewLink => 'Gerar link novo';

  @override
  String get shareRevoke => 'Desativar o link';

  @override
  String shareRevokeConfirm(String order) {
    return 'O cliente não vai mais conseguir abrir a $order por este link.';
  }

  @override
  String get shareMenu => 'Opções do link';

  @override
  String get orderItemNotesPlaceholder => 'Algo a mais sobre este item';

  @override
  String get orderItemRemoveTitle => 'Tirar da OS?';

  @override
  String orderItemRemoveMessage(String name) {
    return '\"$name\" sai da OS e do total.';
  }

  @override
  String get orderItemQuantityInvalid => 'Coloque pelo menos 1.';

  @override
  String orderPhotoShareText(String order) {
    return 'Foto da $order';
  }

  @override
  String get orderPhotoShareError =>
      'Não deu para compartilhar a foto. Tente de novo.';

  @override
  String get orderPhotoDeleteTitle => 'Apagar esta foto?';

  @override
  String get orderPhotoDeleted => 'Foto apagada';

  @override
  String get orderPhotoDeleteError =>
      'Não deu para apagar a foto. Tente de novo.';

  @override
  String get orderPhotoCoverSet => 'Foto definida como capa';

  @override
  String get orderDocumentTypeTitle => 'Que documento é este?';

  @override
  String get shareWhatCanDo => 'O que o cliente pode fazer';

  @override
  String get orderPhotoDelete => 'Apagar foto';

  @override
  String get contractStopRepeating => 'Parar de repetir';

  @override
  String get contractStopRepeatingTitle => 'Parar de repetir?';

  @override
  String get contractStopRepeatingMessage =>
      'As próximas OS não serão mais criadas. As que já existem continuam.';

  @override
  String get commentsEmpty => 'Ninguém comentou ainda.';

  @override
  String get commentsTeamOnly => 'Só a equipe vê';

  @override
  String get commentsCustomerSees => 'O cliente também vê, pelo link da OS';

  @override
  String get commentsCustomerHidden => 'O cliente não vê';

  @override
  String get commentTeamOnlyTag => 'só a equipe';

  @override
  String get commentSendError => 'Não deu para enviar. Tente de novo.';

  @override
  String get inviteSheetTitle => 'Convite para a equipe';

  @override
  String inviteShareSentence(int days) {
    return 'Mande este código para a pessoa entrar na equipe. Vale por $days dias.';
  }

  @override
  String get inviteShareButton => 'Compartilhar convite';

  @override
  String get inviteSendWhatsApp => 'Mandar pelo WhatsApp';

  @override
  String get inviteCopyCode => 'Copiar código';

  @override
  String get inviteMenu => 'Mais opções do convite';

  @override
  String get teamCancelInvite => 'Cancelar convite';

  @override
  String teamCancelInviteQuestion(String name) {
    return 'Cancelar o convite de $name?';
  }

  @override
  String get teamCancelInviteMessage => 'O código para de funcionar.';

  @override
  String get teamKeepInvite => 'Manter convite';

  @override
  String get teamInviteCanceled => 'Convite cancelado';

  @override
  String teamInviteExpiredQuestion(String name) {
    return 'O convite de $name venceu';
  }

  @override
  String get teamInviteExpiredMessage =>
      'O código não funciona mais. Convide de novo para mandar um código novo.';

  @override
  String get teamInviteAgain => 'Convidar de novo';

  @override
  String teamMemberRoleQuestion(String name) {
    return 'O que $name pode fazer?';
  }

  @override
  String get teamRemoveMember => 'Tirar da equipe';

  @override
  String teamRemoveMemberQuestion(String name) {
    return 'Tirar $name da equipe?';
  }

  @override
  String get teamRemoveMemberMessage =>
      'A pessoa perde o acesso às OS da empresa.';

  @override
  String get teamRoleChanged => 'Papel trocado';

  @override
  String teamMemberRemoved(String name) {
    return '$name saiu da equipe';
  }

  @override
  String get integrationsAiSection => 'ChatGPT e Claude';

  @override
  String get integrationsEmptyLine =>
      'Nenhuma conexão ainda. Toque em + para ligar o PraticOS ao ChatGPT ou ao Claude.';

  @override
  String get integrationsRevoked => 'Conexão desligada';

  @override
  String get asaasConnectHeadline =>
      'Conecte a conta Asaas para receber Pix, boleto e cartão pela OS.';

  @override
  String get asaasConnectedHeadline =>
      'Os pagamentos pelo Asaas dão baixa na OS sozinhos.';

  @override
  String get asaasConnecting => 'Conectando…';

  @override
  String get asaasConnectedToast => 'Conta Asaas conectada';

  @override
  String get asaasDisconnectedToast => 'Conta Asaas desconectada';

  @override
  String get asaasMenu => 'Mais opções do Asaas';

  @override
  String get nfseErrorAsaasValidation =>
      'O Asaas recusou os dados da nota. Confira o CPF/CNPJ e o endereço do cliente e a configuração fiscal.';

  @override
  String get nfseErrorNotEnabled =>
      'A nota fiscal não está ligada para esta empresa.';

  @override
  String get nfseErrorNotReady =>
      'Falta configurar a nota fiscal. Veja em Integrações, Asaas.';

  @override
  String get nfseErrorOrderNotAllowed =>
      'Esta OS não pode ter nota: ela é orçamento ou foi cancelada.';

  @override
  String get nfseErrorNoServices =>
      'Esta OS não tem serviço com valor. Só serviços entram na nota.';

  @override
  String get nfseErrorOrderHasInvoice =>
      'Esta OS já tem nota. Cancele a nota antes de emitir outra.';

  @override
  String get nfseErrorOrderNotOfCustomer =>
      'Todas as OS da nota precisam ser do mesmo cliente.';

  @override
  String get nfseErrorNotFound => 'Não achamos esta nota. Atualize a tela.';

  @override
  String get nfseErrorNotCancelable =>
      'Esta nota não pode ser cancelada agora.';

  @override
  String get nfseErrorCancelNotSupported =>
      'Esta prefeitura não deixa cancelar a nota por aqui. Cancele no site da prefeitura.';

  @override
  String get nfseErrorInvalidDate =>
      'A data da nota não pode ser antes de hoje.';

  @override
  String get nfseErrorInvalidFiscalInfo =>
      'O Asaas não aceitou os dados fiscais. Confira com o seu contador.';

  @override
  String get nfseErrorReconnectNeeded => 'Reconecte o Asaas para emitir notas.';

  @override
  String get nfseErrorSetupNeeded =>
      'A conta do Asaas mudou. Configure a nota fiscal de novo.';

  @override
  String get nfseErrorOtherAccount =>
      'Esta nota é de outra conta do Asaas. Cancele por lá.';

  @override
  String get nfseConflictNotice =>
      'Nota emitida fora do PraticOS, confira no Asaas.';

  @override
  String get nfseStatusWaiting => 'Aguardando prefeitura';

  @override
  String nfseStatusScheduledFor(String date) {
    return 'Será emitida em $date';
  }

  @override
  String get nfseStatusIssued => 'Emitida';

  @override
  String nfseStatusIssuedNumber(String number) {
    return 'Emitida · nº $number';
  }

  @override
  String get nfseStatusCanceling => 'Cancelando';

  @override
  String get nfseStatusCancelDenied => 'Cancelamento recusado';

  @override
  String get nfseStatusCanceled => 'Cancelada';

  @override
  String get nfseStatusError => 'Erro na prefeitura';

  @override
  String get nfseRowTitle => 'Nota fiscal';

  @override
  String get nfseIssueAction => 'Emitir nota fiscal';

  @override
  String get nfseIssueSeveralAction => 'Emitir uma nota com várias OS';

  @override
  String get nfseValueLabel => 'Valor da nota';

  @override
  String get nfseOnlyServicesNote =>
      'Só os serviços entram na nota. Peças e produtos ficam de fora.';

  @override
  String get nfseDiscountNote =>
      'O desconto foi repartido entre serviços e peças.';

  @override
  String nfseOrderLine(String number, String value) {
    return 'OS $number · $value';
  }

  @override
  String get nfseDescriptionLabel => 'O que aparece na nota';

  @override
  String get nfseDateLabel => 'Data da nota';

  @override
  String get nfseServiceRow => 'Serviço da prefeitura';

  @override
  String get nfseTaxIdHint =>
      'A nota precisa do CPF ou CNPJ do cliente. Fica salvo no cadastro dele.';

  @override
  String get nfseTaxIdMissing => 'Falta o CPF ou CNPJ do cliente';

  @override
  String get nfseNothingToIssue => 'Nada para emitir: a nota ficaria sem valor';

  @override
  String nfseAlreadyIssued(String numbers) {
    return 'A OS $numbers já tem nota';
  }

  @override
  String get nfseSent => 'Nota enviada para a prefeitura';

  @override
  String nfseSeveralIntro(int count, String name, String numbers) {
    return 'Uma nota para $count OS de $name: $numbers.';
  }

  @override
  String get nfseNotReadyTitle => 'Falta configurar a nota fiscal';

  @override
  String get nfseNotReadyAdmin =>
      'Antes da primeira nota, preencha os dados fiscais da empresa e o serviço da nota.';

  @override
  String get nfseNotReadyOther =>
      'Peça ao dono da empresa para configurar a nota fiscal em Integrações, Asaas.';

  @override
  String get nfseSetupAction => 'Configurar';

  @override
  String get nfsePickOrdersTitle => 'Quais OS entram na nota?';

  @override
  String nfsePickOrderSubtitle(String value, String date) {
    return 'Serviços $value · $date';
  }

  @override
  String get nfseNoOrdersToPick =>
      'Nenhuma OS deste cliente pode ter nota agora';

  @override
  String get nfseHeadWaiting => 'A prefeitura ainda está analisando a nota.';

  @override
  String nfseHeadScheduled(String date) {
    return 'A nota vai para a prefeitura em $date.';
  }

  @override
  String get nfseHeadIssued => 'A nota foi emitida.';

  @override
  String get nfseHeadError =>
      'A prefeitura recusou a nota. Confira os dados fiscais e o cadastro do cliente e emita de novo.';

  @override
  String get nfseHeadCanceling => 'A prefeitura está cancelando a nota.';

  @override
  String get nfseHeadCancelDenied =>
      'A prefeitura não aceitou cancelar a nota. Ela continua valendo.';

  @override
  String get nfseHeadCanceled => 'A nota foi cancelada.';

  @override
  String get nfseReasonLabel => 'Motivo dado pela prefeitura';

  @override
  String get nfseNumberLabel => 'Número';

  @override
  String get nfseOrdersLabel => 'OS na nota';

  @override
  String get nfseOpenPdf => 'Abrir PDF da nota';

  @override
  String get nfseOpenXml => 'Abrir XML da nota';

  @override
  String get nfseMenu => 'Mais opções da nota';

  @override
  String get nfseCancelAction => 'Cancelar nota';

  @override
  String nfseCancelQuestion(String value) {
    return 'Cancelar a nota de $value?';
  }

  @override
  String get nfseCancelMessage =>
      'A prefeitura recebe o pedido e a nota deixa de valer. O pagamento da OS continua como está.';

  @override
  String get nfseKeep => 'Manter nota';

  @override
  String get nfseCancelRequested => 'Pedido de cancelamento enviado';

  @override
  String get nfseCancelAtCityTitle => 'Cancele no site da prefeitura';

  @override
  String get nfseCancelAtCityMessage =>
      'Esta prefeitura não deixa cancelar a nota por aqui. Cancele no site dela e depois marque aqui que já cancelou.';

  @override
  String get nfseCanceledAtCity => 'Já cancelei na prefeitura';

  @override
  String get nfseCanceledToast => 'Nota cancelada';

  @override
  String get nfseSetupReady => 'Pronta para emitir';

  @override
  String get nfseSetupMissingShort => 'Falta configurar';

  @override
  String get nfseSetupHeadReady => 'Tudo pronto. A nota sai pela OS, no “…”.';

  @override
  String nfseSetupHeadMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count passos para emitir notas.',
      one: 'Falta 1 passo para emitir notas.',
    );
    return '$_temp0';
  }

  @override
  String get nfseSetupFiscalInfo => 'Dados fiscais da empresa';

  @override
  String get nfseSetupCityAccess => 'Acesso à prefeitura';

  @override
  String get nfseSetupService => 'Serviço da nota';

  @override
  String get nfseSetupDone => 'Pronto';

  @override
  String get nfseSetupTodo => 'Falta';

  @override
  String get nfseSetupNext => 'Configurar o que falta';

  @override
  String get nfseCityAccessCertificate =>
      'A prefeitura pede o certificado digital da empresa. Envie no painel do Asaas, em Notas fiscais.';

  @override
  String get nfseCityAccessPassword =>
      'A prefeitura pede o usuário e a senha do site dela. Informe no painel do Asaas, em Notas fiscais.';

  @override
  String get nfseCityAccessToken =>
      'A prefeitura pede um código de acesso. Informe no painel do Asaas, em Notas fiscais.';

  @override
  String get nfseCityAccessFirst =>
      'Preencha primeiro os dados fiscais: aí dá para saber o que a prefeitura pede.';

  @override
  String get nfseCityAccessNone => 'Esta prefeitura não pede acesso extra.';

  @override
  String get nfseOpenAsaasPanel => 'Abrir o painel do Asaas';

  @override
  String get nfseCheckAgain => 'Já enviei, conferir de novo';

  @override
  String get nfseNoCancelNote =>
      'Esta prefeitura não deixa cancelar a nota pelo app: o cancelamento é feito no site dela.';

  @override
  String get nfseFiscalNote =>
      'Esses dados ficam no Asaas e vão em todas as notas. Na dúvida, peça ao seu contador.';

  @override
  String get nfseFiscalEmail => 'E-mail para receber as notas';

  @override
  String get nfseFiscalMunicipalInscription => 'Inscrição municipal';

  @override
  String get nfseFiscalSimples => 'Empresa do Simples Nacional';

  @override
  String get nfseFiscalCnae => 'CNAE (se o contador pedir)';

  @override
  String get nfseFiscalSpecialRegime => 'Regime especial';

  @override
  String get nfseFiscalSpecialRegimeQuestion => 'Qual é o regime especial?';

  @override
  String get nfseFiscalServiceListItem => 'Item da lista de serviço';

  @override
  String get nfseFiscalEmailMissing => 'Escreva um e-mail válido para salvar.';

  @override
  String get nfseFiscalSaved => 'Dados fiscais salvos';

  @override
  String get nfseServicePickTitle => 'Qual serviço você presta?';

  @override
  String get nfseServiceSearch => 'Busque pelo nome, ex.: manutenção';

  @override
  String get nfseServiceSearchEmpty =>
      'Nada encontrado. Tente outra palavra ou digite o código.';

  @override
  String get nfseServiceTypeCode => 'Digitar o código';

  @override
  String get nfseServiceCode => 'Código do serviço na prefeitura';

  @override
  String get nfseServiceName => 'Nome do serviço';

  @override
  String get nfseServiceMissing =>
      'Escolha o serviço da prefeitura para salvar.';

  @override
  String get nfseIss => 'ISS (%)';

  @override
  String get nfseRetainIss => 'O cliente retém o ISS';

  @override
  String get nfseOtherTaxes => 'Outros impostos (%)';

  @override
  String get nfseTaxesNote =>
      'Use o que a prefeitura e o seu contador indicarem. Deixe 0 no que não se aplica.';

  @override
  String get nfseTemplateLabel => 'Texto da nota';

  @override
  String nfseTemplateHint(Object os, Object servicos) {
    return '$servicos vira os serviços da OS e $os os números das OS.';
  }

  @override
  String get nfseServiceSaved => 'Serviço da nota salvo';

  @override
  String get nfseAutoIssueRow => 'Emitir a nota';

  @override
  String get nfseAutoIssueQuestion => 'Quando emitir a nota?';

  @override
  String get nfseAutoIssueManual => 'Só quando eu pedir';

  @override
  String get nfseAutoIssuePaid => 'Quando a OS for paga';

  @override
  String get nfseAutoIssueCompleted => 'Quando a OS for concluída';

  @override
  String get nfseAutoIssueManualHint =>
      'Você emite pelo menu da OS ou do cliente.';

  @override
  String get nfseAutoIssuePaidHint =>
      'Sai sozinha quando o cliente termina de pagar a OS.';

  @override
  String get nfseAutoIssueCompletedHint =>
      'Sai sozinha quando a OS é concluída, antes de receber.';

  @override
  String get nfseHeadAutoError =>
      'A nota não saiu sozinha. Corrija o motivo abaixo e emita pelo menu da OS.';

  @override
  String get nfseAutoReasonLabel => 'Por que não saiu';

  @override
  String get nfseAutoErrorTaxId => 'O cliente não tem CPF ou CNPJ no cadastro.';
}
