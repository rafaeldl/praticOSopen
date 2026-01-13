// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'PraticOS';

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
  String get basicInfo => 'Informações Básicas';

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
  String get seeAll => 'Ver todos';

  @override
  String get seeMore => 'Ver Mais';

  @override
  String get details => 'Detalhes';

  @override
  String get options => 'Opções';

  @override
  String get actions => 'Ações';

  @override
  String get statusAll => 'Todos';

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
  String get statusDelivery => 'Entrega';

  @override
  String get statusScheduled => 'Agendado';

  @override
  String get statusWaiting => 'Aguardando';

  @override
  String get statusRejected => 'Rejeitado';

  @override
  String get statusOpen => 'Aberto';

  @override
  String get statusClosed => 'Fechado';

  @override
  String get payments => 'Pagamentos';

  @override
  String get payment => 'Pagamento';

  @override
  String get paid => 'Pago';

  @override
  String get unpaid => 'Não Pago';

  @override
  String get partiallyPaid => 'Parcialmente Pago';

  @override
  String get toReceive => 'A Receber';

  @override
  String get toPay => 'A Pagar';

  @override
  String get received => 'Recebido';

  @override
  String get paymentMethod => 'Forma de Pagamento';

  @override
  String get paymentMethods => 'Formas de Pagamento';

  @override
  String get cash => 'Dinheiro';

  @override
  String get creditCard => 'Cartão de Crédito';

  @override
  String get debitCard => 'Cartão de Débito';

  @override
  String get pix => 'PIX';

  @override
  String get bankTransfer => 'Transferência';

  @override
  String get check => 'Cheque';

  @override
  String get installments => 'Parcelas';

  @override
  String get installment => 'Parcela';

  @override
  String get dueDate => 'Vencimento';

  @override
  String get paymentDate => 'Data do Pagamento';

  @override
  String get payTotalAmount => 'Pagar valor total';

  @override
  String get registerPayment => 'Registrar Pagamento';

  @override
  String get applyDiscount => 'Aplicar Desconto';

  @override
  String get paymentAmount => 'Valor do pagamento';

  @override
  String get discountAmount => 'Valor do desconto';

  @override
  String get fillValue => 'Preencha o valor';

  @override
  String get paymentCannotExceedBalance =>
      'Pagamento não pode ser maior que o saldo';

  @override
  String get discountCannotExceedBalance =>
      'Desconto não pode ser maior que o saldo';

  @override
  String get paymentRegistered => 'Pagamento registrado';

  @override
  String get discountApplied => 'Desconto aplicado';

  @override
  String get register => 'Registrar';

  @override
  String get history => 'Histórico';

  @override
  String get valueMustBeGreaterThanZero => 'O valor deve ser maior que zero';

  @override
  String get exampleCashPayment => 'Ex: Pagamento em dinheiro';

  @override
  String get exampleLoyaltyDiscount => 'Ex: Desconto de fidelidade';

  @override
  String get noTransactionsRecorded => 'Nenhuma transação registrada';

  @override
  String confirmRemoveTransaction(String type, String amount) {
    return 'Deseja remover este $type de $amount?';
  }

  @override
  String get requiredField => 'Campo obrigatório';

  @override
  String get invalidEmail => 'Email inválido';

  @override
  String get invalidPhone => 'Telefone inválido';

  @override
  String get invalidValue => 'Valor inválido';

  @override
  String get invalidDate => 'Data inválida';

  @override
  String get invalidFormat => 'Formato inválido';

  @override
  String get minimum => 'Mínimo';

  @override
  String get maximum => 'Máximo';

  @override
  String get characters => 'caracteres';

  @override
  String get selectOption => 'Selecione uma opção';

  @override
  String get noResults => 'Nenhum resultado encontrado';

  @override
  String get noData => 'Nenhum dado disponível';

  @override
  String get selectAtLeastOne => 'Selecione ao menos uma opção';

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
  String get photos => 'Fotos';

  @override
  String get photo => 'Foto';

  @override
  String get camera => 'Câmera';

  @override
  String get gallery => 'Galeria';

  @override
  String get noPhotos => 'Nenhuma foto';

  @override
  String get photoAdded => 'Foto adicionada';

  @override
  String get photoRemoved => 'Foto removida';

  @override
  String get today => 'Hoje';

  @override
  String get yesterday => 'Ontem';

  @override
  String get tomorrow => 'Amanhã';

  @override
  String get thisWeek => 'Esta Semana';

  @override
  String get lastWeek => 'Semana Passada';

  @override
  String get thisMonth => 'Este Mês';

  @override
  String get lastMonth => 'Mês Passado';

  @override
  String get thisYear => 'Este Ano';

  @override
  String get scheduledDate => 'Data Agendada';

  @override
  String get createdAt => 'Criado em';

  @override
  String get updatedAt => 'Atualizado em';

  @override
  String get date => 'Data';

  @override
  String get time => 'Hora';

  @override
  String get dateTime => 'Data e Hora';

  @override
  String get startDate => 'Data Inicial';

  @override
  String get endDate => 'Data Final';

  @override
  String get period => 'Período';

  @override
  String get confirmDelete => 'Confirmar Exclusão';

  @override
  String get confirmDeleteMessage => 'Deseja realmente excluir este item?';

  @override
  String confirmDeleteMessageNamed(String name) {
    return 'Deseja realmente excluir \"$name\"?';
  }

  @override
  String get confirmCancel => 'Confirmar Cancelamento';

  @override
  String get confirmCancelMessage => 'Deseja realmente cancelar?';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String get unsavedChangesMessage =>
      'Você tem alterações não salvas. Deseja sair mesmo assim?';

  @override
  String get confirmAction => 'Confirmar Ação';

  @override
  String get areYouSure => 'Tem certeza?';

  @override
  String get cannotUndo => 'Esta ação não pode ser desfeita.';

  @override
  String get discard => 'Descartar';

  @override
  String get keepEditing => 'Continuar Editando';

  @override
  String get leave => 'Sair';

  @override
  String get stay => 'Ficar';

  @override
  String get customer => 'Cliente';

  @override
  String get newCustomer => 'Novo Cliente';

  @override
  String get editCustomer => 'Editar Cliente';

  @override
  String get customerDetails => 'Detalhes do Cliente';

  @override
  String get customerName => 'Nome do Cliente';

  @override
  String get customerList => 'Lista de Clientes';

  @override
  String get searchCustomer => 'Buscar Cliente';

  @override
  String get selectCustomer => 'Selecionar Cliente';

  @override
  String get noCustomers => 'Nenhum cliente cadastrado';

  @override
  String get addCustomer => 'Adicionar Cliente';

  @override
  String get name => 'Nome';

  @override
  String get fullName => 'Nome Completo';

  @override
  String get nickname => 'Apelido';

  @override
  String get phone => 'Telefone';

  @override
  String get phones => 'Telefones';

  @override
  String get cellphone => 'Celular';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get email => 'E-mail';

  @override
  String get emails => 'E-mails';

  @override
  String get address => 'Endereço';

  @override
  String get addresses => 'Endereços';

  @override
  String get street => 'Rua';

  @override
  String get number => 'Número';

  @override
  String get complement => 'Complemento';

  @override
  String get neighborhood => 'Bairro';

  @override
  String get city => 'Cidade';

  @override
  String get state => 'Estado';

  @override
  String get zipCode => 'CEP';

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
  String get cpf => 'CPF';

  @override
  String get cnpj => 'CNPJ';

  @override
  String get cpfCnpj => 'CPF/CNPJ';

  @override
  String get order => 'Ordem de Serviço';

  @override
  String get orderShort => 'OS';

  @override
  String get newOrder => 'Nova OS';

  @override
  String get editOrder => 'Editar OS';

  @override
  String get orderDetails => 'Detalhes da OS';

  @override
  String get orderNumber => 'Número da OS';

  @override
  String get orderList => 'Lista de OS';

  @override
  String get searchOrder => 'Buscar OS';

  @override
  String get noOrders => 'Nenhuma OS encontrada';

  @override
  String get addOrder => 'Adicionar OS';

  @override
  String get createOrder => 'Criar OS';

  @override
  String get orderCreated => 'OS criada com sucesso';

  @override
  String get orderUpdated => 'OS atualizada com sucesso';

  @override
  String get orderDeleted => 'OS excluída com sucesso';

  @override
  String get orderStatus => 'Status da OS';

  @override
  String get changeStatus => 'Alterar Status';

  @override
  String get technician => 'Técnico';

  @override
  String get technicians => 'Técnicos';

  @override
  String get assignTechnician => 'Atribuir Técnico';

  @override
  String get problem => 'Problema Relatado';

  @override
  String get problemDescription => 'Descrição do Problema';

  @override
  String get solution => 'Solução';

  @override
  String get solutionDescription => 'Descrição da Solução';

  @override
  String get diagnosis => 'Diagnóstico';

  @override
  String get warranty => 'Garantia';

  @override
  String get warrantyPeriod => 'Período de Garantia';

  @override
  String get hasWarranty => 'Possui Garantia';

  @override
  String get noWarranty => 'Sem Garantia';

  @override
  String get warrantyExpired => 'Garantia Expirada';

  @override
  String get warrantyValid => 'Garantia Válida';

  @override
  String get priority => 'Prioridade';

  @override
  String get priorityLow => 'Baixa';

  @override
  String get priorityMedium => 'Média';

  @override
  String get priorityHigh => 'Alta';

  @override
  String get priorityUrgent => 'Urgente';

  @override
  String get device => 'Equipamento';

  @override
  String get deviceCategory => 'Categoria';

  @override
  String get newDevice => 'Novo Equipamento';

  @override
  String get editDevice => 'Editar Equipamento';

  @override
  String get deviceDetails => 'Detalhes do Equipamento';

  @override
  String get deviceList => 'Lista de Equipamentos';

  @override
  String get searchDevice => 'Buscar Equipamento';

  @override
  String get selectDevice => 'Selecionar Equipamento';

  @override
  String get noDevices => 'Nenhum equipamento cadastrado';

  @override
  String get addDevice => 'Adicionar Equipamento';

  @override
  String get brand => 'Marca';

  @override
  String get model => 'Modelo';

  @override
  String get serialNumber => 'Número de Série';

  @override
  String get imei => 'IMEI';

  @override
  String get color => 'Cor';

  @override
  String get condition => 'Condição';

  @override
  String get conditionNew => 'Novo';

  @override
  String get conditionUsed => 'Usado';

  @override
  String get conditionDamaged => 'Danificado';

  @override
  String get accessories => 'Acessórios';

  @override
  String get accessory => 'Acessório';

  @override
  String get defects => 'Defeitos';

  @override
  String get defect => 'Defeito';

  @override
  String get service => 'Serviço';

  @override
  String get newService => 'Novo Serviço';

  @override
  String get editService => 'Editar Serviço';

  @override
  String get serviceDetails => 'Detalhes do Serviço';

  @override
  String get serviceList => 'Lista de Serviços';

  @override
  String get searchService => 'Buscar Serviço';

  @override
  String get selectService => 'Selecionar Serviço';

  @override
  String get noServices => 'Nenhum serviço cadastrado';

  @override
  String get addService => 'Adicionar Serviço';

  @override
  String get serviceValue => 'Valor do Serviço';

  @override
  String get laborCost => 'Mão de Obra';

  @override
  String get product => 'Produto';

  @override
  String get newProduct => 'Novo Produto';

  @override
  String get editProduct => 'Editar Produto';

  @override
  String get productDetails => 'Detalhes do Produto';

  @override
  String get productList => 'Lista de Produtos';

  @override
  String get searchProduct => 'Buscar Produto';

  @override
  String get selectProduct => 'Selecionar Produto';

  @override
  String get noProducts => 'Nenhum produto cadastrado';

  @override
  String get addProduct => 'Adicionar Produto';

  @override
  String get sku => 'Código';

  @override
  String get barcode => 'Código de Barras';

  @override
  String get stock => 'Estoque';

  @override
  String get stockQuantity => 'Quantidade em Estoque';

  @override
  String get lowStock => 'Estoque Baixo';

  @override
  String get outOfStock => 'Sem Estoque';

  @override
  String get inStock => 'Em Estoque';

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
  String get discountPercent => 'Desconto (%)';

  @override
  String get discountValue => 'Valor do Desconto';

  @override
  String get price => 'Preço';

  @override
  String get unitPrice => 'Preço Unitário';

  @override
  String get costPrice => 'Preço de Custo';

  @override
  String get salePrice => 'Preço de Venda';

  @override
  String get quantity => 'Quantidade';

  @override
  String get value => 'Valor';

  @override
  String get amount => 'Valor';

  @override
  String get tax => 'Imposto';

  @override
  String get taxes => 'Impostos';

  @override
  String get fee => 'Taxa';

  @override
  String get fees => 'Taxas';

  @override
  String get grandTotal => 'Total Geral';

  @override
  String get balance => 'Saldo';

  @override
  String get totalPaid => 'Total Pago';

  @override
  String get remaining => 'Restante';

  @override
  String get change => 'Troco';

  @override
  String get savedSuccessfully => 'Salvo com sucesso';

  @override
  String get deletedSuccessfully => 'Excluído com sucesso';

  @override
  String get updatedSuccessfully => 'Atualizado com sucesso';

  @override
  String get createdSuccessfully => 'Criado com sucesso';

  @override
  String get copiedSuccessfully => 'Copiado com sucesso';

  @override
  String get sentSuccessfully => 'Enviado com sucesso';

  @override
  String get errorOccurred => 'Ocorreu um erro';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get operationFailed => 'Operação falhou';

  @override
  String get noInternetConnection => 'Sem conexão com a internet';

  @override
  String get connectionError => 'Erro de conexão';

  @override
  String get serverError => 'Erro no servidor';

  @override
  String get unknownError => 'Erro desconhecido';

  @override
  String get permissionDenied => 'Permissão negada';

  @override
  String get notFound => 'Não encontrado';

  @override
  String get timeout => 'Tempo esgotado';

  @override
  String get sessionExpired => 'Sessão expirada';

  @override
  String get login => 'Entrar';

  @override
  String get logout => 'Sair';

  @override
  String get logoutConfirm => 'Deseja realmente sair?';

  @override
  String get signUp => 'Criar Conta';

  @override
  String get signIn => 'Entrar';

  @override
  String get forgotPassword => 'Esqueci a senha';

  @override
  String get resetPassword => 'Redefinir Senha';

  @override
  String get changePassword => 'Alterar Senha';

  @override
  String get password => 'Senha';

  @override
  String get currentPassword => 'Senha Atual';

  @override
  String get newPassword => 'Nova Senha';

  @override
  String get confirmPassword => 'Confirmar Senha';

  @override
  String get passwordsDontMatch => 'As senhas não conferem';

  @override
  String get passwordTooShort => 'Senha muito curta';

  @override
  String get invalidCredentials => 'Credenciais inválidas';

  @override
  String get accountCreated => 'Conta criada com sucesso';

  @override
  String get emailSent => 'E-mail enviado';

  @override
  String get checkYourEmail => 'Verifique seu e-mail';

  @override
  String get continueWithGoogle => 'Continuar com Google';

  @override
  String get continueWithApple => 'Continuar com Apple';

  @override
  String get orContinueWith => 'Ou continue com';

  @override
  String get alreadyHaveAccount => 'Já possui uma conta?';

  @override
  String get dontHaveAccount => 'Não possui uma conta?';

  @override
  String get termsAndConditions => 'Termos e Condições';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get agreeToTerms => 'Eu concordo com os Termos e Condições';

  @override
  String get welcome => 'Bem-vindo';

  @override
  String get welcomeBack => 'Bem-vindo de volta';

  @override
  String get getStarted => 'Começar';

  @override
  String get letsStart => 'Vamos Começar';

  @override
  String get selectSegment => 'Selecionar Segmento';

  @override
  String get selectSpecialties => 'Selecione suas Especialidades';

  @override
  String get companyName => 'Nome da Empresa';

  @override
  String get setupComplete => 'Configuração Concluída';

  @override
  String get allSet => 'Tudo Pronto!';

  @override
  String get startUsing => 'Comece a usar o PraticOS';

  @override
  String get skip => 'Pular';

  @override
  String get continue_ => 'Continuar';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar Idioma';

  @override
  String get portuguese => 'Português';

  @override
  String get english => 'Inglês';

  @override
  String get spanish => 'Espanhol';

  @override
  String get theme => 'Tema';

  @override
  String get darkMode => 'Modo Escuro';

  @override
  String get lightMode => 'Modo Claro';

  @override
  String get systemDefault => 'Padrão do Sistema';

  @override
  String get notifications => 'Notificações';

  @override
  String get enableNotifications => 'Ativar Notificações';

  @override
  String get sound => 'Som';

  @override
  String get vibration => 'Vibração';

  @override
  String get about => 'Sobre';

  @override
  String get version => 'Versão';

  @override
  String get help => 'Ajuda';

  @override
  String get support => 'Suporte';

  @override
  String get contactUs => 'Fale Conosco';

  @override
  String get rateApp => 'Avaliar App';

  @override
  String get shareApp => 'Compartilhar App';

  @override
  String get dashboard => 'Painel';

  @override
  String get overview => 'Visão Geral';

  @override
  String get statistics => 'Estatísticas';

  @override
  String get analytics => 'Análises';

  @override
  String get revenue => 'Receita';

  @override
  String get expenses => 'Despesas';

  @override
  String get profit => 'Lucro';

  @override
  String get ordersToday => 'OS Hoje';

  @override
  String get ordersThisWeek => 'OS Esta Semana';

  @override
  String get ordersThisMonth => 'OS Este Mês';

  @override
  String get pendingOrders => 'OS Pendentes';

  @override
  String get completedOrders => 'OS Concluídas';

  @override
  String get topServices => 'Serviços Mais Realizados';

  @override
  String get topProducts => 'Produtos Mais Vendidos';

  @override
  String get recentOrders => 'OS Recentes';

  @override
  String get recentCustomers => 'Clientes Recentes';

  @override
  String get role => 'Função';

  @override
  String get roles => 'Funções';

  @override
  String get owner => 'Proprietário';

  @override
  String get admin => 'Administrador';

  @override
  String get manager => 'Gerente';

  @override
  String get employee => 'Funcionário';

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
  String get inviteMember => 'Convidar Membro';

  @override
  String get removeMember => 'Remover Membro';

  @override
  String get memberRemoved => 'Membro removido';

  @override
  String get invitationSent => 'Convite enviado';

  @override
  String get pendingInvitations => 'Convites Pendentes';

  @override
  String get acceptInvitation => 'Aceitar Convite';

  @override
  String get declineInvitation => 'Recusar Convite';

  @override
  String get form => 'Formulário';

  @override
  String get forms => 'Formulários';

  @override
  String get checklist => 'Checklist';

  @override
  String get checklists => 'Checklists';

  @override
  String get inspection => 'Vistoria';

  @override
  String get inspections => 'Vistorias';

  @override
  String get signature => 'Assinatura';

  @override
  String get customerSignature => 'Assinatura do Cliente';

  @override
  String get technicianSignature => 'Assinatura do Técnico';

  @override
  String get signHere => 'Assine aqui';

  @override
  String get clearSignature => 'Limpar Assinatura';

  @override
  String get required => 'Obrigatório';

  @override
  String get optional => 'Opcional';

  @override
  String get complete => 'Concluir';

  @override
  String get incomplete => 'Incompleto';

  @override
  String get answered => 'Respondido';

  @override
  String get notAnswered => 'Não Respondido';

  @override
  String get quote => 'Orçamento';

  @override
  String get quotes => 'Orçamentos';

  @override
  String get newQuote => 'Novo Orçamento';

  @override
  String get editQuote => 'Editar Orçamento';

  @override
  String get quoteDetails => 'Detalhes do Orçamento';

  @override
  String get sendQuote => 'Enviar Orçamento';

  @override
  String get approveQuote => 'Aprovar Orçamento';

  @override
  String get rejectQuote => 'Rejeitar Orçamento';

  @override
  String get quoteApproved => 'Orçamento Aprovado';

  @override
  String get quoteRejected => 'Orçamento Rejeitado';

  @override
  String get quoteSent => 'Orçamento Enviado';

  @override
  String get validUntil => 'Válido até';

  @override
  String expiresIn(int days) {
    return 'Expira em $days dias';
  }

  @override
  String get expired => 'Expirado';

  @override
  String get active => 'Ativo';

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
  String get published => 'Publicado';

  @override
  String get archived => 'Arquivado';

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
  String get default_ => 'Padrão';

  @override
  String get custom => 'Personalizado';

  @override
  String get new_ => 'Novo';

  @override
  String get old => 'Antigo';

  @override
  String get recent => 'Recente';

  @override
  String get popular => 'Popular';

  @override
  String get featured => 'Destaque';

  @override
  String get recommended => 'Recomendado';

  @override
  String get welcomeToApp => 'Bem-vindo ao PraticOS';

  @override
  String get appSubtitle =>
      'Gerencie suas ordens de serviço\nde forma simples e eficiente';

  @override
  String get signInWithEmail => 'Entrar com email';

  @override
  String get byContinuingYouAgree => 'Ao continuar, você concorda com nossa';

  @override
  String get error => 'Erro';

  @override
  String get errorSignInApple => 'Erro ao entrar com Apple';

  @override
  String get errorSignInGoogle => 'Erro ao entrar com Google';

  @override
  String get companyNotFound => 'Empresa não encontrada';

  @override
  String get companyNoSegment => 'Empresa sem segmento definido';

  @override
  String get errorLoadingConfig => 'Erro ao carregar configuração';

  @override
  String get enterEmailPassword =>
      'Digite seu email e senha para acessar sua conta';

  @override
  String get credentials => 'Credenciais';

  @override
  String get enterYourPassword => 'Digite sua senha';

  @override
  String get userNotFound => 'Usuário não encontrado';

  @override
  String get wrongPassword => 'Senha incorreta';

  @override
  String get errorSignIn => 'Erro ao entrar. Tente novamente.';

  @override
  String get enterYourEmail => 'Digite seu email';

  @override
  String get checkInboxResetPassword =>
      'Verifique sua caixa de entrada para redefinir sua senha.';

  @override
  String get errorSendingRecoveryEmail => 'Erro ao enviar email de recuperação';

  @override
  String get user => 'Usuário';

  @override
  String get organization => 'Organização';

  @override
  String get switchCompany => 'Trocar Empresa';

  @override
  String get switchBetweenOrganizations => 'Alternar entre organizações';

  @override
  String get management => 'Gerenciamento';

  @override
  String get companyData => 'Dados da Empresa';

  @override
  String get interface_ => 'Interface';

  @override
  String get nightMode => 'Modo Noturno';

  @override
  String get account => 'Conta';

  @override
  String get deleteAccount => 'Excluir Conta';

  @override
  String get permanentlyRemoveAllData =>
      'Remover permanentemente todos os dados';

  @override
  String get chooseTheme => 'Escolher tema';

  @override
  String get automaticSystem => 'Automático (Sistema)';

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
  String get nowDeletingAccount =>
      'Agora você pode prosseguir com a exclusão da conta.';

  @override
  String get reauthenticationFailed => 'Falha na Re-autenticação';

  @override
  String get couldNotReauthenticate => 'Não foi possível autenticar novamente.';

  @override
  String get errorLoadingData => 'Erro ao carregar dados';

  @override
  String get tapToAddFirst => 'Toque em + para adicionar';

  @override
  String get confirmRemove => 'Deseja remover';

  @override
  String get remove => 'Remover';

  @override
  String get noPermission => 'Sem Permissão';

  @override
  String get noPermissionToRemove =>
      'Você não tem permissão para remover este item.';

  @override
  String get professionalizeYourBusiness => 'Profissionalize seu negócio';

  @override
  String get configureCompanyProfile =>
      'Configure o perfil da sua empresa para emitir ordens de serviço profissionais agora mesmo.';

  @override
  String get professionalOrders => 'Ordens Profissionais';

  @override
  String get createDigitalOrders => 'Crie OS digitais personalizadas.';

  @override
  String get customerManagement => 'Gestão de Clientes';

  @override
  String get keepHistoryOrganized =>
      'Mantenha histórico e contatos organizados.';

  @override
  String get configureMyBusiness => 'Configurar Meu Negócio';

  @override
  String get configureLater => 'Configurar Depois';

  @override
  String get errorCreatingCompany => 'Erro ao criar empresa padrão';

  @override
  String get chooseSegment => 'Escolha o Ramo';

  @override
  String get selectSegmentPrompt =>
      'Selecione o ramo de atuação para personalizar o sistema para você.';

  @override
  String get availableSegments => 'Segmentos Disponíveis';

  @override
  String get noSegmentsAvailable => 'Nenhum segmento disponível';

  @override
  String get errorLoadingSegments => 'Erro ao carregar segmentos';

  @override
  String get specialties => 'Especialidades';

  @override
  String get myCompany => 'Minha Empresa';

  @override
  String get retryAgain => 'Tentar novamente';

  @override
  String get noResultsFound => 'Nenhum resultado encontrado';

  @override
  String get unitValue => 'Valor unitário';

  @override
  String get setAsCover => 'Definir como capa';

  @override
  String get roleAdmin => 'Administrador';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleManager => 'Gerente';

  @override
  String get roleConsultant => 'Consultor';

  @override
  String get roleTechnician => 'Técnico';

  @override
  String get roleDescAdmin => 'Acesso total ao sistema';

  @override
  String get roleDescSupervisor => 'Gestão operacional dos técnicos';

  @override
  String get roleDescManager => 'Gestão financeira e relatórios';

  @override
  String get roleDescConsultant => 'Vendas e acompanhamento comercial';

  @override
  String get roleDescTechnician => 'Execução de serviços';

  @override
  String get noFeminine => 'Nenhuma';

  @override
  String get registered => 'cadastrado';

  @override
  String get registeredFeminine => 'cadastrada';

  @override
  String get errorLoading => 'Erro ao carregar';

  @override
  String get tapPlusToAddYourFirst => 'Toque em + para adicionar seu primeiro';

  @override
  String get tapPlusToAddYourFirstFeminine =>
      'Toque em + para adicionar sua primeira';

  @override
  String get doYouWantToRemoveThe => 'Deseja remover o';

  @override
  String get doYouWantToRemoveTheFeminine => 'Deseja remover a';

  @override
  String get searchCollaborator => 'Buscar colaborador';

  @override
  String get noCollaboratorFound => 'Nenhum colaborador encontrado';

  @override
  String get pending => 'Pendente';

  @override
  String get inviteTo => 'Convite para';

  @override
  String get invitePendingMessage =>
      'Este convite está pendente. O usuário verá o convite quando se cadastrar no sistema.';

  @override
  String get cancelInvite => 'Cancelar Convite';

  @override
  String get confirmCancelInvite =>
      'Tem certeza que deseja cancelar o convite para';

  @override
  String get yesCancel => 'Sim, Cancelar';

  @override
  String get userWithoutName => 'Usuário sem nome';

  @override
  String get actionsFor => 'Ações para';

  @override
  String get editPermission => 'Editar Permissão';

  @override
  String get removeFromCompany => 'Remover da Empresa';

  @override
  String get selectProfile => 'Selecionar Perfil';

  @override
  String get chooseCollaboratorRole =>
      'Escolha o perfil de acesso do colaborador';

  @override
  String get removeCollaborator => 'Remover Colaborador';

  @override
  String confirmRemoveFromOrganization(String name) {
    return 'Tem certeza que deseja remover $name da organização?';
  }

  @override
  String get emailNotProvided => 'Email não informado';

  @override
  String get newCollaborator => 'Novo Colaborador';

  @override
  String get userInformation => 'Informações do Usuário';

  @override
  String get userWillReceiveInviteByEmail =>
      'O usuário receberá um convite por email.';

  @override
  String get emailPlaceholder => 'email@exemplo.com';

  @override
  String get collaboratorAdded => 'Colaborador Adicionado';

  @override
  String get collaboratorAddedSuccess =>
      'O colaborador foi adicionado à empresa com sucesso.';

  @override
  String get inviteSent => 'Convite Enviado';

  @override
  String get inviteCreatedMessage =>
      'O usuário ainda não está cadastrado no sistema. Um convite foi criado e aparecerá quando ele se cadastrar.';

  @override
  String get financialDashboard => 'Painel Financeiro';

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
  String get tapToReturnToCurrent => 'Toque para voltar ao atual';

  @override
  String get selectPeriod => 'Selecionar Período';

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
  String get noCustomerDataInPeriod => 'Sem dados de clientes neste período';

  @override
  String get serviceWithoutName => 'Serviço sem nome';

  @override
  String get productWithoutName => 'Produto sem nome';

  @override
  String get noServiceDataInPeriod => 'Sem dados de serviços neste período';

  @override
  String get noProductDataInPeriod => 'Sem dados de produtos neste período';

  @override
  String get seeLess => 'Ver menos';

  @override
  String seeAllCount(int count) {
    return 'Ver todos ($count)';
  }

  @override
  String get toReceiveLowerCase => 'A receber';

  @override
  String get errorGeneratingReport => 'Erro ao gerar relatório';

  @override
  String get pendingPayment => 'Pendente';

  @override
  String get selectCountry => 'Selecionar País';

  @override
  String get chooseCompanySegment => 'Escolha o ramo de atuação da empresa';

  @override
  String get contacts => 'Contatos';

  @override
  String get contactMethods => 'Meios de Contato';

  @override
  String get howCustomersCanReachYou =>
      'Como seus clientes podem falar com você?';

  @override
  String get preparing => 'Preparando...';

  @override
  String get uploadingLogo => 'Enviando logo...';

  @override
  String get creatingCompany => 'Criando empresa...';

  @override
  String get importingForms => 'Importando formulários...';

  @override
  String get creatingSampleData => 'Criando dados de exemplo...';

  @override
  String get createSampleDataQuestion => 'Deseja criar dados de exemplo?';

  @override
  String get sampleDataDescription =>
      'Podemos criar alguns dados de exemplo para você começar a usar o sistema imediatamente:';

  @override
  String get commonServicesForSegment => 'Serviços comuns do seu segmento';

  @override
  String get mostUsedProducts => 'Produtos e peças mais utilizados';

  @override
  String get sampleEquipment => 'Equipamentos de exemplo';

  @override
  String get sampleForms => 'Formulários de vistoria';

  @override
  String get demoCustomer => 'Cliente de demonstração';

  @override
  String get canEditOrDeleteAnytime =>
      'Você poderá editar ou excluir esses dados a qualquer momento.';

  @override
  String get noStartFromScratch => 'Não, começar do zero';

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
  String get formCompleted => 'Procedimento concluído';

  @override
  String get noPhotoAdded => 'Nenhuma foto adicionada';

  @override
  String get tapCameraIconToAdd => 'Toque no ícone da câmera para adicionar';

  @override
  String get type => 'Digitar';

  @override
  String get errorLoadingPhoto => 'Erro ao carregar foto';

  @override
  String get reopen => 'Reabrir';

  @override
  String get addItems => 'Adicione itens';

  @override
  String get pleaseAddAtLeastOneItem =>
      'Por favor, adicione pelo menos um item ao procedimento.';

  @override
  String get couldNotSaveForm => 'Não foi possível salvar o procedimento.';

  @override
  String get removeItem => 'Remover item';

  @override
  String get minOptions => 'Mínimo de opções';

  @override
  String get pleaseEnterAtLeast2Options => 'Informe pelo menos 2 opções.';

  @override
  String get selectItemType => 'Tipo do Item';

  @override
  String get selectResponseType => 'Selecione o tipo de resposta esperada';

  @override
  String get itemConfiguration => 'CONFIGURAÇÃO DO ITEM';

  @override
  String get formInformation => 'INFORMAÇÕES';

  @override
  String get formConfiguration => 'CONFIGURAÇÕES';

  @override
  String get title => 'Título';

  @override
  String get label => 'Label';

  @override
  String get itemType => 'Tipo';

  @override
  String get optionsHeader => 'OPÇÕES';

  @override
  String get typeOneOptionPerLine => 'Digite uma opção por linha';

  @override
  String get allowPhotos => 'Permitir fotos';

  @override
  String get userCanAttachPhotos => 'Usuário pode anexar fotos a este item';

  @override
  String get procedures => 'Procedimentos';

  @override
  String get searchProcedure => 'Buscar procedimento';

  @override
  String get myProcedures => 'Meus Procedimentos';

  @override
  String get globalProcedures => 'Procedimentos Globais';

  @override
  String get noProceduresRegistered => 'Nenhum procedimento cadastrado';

  @override
  String get noProceduresAvailable => 'Nenhum procedimento disponível';

  @override
  String get tapPlusToCreateFirst =>
      'Toque em + para criar seu primeiro procedimento.';

  @override
  String get fromCompany => 'Da Empresa';

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
  String get youHaveBeenInvited =>
      'Você foi convidado para fazer parte de empresas no PraticOS!';

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
  String get markAsToReceive => 'Marcar como A Receber';

  @override
  String get thisWillRemoveAllPayments =>
      'Isso irá remover todos os pagamentos e descontos registrados. Deseja continuar?';

  @override
  String get attention => 'Atenção';

  @override
  String get almostThere => 'Quase lá!';

  @override
  String get yesCreateSampleData => 'Sim, criar dados de exemplo';

  @override
  String get availableSpecialties => 'ESPECIALIDADES DISPONÍVEIS';

  @override
  String get pleaseSelectAtLeastOneSpecialty =>
      'Por favor, selecione pelo menos uma especialidade para continuar.';
}
