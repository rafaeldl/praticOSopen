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
  String get collaborators => 'Pessoas na equipe';

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
  String get toReceive => 'Falta pagar';

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
  String get paymentExceedsBalance =>
      'O valor passa do que falta receber. Confira e tente de novo.';

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
  String get switchCompany => 'Trocar de conta';

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
  String get companyData => 'Dados para o cliente';

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
  String get selectCompany => 'Escolher conta';

  @override
  String get companyNoName => 'Conta sem nome';

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
  String get myCompany => 'Ajustes';

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
      'Acesso total. Cuida dos ajustes, da equipe e vê todos os dados.';

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
  String get billing => 'Vendido';

  @override
  String get composition => 'Composição';

  @override
  String get customersReceived => 'Clientes que já pagaram';

  @override
  String get customersToReceive => 'Clientes com valor a pagar';

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
  String get companyNamePlaceholder => 'Nome que aparece na OS';

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
  String get importForMyCompany => 'Importar para a minha conta';

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
  String get totalBilling => 'Vendido';

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
  String get ordersToReceive => 'OS com valor a pagar';

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
    return 'Página $current de $total';
  }

  @override
  String get preparingReport => 'Preparando relatório...';

  @override
  String get appTagline => 'Sistema de Gestão de Ordens de Serviço';

  @override
  String receivedWithPercent(String percent) {
    return 'Já pago ($percent%)';
  }

  @override
  String toReceiveWithPercent(String percent) {
    return 'Falta pagar ($percent%)';
  }

  @override
  String get generatedByPraticos => 'Gerado por PraticOS';

  @override
  String get serviceDescriptionColumn => 'DESCRIÇÃO DO SERVIÇO';

  @override
  String get descriptionColumn => 'DESCRIÇÃO';

  @override
  String get unitShort => 'UNIT.';

  @override
  String get alreadyPaid => 'Já pago';

  @override
  String get remainingBalance => 'SALDO RESTANTE';

  @override
  String get totalToPay => 'TOTAL A PAGAR';

  @override
  String get photosAvailableDigitally => 'Fotos disponíveis no sistema digital';

  @override
  String attachedPhotosCount(int count) {
    return 'Fotos Anexadas ($count)';
  }

  @override
  String get photoRecord => 'REGISTRO FOTOGRÁFICO';

  @override
  String get partsAndProducts => 'PEÇAS E PRODUTOS';

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
  String get notSelected => 'Não selecionado';

  @override
  String formLabelWithTitle(String title) {
    return 'Formulário: $title';
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
      'Não dá para tirar o único administrador. Torne outra pessoa administrador antes.';

  @override
  String get cannotChangeOnlyAdminRole =>
      'Não é possível alterar o perfil do único administrador. Promova outro colaborador a administrador antes de alterar este.';

  @override
  String get cannotChangeOwner =>
      'Não dá para mudar o perfil nem tirar o dono da empresa.';

  @override
  String get teamActionNotAllowed =>
      'Só o dono ou um administrador pode mudar a equipe.';

  @override
  String get teamActionFailed =>
      'Não deu para salvar a mudança na equipe. Tente de novo.';

  @override
  String get cannotRemoveSelf => 'Você não pode tirar a si mesmo da equipe.';

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
  String get pdfTermsAndConditions => 'Termos e Condições';

  @override
  String get pdfCompanySignature => 'Responsável';

  @override
  String get pdfClientSignature => 'Cliente';

  @override
  String get pdfTechnician => 'Técnico';

  @override
  String get pdfCreatedDate => 'Criada';

  @override
  String get pdfCompletedDate => 'Concluída';

  @override
  String get pdfIssuedDate => 'Emitida';

  @override
  String get pdfServicesSubtotal => 'Subtotal Serviços';

  @override
  String get pdfPartsSubtotal => 'Subtotal Peças';

  @override
  String get pdfPaid => 'Pago';

  @override
  String get pdfUnitValue => 'Valor Unit.';

  @override
  String get pdfServiceType => 'Serviço';

  @override
  String get pdfProductType => 'Peça';

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
      'Escaneie o QR Code para acompanhar esta ordem de serviço';

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
      'Peça ao administrador da conta para mudar de plano.';

  @override
  String get subscriptionUnavailable =>
      'As assinaturas não estão disponíveis agora. Tente novamente mais tarde.';

  @override
  String planActiveMessage(String plan) {
    return 'Seu plano $plan está ativo.';
  }

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
  String searchCustomerPlaceholder(String serial) {
    return 'Buscar por nome, telefone ou $serial';
  }

  @override
  String get customerNamePlaceholder => 'Ex.: Ana Ribeiro';

  @override
  String get customerNameRequired => 'Digite o nome do cliente';

  @override
  String get orderMissingWhatsapp => 'WhatsApp';

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
      other: '$count OS abertas',
      one: '1 OS aberta',
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
  String serviceNameHint(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Troca de óleo',
      'hvac': 'Limpeza do split',
      'smartphones': 'Troca de tela',
      'computers': 'Formatação',
      'appliances': 'Conserto de geladeira',
      'electrical': 'Troca de disjuntor',
      'plumbing': 'Conserto de vazamento',
      'security': 'Instalação de câmera',
      'solar': 'Limpeza das placas',
      'printers': 'Troca de toner',
      'bicycles': 'Revisão completa',
      'software_it': 'Suporte técnico mensal',
      'other': 'Manutenção',
    });
    return 'Ex.: $_temp0';
  }

  @override
  String productNameHint(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Filtro de óleo',
      'hvac': 'Capacitor',
      'smartphones': 'Tela',
      'computers': 'Memória RAM',
      'appliances': 'Resistência',
      'electrical': 'Disjuntor',
      'plumbing': 'Registro',
      'security': 'Câmera',
      'solar': 'Inversor',
      'printers': 'Toner',
      'bicycles': 'Câmara de ar',
      'software_it': 'Licença Microsoft 365',
      'other': 'Peça de reposição',
    });
    return 'Ex.: $_temp0';
  }

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
  String orderItemSearchPlaceholder(String product) {
    return 'Buscar serviço ou $product';
  }

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
  String get orderItemDescription => 'Descrição';

  @override
  String get orderItemDescriptionHint =>
      'Opcional: o que é só deste item, como a peça ou o lado. Aparece na OS e no PDF.';

  @override
  String get orderItemQuantity => 'Quantidade';

  @override
  String get orderItemLess => 'Menos um';

  @override
  String get orderItemMore => 'Mais um';

  @override
  String get orderItemRemove => 'Tirar da OS';

  @override
  String get orderItemDiscard => 'Não adicionar';

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
  String get yourCompany => 'Dados para o cliente';

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
  String get financialAlreadyPaid => 'Já pago';

  @override
  String financialEmptyReceived(String month) {
    return 'Nenhum pagamento em $month.';
  }

  @override
  String get financialReceivable => 'A receber';

  @override
  String get financialInProgress => 'Em andamento';

  @override
  String get financialSold => 'Vendido';

  @override
  String get financialToday => 'Hoje';

  @override
  String get financialReceivableCompleted => 'Serviços concluídos';

  @override
  String get financialReceivableOpen => 'Serviços em aberto';

  @override
  String get financialNextCharge => 'Próxima cobrança';

  @override
  String get financialAlreadyReceived => 'Já recebi';

  @override
  String financialNextChargeMessage(String name, String amount, String date) {
    return '$name deve $amount desde $date';
  }

  @override
  String get financialSendCharge => 'Mandar cobrança';

  @override
  String financialReceivableSummary(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes',
      one: '1 cliente',
    );
    return '$amount de $_temp0';
  }

  @override
  String financialInProgressSummary(String amount, int count) {
    return '$amount em $count OS';
  }

  @override
  String financialMonthAmount(String month, String amount) {
    return '$month · $amount';
  }

  @override
  String financialSince(String date) {
    return 'desde $date';
  }

  @override
  String financialOrderDate(int number, String date) {
    return 'OS $number · $date';
  }

  @override
  String get financialEmptyReceivable => 'Ninguém com valor a receber.';

  @override
  String get financialEmptyInProgress =>
      'Nenhuma OS em andamento com valor a receber.';

  @override
  String get financialToReceive => 'Falta receber';

  @override
  String financialOrderSince(int number, String date) {
    return 'OS $number · desde $date';
  }

  @override
  String get financialOtherPeriod => 'Outro período';

  @override
  String get financialPreviousMonth => 'Mês anterior';

  @override
  String get financialNextMonth => 'Próximo mês';

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
  String get receiveMarkReceived => 'Marcar como recebido';

  @override
  String receiveReceivedFrom(String customer) {
    return 'Recebido de $customer';
  }

  @override
  String get receiveReceivedTitle => 'Recebido';

  @override
  String receiveSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A receber · $count OS',
      one: 'A receber · 1 OS',
    );
    return '$_temp0';
  }

  @override
  String receiveSummarySome(int checked, int total) {
    return 'A receber · $checked de $total OS';
  }

  @override
  String receiveSummaryOrder(String order) {
    return 'A receber · $order';
  }

  @override
  String get receiveSummaryPlain => 'A receber';

  @override
  String get receiveOrdersIncluded => 'OS incluídas';

  @override
  String receivePreviewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quita as $count OS.',
      one: 'Quita a OS.',
    );
    return '$_temp0';
  }

  @override
  String receivePreviewSettles(String numbers) {
    return 'Quita OS $numbers.';
  }

  @override
  String receivePreviewPart(String amount, String number) {
    return 'Paga $amount da OS $number.';
  }

  @override
  String receivePreviewLeft(String amount) {
    return 'Ficam $amount.';
  }

  @override
  String receiveChargeAdjusts(String customer) {
    return 'A cobrança aberta se ajusta sozinha, sem avisar $customer.';
  }

  @override
  String get receiveChargeAdjustsNoName =>
      'A cobrança aberta se ajusta sozinha, sem avisar o cliente.';

  @override
  String get chargeSend => 'Mandar cobrança';

  @override
  String get chargeSendAgain => 'Mandar de novo';

  @override
  String get chargeSendOrderLink => 'Mandar link da OS';

  @override
  String chargeDetailUntil(String value, String date) {
    return 'Cobrança de $value · vale até $date';
  }

  @override
  String chargeDetailOverdue(String value) {
    return 'Cobrança de $value · ainda dá para pagar';
  }

  @override
  String chargeDetailValue(String value) {
    return 'Cobrança de $value';
  }

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
  String get receiveCustomerBalanceChanged =>
      'Os valores mudaram desde que a tela abriu. Confira e confirme de novo.';

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
  String get loginTitle => 'Você fala.\nO PraticOS';

  @override
  String get loginTitleHighlight => 'faz a OS.';

  @override
  String get loginTradeAutomotivo => 'Oficina Mecânica';

  @override
  String get loginTradeRefrigeracao => 'Refrigeração';

  @override
  String get loginTradeEletrica => 'Elétrica';

  @override
  String get loginTradeAssistenciaCelular => 'Assistência de Celular';

  @override
  String get loginTradeHidraulica => 'Hidráulica';

  @override
  String get loginTradeEnergiaSolar => 'Energia Solar';

  @override
  String get loginTradeInformatica => 'Informática';

  @override
  String get loginTradeLimpeza => 'Limpeza';

  @override
  String get loginTradeEletronica => 'Eletrônica';

  @override
  String get loginTradeSegurancaCftv => 'Segurança CFTV';

  @override
  String get loginTradeBicicletaria => 'Bicicletaria';

  @override
  String get loginTradeEletrodomesticos => 'Eletrodomésticos';

  @override
  String get loginTradeImpressoras => 'Impressoras';

  @override
  String get loginTradeAutomacao => 'Automação Residencial';

  @override
  String get loginTradeDedetizacao => 'Dedetização';

  @override
  String get loginTradeElevadores => 'Elevadores';

  @override
  String get loginTradeManutencaoPredial => 'Manutenção Predial';

  @override
  String get loginTradeMoveis => 'Móveis';

  @override
  String get loginTradeManutencaoAtivos => 'Manutenção de Ativos';

  @override
  String get loginTradeObrasPublicas => 'Obras Públicas';

  @override
  String get loginSampleSaid => 'Você diz';

  @override
  String get loginSampleAutomotivo =>
      '“Onix da Juliana, troca de óleo e alinhamento”';

  @override
  String get loginSampleRefrigeracao =>
      '“Split da Dona Marta, limpeza e recarga de gás”';

  @override
  String get loginSampleEletrica =>
      '“Casa do Paulo, troca de disjuntores no quadro”';

  @override
  String get loginSampleAssistenciaCelular =>
      '“iPhone do Lucas, troca de tela e bateria”';

  @override
  String get loginSampleHidraulica => '“Apê da Ana, vazamento no sifão da pia”';

  @override
  String get loginSampleEnergiaSolar =>
      '“Telhado do Carlos, instalar mais duas placas”';

  @override
  String get loginSampleInformatica =>
      '“Notebook da Bia, formatação e troca do SSD”';

  @override
  String get loginSampleLimpeza => '“Escritório da Clara, limpeza dos vidros”';

  @override
  String get loginSampleEletronica =>
      '“TV do Seu José, troca da placa principal”';

  @override
  String get loginSampleSegurancaCftv =>
      '“Loja do Marcos, instalar quatro câmeras”';

  @override
  String get loginSampleBicicletaria =>
      '“Bike do Pedro, revisão geral e pneu novo”';

  @override
  String get loginSampleEletrodomesticos =>
      '“Lavadora da Sônia, troca da bomba de água”';

  @override
  String get loginSampleImpressoras =>
      '“Impressora do escritório, troca do fusor”';

  @override
  String get loginSampleAutomacao =>
      '“Casa da Renata, instalar o painel da sala”';

  @override
  String get loginSampleDedetizacao =>
      '“Cozinha do Tião, dedetização com laudo”';

  @override
  String get loginSampleElevadores =>
      '“Prédio Aurora, manutenção mensal do elevador”';

  @override
  String get loginSampleManutencaoPredial =>
      '“Condomínio Jardim, vistoria do corredor e do hall”';

  @override
  String get loginSampleMoveis =>
      '“Guarda-roupa da Luciana, montagem e ajustes”';

  @override
  String get loginSampleManutencaoAtivos =>
      '“Motor da linha 2, troca de rolamentos”';

  @override
  String get loginSampleObrasPublicas =>
      '“Rua das Flores, recapeamento do trecho 3”';

  @override
  String get loginSampleDone => 'OS pronta para enviar';

  @override
  String get loginWithEmailLink => 'Já tenho conta com e-mail';

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
  String get onboardingBusinessTitle => 'Para o cliente';

  @override
  String get onboardingBusinessName => 'Nome que aparece na OS';

  @override
  String get onboardingBusinessNamePlaceholder =>
      'Ex.: Refrigeração Silva ou o seu nome';

  @override
  String get onboardingBusinessNameRequired =>
      'Escreva o nome que aparece na OS.';

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
  String get inviteCreateOwnCompany => 'Começar sem convite';

  @override
  String get inviteCodePlaceholder => 'Ex.: 7K2P9QXA';

  @override
  String get segmentLoadError =>
      'Não deu para abrir as suas OS. Confira a internet e tente de novo.';

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
      'O assistente ainda não está liberado para a sua conta.';

  @override
  String get orderAssistantErrorQuota =>
      'O assistente chegou ao limite deste mês. Dá para continuar preenchendo à mão.';

  @override
  String get orderAssistantErrorQuotaDay =>
      'O assistente chegou ao limite de hoje. Amanhã volta; dá para continuar preenchendo à mão.';

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
  String get moreSectionCompany => 'Seu trabalho';

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
  String get companyNameRequired => 'Escreva o nome que aparece na OS';

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
  String customerInProgressValue(String value) {
    return 'Em andamento $value';
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
  String remainingShort(String amount) {
    return 'falta $amount';
  }

  @override
  String get firstOrderTapPlus =>
      'Toque no + para criar sua primeira OS. Leva menos de um minuto.';

  @override
  String profileButtonA11y(String company) {
    return '$company: catálogo, equipe e ajustes';
  }

  @override
  String get orderAssistantPhoto => 'Foto';

  @override
  String get orderAssistantTalkShort => 'Falar';

  @override
  String get orderCustomerRequestTitle => 'O que o cliente pediu';

  @override
  String orderCustomerRequestPlaceholder(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'barulho ao frear',
      'hvac': 'não está gelando',
      'smartphones': 'tela quebrada',
      'computers': 'não liga',
      'appliances': 'parou de funcionar',
      'electrical': 'tomada sem energia',
      'plumbing': 'vazamento na pia',
      'security': 'câmera sem imagem',
      'solar': 'geração baixa',
      'printers': 'papel enroscando',
      'bicycles': 'corrente pulando',
      'software_it': 'relatório não abre',
      'other': 'não está funcionando',
    });
    return 'Ex.: $_temp0';
  }

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
  String speechHint(String device) {
    return 'Fale quem é o cliente, qual $device e o que vai ser feito.';
  }

  @override
  String get speechListening => 'Ouvindo…';

  @override
  String get speechFill => 'Preencher a OS';

  @override
  String get speechUnavailable =>
      'O microfone não está liberado. Libere em Ajustes ou digite o serviço.';

  @override
  String orderAddItemRow(String product) {
    return 'Adicionar serviço ou $product';
  }

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
  String speechTypeHint(String device) {
    return 'Escreva quem é o cliente, qual $device e o que vai ser feito';
  }

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
  String pickerNewItem(String product) {
    return 'Novo serviço ou $product';
  }

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
  String pickerNoItemWith(String product, String query) {
    return 'Nenhum serviço ou $product com “$query”. Cadastre e ele já entra na OS.';
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
  String get pickFromContacts => 'Escolher dos contatos';

  @override
  String get contactWhichNumber => 'Qual número?';

  @override
  String get customerDuplicateTitle => 'Já cadastrado';

  @override
  String customerDuplicateMessage(String name) {
    return '$name já está com este telefone.';
  }

  @override
  String get customerDuplicateOpen => 'Abrir cliente';

  @override
  String get customerDuplicateSaveAnyway => 'Salvar mesmo assim';

  @override
  String get contactReadFailed => 'Não deu para ler este contato.';

  @override
  String contactFirstOfMany(int count) {
    return 'Este arquivo tem $count contatos. Abrimos o primeiro.';
  }

  @override
  String get contactCannotAddCustomer =>
      'Seu perfil não pode cadastrar clientes.';

  @override
  String get customerMoreDataHint => 'E-mail, CPF ou CNPJ, endereço';

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
  String get checklistStopUsing => 'Parar de usar';

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
  String checklistQuestionPlaceholder(String segment) {
    String _temp0 = intl.Intl.selectLogic(segment, {
      'automotive': 'Os pneus estão bons?',
      'hvac': 'O dreno está livre?',
      'smartphones': 'A tela liga?',
      'computers': 'O ventilador gira?',
      'appliances': 'O aparelho liga?',
      'electrical': 'O quadro está identificado?',
      'plumbing': 'Há sinal de vazamento?',
      'security': 'As câmeras estão gravando?',
      'solar': 'As placas estão limpas?',
      'printers': 'A impressão sai nítida?',
      'bicycles': 'Os freios estão bons?',
      'software_it': 'O backup rodou?',
      'other': 'Está funcionando?',
    });
    return 'Ex.: $_temp0';
  }

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
  String get chargeCopyLink => 'Copiar link';

  @override
  String get chargeLinkCopied => 'Link copiado';

  @override
  String get chargeCancelLink => 'Cancelar cobrança';

  @override
  String get chargeLinkTitle => 'Mandar cobrança';

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
  String get emailLoginNewAccountHint =>
      'Ainda não tem conta? Volte e continue com Apple ou Google.';

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
  String get checklistPreviousShort => 'Anterior';

  @override
  String get checklistSkipShort => 'Pular';

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
  String get shareSendPdf => 'Mandar o PDF';

  @override
  String get sharePreparingPdf => 'Preparando o PDF…';

  @override
  String get shareSendLinkWhatsApp => 'Mandar só o link no WhatsApp';

  @override
  String get shareSendLinkOnly => 'Mandar só o link';

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
  String get teamRemoveMemberMessage => 'A pessoa perde o acesso às OS.';

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
  String get nfseStatusIssuedAuto => 'Emitida sozinha';

  @override
  String nfseStatusIssuedAutoNumber(String number) {
    return 'Emitida sozinha · nº $number';
  }

  @override
  String get nfseAutoMissingTaxId => 'Falta o CPF ou CNPJ do cliente';

  @override
  String get nfseAutoCertificateExpired => 'Certificado vencido';

  @override
  String get nfseAutoEmitterNotReady => 'Falta configurar o CNPJ da nota';

  @override
  String get nfseAutoDailyLimit => 'Limite de notas de hoje';

  @override
  String get nfseAutoNotIssued => 'Não saiu sozinha';

  @override
  String get nfseAutoErrorPickEmitter =>
      'Escolha o CNPJ padrão em Nota fiscal para as notas saírem sozinhas.';

  @override
  String get nfseStatusCanceling => 'Cancelando';

  @override
  String get nfseStatusCancelDenied => 'Cancelamento recusado';

  @override
  String get nfseStatusCanceled => 'Cancelada';

  @override
  String get nfseStatusError => 'Erro na prefeitura';

  @override
  String get nfseListTitle => 'Notas fiscais';

  @override
  String nfseListCustomerTitle(String name) {
    return 'Notas de $name';
  }

  @override
  String nfseListSummary(int count, String month, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em $month saíram $count notas, no total de $value.',
      one: 'Em $month saiu 1 nota, de $value.',
      zero: 'Nenhuma nota saiu em $month.',
    );
    return '$_temp0';
  }

  @override
  String nfseListEmpty(String month) {
    return 'Nenhuma nota em $month';
  }

  @override
  String get nfseListEmptyHint => 'Para emitir, abra a OS e toque em “…”.';

  @override
  String get nfseListEmptyHintDirect =>
      'Para emitir, abra a OS e toque em “Nota fiscal”.';

  @override
  String get nfseListSearch => 'Cliente, número da nota ou OS';

  @override
  String get nfseListAttention => 'Precisa de atenção';

  @override
  String nfseListAttentionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count precisam de atenção',
      one: '1 precisa de atenção',
    );
    return '$_temp0';
  }

  @override
  String nfseListNumber(String number) {
    return 'Nota $number';
  }

  @override
  String nfseListOrders(String numbers) {
    return 'OS $numbers';
  }

  @override
  String get nfseListOnlyServices =>
      'Só os serviços entram na nota, por isso o total pode ser diferente do Vendido.';

  @override
  String nfseListNoResults(String month) {
    return 'Nada encontrado em $month.';
  }

  @override
  String get nfseListMenu => 'Mais opções das notas';

  @override
  String get nfseListSetup => 'Configurar nota fiscal';

  @override
  String get nfseNotIssued => 'Não emitida';

  @override
  String get nfseIssueLink => 'Emitir';

  @override
  String get nfseFixAndIssue => 'Corrigir e emitir';

  @override
  String get nfseSharePdf => 'Compartilhar PDF';

  @override
  String get nfseRowTitle => 'Nota fiscal';

  @override
  String get nfseCompanyRowNoCnpj => 'Falta cadastrar o CNPJ';

  @override
  String get nfseCompanyRowPending => 'Falta terminar a configuração';

  @override
  String get nfseCompanyRowReady => 'Pronta para emitir';

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
  String get nfseErrorCustomerData =>
      'A prefeitura pede o e-mail e o endereço completo do cliente (com CEP). Preencha e emita de novo.';

  @override
  String nfseErrorAsaasSaid(String detail) {
    return 'O Asaas recusou a nota: $detail';
  }

  @override
  String get nfseErrorSetupRejected =>
      'O Asaas recusou a configuração da nota (serviço ou dados fiscais). Confira em Configurar.';

  @override
  String get nfseCustomerDataIntro =>
      'A prefeitura pede o e-mail e o endereço do cliente. Ficam salvos no cadastro dele.';

  @override
  String get nfseCustomerDataMissing =>
      'Falta o e-mail ou o endereço do cliente';

  @override
  String get nfsePostalCode => 'CEP';

  @override
  String get nfseStreet => 'Rua';

  @override
  String get nfseAddressComplement => 'Complemento';

  @override
  String get nfseDistrict => 'Bairro';

  @override
  String get nfseHeadNotIssued =>
      'A nota não saiu. Corrija o motivo abaixo e emita de novo.';

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
      'A nota não saiu sozinha. Corrija o motivo abaixo e emita.';

  @override
  String get nfseAutoReasonLabel => 'Por que não saiu';

  @override
  String get nfseAutoErrorTaxId => 'O cliente não tem CPF ou CNPJ no cadastro.';

  @override
  String recurringOrdersTitle(String orders) {
    return '$orders que se repetem';
  }

  @override
  String get customerSaveError =>
      'Não deu para salvar o cliente. Tente de novo.';

  @override
  String chargeMissingOutsideLink(String value) {
    return 'Falta mais $value fora do link.';
  }

  @override
  String get chargeInstallmentsCanceled => 'Parcelamento cancelado';

  @override
  String chargeSendNewLink(String value) {
    return 'Mande um link novo de $value.';
  }

  @override
  String orderAssistantUsesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count usos do assistente este mês.',
      one: 'Resta 1 uso do assistente este mês.',
      zero: 'Acabaram os usos do assistente deste mês.',
    );
    return '$_temp0';
  }

  @override
  String get planUsageAi => 'Assistente este mês';

  @override
  String planLimitAi(String used, String limit) {
    return 'Você usou $used de $limit pedidos do assistente neste mês. Para continuar agora, veja os planos.';
  }

  @override
  String aiIntroTitle(String order) {
    return 'Crie sua próxima $order falando';
  }

  @override
  String get aiIntroBody =>
      'Diga o cliente e o serviço, ou tire uma foto. O app preenche e você só confere antes de salvar.';

  @override
  String get aiIntroTry => 'Experimentar agora';

  @override
  String get aiIntroLater => 'Agora não';

  @override
  String get courtesyBannerLabel => 'Cortesia do plano Pro';

  @override
  String courtesyBannerEnds(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Acaba em $days dias.',
      one: 'Acaba em 1 dia.',
    );
    return '$_temp0';
  }

  @override
  String courtesyBannerOrdersUse(int used, int free) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: 'Neste mês você abriu $used OS; no Free são $free por mês.',
      one: 'Neste mês você abriu 1 OS; no Free são $free por mês.',
    );
    return '$_temp0';
  }

  @override
  String get courtesyBannerToFree =>
      'Depois disso, o app volta para o plano Free.';

  @override
  String courtesyBannerPlan(String plan) {
    return 'O plano $plan cobre o seu uso.';
  }

  @override
  String get courtesyBannerLater => 'Agora não';

  @override
  String deviceSaveNeedsAny(String first, String second) {
    return 'Preencha $first ou $second para salvar.';
  }

  @override
  String orderStatusVisit(String status, String date) {
    return '$status · visita $date';
  }

  @override
  String get orderOpenChecklist => 'Abrir checklist';

  @override
  String orderPdfTitle(String order, String number) {
    return '$order $number';
  }

  @override
  String get receivePaymentMethod => 'Forma de pagamento';

  @override
  String get receivePaymentMethodOptional => 'Opcional';

  @override
  String get receivePaymentMethodQuestion => 'Como foi pago?';

  @override
  String get receivePaymentMethodNone => 'Não informar';

  @override
  String get paymentMethodPix => 'Pix';

  @override
  String get paymentMethodCash => 'Dinheiro';

  @override
  String get paymentMethodCard => 'Cartão';

  @override
  String get paymentMethodOther => 'Outro';

  @override
  String get filterQuotes => 'Orçamentos';

  @override
  String homeQuotesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orçamentos sem resposta',
      one: '1 orçamento sem resposta',
    );
    return '$_temp0';
  }

  @override
  String get noQuotesWaiting => 'Nenhum orçamento sem resposta.';

  @override
  String ratingsEmptyHint(String order) {
    return 'A avaliação chega quando o cliente dá a nota pelo link da $order, depois que ela fica pronta. Para pedir uma, abra uma $order concluída e mande o link para o cliente.';
  }

  @override
  String noticesEmptyHint(String order) {
    return 'Aqui aparece o que acontece nas suas $order: aprovação do cliente, comentários, avaliações e pagamentos. Os lembretes de horário marcado chegam direto no celular.';
  }

  @override
  String get noticesRemindersLink => 'Ajustar lembretes';

  @override
  String reminderWillNotify(String time) {
    return 'O app avisa $time antes.';
  }

  @override
  String get reminderIsOff => 'Lembrete desligado.';

  @override
  String get reminderPhoneBlocked =>
      'Os avisos estão desligados nos Ajustes do celular.';

  @override
  String get reminderAdjust => 'Ajustar';

  @override
  String reminderNotificationTitle(String time) {
    return 'Agendamento às $time';
  }

  @override
  String get notificationPromptTitle => 'Avisos do PraticOS';

  @override
  String get notificationPromptMessage =>
      'O app lembra você antes de cada horário marcado e avisa quando o cliente aprova um orçamento. O celular vai perguntar se pode mandar esses avisos.';

  @override
  String get continueAction => 'Continuar';

  @override
  String get checklistOfferTitle => 'Fazer o checklist de entrada?';

  @override
  String checklistOfferMessage(String device) {
    return 'Registre como $device chegou, antes de começar o serviço.';
  }

  @override
  String get checklistOfferAction => 'Fazer checklist';

  @override
  String get moreContractsSubtitle => 'Manutenção que se repete sozinha';

  @override
  String get contractsOffQuestion =>
      'Tem cliente fixo ou manutenção que se repete?';

  @override
  String contractsOffMessage(String order) {
    return 'Com contratos, você combina uma vez, por exemplo a cada 6 meses, e o app cuida da próxima $order na data certa.';
  }

  @override
  String get contractsOffAction => 'Usar contratos';

  @override
  String get filterOnHold => 'Paradas';

  @override
  String homeOnHoldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '1 parada',
    );
    return '$_temp0';
  }

  @override
  String get noOrdersOnHold => 'Nenhum serviço parado.';

  @override
  String get orderHoldMark => 'Marcar como parada';

  @override
  String get orderHoldResume => 'Retomar serviço';

  @override
  String get orderHoldSaveError => 'Não deu para salvar. Tente de novo.';

  @override
  String orderStageMoveTo(String stage) {
    return 'Passar para $stage';
  }

  @override
  String get orderMenuChangeStage => 'Mudar etapa';

  @override
  String get orderStagePickerTitle => 'Em que etapa está?';

  @override
  String get orderStageSaveError =>
      'Não deu para mudar a etapa. Confira a internet e tente de novo.';

  @override
  String get orderHoldSheetTitle => 'Por que parou?';

  @override
  String get orderHoldNoteHint => 'Observação (opcional)';

  @override
  String get orderHoldReasonPart => 'Esperando peça';

  @override
  String get orderHoldReasonCustomer => 'Esperando cliente';

  @override
  String get orderHoldReasonAuthorization => 'Esperando autorização';

  @override
  String get orderHoldReasonOther => 'Outro motivo';

  @override
  String orderHoldSince(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Parada há $count dias',
      one: 'Parada há 1 dia',
      zero: 'Parada desde hoje',
    );
    return '$_temp0';
  }

  @override
  String orderHoldLogMarked(String reason) {
    return 'Marcada como parada: $reason';
  }

  @override
  String orderHoldLogResumed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retomada depois de $count dias parada',
      one: 'Retomada depois de 1 dia parada',
      zero: 'Retomada no mesmo dia',
    );
    return '$_temp0';
  }

  @override
  String get aiActionsTitle => 'Confere?';

  @override
  String aiActionsReceive(String amount) {
    return 'Receber $amount';
  }

  @override
  String get aiActionsReceiveNoAmount => 'Receber';

  @override
  String aiActionsReceived(String amount) {
    return 'Recebido $amount';
  }

  @override
  String get aiActionsTypeAmount => 'toque para informar o valor';

  @override
  String aiActionsLeft(String amount) {
    return 'falta $amount';
  }

  @override
  String get aiActionsPaidOff => 'quitada';

  @override
  String aiActionsDiscount(String amount) {
    return 'Desconto de $amount';
  }

  @override
  String aiActionsNewTotal(String amount) {
    return 'total $amount';
  }

  @override
  String aiActionsMarkAs(String status) {
    return 'Marcar como $status';
  }

  @override
  String get aiActionsIssuesNfse => 'Isso também emite a nota fiscal.';

  @override
  String get aiActionsCannotReceive =>
      'Só quem recebe pagamentos pode registrar isso.';

  @override
  String get aiActionsCannotDiscount =>
      'Só quem cuida do financeiro pode dar desconto.';

  @override
  String get aiActionsOrderCanceled => 'Esta OS está cancelada.';

  @override
  String get aiActionsNothingToReceive => 'Esta OS não tem nada a receber.';

  @override
  String aiActionsOnlyLeft(String amount) {
    return 'Falta só $amount.';
  }

  @override
  String get aiActionsAfterSave => 'Ao salvar, vou pedir para você conferir.';

  @override
  String get aiActionsSaving => 'Salvando…';

  @override
  String get aiActionsSavedOffline =>
      'OS salva. Registre o recebimento quando estiver online.';

  @override
  String aiActionsStatusKept(String status) {
    return 'O status continua $status.';
  }

  @override
  String get aiActionsNfseStays => 'A nota fiscal continua emitida.';

  @override
  String get nextMaintenanceQuestion => 'Quando é a próxima manutenção?';

  @override
  String get nextMaintenanceThreeMonths => '3 meses';

  @override
  String get nextMaintenanceSixMonths => '6 meses';

  @override
  String get nextMaintenanceOneYear => '1 ano';

  @override
  String get nextMaintenanceNoRepeat => 'Não repetir';

  @override
  String nextMaintenanceCurrent(String date) {
    return 'Marcada para $date';
  }

  @override
  String nextMaintenanceOn(String date) {
    return 'Próxima manutenção: $date';
  }

  @override
  String get nextMaintenanceSet => 'Definir próxima manutenção';

  @override
  String get nextMaintenanceChangeHint => 'Toque para mudar ou tirar';

  @override
  String get nextMaintenanceRemove => 'Tirar';

  @override
  String get nextMaintenanceByContract => 'Pelo contrato';

  @override
  String get nextMaintenanceSaveError =>
      'Não foi possível salvar a data da manutenção';

  @override
  String get orderStatusSaveError => 'Não foi possível salvar. Tente de novo.';

  @override
  String get maintenanceComing => 'Manutenções chegando';

  @override
  String maintenanceShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver mais $count',
      one: 'Ver mais 1',
    );
    return '$_temp0';
  }

  @override
  String get maintenanceCallCustomer => 'Chamar cliente';

  @override
  String get maintenanceOpenOrder => 'Abrir OS';

  @override
  String maintenanceViewDevice(String device) {
    return 'Ver $device';
  }

  @override
  String get maintenanceNoPhone => 'Cliente sem telefone';

  @override
  String get maintenanceWhatsappError => 'Não foi possível abrir o WhatsApp';

  @override
  String maintenanceWhatsappMessage(
    String customer,
    String device,
    String date,
  ) {
    return 'Olá, $customer! Está chegando a manutenção de $device, prevista para $date. Podemos combinar um dia?';
  }

  @override
  String maintenanceWhatsappMessageNoName(String device, String date) {
    return 'Olá! Está chegando a manutenção de $device, prevista para $date. Podemos combinar um dia?';
  }

  @override
  String maintenanceLastService(String service) {
    return 'Última: $service';
  }

  @override
  String get orderCreateFailedTitle => 'Não deu para salvar a OS';

  @override
  String get orderCreateFailedMessage =>
      'Confira a internet e crie a OS de novo.';

  @override
  String get receiveChargeMaybeOpen =>
      'Pode haver um link de pagamento aberto nesta OS. Confira com quem cuida do financeiro antes de marcar como recebido.';

  @override
  String get checklistAnswerSaveFailed =>
      'Não deu para guardar a resposta. Tente de novo.';

  @override
  String checklistReadingBelowLastVisit(String reading) {
    return 'Menor que os $reading da última visita. Está certo?';
  }

  @override
  String get profileSaveFailed =>
      'Não deu para salvar o perfil. Tente de novo.';

  @override
  String get saveFailedTryAgain => 'Não deu para salvar. Tente de novo.';

  @override
  String get deleteFailedTryAgain => 'Não deu para apagar. Tente de novo.';

  @override
  String get nfseDirectHeadEmpty =>
      'Envie o certificado digital para emitir notas';

  @override
  String get nfseDirectHeadWithEmitters =>
      'Notas saem pelo CNPJ que você escolher na hora';

  @override
  String get nfseDirectEmittersSection => 'Seus CNPJs';

  @override
  String get nfseDirectAddCnpjTitle => 'Adicionar CNPJ';

  @override
  String get nfseDirectAddCnpjIntro =>
      'Escolha o certificado digital A1 do CNPJ e digite a senha dele. O resto o PraticOS busca sozinho.';

  @override
  String get nfseDirectReplaceTitle => 'Trocar certificado';

  @override
  String nfseDirectReplaceIntro(String name) {
    return 'Escolha o certificado novo da $name e digite a senha dele.';
  }

  @override
  String get nfseDirectSendCertificate => 'Enviar certificado';

  @override
  String get nfseDirectCertificateFile => 'Arquivo do certificado';

  @override
  String get nfseDirectPickFile => 'Escolher';

  @override
  String get nfseDirectCertificatePassword => 'Senha do certificado';

  @override
  String get nfseDirectCertificatePasswordHint =>
      'Fica só no envio. O PraticOS não guarda a senha.';

  @override
  String get nfseDirectUploadMissing =>
      'Escolha o arquivo, digite a senha e aceite o termo para enviar.';

  @override
  String get nfseDirectTerms =>
      'O PraticOS usa o certificado só para emitir e ler as suas notas. Você pode apagar quando quiser.';

  @override
  String get nfseDirectTermsLink => 'Ler o termo';

  @override
  String get nfseDirectCnpjAdded => 'CNPJ adicionado';

  @override
  String get nfseDirectCertificateReplaced => 'Certificado trocado';

  @override
  String get nfseDirectCertificateDeleted => 'Certificado apagado';

  @override
  String get nfseDirectRegimeMei => 'MEI';

  @override
  String get nfseDirectRegimeSimples => 'Simples';

  @override
  String get nfseDirectDefault => 'Padrão';

  @override
  String get nfseDirectDefaultSaved =>
      'Notas saem por este CNPJ quando o cliente não tem outro';

  @override
  String get nfseDirectUseAsDefault => 'Usar como padrão';

  @override
  String nfseDirectCertValidUntil(String date) {
    return 'Certificado vale até $date';
  }

  @override
  String nfseDirectCertExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Certificado vence em $days dias',
      one: 'Certificado vence amanhã',
    );
    return '$_temp0';
  }

  @override
  String get nfseDirectCertExpired => 'Certificado vencido';

  @override
  String get nfseDirectCertPending => 'Certificado esperando você confirmar';

  @override
  String get nfseDirectCertMissing => 'Sem certificado';

  @override
  String nfseDirectCertExpiresOn(String date) {
    return 'Vence em $date';
  }

  @override
  String nfseDirectCertExpiredOn(String date) {
    return 'Venceu em $date';
  }

  @override
  String nfseDirectCertSentBy(String expires, String name, String date) {
    return '$expires · enviado por $name em $date';
  }

  @override
  String get nfseDirectAutoIssueRow => 'Emitir sozinha quando concluir a OS';

  @override
  String get nfseDirectAutoIssueQuestion => 'Quando a nota sai sozinha?';

  @override
  String get nfseDirectAutoIssueNever => 'Nunca';

  @override
  String get nfseDirectAutoIssueNeverHint => 'Você emite pela OS, com um toque';

  @override
  String get nfseDirectAutoIssueSelected => 'Para os clientes escolhidos';

  @override
  String get nfseDirectAutoIssueSelectedHint =>
      'Ligue no cadastro de cada cliente';

  @override
  String get nfseDirectAutoIssueAll => 'Para todas as OS';

  @override
  String get nfseDirectAutoIssueAllHint => 'Sai quando a OS é concluída';

  @override
  String get nfseDirectEmitterTitle => 'CNPJ';

  @override
  String nfseDirectTotals(String year, String month) {
    return 'Notas este ano: $year · este mês: $month';
  }

  @override
  String nfseDirectMeiLimit(String value, String limit) {
    return 'Faturou $value de $limit este ano (pelas notas)';
  }

  @override
  String nfseDirectNotEnabledInCity(String city) {
    return 'Ainda não habilitado para emitir em $city';
  }

  @override
  String get nfseDirectNotEnabledNoCity =>
      'Ainda não conferimos se este CNPJ já pode emitir nota pelo governo.';

  @override
  String get nfseDirectServiceRow => 'Serviço da nota';

  @override
  String get nfseDirectServiceName => 'Nome do serviço';

  @override
  String get nfseDirectServiceNamePlaceholder => 'Ex.: Manutenção de veículos';

  @override
  String get nfseDirectServiceCode => 'Código do serviço';

  @override
  String get nfseDirectServiceCodeHint =>
      '6 números da lista nacional. O contador sabe qual é.';

  @override
  String get nfseDirectServiceMissing =>
      'Escreva o nome e os 6 números do código para salvar.';

  @override
  String get nfseDirectRegistrationRow => 'Inscrição municipal';

  @override
  String get nfseDirectRegistrationHint =>
      'Deixe em branco se a prefeitura não usa.';

  @override
  String get nfseDirectStyleRow => 'Estilo da descrição';

  @override
  String get nfseDirectStyleHead => 'Como os serviços aparecem na nota';

  @override
  String get nfseDirectStyleUppercase => 'Tudo em maiúsculas';

  @override
  String get nfseDirectStyleSeparator => 'Separar serviços com';

  @override
  String get nfseDirectSeparatorQuestion => 'Como separar os serviços?';

  @override
  String nfseDirectStyleSample(String sample) {
    return 'Fica assim: $sample';
  }

  @override
  String get nfseDirectSampleService1 => 'Serviço 1';

  @override
  String get nfseDirectSampleService2 => 'Serviço 2';

  @override
  String get nfseDirectCertificateRow => 'Certificado';

  @override
  String get nfseDirectMissing => 'Falta';

  @override
  String get nfseDirectNone => 'Nenhuma';

  @override
  String get nfseDirectSaved => 'Salvo';

  @override
  String get nfseDirectDeleteAction => 'Apagar certificado';

  @override
  String get nfseDirectDeleteTitle => 'Apagar o certificado?';

  @override
  String nfseDirectDeleteMessage(String name) {
    return 'O certificado da $name é apagado de vez e não dá mais para emitir por ele. As notas ficam.';
  }

  @override
  String get nfseDirectErrorInvalidFile =>
      'Esse arquivo não é um certificado A1. Escolha o arquivo .pfx ou .p12.';

  @override
  String get nfseDirectErrorWrongPassword =>
      'Senha errada. Confira com quem mandou o certificado.';

  @override
  String get nfseDirectErrorExpired =>
      'Esse certificado já venceu. Peça um novo ao contador.';

  @override
  String get nfseDirectErrorNotYetValid =>
      'Esse certificado ainda não começou a valer.';

  @override
  String get nfseDirectErrorNotIcpBrasil =>
      'Esse certificado não é do ICP-Brasil. Use o certificado A1 da empresa.';

  @override
  String get nfseDirectErrorNoTaxId =>
      'Esse certificado não é de um CNPJ. Use o certificado A1 da empresa.';

  @override
  String get nfseDirectErrorOtherTaxId =>
      'Esse certificado é de outro CNPJ. Para trocar, use um do mesmo CNPJ.';

  @override
  String get nfseDirectErrorAlreadyExists =>
      'Esse CNPJ já está cadastrado. Para renovar, abra o CNPJ e troque o certificado.';

  @override
  String get nfseDirectErrorNotFound => 'Esse CNPJ não está mais cadastrado.';

  @override
  String get nfseDirectErrorNotEnabled =>
      'A nota fiscal ainda não está ligada para a sua empresa.';

  @override
  String get nfseDirectErrorForbidden =>
      'Só o dono e o administrador mexem nessa configuração.';

  @override
  String get nfseDirectErrorValidation =>
      'Confira o que foi digitado e tente de novo.';

  @override
  String get nfseDirectErrorUnavailable =>
      'Não deu para enviar agora. Tente de novo em alguns minutos.';

  @override
  String get nfseDirectErrorGeneric => 'Não deu certo. Tente de novo.';

  @override
  String get nfseDirectServiceCodePlaceholder => 'Ex.: 140101';

  @override
  String nfseDirectSeparatorValue(String separator) {
    return '“$separator”';
  }

  @override
  String get invoiceDataTitle => 'Dados para nota';

  @override
  String get invoiceDataHint =>
      'CPF/CNPJ, razão social e endereço da nota fiscal';

  @override
  String get invoiceLegalName => 'Razão social';

  @override
  String get invoiceLegalNamePlaceholder => 'Ex.: REVENDA EXEMPLO LTDA';

  @override
  String get invoicePostalCode => 'CEP';

  @override
  String get invoicePostalCodePlaceholder => '00000-000';

  @override
  String get invoiceStreet => 'Rua';

  @override
  String get invoiceNumber => 'Número';

  @override
  String get invoiceComplement => 'Complemento';

  @override
  String get invoiceDistrict => 'Bairro';

  @override
  String get invoiceCity => 'Cidade';

  @override
  String get invoiceState => 'UF';

  @override
  String get invoiceStatePlaceholder => 'SP';

  @override
  String get invoiceEmailLabel => 'E-mail da nota';

  @override
  String get invoiceEmailFallback =>
      'Vazio, a nota vai para o e-mail do cliente';

  @override
  String get invoiceTaxIdLooking => 'Buscando o CNPJ na Receita…';

  @override
  String get invoiceTaxIdFound =>
      'Preenchido com os dados da Receita. Confira antes de salvar.';

  @override
  String get invoiceTaxIdNotFound =>
      'Não achamos este CNPJ na Receita. Preencha à mão.';

  @override
  String get invoicePostalCodeLooking => 'Buscando o CEP…';

  @override
  String get invoicePostalCodeNotFound =>
      'Não achamos este CEP. Preencha à mão.';

  @override
  String get invoiceRecipientLabel => 'Nota fiscal para';

  @override
  String get invoiceRecipientAction => 'Mandar a nota para outro cliente';

  @override
  String get invoiceRecipientPickerTitle => 'Para quem vai a nota?';

  @override
  String get invoiceRecipientNone =>
      'Nenhum: a nota vai para o próprio cliente';

  @override
  String get invoiceAutoIssue => 'Emitir nota sozinha';

  @override
  String get invoiceAutoIssueHint => 'Quando concluir a OS';

  @override
  String invoiceTaxIdTakenCnpj(String name) {
    return '$name já tem este CNPJ';
  }

  @override
  String invoiceTaxIdTakenCpf(String name) {
    return '$name já tem este CPF';
  }

  @override
  String get invoiceTaxIdTakenMessage =>
      'Cada CPF ou CNPJ fica em um cliente só.';

  @override
  String get invoiceTaxIdTakenUse => 'Mandar as notas desta loja para ela';

  @override
  String invoiceRecipientSet(String customer, String recipient) {
    return 'As notas de $customer vão para $recipient';
  }

  @override
  String invoiceRecipientCleared(String customer) {
    return 'As notas de $customer vão para ele mesmo';
  }

  @override
  String nfseDirectCpfLine(String value) {
    return 'CPF $value';
  }

  @override
  String nfseDirectCnpjLine(String value) {
    return 'CNPJ $value';
  }

  @override
  String get nfseDirectProblemCertificate => 'Sem certificado digital';

  @override
  String get nfseDirectProblemNotEnabled => 'Não habilitado a emitir na cidade';

  @override
  String get nfseDirectProblemService => 'Falta o serviço da nota';

  @override
  String get nfseDirectProblemSetup =>
      'Falta terminar a configuração deste CNPJ';

  @override
  String nfseDirectIssueCannot(String reason) {
    return 'Este CNPJ não emite agora: $reason';
  }

  @override
  String get nfseDirectIssueCityByPostalCode =>
      'Digite o CEP para achar a cidade.';

  @override
  String get nfseDirectIssueAddressMissing =>
      'Falta o endereço com CEP de quem recebe a nota.';

  @override
  String get nfseDirectIssueEmailMissing =>
      'Falta o e-mail de quem recebe a nota.';

  @override
  String get nfseDirectIssueEmitterQuestion => 'Por qual CNPJ emitir?';

  @override
  String get nfseDirectIssueRecipientQuestion => 'Para quem vai esta nota?';

  @override
  String get nfseDirectIssueRecipientOnlyThis => 'Vale só para esta nota';

  @override
  String get nfseDirectRefusedGeneric => 'O governo recusou a nota.';

  @override
  String get nfseDirectRefusedFixRecipient =>
      'Confira os dados de quem recebe a nota e toque em ✓ de novo.';

  @override
  String get nfseDirectIssueBy => 'Emitir por';

  @override
  String get nfseDirectIssueTo => 'Para';

  @override
  String nfseDirectIssueViaRecipient(String name) {
    return 'Pelo “Nota fiscal para” de $name';
  }

  @override
  String get nfseDirectMeiNear =>
      'Com esta nota, o MEI passa de 80% do teto do ano.';

  @override
  String get nfseDirectMeiOver =>
      'Com esta nota, o MEI passa do teto do ano. Fale com o seu contador.';

  @override
  String nfseDirectIssueRecipientDataIntro(String name) {
    return 'Faltam dados de $name para a nota. Ficam salvos no cadastro.';
  }

  @override
  String nfseDirectIssueComplementary(String info) {
    return 'Vai junto na nota: $info';
  }

  @override
  String get nfseDirectIssuedToast => 'Nota emitida';

  @override
  String get nfseDirectWaitingToast =>
      'O governo ainda não respondeu. A nota aparece assim que ele confirmar.';

  @override
  String get nfseDirectErrorRecipientTaxId =>
      'Falta o CPF ou CNPJ de quem recebe a nota.';

  @override
  String get nfseDirectErrorEmitterNotReady =>
      'Este CNPJ ainda não pode emitir. Confira a configuração da nota.';

  @override
  String get nfseDirectErrorManagerNotAllowed =>
      'O dono não liberou a emissão de notas para gerentes. Peça para ele emitir ou liberar.';

  @override
  String get nfseDirectErrorOrderHasInvoice => 'Esta OS já tem nota.';

  @override
  String get nfseDirectErrorGovUnavailable =>
      'O governo não respondeu. Tente de novo em alguns minutos.';

  @override
  String get nfseDirectErrorNotCancelable =>
      'Esta nota não pode ser cancelada.';

  @override
  String get nfseDirectErrorPdf => 'O PDF desta nota ainda não está pronto.';

  @override
  String get nfseDirectCancelPortal =>
      'A cidade não aceitou o cancelamento por aqui. Cancele no portal do governo (nfse.gov.br).';

  @override
  String get nfseDirectCancelMessage =>
      'Diga o motivo. O governo registra na hora e a nota deixa de valer.';

  @override
  String get nfseDirectCancelReasonIssueError => 'Erro na nota';

  @override
  String get nfseDirectCancelReasonNotProvided => 'Serviço não prestado';

  @override
  String get nfseDirectCancelReasonRow => 'Motivo';

  @override
  String get nfseDirectEmitterLabel => 'Emitida por';

  @override
  String get nfseDirectAccessKeyLabel => 'Chave de acesso';

  @override
  String get nfseDirectExternalTag => 'Emitida fora do PraticOS';

  @override
  String get nfseDirectCheckNow => 'Conferir agora';

  @override
  String get nfseDirectFilterRow => 'CNPJ';

  @override
  String get nfseDirectFilterAll => 'Todos';

  @override
  String get nfseDirectFilterQuestion => 'Notas de qual CNPJ?';

  @override
  String get nfseImportTitle => 'Importar notas';

  @override
  String get nfseImportReading => 'Lendo suas notas no governo…';

  @override
  String nfseImportReadingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documentos lidos',
      one: '1 documento lido',
      zero: 'Começando',
    );
    return '$_temp0';
  }

  @override
  String nfseImportHeadline(int notas, int customers) {
    return 'Achamos $notas notas para $customers clientes. Vamos preencher seus clientes e o serviço da nota.';
  }

  @override
  String get nfseImportHeadlineEmpty =>
      'Não achamos notas deste CNPJ no governo. Vamos preencher o serviço e a série da nota.';

  @override
  String get nfseImportEmitterSection => 'Emitente';

  @override
  String get nfseImportServiceRow => 'Serviço mais usado';

  @override
  String nfseImportServiceValue(String name, String rate) {
    return '$name · ISS $rate';
  }

  @override
  String get nfseImportSeriesRow => 'Série das notas do PraticOS';

  @override
  String get nfseImportCustomersSection => 'Clientes';

  @override
  String nfseImportCustomersNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes novos',
      one: '1 cliente novo',
    );
    return '$_temp0';
  }

  @override
  String nfseImportCustomersCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completam clientes que você já tem',
      one: '1 completa um cliente que você já tem',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportCustomersHint =>
      'Só preenchemos o que está vazio. Nada que você digitou muda.';

  @override
  String get nfseImportAskSection => 'Este é o mesmo cliente?';

  @override
  String nfseImportAskSubtitle(String customer) {
    return 'É o seu cliente $customer?';
  }

  @override
  String get nfseImportAskUnanswered => 'Responder';

  @override
  String get nfseImportAskSame => 'Sim';

  @override
  String get nfseImportAskNew => 'Não, criar outro';

  @override
  String get nfseImportAskHint => 'Sem resposta, vira cliente novo.';

  @override
  String get nfseImportStoresSection => 'Lojas que faturam em outro CNPJ';

  @override
  String nfseImportStoreRow(String recipient) {
    return 'Nota fiscal para $recipient';
  }

  @override
  String get nfseImportAutoSection => 'Emitir sozinha';

  @override
  String nfseImportAutoQuestion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Estes $count clientes tiveram nota em quase todas as OS. Ligar a nota sozinha para eles?',
      one:
          'Este cliente teve nota em quase todas as OS. Ligar a nota sozinha para ele?',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportNotasSection => 'Notas';

  @override
  String nfseImportNotasLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ligadas às suas OS',
      one: '1 ligada às suas OS',
    );
    return '$_temp0';
  }

  @override
  String nfseImportNotasHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count só no histórico',
      one: '1 só no histórico',
    );
    return '$_temp0';
  }

  @override
  String get nfseImportButton => 'Importar';

  @override
  String get nfseImportDone => 'Notas importadas';

  @override
  String get nfseImportAction => 'Importar notas do governo';

  @override
  String get nfseImportUndoAction => 'Desfazer importação';

  @override
  String get nfseImportUndoQuestion => 'Desfazer a importação?';

  @override
  String get nfseImportUndoMessage =>
      'Apagamos os clientes criados que ainda não têm OS, esvaziamos o que foi preenchido e desligamos as notas das OS. As notas continuam no histórico.';

  @override
  String get nfseImportUndone => 'Importação desfeita';

  @override
  String get nfseImportErrorUndoExpired =>
      'A importação tem mais de 30 dias e não pode mais ser desfeita.';

  @override
  String get nfseLinkOrderRow => 'OS';

  @override
  String get nfseLinkOrderAction => 'Ligar a uma OS';

  @override
  String get nfseLinkPickerTitle => 'Qual OS é desta nota?';

  @override
  String get nfseLinkPickerSame => 'Do cliente';

  @override
  String get nfseLinkPickerOthers => 'Outras';

  @override
  String get nfseLinkPickerEmpty => 'Nenhuma OS para ligar';

  @override
  String nfseLinkOrderTitle(String number) {
    return 'OS $number';
  }

  @override
  String get nfseLinkHasNota => 'Já tem nota';

  @override
  String get nfseLinked => 'Nota ligada à OS';

  @override
  String get nfseUnlinkAction => 'Desligar da OS';

  @override
  String nfseUnlinkQuestion(String numbers) {
    return 'Desligar a nota da OS $numbers?';
  }

  @override
  String get nfseUnlinkMessage =>
      'A OS fica livre para outra nota. A nota continua no histórico.';

  @override
  String get nfseUnlinked => 'Nota desligada da OS';

  @override
  String get nfseLinkErrorOrderHasNota =>
      'Esta OS já tem nota. Cancele a outra antes.';

  @override
  String get nfseLinkErrorAlreadyLinked => 'Esta nota já está ligada a uma OS.';

  @override
  String get nfseDirectAcceptTerms => 'Li e aceito o termo do certificado';

  @override
  String get nfseDirectErrorTooManyAttempts =>
      'Muitas tentativas de enviar o certificado. Espere uma hora e tente de novo.';

  @override
  String get nfseDirectErrorBusy =>
      'Outra pessoa está mexendo neste certificado agora. Tente de novo em alguns minutos.';

  @override
  String get nfseDirectErrorDailyLimit =>
      'Este CNPJ chegou ao limite de notas de hoje. Amanhã volta a emitir; se precisar de mais, fale com o suporte.';

  @override
  String get nfseDirectErrorOwnerOnly => 'Só o dono da conta muda isso.';

  @override
  String get nfseDirectManagerCanIssue => 'Gerente pode emitir notas';

  @override
  String get nfseDirectManagerCanIssueHint =>
      'Você recebe um aviso sempre que outra pessoa emite ou cancela uma nota.';

  @override
  String get nfseEmailRow => 'E-mail ao cliente';

  @override
  String nfseEmailSentTo(String email, String date) {
    return 'Enviada para $email em $date';
  }

  @override
  String nfseEmailCancelSentTo(String email, String date) {
    return 'Aviso de cancelamento enviado para $email em $date';
  }

  @override
  String nfseEmailFailedTo(String email, String date) {
    return 'Não deu para mandar para $email em $date';
  }

  @override
  String get nfseEmailSkippedNoEmail =>
      'Não foi: o cliente não tem e-mail no cadastro';

  @override
  String get nfseEmailSkippedTurnedOff =>
      'Não foi: o envio automático está desligado';

  @override
  String get nfseEmailNotSentYet => 'Ainda não foi por e-mail';

  @override
  String get nfseEmailSendAgain => 'Enviar de novo';

  @override
  String get nfseEmailSend => 'Enviar';

  @override
  String get nfseIssuingProgress =>
      'Emitindo a nota… pode levar alguns segundos.';

  @override
  String get nfseCancelingProgress => 'Cancelando a nota…';

  @override
  String get nfseEmailSendingProgress => 'Mandando o e-mail…';

  @override
  String nfseEmailSentToast(String email) {
    return 'Nota enviada para $email';
  }

  @override
  String get nfseEmailFailedToast =>
      'Não deu para mandar o e-mail. Tente de novo daqui a pouco.';

  @override
  String get nfseEmailNoAddressToast =>
      'O cliente não tem e-mail. Coloque o e-mail no cadastro dele e envie de novo.';

  @override
  String get nfseDirectEmailToCustomer => 'Mandar a nota por e-mail ao cliente';

  @override
  String get nfseDirectEmailToCustomerHint =>
      'Vai sozinha ao emitir e ao cancelar, com o PDF e o XML. Desligue se você manda pelo WhatsApp.';

  @override
  String nfseDirectIssueEmailGoesTo(String email) {
    return 'A nota vai por e-mail para $email.';
  }

  @override
  String get nfseDirectIssueEmailOff =>
      'A nota não vai por e-mail: o envio automático está desligado.';

  @override
  String deviceReadingLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String get orderItemCatalogPriceTitle => 'Mudar o preço no Catálogo?';

  @override
  String orderItemCatalogPriceMessage(
    String entity,
    String name,
    String from,
    String to,
  ) {
    return '$entity “$name” custa $from no Catálogo. Usar $to sempre ou só nesta OS?';
  }

  @override
  String get orderItemCatalogPriceAlways => 'Usar sempre';

  @override
  String get orderItemCatalogPriceOnlyHere => 'Só nesta OS';

  @override
  String orderItemCatalogPriceSaved(String to) {
    return 'Preço do Catálogo mudou para $to';
  }

  @override
  String get orderItemCatalogPriceFailed =>
      'Não deu para mudar o preço no Catálogo. Mude por lá.';

  @override
  String get sharePreview => 'Ver como o cliente vê';

  @override
  String get sharePreviewFailed =>
      'Não deu para abrir a prévia. Tente de novo.';

  @override
  String checklistStatusDoneMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Concluído · $count sem resposta',
      one: 'Concluído · 1 sem resposta',
    );
    return '$_temp0';
  }

  @override
  String get checklistDoneTitle => 'Checklist concluído';

  @override
  String get checklistDoneReopenBody =>
      'Para mudar uma resposta, reabra o checklist.';

  @override
  String get checklistDoneAskReopenBody =>
      'Para mudar uma resposta, peça a quem gerencia a equipe para reabrir o checklist.';

  @override
  String get statementSend => 'Mandar extrato';

  @override
  String statementSendTitle(String name) {
    return 'Mandar a $name o que falta pagar';
  }

  @override
  String get statementSendMessage =>
      'Vai uma mensagem com as OS marcadas e quanto falta em cada uma. Quer mandar o PDF junto?';

  @override
  String get statementWithPdf => 'Mandar com PDF';

  @override
  String get statementTextOnly => 'Só o texto';

  @override
  String statementTextHello(String name, String company) {
    return 'Olá, $name! Estas são as OS em aberto com $company:';
  }

  @override
  String statementTextHelloNoCompany(String name) {
    return 'Olá, $name! Estas são as OS em aberto:';
  }

  @override
  String statementOrderNumber(String number) {
    return 'OS $number';
  }

  @override
  String statementOpenLine(String amount) {
    return 'Falta $amount';
  }

  @override
  String get statementInProgress => 'em andamento';

  @override
  String statementTotalOpen(String amount) {
    return 'Total em aberto: $amount';
  }

  @override
  String get statementPdfTitle => 'Extrato';

  @override
  String statementPdfSentence(String name, String date) {
    return 'OS em aberto de $name em $date.';
  }

  @override
  String get statementItemColumn => 'Serviço ou peça';

  @override
  String statementOrderTotals(String total, String paid, String open) {
    return 'Total $total  ·  Pago $paid  ·  Falta $open';
  }

  @override
  String get statementPdfTotalOpen => 'Total em aberto';

  @override
  String statementFileName(String date) {
    return 'Extrato-$date';
  }

  @override
  String get customersOrderRecent => 'Mais recentes';

  @override
  String get customersOrderName => 'Nome (A–Z)';

  @override
  String get customersSortBy => 'Ordenar por';

  @override
  String customerShowAllDevices(int count, String devices) {
    return 'Ver todos os $count $devices';
  }

  @override
  String customerShowAllOrders(int count) {
    return 'Ver todas as $count OS';
  }

  @override
  String get customerShowLess => 'Mostrar menos';

  @override
  String get customerSearchDevices => 'Buscar pelo nome ou placa';

  @override
  String get customerSearchOrders => 'Buscar pelo número da OS';

  @override
  String get filterLate => 'Atrasadas';

  @override
  String get filterUnpaid => 'Sem receber';

  @override
  String get noLateOrders => 'Nada atrasado.';

  @override
  String get noUnpaidOrders => 'Nada para receber.';

  @override
  String get checklistNoteAdd => '+ Observação';

  @override
  String get checklistNote => 'Observação';

  @override
  String get checklistNotePlaceholder => 'O que você viu e onde';

  @override
  String checklistNotePhoto(int number) {
    return 'Foto $number';
  }

  @override
  String checklistNoteLine(String label, String text) {
    return '$label: $text';
  }

  @override
  String get checklistAiReading => 'Lendo a foto…';

  @override
  String checklistAiFilled(String summary) {
    return 'Preenchi: $summary';
  }

  @override
  String get checklistAiFilledMark => 'Preenchido pela IA';

  @override
  String checklistAiSeenAlso(String text) {
    return 'A IA viu também: $text';
  }

  @override
  String get checklistAiAppend => 'Acrescentar';

  @override
  String checklistAiDiffers(String answer) {
    return 'A foto mostra: $answer';
  }

  @override
  String get checklistAiUseAnswer => 'Trocar';

  @override
  String get checklistAiDark => 'Foto escura, não deu para ler';

  @override
  String get checklistAiBlurry => 'Foto tremida, não deu para ler';

  @override
  String get checklistAiOffTarget => 'A foto não mostra o que a pergunta pede';

  @override
  String get checklistAiRetake => 'Tirar de novo';

  @override
  String get checklistAiFailed => 'Não deu para ler a foto agora';

  @override
  String get checklistAiQuota => 'Acabaram as leituras da IA deste mês';

  @override
  String get checklistAiNothing => 'A IA não achou a resposta na foto';

  @override
  String get checklistAiView => 'Ver';

  @override
  String planFeatureTitle(String plan) {
    return 'Recurso do plano $plan';
  }

  @override
  String planFeatureBody(String plan) {
    return 'Para usar, mude para o plano $plan. O que você já tem continua.';
  }

  @override
  String planFeatureAskOwner(String plan) {
    return 'Peça ao dono da empresa para mudar para o plano $plan.';
  }

  @override
  String planFeatureBadge(String plan) {
    return 'Plano $plan';
  }

  @override
  String get planFeatureNfse => 'Nota fiscal';

  @override
  String get planFeatureBrandedPdf => 'PDF sem a marca PraticOS';

  @override
  String get planFeatureOwnChecklists => 'Checklists próprios';

  @override
  String get planFeatureCharges => 'Cobrança e lembrete de pagamento';

  @override
  String get planFeatureTeamRoles => 'Técnico, gerente e outros perfis';

  @override
  String get planFeaturePerPersonAgenda => 'Agenda e responsável por pessoa';

  @override
  String get planFeatureWorkStages => 'Etapas do serviço';

  @override
  String get planFeatureTvMode => 'Modo TV';

  @override
  String get planFeatureContracts => 'Contratos';

  @override
  String get planFeatureAiFinance => 'IA no financeiro';

  @override
  String get planFeatureSpreadsheetExport => 'Relatório em planilha';

  @override
  String get planFeatureBulkActions => 'Ações em lote';

  @override
  String get planFeatureMcp => 'ChatGPT e Claude';

  @override
  String get planFeatureApi => 'API com chave';

  @override
  String get planUsageOrders => 'OS este mês';

  @override
  String get planUsageTaxIds => 'CNPJs na nota fiscal';

  @override
  String planNoticeOrdersNear(String used, String limit) {
    return 'Você já abriu $used de $limit OS este mês.';
  }

  @override
  String planNoticeOrdersAtLimit(String limit) {
    return 'Você abriu as $limit OS do mês. Pode continuar abrindo este mês; se passar de novo no mês que vem, a OS nova espera você mudar de plano.';
  }

  @override
  String planNoticeOrdersGrace(String limit) {
    return 'Este mês passou de $limit OS e nada foi travado. Se passar de novo no mês que vem, a OS nova espera você mudar de plano.';
  }

  @override
  String planNoticeOrdersBlocked(String limit) {
    return 'Passou de $limit OS de novo. As OS abertas continuam normais; a nova espera você mudar de plano.';
  }

  @override
  String planNoticeOrdersContactUs(String limit) {
    return 'Este mês já passou das $limit OS incluídas no Business.';
  }

  @override
  String planNoticePeopleContactUs(String limit) {
    return 'A equipe já passou das $limit pessoas incluídas no Business.';
  }

  @override
  String planNextTitle(String plan) {
    return 'O que o $plan dá a mais';
  }
}
