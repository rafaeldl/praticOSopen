import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// Nome do aplicativo
  ///
  /// In pt, this message translates to:
  /// **'PraticOS'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get home;

  /// No description provided for @orders.
  ///
  /// In pt, this message translates to:
  /// **'Ordens de Serviço'**
  String get orders;

  /// No description provided for @customers.
  ///
  /// In pt, this message translates to:
  /// **'Clientes'**
  String get customers;

  /// No description provided for @devices.
  ///
  /// In pt, this message translates to:
  /// **'Equipamentos'**
  String get devices;

  /// No description provided for @services.
  ///
  /// In pt, this message translates to:
  /// **'Serviços'**
  String get services;

  /// No description provided for @products.
  ///
  /// In pt, this message translates to:
  /// **'Produtos'**
  String get products;

  /// No description provided for @reports.
  ///
  /// In pt, this message translates to:
  /// **'Relatórios'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// No description provided for @company.
  ///
  /// In pt, this message translates to:
  /// **'Empresa'**
  String get company;

  /// No description provided for @team.
  ///
  /// In pt, this message translates to:
  /// **'Equipe'**
  String get team;

  /// No description provided for @collaborators.
  ///
  /// In pt, this message translates to:
  /// **'Colaboradores'**
  String get collaborators;

  /// No description provided for @save.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get add;

  /// No description provided for @create.
  ///
  /// In pt, this message translates to:
  /// **'Criar'**
  String get create;

  /// No description provided for @update.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get update;

  /// No description provided for @search.
  ///
  /// In pt, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @searchOrAddNew.
  ///
  /// In pt, this message translates to:
  /// **'Buscar ou adicionar novo'**
  String get searchOrAddNew;

  /// No description provided for @filter.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In pt, this message translates to:
  /// **'Ordenar'**
  String get sort;

  /// No description provided for @refresh.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get refresh;

  /// No description provided for @close.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get back;

  /// No description provided for @next.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In pt, this message translates to:
  /// **'Anterior'**
  String get previous;

  /// No description provided for @done.
  ///
  /// In pt, this message translates to:
  /// **'Concluído'**
  String get done;

  /// No description provided for @finish.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar'**
  String get finish;

  /// No description provided for @loading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando...'**
  String get loading;

  /// No description provided for @send.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get send;

  /// No description provided for @share.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In pt, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @print.
  ///
  /// In pt, this message translates to:
  /// **'Imprimir'**
  String get print;

  /// No description provided for @preview.
  ///
  /// In pt, this message translates to:
  /// **'Visualizar'**
  String get preview;

  /// No description provided for @export.
  ///
  /// In pt, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @import.
  ///
  /// In pt, this message translates to:
  /// **'Importar'**
  String get import;

  /// No description provided for @select.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Tudo'**
  String get selectAll;

  /// No description provided for @clear.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get clear;

  /// No description provided for @reset.
  ///
  /// In pt, this message translates to:
  /// **'Redefinir'**
  String get reset;

  /// No description provided for @basicInfo.
  ///
  /// In pt, this message translates to:
  /// **'Informações Básicas'**
  String get basicInfo;

  /// No description provided for @apply.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar'**
  String get apply;

  /// No description provided for @ok.
  ///
  /// In pt, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In pt, this message translates to:
  /// **'Sim'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In pt, this message translates to:
  /// **'Não'**
  String get no;

  /// No description provided for @more.
  ///
  /// In pt, this message translates to:
  /// **'Mais'**
  String get more;

  /// No description provided for @less.
  ///
  /// In pt, this message translates to:
  /// **'Menos'**
  String get less;

  /// No description provided for @seeAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get seeAll;

  /// No description provided for @seeMore.
  ///
  /// In pt, this message translates to:
  /// **'Ver Mais'**
  String get seeMore;

  /// No description provided for @details.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes'**
  String get details;

  /// No description provided for @options.
  ///
  /// In pt, this message translates to:
  /// **'Opções'**
  String get options;

  /// No description provided for @actions.
  ///
  /// In pt, this message translates to:
  /// **'Ações'**
  String get actions;

  /// No description provided for @statusAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get statusAll;

  /// No description provided for @statusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovado'**
  String get statusApproved;

  /// No description provided for @statusInProgress.
  ///
  /// In pt, this message translates to:
  /// **'Em Andamento'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluído'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelado'**
  String get statusCancelled;

  /// No description provided for @statusQuote.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento'**
  String get statusQuote;

  /// No description provided for @statusDelivery.
  ///
  /// In pt, this message translates to:
  /// **'Entrega'**
  String get statusDelivery;

  /// No description provided for @statusScheduled.
  ///
  /// In pt, this message translates to:
  /// **'Agendado'**
  String get statusScheduled;

  /// No description provided for @statusWaiting.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando'**
  String get statusWaiting;

  /// No description provided for @statusRejected.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitado'**
  String get statusRejected;

  /// No description provided for @statusOpen.
  ///
  /// In pt, this message translates to:
  /// **'Aberto'**
  String get statusOpen;

  /// No description provided for @statusClosed.
  ///
  /// In pt, this message translates to:
  /// **'Fechado'**
  String get statusClosed;

  /// No description provided for @payments.
  ///
  /// In pt, this message translates to:
  /// **'Pagamentos'**
  String get payments;

  /// No description provided for @payment.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento'**
  String get payment;

  /// No description provided for @paid.
  ///
  /// In pt, this message translates to:
  /// **'Pago'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In pt, this message translates to:
  /// **'Não Pago'**
  String get unpaid;

  /// No description provided for @partiallyPaid.
  ///
  /// In pt, this message translates to:
  /// **'Parcialmente Pago'**
  String get partiallyPaid;

  /// No description provided for @toReceive.
  ///
  /// In pt, this message translates to:
  /// **'A Receber'**
  String get toReceive;

  /// No description provided for @toPay.
  ///
  /// In pt, this message translates to:
  /// **'A Pagar'**
  String get toPay;

  /// No description provided for @received.
  ///
  /// In pt, this message translates to:
  /// **'Recebido'**
  String get received;

  /// No description provided for @paymentMethod.
  ///
  /// In pt, this message translates to:
  /// **'Forma de Pagamento'**
  String get paymentMethod;

  /// No description provided for @paymentMethods.
  ///
  /// In pt, this message translates to:
  /// **'Formas de Pagamento'**
  String get paymentMethods;

  /// No description provided for @cash.
  ///
  /// In pt, this message translates to:
  /// **'Dinheiro'**
  String get cash;

  /// No description provided for @creditCard.
  ///
  /// In pt, this message translates to:
  /// **'Cartão de Crédito'**
  String get creditCard;

  /// No description provided for @debitCard.
  ///
  /// In pt, this message translates to:
  /// **'Cartão de Débito'**
  String get debitCard;

  /// No description provided for @pix.
  ///
  /// In pt, this message translates to:
  /// **'PIX'**
  String get pix;

  /// No description provided for @bankTransfer.
  ///
  /// In pt, this message translates to:
  /// **'Transferência'**
  String get bankTransfer;

  /// No description provided for @check.
  ///
  /// In pt, this message translates to:
  /// **'Cheque'**
  String get check;

  /// No description provided for @installments.
  ///
  /// In pt, this message translates to:
  /// **'Parcelas'**
  String get installments;

  /// No description provided for @installment.
  ///
  /// In pt, this message translates to:
  /// **'Parcela'**
  String get installment;

  /// No description provided for @dueDate.
  ///
  /// In pt, this message translates to:
  /// **'Vencimento'**
  String get dueDate;

  /// No description provided for @paymentDate.
  ///
  /// In pt, this message translates to:
  /// **'Data do Pagamento'**
  String get paymentDate;

  /// No description provided for @payTotalAmount.
  ///
  /// In pt, this message translates to:
  /// **'Pagar valor total'**
  String get payTotalAmount;

  /// No description provided for @registerPayment.
  ///
  /// In pt, this message translates to:
  /// **'Registrar Pagamento'**
  String get registerPayment;

  /// No description provided for @applyDiscount.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar Desconto'**
  String get applyDiscount;

  /// No description provided for @paymentAmount.
  ///
  /// In pt, this message translates to:
  /// **'Valor do pagamento'**
  String get paymentAmount;

  /// No description provided for @discountAmount.
  ///
  /// In pt, this message translates to:
  /// **'Valor do desconto'**
  String get discountAmount;

  /// No description provided for @fillValue.
  ///
  /// In pt, this message translates to:
  /// **'Preencha o valor'**
  String get fillValue;

  /// No description provided for @paymentCannotExceedBalance.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento não pode ser maior que o saldo'**
  String get paymentCannotExceedBalance;

  /// No description provided for @discountCannotExceedBalance.
  ///
  /// In pt, this message translates to:
  /// **'Desconto não pode ser maior que o saldo'**
  String get discountCannotExceedBalance;

  /// No description provided for @paymentRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento registrado'**
  String get paymentRegistered;

  /// No description provided for @discountApplied.
  ///
  /// In pt, this message translates to:
  /// **'Desconto aplicado'**
  String get discountApplied;

  /// No description provided for @register.
  ///
  /// In pt, this message translates to:
  /// **'Registrar'**
  String get register;

  /// No description provided for @history.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get history;

  /// No description provided for @valueMustBeGreaterThanZero.
  ///
  /// In pt, this message translates to:
  /// **'O valor deve ser maior que zero'**
  String get valueMustBeGreaterThanZero;

  /// No description provided for @exampleCashPayment.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Pagamento em dinheiro'**
  String get exampleCashPayment;

  /// No description provided for @exampleLoyaltyDiscount.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Desconto de fidelidade'**
  String get exampleLoyaltyDiscount;

  /// No description provided for @noTransactionsRecorded.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma transação registrada'**
  String get noTransactionsRecorded;

  /// Mensagem de confirmação para remover transação
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover este {type} de {amount}?'**
  String confirmRemoveTransaction(String type, String amount);

  /// No description provided for @requiredField.
  ///
  /// In pt, this message translates to:
  /// **'Campo obrigatório'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In pt, this message translates to:
  /// **'Email inválido'**
  String get invalidEmail;

  /// No description provided for @invalidPhone.
  ///
  /// In pt, this message translates to:
  /// **'Telefone inválido'**
  String get invalidPhone;

  /// No description provided for @invalidValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor inválido'**
  String get invalidValue;

  /// No description provided for @invalidDate.
  ///
  /// In pt, this message translates to:
  /// **'Data inválida'**
  String get invalidDate;

  /// No description provided for @invalidFormat.
  ///
  /// In pt, this message translates to:
  /// **'Formato inválido'**
  String get invalidFormat;

  /// No description provided for @minimum.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo'**
  String get minimum;

  /// No description provided for @maximum.
  ///
  /// In pt, this message translates to:
  /// **'Máximo'**
  String get maximum;

  /// No description provided for @characters.
  ///
  /// In pt, this message translates to:
  /// **'caracteres'**
  String get characters;

  /// No description provided for @selectOption.
  ///
  /// In pt, this message translates to:
  /// **'Selecione uma opção'**
  String get selectOption;

  /// No description provided for @noResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum resultado encontrado'**
  String get noResults;

  /// No description provided for @noData.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum dado disponível'**
  String get noData;

  /// No description provided for @noValuesRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum valor cadastrado'**
  String get noValuesRegistered;

  /// No description provided for @typeAboveToAdd.
  ///
  /// In pt, this message translates to:
  /// **'Digite no campo acima para adicionar'**
  String get typeAboveToAdd;

  /// No description provided for @addNewValue.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar novo valor'**
  String get addNewValue;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In pt, this message translates to:
  /// **'Selecione ao menos uma opção'**
  String get selectAtLeastOne;

  /// No description provided for @minLength.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo de {count} caracteres'**
  String minLength(int count);

  /// No description provided for @maxLength.
  ///
  /// In pt, this message translates to:
  /// **'Máximo de {count} caracteres'**
  String maxLength(int count);

  /// No description provided for @takePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Tirar Foto'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In pt, this message translates to:
  /// **'Escolher da Galeria'**
  String get chooseFromGallery;

  /// No description provided for @changePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Alterar Foto'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Remover Foto'**
  String get removePhoto;

  /// No description provided for @addPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Foto'**
  String get addPhoto;

  /// No description provided for @photos.
  ///
  /// In pt, this message translates to:
  /// **'Fotos'**
  String get photos;

  /// No description provided for @photo.
  ///
  /// In pt, this message translates to:
  /// **'Foto'**
  String get photo;

  /// No description provided for @camera.
  ///
  /// In pt, this message translates to:
  /// **'Câmera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In pt, this message translates to:
  /// **'Galeria'**
  String get gallery;

  /// No description provided for @noPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma foto'**
  String get noPhotos;

  /// No description provided for @photoAdded.
  ///
  /// In pt, this message translates to:
  /// **'Foto adicionada'**
  String get photoAdded;

  /// No description provided for @photoRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Foto removida'**
  String get photoRemoved;

  /// No description provided for @today.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In pt, this message translates to:
  /// **'Amanhã'**
  String get tomorrow;

  /// No description provided for @thisWeek.
  ///
  /// In pt, this message translates to:
  /// **'Esta Semana'**
  String get thisWeek;

  /// No description provided for @lastWeek.
  ///
  /// In pt, this message translates to:
  /// **'Semana Passada'**
  String get lastWeek;

  /// No description provided for @thisMonth.
  ///
  /// In pt, this message translates to:
  /// **'Este Mês'**
  String get thisMonth;

  /// No description provided for @lastMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês Passado'**
  String get lastMonth;

  /// No description provided for @thisYear.
  ///
  /// In pt, this message translates to:
  /// **'Este Ano'**
  String get thisYear;

  /// No description provided for @scheduledDate.
  ///
  /// In pt, this message translates to:
  /// **'Data Agendada'**
  String get scheduledDate;

  /// No description provided for @createdAt.
  ///
  /// In pt, this message translates to:
  /// **'Criado em'**
  String get createdAt;

  /// No description provided for @updatedAt.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado em'**
  String get updatedAt;

  /// No description provided for @date.
  ///
  /// In pt, this message translates to:
  /// **'Data'**
  String get date;

  /// No description provided for @time.
  ///
  /// In pt, this message translates to:
  /// **'Hora'**
  String get time;

  /// No description provided for @dateTime.
  ///
  /// In pt, this message translates to:
  /// **'Data e Hora'**
  String get dateTime;

  /// No description provided for @startDate.
  ///
  /// In pt, this message translates to:
  /// **'Data Inicial'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In pt, this message translates to:
  /// **'Data Final'**
  String get endDate;

  /// No description provided for @period.
  ///
  /// In pt, this message translates to:
  /// **'Período'**
  String get period;

  /// No description provided for @confirmDelete.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Exclusão'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente excluir este item?'**
  String get confirmDeleteMessage;

  /// No description provided for @confirmDeleteMessageNamed.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente excluir \"{name}\"?'**
  String confirmDeleteMessageNamed(String name);

  /// No description provided for @confirmCancel.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Cancelamento'**
  String get confirmCancel;

  /// No description provided for @confirmCancelMessage.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente cancelar?'**
  String get confirmCancelMessage;

  /// No description provided for @unsavedChanges.
  ///
  /// In pt, this message translates to:
  /// **'Alterações não salvas'**
  String get unsavedChanges;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você tem alterações não salvas. Deseja sair mesmo assim?'**
  String get unsavedChangesMessage;

  /// No description provided for @confirmAction.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Ação'**
  String get confirmAction;

  /// No description provided for @areYouSure.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza?'**
  String get areYouSure;

  /// No description provided for @cannotUndo.
  ///
  /// In pt, this message translates to:
  /// **'Esta ação não pode ser desfeita.'**
  String get cannotUndo;

  /// No description provided for @discard.
  ///
  /// In pt, this message translates to:
  /// **'Descartar'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In pt, this message translates to:
  /// **'Continuar Editando'**
  String get keepEditing;

  /// No description provided for @leave.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get leave;

  /// No description provided for @stay.
  ///
  /// In pt, this message translates to:
  /// **'Ficar'**
  String get stay;

  /// No description provided for @customer.
  ///
  /// In pt, this message translates to:
  /// **'Cliente'**
  String get customer;

  /// No description provided for @newCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Novo Cliente'**
  String get newCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Editar Cliente'**
  String get editCustomer;

  /// No description provided for @customerDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do Cliente'**
  String get customerDetails;

  /// No description provided for @customerName.
  ///
  /// In pt, this message translates to:
  /// **'Nome do Cliente'**
  String get customerName;

  /// No description provided for @customerList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de Clientes'**
  String get customerList;

  /// No description provided for @searchCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Buscar Cliente'**
  String get searchCustomer;

  /// No description provided for @selectCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Cliente'**
  String get selectCustomer;

  /// No description provided for @noCustomers.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cliente cadastrado'**
  String get noCustomers;

  /// No description provided for @addCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Cliente'**
  String get addCustomer;

  /// No description provided for @name.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get name;

  /// No description provided for @namePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex: João Silva'**
  String get namePlaceholder;

  /// No description provided for @fullName.
  ///
  /// In pt, this message translates to:
  /// **'Nome Completo'**
  String get fullName;

  /// No description provided for @nickname.
  ///
  /// In pt, this message translates to:
  /// **'Apelido'**
  String get nickname;

  /// No description provided for @phone.
  ///
  /// In pt, this message translates to:
  /// **'Telefone'**
  String get phone;

  /// No description provided for @phones.
  ///
  /// In pt, this message translates to:
  /// **'Telefones'**
  String get phones;

  /// No description provided for @cellphone.
  ///
  /// In pt, this message translates to:
  /// **'Celular'**
  String get cellphone;

  /// No description provided for @whatsapp.
  ///
  /// In pt, this message translates to:
  /// **'WhatsApp'**
  String get whatsapp;

  /// No description provided for @email.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @emails.
  ///
  /// In pt, this message translates to:
  /// **'E-mails'**
  String get emails;

  /// No description provided for @address.
  ///
  /// In pt, this message translates to:
  /// **'Endereço'**
  String get address;

  /// No description provided for @addresses.
  ///
  /// In pt, this message translates to:
  /// **'Endereços'**
  String get addresses;

  /// No description provided for @street.
  ///
  /// In pt, this message translates to:
  /// **'Rua'**
  String get street;

  /// No description provided for @number.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get number;

  /// No description provided for @complement.
  ///
  /// In pt, this message translates to:
  /// **'Complemento'**
  String get complement;

  /// No description provided for @neighborhood.
  ///
  /// In pt, this message translates to:
  /// **'Bairro'**
  String get neighborhood;

  /// No description provided for @city.
  ///
  /// In pt, this message translates to:
  /// **'Cidade'**
  String get city;

  /// No description provided for @state.
  ///
  /// In pt, this message translates to:
  /// **'Estado'**
  String get state;

  /// No description provided for @zipCode.
  ///
  /// In pt, this message translates to:
  /// **'CEP'**
  String get zipCode;

  /// No description provided for @country.
  ///
  /// In pt, this message translates to:
  /// **'País'**
  String get country;

  /// No description provided for @notes.
  ///
  /// In pt, this message translates to:
  /// **'Observações'**
  String get notes;

  /// No description provided for @observation.
  ///
  /// In pt, this message translates to:
  /// **'Observação'**
  String get observation;

  /// No description provided for @description.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get description;

  /// No description provided for @comments.
  ///
  /// In pt, this message translates to:
  /// **'Comentários'**
  String get comments;

  /// No description provided for @document.
  ///
  /// In pt, this message translates to:
  /// **'Documento'**
  String get document;

  /// No description provided for @cpf.
  ///
  /// In pt, this message translates to:
  /// **'CPF'**
  String get cpf;

  /// No description provided for @cnpj.
  ///
  /// In pt, this message translates to:
  /// **'CNPJ'**
  String get cnpj;

  /// No description provided for @cpfCnpj.
  ///
  /// In pt, this message translates to:
  /// **'CPF/CNPJ'**
  String get cpfCnpj;

  /// No description provided for @order.
  ///
  /// In pt, this message translates to:
  /// **'Ordem de Serviço'**
  String get order;

  /// No description provided for @orderShort.
  ///
  /// In pt, this message translates to:
  /// **'OS'**
  String get orderShort;

  /// No description provided for @newOrder.
  ///
  /// In pt, this message translates to:
  /// **'NOVA'**
  String get newOrder;

  /// No description provided for @editOrder.
  ///
  /// In pt, this message translates to:
  /// **'Editar OS'**
  String get editOrder;

  /// No description provided for @orderDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes da OS'**
  String get orderDetails;

  /// No description provided for @orderNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número da OS'**
  String get orderNumber;

  /// No description provided for @orderList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de OS'**
  String get orderList;

  /// No description provided for @searchOrder.
  ///
  /// In pt, this message translates to:
  /// **'Buscar OS'**
  String get searchOrder;

  /// No description provided for @noOrders.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS encontrada'**
  String get noOrders;

  /// No description provided for @addOrder.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar OS'**
  String get addOrder;

  /// No description provided for @createOrder.
  ///
  /// In pt, this message translates to:
  /// **'Criar OS'**
  String get createOrder;

  /// No description provided for @orderCreated.
  ///
  /// In pt, this message translates to:
  /// **'OS criada com sucesso'**
  String get orderCreated;

  /// No description provided for @orderUpdated.
  ///
  /// In pt, this message translates to:
  /// **'OS atualizada com sucesso'**
  String get orderUpdated;

  /// No description provided for @orderDeleted.
  ///
  /// In pt, this message translates to:
  /// **'OS excluída com sucesso'**
  String get orderDeleted;

  /// No description provided for @orderStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status da OS'**
  String get orderStatus;

  /// No description provided for @changeStatus.
  ///
  /// In pt, this message translates to:
  /// **'Alterar Status'**
  String get changeStatus;

  /// No description provided for @technician.
  ///
  /// In pt, this message translates to:
  /// **'Técnico'**
  String get technician;

  /// No description provided for @technicians.
  ///
  /// In pt, this message translates to:
  /// **'Técnicos'**
  String get technicians;

  /// No description provided for @assignTechnician.
  ///
  /// In pt, this message translates to:
  /// **'Atribuir Técnico'**
  String get assignTechnician;

  /// No description provided for @problem.
  ///
  /// In pt, this message translates to:
  /// **'Problema Relatado'**
  String get problem;

  /// No description provided for @problemDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição do Problema'**
  String get problemDescription;

  /// No description provided for @solution.
  ///
  /// In pt, this message translates to:
  /// **'Solução'**
  String get solution;

  /// No description provided for @solutionDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição da Solução'**
  String get solutionDescription;

  /// No description provided for @diagnosis.
  ///
  /// In pt, this message translates to:
  /// **'Diagnóstico'**
  String get diagnosis;

  /// No description provided for @warranty.
  ///
  /// In pt, this message translates to:
  /// **'Garantia'**
  String get warranty;

  /// No description provided for @warrantyPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Período de Garantia'**
  String get warrantyPeriod;

  /// No description provided for @hasWarranty.
  ///
  /// In pt, this message translates to:
  /// **'Possui Garantia'**
  String get hasWarranty;

  /// No description provided for @noWarranty.
  ///
  /// In pt, this message translates to:
  /// **'Sem Garantia'**
  String get noWarranty;

  /// No description provided for @warrantyExpired.
  ///
  /// In pt, this message translates to:
  /// **'Garantia Expirada'**
  String get warrantyExpired;

  /// No description provided for @warrantyValid.
  ///
  /// In pt, this message translates to:
  /// **'Garantia Válida'**
  String get warrantyValid;

  /// No description provided for @priority.
  ///
  /// In pt, this message translates to:
  /// **'Prioridade'**
  String get priority;

  /// No description provided for @priorityLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixa'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In pt, this message translates to:
  /// **'Média'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alta'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In pt, this message translates to:
  /// **'Urgente'**
  String get priorityUrgent;

  /// No description provided for @device.
  ///
  /// In pt, this message translates to:
  /// **'Equipamento'**
  String get device;

  /// No description provided for @deviceCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get deviceCategory;

  /// No description provided for @newDevice.
  ///
  /// In pt, this message translates to:
  /// **'Novo Equipamento'**
  String get newDevice;

  /// No description provided for @editDevice.
  ///
  /// In pt, this message translates to:
  /// **'Editar Equipamento'**
  String get editDevice;

  /// No description provided for @deviceDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do Equipamento'**
  String get deviceDetails;

  /// No description provided for @deviceList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de Equipamentos'**
  String get deviceList;

  /// No description provided for @searchDevice.
  ///
  /// In pt, this message translates to:
  /// **'Buscar Equipamento'**
  String get searchDevice;

  /// No description provided for @selectDevice.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Equipamento'**
  String get selectDevice;

  /// No description provided for @noDevices.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum equipamento cadastrado'**
  String get noDevices;

  /// No description provided for @addDevice.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Equipamento'**
  String get addDevice;

  /// No description provided for @brand.
  ///
  /// In pt, this message translates to:
  /// **'Marca'**
  String get brand;

  /// No description provided for @model.
  ///
  /// In pt, this message translates to:
  /// **'Modelo'**
  String get model;

  /// No description provided for @serialNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número de Série'**
  String get serialNumber;

  /// No description provided for @imei.
  ///
  /// In pt, this message translates to:
  /// **'IMEI'**
  String get imei;

  /// No description provided for @color.
  ///
  /// In pt, this message translates to:
  /// **'Cor'**
  String get color;

  /// No description provided for @condition.
  ///
  /// In pt, this message translates to:
  /// **'Condição'**
  String get condition;

  /// No description provided for @conditionNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get conditionNew;

  /// No description provided for @conditionUsed.
  ///
  /// In pt, this message translates to:
  /// **'Usado'**
  String get conditionUsed;

  /// No description provided for @conditionDamaged.
  ///
  /// In pt, this message translates to:
  /// **'Danificado'**
  String get conditionDamaged;

  /// No description provided for @accessories.
  ///
  /// In pt, this message translates to:
  /// **'Acessórios'**
  String get accessories;

  /// No description provided for @accessory.
  ///
  /// In pt, this message translates to:
  /// **'Acessório'**
  String get accessory;

  /// No description provided for @defects.
  ///
  /// In pt, this message translates to:
  /// **'Defeitos'**
  String get defects;

  /// No description provided for @defect.
  ///
  /// In pt, this message translates to:
  /// **'Defeito'**
  String get defect;

  /// No description provided for @service.
  ///
  /// In pt, this message translates to:
  /// **'Serviço'**
  String get service;

  /// No description provided for @newService.
  ///
  /// In pt, this message translates to:
  /// **'Novo Serviço'**
  String get newService;

  /// No description provided for @editService.
  ///
  /// In pt, this message translates to:
  /// **'Editar Serviço'**
  String get editService;

  /// No description provided for @serviceDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do Serviço'**
  String get serviceDetails;

  /// No description provided for @serviceList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de Serviços'**
  String get serviceList;

  /// No description provided for @searchService.
  ///
  /// In pt, this message translates to:
  /// **'Buscar Serviço'**
  String get searchService;

  /// No description provided for @selectService.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Serviço'**
  String get selectService;

  /// No description provided for @noServices.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum serviço cadastrado'**
  String get noServices;

  /// No description provided for @addService.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Serviço'**
  String get addService;

  /// No description provided for @serviceValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor do Serviço'**
  String get serviceValue;

  /// No description provided for @laborCost.
  ///
  /// In pt, this message translates to:
  /// **'Mão de Obra'**
  String get laborCost;

  /// No description provided for @product.
  ///
  /// In pt, this message translates to:
  /// **'Produto'**
  String get product;

  /// No description provided for @newProduct.
  ///
  /// In pt, this message translates to:
  /// **'Novo Produto'**
  String get newProduct;

  /// No description provided for @editProduct.
  ///
  /// In pt, this message translates to:
  /// **'Editar Produto'**
  String get editProduct;

  /// No description provided for @productDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do Produto'**
  String get productDetails;

  /// No description provided for @productList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de Produtos'**
  String get productList;

  /// No description provided for @searchProduct.
  ///
  /// In pt, this message translates to:
  /// **'Buscar Produto'**
  String get searchProduct;

  /// No description provided for @selectProduct.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Produto'**
  String get selectProduct;

  /// No description provided for @noProducts.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum produto cadastrado'**
  String get noProducts;

  /// No description provided for @addProduct.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Produto'**
  String get addProduct;

  /// No description provided for @sku.
  ///
  /// In pt, this message translates to:
  /// **'Código'**
  String get sku;

  /// No description provided for @barcode.
  ///
  /// In pt, this message translates to:
  /// **'Código de Barras'**
  String get barcode;

  /// No description provided for @stock.
  ///
  /// In pt, this message translates to:
  /// **'Estoque'**
  String get stock;

  /// No description provided for @stockQuantity.
  ///
  /// In pt, this message translates to:
  /// **'Quantidade em Estoque'**
  String get stockQuantity;

  /// No description provided for @lowStock.
  ///
  /// In pt, this message translates to:
  /// **'Estoque Baixo'**
  String get lowStock;

  /// No description provided for @outOfStock.
  ///
  /// In pt, this message translates to:
  /// **'Sem Estoque'**
  String get outOfStock;

  /// No description provided for @inStock.
  ///
  /// In pt, this message translates to:
  /// **'Em Estoque'**
  String get inStock;

  /// No description provided for @unit.
  ///
  /// In pt, this message translates to:
  /// **'Unidade'**
  String get unit;

  /// No description provided for @category.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get category;

  /// No description provided for @categories.
  ///
  /// In pt, this message translates to:
  /// **'Categorias'**
  String get categories;

  /// No description provided for @total.
  ///
  /// In pt, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In pt, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In pt, this message translates to:
  /// **'Desconto'**
  String get discount;

  /// No description provided for @discountPercent.
  ///
  /// In pt, this message translates to:
  /// **'Desconto (%)'**
  String get discountPercent;

  /// No description provided for @discountValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor do Desconto'**
  String get discountValue;

  /// No description provided for @price.
  ///
  /// In pt, this message translates to:
  /// **'Preço'**
  String get price;

  /// No description provided for @unitPrice.
  ///
  /// In pt, this message translates to:
  /// **'Preço Unitário'**
  String get unitPrice;

  /// No description provided for @costPrice.
  ///
  /// In pt, this message translates to:
  /// **'Preço de Custo'**
  String get costPrice;

  /// No description provided for @salePrice.
  ///
  /// In pt, this message translates to:
  /// **'Preço de Venda'**
  String get salePrice;

  /// No description provided for @quantity.
  ///
  /// In pt, this message translates to:
  /// **'Quantidade'**
  String get quantity;

  /// No description provided for @value.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get value;

  /// No description provided for @amount.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get amount;

  /// No description provided for @tax.
  ///
  /// In pt, this message translates to:
  /// **'Imposto'**
  String get tax;

  /// No description provided for @taxes.
  ///
  /// In pt, this message translates to:
  /// **'Impostos'**
  String get taxes;

  /// No description provided for @fee.
  ///
  /// In pt, this message translates to:
  /// **'Taxa'**
  String get fee;

  /// No description provided for @fees.
  ///
  /// In pt, this message translates to:
  /// **'Taxas'**
  String get fees;

  /// No description provided for @grandTotal.
  ///
  /// In pt, this message translates to:
  /// **'Total Geral'**
  String get grandTotal;

  /// No description provided for @balance.
  ///
  /// In pt, this message translates to:
  /// **'Saldo'**
  String get balance;

  /// No description provided for @totalPaid.
  ///
  /// In pt, this message translates to:
  /// **'Total Pago'**
  String get totalPaid;

  /// No description provided for @remaining.
  ///
  /// In pt, this message translates to:
  /// **'Restante'**
  String get remaining;

  /// No description provided for @change.
  ///
  /// In pt, this message translates to:
  /// **'Troco'**
  String get change;

  /// No description provided for @savedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Salvo com sucesso'**
  String get savedSuccessfully;

  /// No description provided for @deletedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Excluído com sucesso'**
  String get deletedSuccessfully;

  /// No description provided for @updatedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado com sucesso'**
  String get updatedSuccessfully;

  /// No description provided for @createdSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Criado com sucesso'**
  String get createdSuccessfully;

  /// No description provided for @copiedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Copiado com sucesso'**
  String get copiedSuccessfully;

  /// No description provided for @sentSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Enviado com sucesso'**
  String get sentSuccessfully;

  /// No description provided for @errorOccurred.
  ///
  /// In pt, this message translates to:
  /// **'Ocorreu um erro'**
  String get errorOccurred;

  /// No description provided for @tryAgain.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get tryAgain;

  /// No description provided for @operationFailed.
  ///
  /// In pt, this message translates to:
  /// **'Operação falhou'**
  String get operationFailed;

  /// No description provided for @noInternetConnection.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet'**
  String get noInternetConnection;

  /// No description provided for @connectionError.
  ///
  /// In pt, this message translates to:
  /// **'Erro de conexão'**
  String get connectionError;

  /// No description provided for @serverError.
  ///
  /// In pt, this message translates to:
  /// **'Erro no servidor'**
  String get serverError;

  /// No description provided for @unknownError.
  ///
  /// In pt, this message translates to:
  /// **'Erro desconhecido'**
  String get unknownError;

  /// No description provided for @permissionDenied.
  ///
  /// In pt, this message translates to:
  /// **'Permissão negada'**
  String get permissionDenied;

  /// No description provided for @notFound.
  ///
  /// In pt, this message translates to:
  /// **'Não encontrado'**
  String get notFound;

  /// No description provided for @timeout.
  ///
  /// In pt, this message translates to:
  /// **'Tempo esgotado'**
  String get timeout;

  /// No description provided for @sessionExpired.
  ///
  /// In pt, this message translates to:
  /// **'Sessão expirada'**
  String get sessionExpired;

  /// No description provided for @login.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente sair?'**
  String get logoutConfirm;

  /// No description provided for @signUp.
  ///
  /// In pt, this message translates to:
  /// **'Criar Conta'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get signIn;

  /// No description provided for @forgotPassword.
  ///
  /// In pt, this message translates to:
  /// **'Esqueci a senha'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In pt, this message translates to:
  /// **'Redefinir Senha'**
  String get resetPassword;

  /// No description provided for @changePassword.
  ///
  /// In pt, this message translates to:
  /// **'Alterar Senha'**
  String get changePassword;

  /// No description provided for @password.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get password;

  /// No description provided for @currentPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha Atual'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In pt, this message translates to:
  /// **'Nova Senha'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Senha'**
  String get confirmPassword;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In pt, this message translates to:
  /// **'As senhas não conferem'**
  String get passwordsDontMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In pt, this message translates to:
  /// **'Senha muito curta'**
  String get passwordTooShort;

  /// No description provided for @invalidCredentials.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais inválidas'**
  String get invalidCredentials;

  /// No description provided for @accountCreated.
  ///
  /// In pt, this message translates to:
  /// **'Conta criada com sucesso'**
  String get accountCreated;

  /// No description provided for @emailSent.
  ///
  /// In pt, this message translates to:
  /// **'E-mail enviado'**
  String get emailSent;

  /// No description provided for @checkYourEmail.
  ///
  /// In pt, this message translates to:
  /// **'Verifique seu e-mail'**
  String get checkYourEmail;

  /// No description provided for @continueWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Continuar com Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In pt, this message translates to:
  /// **'Continuar com Apple'**
  String get continueWithApple;

  /// No description provided for @orContinueWith.
  ///
  /// In pt, this message translates to:
  /// **'Ou continue com'**
  String get orContinueWith;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In pt, this message translates to:
  /// **'Já possui uma conta?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não possui uma conta?'**
  String get dontHaveAccount;

  /// No description provided for @termsAndConditions.
  ///
  /// In pt, this message translates to:
  /// **'Termos e Condições'**
  String get termsAndConditions;

  /// No description provided for @privacyPolicy.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get privacyPolicy;

  /// No description provided for @agreeToTerms.
  ///
  /// In pt, this message translates to:
  /// **'Eu concordo com os Termos e Condições'**
  String get agreeToTerms;

  /// No description provided for @welcome.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo'**
  String get welcome;

  /// No description provided for @welcomeBack.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo de volta'**
  String get welcomeBack;

  /// No description provided for @getStarted.
  ///
  /// In pt, this message translates to:
  /// **'Começar'**
  String get getStarted;

  /// No description provided for @letsStart.
  ///
  /// In pt, this message translates to:
  /// **'Vamos Começar'**
  String get letsStart;

  /// No description provided for @selectSegment.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Segmento'**
  String get selectSegment;

  /// No description provided for @selectSpecialties.
  ///
  /// In pt, this message translates to:
  /// **'Selecione suas Especialidades'**
  String get selectSpecialties;

  /// No description provided for @companyName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da Empresa'**
  String get companyName;

  /// No description provided for @setupComplete.
  ///
  /// In pt, this message translates to:
  /// **'Configuração Concluída'**
  String get setupComplete;

  /// No description provided for @allSet.
  ///
  /// In pt, this message translates to:
  /// **'Tudo Pronto!'**
  String get allSet;

  /// No description provided for @startUsing.
  ///
  /// In pt, this message translates to:
  /// **'Comece a usar o PraticOS'**
  String get startUsing;

  /// No description provided for @skip.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get skip;

  /// No description provided for @continue_.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get continue_;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Idioma'**
  String get selectLanguage;

  /// No description provided for @portuguese.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get portuguese;

  /// No description provided for @english.
  ///
  /// In pt, this message translates to:
  /// **'Inglês'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In pt, this message translates to:
  /// **'Espanhol'**
  String get spanish;

  /// No description provided for @theme.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo Escuro'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo Claro'**
  String get lightMode;

  /// No description provided for @systemDefault.
  ///
  /// In pt, this message translates to:
  /// **'Padrão do Sistema'**
  String get systemDefault;

  /// No description provided for @notifications.
  ///
  /// In pt, this message translates to:
  /// **'Notificações'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma notificação'**
  String get noNotifications;

  /// No description provided for @noNotificationsDescription.
  ///
  /// In pt, this message translates to:
  /// **'Você receberá notificações quando clientes aprovarem, rejeitarem ou avaliarem ordens de serviço.'**
  String get noNotificationsDescription;

  /// No description provided for @markAllAsRead.
  ///
  /// In pt, this message translates to:
  /// **'Marcar todas'**
  String get markAllAsRead;

  /// No description provided for @enableNotifications.
  ///
  /// In pt, this message translates to:
  /// **'Ativar Notificações'**
  String get enableNotifications;

  /// No description provided for @sound.
  ///
  /// In pt, this message translates to:
  /// **'Som'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In pt, this message translates to:
  /// **'Vibração'**
  String get vibration;

  /// No description provided for @about.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get about;

  /// No description provided for @version.
  ///
  /// In pt, this message translates to:
  /// **'Versão'**
  String get version;

  /// No description provided for @help.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda'**
  String get help;

  /// No description provided for @support.
  ///
  /// In pt, this message translates to:
  /// **'Suporte'**
  String get support;

  /// No description provided for @contactUs.
  ///
  /// In pt, this message translates to:
  /// **'Fale Conosco'**
  String get contactUs;

  /// No description provided for @rateApp.
  ///
  /// In pt, this message translates to:
  /// **'Avaliar App'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar App'**
  String get shareApp;

  /// No description provided for @dashboard.
  ///
  /// In pt, this message translates to:
  /// **'Painel'**
  String get dashboard;

  /// No description provided for @overview.
  ///
  /// In pt, this message translates to:
  /// **'Visão Geral'**
  String get overview;

  /// No description provided for @statistics.
  ///
  /// In pt, this message translates to:
  /// **'Estatísticas'**
  String get statistics;

  /// No description provided for @analytics.
  ///
  /// In pt, this message translates to:
  /// **'Análises'**
  String get analytics;

  /// No description provided for @revenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get revenue;

  /// No description provided for @expenses.
  ///
  /// In pt, this message translates to:
  /// **'Despesas'**
  String get expenses;

  /// No description provided for @profit.
  ///
  /// In pt, this message translates to:
  /// **'Lucro'**
  String get profit;

  /// No description provided for @ordersToday.
  ///
  /// In pt, this message translates to:
  /// **'OS Hoje'**
  String get ordersToday;

  /// No description provided for @ordersThisWeek.
  ///
  /// In pt, this message translates to:
  /// **'OS Esta Semana'**
  String get ordersThisWeek;

  /// No description provided for @ordersThisMonth.
  ///
  /// In pt, this message translates to:
  /// **'OS Este Mês'**
  String get ordersThisMonth;

  /// No description provided for @pendingOrders.
  ///
  /// In pt, this message translates to:
  /// **'OS Pendentes'**
  String get pendingOrders;

  /// No description provided for @completedOrders.
  ///
  /// In pt, this message translates to:
  /// **'OS Concluídas'**
  String get completedOrders;

  /// No description provided for @topServices.
  ///
  /// In pt, this message translates to:
  /// **'Serviços Mais Realizados'**
  String get topServices;

  /// No description provided for @topProducts.
  ///
  /// In pt, this message translates to:
  /// **'Produtos Mais Vendidos'**
  String get topProducts;

  /// No description provided for @recentOrders.
  ///
  /// In pt, this message translates to:
  /// **'OS Recentes'**
  String get recentOrders;

  /// No description provided for @recentCustomers.
  ///
  /// In pt, this message translates to:
  /// **'Clientes Recentes'**
  String get recentCustomers;

  /// No description provided for @role.
  ///
  /// In pt, this message translates to:
  /// **'Função'**
  String get role;

  /// No description provided for @roles.
  ///
  /// In pt, this message translates to:
  /// **'Funções'**
  String get roles;

  /// No description provided for @owner.
  ///
  /// In pt, this message translates to:
  /// **'Proprietário'**
  String get owner;

  /// No description provided for @admin.
  ///
  /// In pt, this message translates to:
  /// **'Administrador'**
  String get admin;

  /// No description provided for @manager.
  ///
  /// In pt, this message translates to:
  /// **'Gerente'**
  String get manager;

  /// No description provided for @employee.
  ///
  /// In pt, this message translates to:
  /// **'Funcionário'**
  String get employee;

  /// No description provided for @viewer.
  ///
  /// In pt, this message translates to:
  /// **'Visualizador'**
  String get viewer;

  /// No description provided for @permissions.
  ///
  /// In pt, this message translates to:
  /// **'Permissões'**
  String get permissions;

  /// No description provided for @canCreate.
  ///
  /// In pt, this message translates to:
  /// **'Pode Criar'**
  String get canCreate;

  /// No description provided for @canEdit.
  ///
  /// In pt, this message translates to:
  /// **'Pode Editar'**
  String get canEdit;

  /// No description provided for @canDelete.
  ///
  /// In pt, this message translates to:
  /// **'Pode Excluir'**
  String get canDelete;

  /// No description provided for @canView.
  ///
  /// In pt, this message translates to:
  /// **'Pode Visualizar'**
  String get canView;

  /// No description provided for @inviteMember.
  ///
  /// In pt, this message translates to:
  /// **'Convidar Membro'**
  String get inviteMember;

  /// No description provided for @removeMember.
  ///
  /// In pt, this message translates to:
  /// **'Remover Membro'**
  String get removeMember;

  /// No description provided for @memberRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Membro removido'**
  String get memberRemoved;

  /// No description provided for @invitationSent.
  ///
  /// In pt, this message translates to:
  /// **'Convite enviado'**
  String get invitationSent;

  /// No description provided for @pendingInvitations.
  ///
  /// In pt, this message translates to:
  /// **'Convites Pendentes'**
  String get pendingInvitations;

  /// No description provided for @acceptInvitation.
  ///
  /// In pt, this message translates to:
  /// **'Aceitar Convite'**
  String get acceptInvitation;

  /// No description provided for @declineInvitation.
  ///
  /// In pt, this message translates to:
  /// **'Recusar Convite'**
  String get declineInvitation;

  /// No description provided for @form.
  ///
  /// In pt, this message translates to:
  /// **'Formulário'**
  String get form;

  /// No description provided for @forms.
  ///
  /// In pt, this message translates to:
  /// **'Formulários'**
  String get forms;

  /// No description provided for @checklist.
  ///
  /// In pt, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @checklists.
  ///
  /// In pt, this message translates to:
  /// **'Checklists'**
  String get checklists;

  /// No description provided for @inspection.
  ///
  /// In pt, this message translates to:
  /// **'Vistoria'**
  String get inspection;

  /// No description provided for @inspections.
  ///
  /// In pt, this message translates to:
  /// **'Vistorias'**
  String get inspections;

  /// No description provided for @signature.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura'**
  String get signature;

  /// No description provided for @customerSignature.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura do Cliente'**
  String get customerSignature;

  /// No description provided for @technicianSignature.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura do Técnico'**
  String get technicianSignature;

  /// No description provided for @signHere.
  ///
  /// In pt, this message translates to:
  /// **'Assine aqui'**
  String get signHere;

  /// No description provided for @clearSignature.
  ///
  /// In pt, this message translates to:
  /// **'Limpar Assinatura'**
  String get clearSignature;

  /// No description provided for @required.
  ///
  /// In pt, this message translates to:
  /// **'Obrigatório'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In pt, this message translates to:
  /// **'Opcional'**
  String get optional;

  /// No description provided for @complete.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get complete;

  /// No description provided for @incomplete.
  ///
  /// In pt, this message translates to:
  /// **'Incompleto'**
  String get incomplete;

  /// No description provided for @answered.
  ///
  /// In pt, this message translates to:
  /// **'Respondido'**
  String get answered;

  /// No description provided for @notAnswered.
  ///
  /// In pt, this message translates to:
  /// **'Não Respondido'**
  String get notAnswered;

  /// No description provided for @quote.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento'**
  String get quote;

  /// No description provided for @quotes.
  ///
  /// In pt, this message translates to:
  /// **'Orçamentos'**
  String get quotes;

  /// No description provided for @newQuote.
  ///
  /// In pt, this message translates to:
  /// **'Novo Orçamento'**
  String get newQuote;

  /// No description provided for @editQuote.
  ///
  /// In pt, this message translates to:
  /// **'Editar Orçamento'**
  String get editQuote;

  /// No description provided for @quoteDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes do Orçamento'**
  String get quoteDetails;

  /// No description provided for @sendQuote.
  ///
  /// In pt, this message translates to:
  /// **'Enviar Orçamento'**
  String get sendQuote;

  /// No description provided for @approveQuote.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar Orçamento'**
  String get approveQuote;

  /// No description provided for @rejectQuote.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitar Orçamento'**
  String get rejectQuote;

  /// No description provided for @quoteApproved.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento Aprovado'**
  String get quoteApproved;

  /// No description provided for @quoteRejected.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento Rejeitado'**
  String get quoteRejected;

  /// No description provided for @quoteSent.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento Enviado'**
  String get quoteSent;

  /// No description provided for @validUntil.
  ///
  /// In pt, this message translates to:
  /// **'Válido até'**
  String get validUntil;

  /// No description provided for @expiresIn.
  ///
  /// In pt, this message translates to:
  /// **'Expira em {days} dias'**
  String expiresIn(int days);

  /// No description provided for @expired.
  ///
  /// In pt, this message translates to:
  /// **'Expirado'**
  String get expired;

  /// No description provided for @active.
  ///
  /// In pt, this message translates to:
  /// **'Ativo'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In pt, this message translates to:
  /// **'Inativo'**
  String get inactive;

  /// No description provided for @enabled.
  ///
  /// In pt, this message translates to:
  /// **'Habilitado'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In pt, this message translates to:
  /// **'Desabilitado'**
  String get disabled;

  /// No description provided for @visible.
  ///
  /// In pt, this message translates to:
  /// **'Visível'**
  String get visible;

  /// No description provided for @hidden.
  ///
  /// In pt, this message translates to:
  /// **'Oculto'**
  String get hidden;

  /// No description provided for @public.
  ///
  /// In pt, this message translates to:
  /// **'Público'**
  String get public;

  /// No description provided for @private.
  ///
  /// In pt, this message translates to:
  /// **'Privado'**
  String get private;

  /// No description provided for @draft.
  ///
  /// In pt, this message translates to:
  /// **'Rascunho'**
  String get draft;

  /// No description provided for @published.
  ///
  /// In pt, this message translates to:
  /// **'Publicado'**
  String get published;

  /// No description provided for @archived.
  ///
  /// In pt, this message translates to:
  /// **'Arquivado'**
  String get archived;

  /// No description provided for @deleted.
  ///
  /// In pt, this message translates to:
  /// **'Excluído'**
  String get deleted;

  /// No description provided for @all.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get all;

  /// No description provided for @none.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get none;

  /// No description provided for @other.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get other;

  /// No description provided for @others.
  ///
  /// In pt, this message translates to:
  /// **'Outros'**
  String get others;

  /// No description provided for @default_.
  ///
  /// In pt, this message translates to:
  /// **'Padrão'**
  String get default_;

  /// No description provided for @custom.
  ///
  /// In pt, this message translates to:
  /// **'Personalizado'**
  String get custom;

  /// No description provided for @new_.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get new_;

  /// No description provided for @old.
  ///
  /// In pt, this message translates to:
  /// **'Antigo'**
  String get old;

  /// No description provided for @recent.
  ///
  /// In pt, this message translates to:
  /// **'Recente'**
  String get recent;

  /// No description provided for @popular.
  ///
  /// In pt, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @featured.
  ///
  /// In pt, this message translates to:
  /// **'Destaque'**
  String get featured;

  /// No description provided for @recommended.
  ///
  /// In pt, this message translates to:
  /// **'Recomendado'**
  String get recommended;

  /// No description provided for @welcomeToApp.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao PraticOS'**
  String get welcomeToApp;

  /// No description provided for @appSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Gerencie suas ordens de serviço\nde forma simples e eficiente'**
  String get appSubtitle;

  /// No description provided for @signInWithEmail.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com email'**
  String get signInWithEmail;

  /// No description provided for @byContinuingYouAgree.
  ///
  /// In pt, this message translates to:
  /// **'Ao continuar, você concorda com nossa'**
  String get byContinuingYouAgree;

  /// No description provided for @error.
  ///
  /// In pt, this message translates to:
  /// **'Erro'**
  String get error;

  /// No description provided for @couldNotLoadCompanyData.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os dados da empresa'**
  String get couldNotLoadCompanyData;

  /// No description provided for @errorSignInApple.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao entrar com Apple'**
  String get errorSignInApple;

  /// No description provided for @errorSignInGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao entrar com Google'**
  String get errorSignInGoogle;

  /// No description provided for @companyNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Empresa não encontrada'**
  String get companyNotFound;

  /// No description provided for @companyNoSegment.
  ///
  /// In pt, this message translates to:
  /// **'Empresa sem segmento definido'**
  String get companyNoSegment;

  /// No description provided for @errorLoadingConfig.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar configuração'**
  String get errorLoadingConfig;

  /// No description provided for @enterEmailPassword.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu email e senha para acessar sua conta'**
  String get enterEmailPassword;

  /// No description provided for @credentials.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais'**
  String get credentials;

  /// No description provided for @enterYourPassword.
  ///
  /// In pt, this message translates to:
  /// **'Digite sua senha'**
  String get enterYourPassword;

  /// No description provided for @userNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Usuário não encontrado'**
  String get userNotFound;

  /// No description provided for @wrongPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha incorreta'**
  String get wrongPassword;

  /// No description provided for @errorSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao entrar. Tente novamente.'**
  String get errorSignIn;

  /// No description provided for @enterYourEmail.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu email'**
  String get enterYourEmail;

  /// No description provided for @checkInboxResetPassword.
  ///
  /// In pt, this message translates to:
  /// **'Verifique sua caixa de entrada para redefinir sua senha.'**
  String get checkInboxResetPassword;

  /// No description provided for @errorSendingRecoveryEmail.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao enviar email de recuperação'**
  String get errorSendingRecoveryEmail;

  /// No description provided for @user.
  ///
  /// In pt, this message translates to:
  /// **'Usuário'**
  String get user;

  /// No description provided for @organization.
  ///
  /// In pt, this message translates to:
  /// **'Organização'**
  String get organization;

  /// No description provided for @switchCompany.
  ///
  /// In pt, this message translates to:
  /// **'Trocar Empresa'**
  String get switchCompany;

  /// No description provided for @switchBetweenOrganizations.
  ///
  /// In pt, this message translates to:
  /// **'Alternar entre organizações'**
  String get switchBetweenOrganizations;

  /// No description provided for @management.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciamento'**
  String get management;

  /// No description provided for @companyData.
  ///
  /// In pt, this message translates to:
  /// **'Dados da Empresa'**
  String get companyData;

  /// No description provided for @interface_.
  ///
  /// In pt, this message translates to:
  /// **'Interface'**
  String get interface_;

  /// No description provided for @nightMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo Noturno'**
  String get nightMode;

  /// No description provided for @reopenOnboarding.
  ///
  /// In pt, this message translates to:
  /// **'Configurações Iniciais'**
  String get reopenOnboarding;

  /// No description provided for @reconfigureCompanySetup.
  ///
  /// In pt, this message translates to:
  /// **'Reconfigurar dados e segmento da empresa'**
  String get reconfigureCompanySetup;

  /// No description provided for @account.
  ///
  /// In pt, this message translates to:
  /// **'Conta'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Conta'**
  String get deleteAccount;

  /// No description provided for @permanentlyRemoveAllData.
  ///
  /// In pt, this message translates to:
  /// **'Remover permanentemente todos os dados'**
  String get permanentlyRemoveAllData;

  /// No description provided for @chooseTheme.
  ///
  /// In pt, this message translates to:
  /// **'Escolher tema'**
  String get chooseTheme;

  /// No description provided for @automaticSystem.
  ///
  /// In pt, this message translates to:
  /// **'Automático (Sistema)'**
  String get automaticSystem;

  /// No description provided for @automatic.
  ///
  /// In pt, this message translates to:
  /// **'Automático'**
  String get automatic;

  /// No description provided for @light.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In pt, this message translates to:
  /// **'Escuro'**
  String get dark;

  /// No description provided for @selectCompany.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Empresa'**
  String get selectCompany;

  /// No description provided for @companyNoName.
  ///
  /// In pt, this message translates to:
  /// **'Empresa sem nome'**
  String get companyNoName;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In pt, this message translates to:
  /// **'Esta ação é permanente e não pode ser desfeita.\n\nTodos os seus dados, incluindo ordens de serviço, clientes e configurações serão removidos permanentemente.\n\nTem certeza que deseja continuar?'**
  String get deleteAccountWarning;

  /// No description provided for @finalConfirmation.
  ///
  /// In pt, this message translates to:
  /// **'Confirmação Final'**
  String get finalConfirmation;

  /// No description provided for @lastChanceCancel.
  ///
  /// In pt, this message translates to:
  /// **'Esta é sua última chance de cancelar.\n\nConfirma a exclusão permanente da sua conta?'**
  String get lastChanceCancel;

  /// No description provided for @permanentlyDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Permanentemente'**
  String get permanentlyDelete;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao Excluir Conta'**
  String get errorDeletingAccount;

  /// No description provided for @couldNotDeleteAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível excluir sua conta.'**
  String get couldNotDeleteAccount;

  /// No description provided for @requiresRecentLogin.
  ///
  /// In pt, this message translates to:
  /// **'Por segurança, o Firebase exige login recente antes de deletar a conta.\n\nPor favor:\n1. Faça logout da sua conta\n2. Faça login novamente\n3. Tente deletar a conta imediatamente após o login'**
  String get requiresRecentLogin;

  /// No description provided for @noPermissionDelete.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para deletar sua conta. Tente novamente mais tarde.'**
  String get noPermissionDelete;

  /// No description provided for @networkError.
  ///
  /// In pt, this message translates to:
  /// **'Erro de conexão. Verifique sua internet e tente novamente.'**
  String get networkError;

  /// No description provided for @reauthenticationRequired.
  ///
  /// In pt, this message translates to:
  /// **'Re-autenticação Necessária'**
  String get reauthenticationRequired;

  /// No description provided for @pleaseSignInAgainToDelete.
  ///
  /// In pt, this message translates to:
  /// **'Por motivos de segurança, você precisa fazer login novamente antes de deletar sua conta.'**
  String get pleaseSignInAgainToDelete;

  /// No description provided for @signInAgain.
  ///
  /// In pt, this message translates to:
  /// **'Entrar Novamente'**
  String get signInAgain;

  /// No description provided for @authenticated.
  ///
  /// In pt, this message translates to:
  /// **'Autenticado'**
  String get authenticated;

  /// No description provided for @nowDeletingAccount.
  ///
  /// In pt, this message translates to:
  /// **'Agora você pode prosseguir com a exclusão da conta.'**
  String get nowDeletingAccount;

  /// No description provided for @reauthenticationFailed.
  ///
  /// In pt, this message translates to:
  /// **'Falha na Re-autenticação'**
  String get reauthenticationFailed;

  /// No description provided for @couldNotReauthenticate.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível autenticar novamente.'**
  String get couldNotReauthenticate;

  /// No description provided for @errorLoadingData.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar dados'**
  String get errorLoadingData;

  /// No description provided for @tapToAddFirst.
  ///
  /// In pt, this message translates to:
  /// **'Toque em + para adicionar'**
  String get tapToAddFirst;

  /// No description provided for @confirmRemove.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover'**
  String get confirmRemove;

  /// No description provided for @remove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get remove;

  /// No description provided for @noPermission.
  ///
  /// In pt, this message translates to:
  /// **'Sem Permissão'**
  String get noPermission;

  /// No description provided for @noPermissionToRemove.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para remover este item.'**
  String get noPermissionToRemove;

  /// No description provided for @professionalizeYourBusiness.
  ///
  /// In pt, this message translates to:
  /// **'Profissionalize seu negócio'**
  String get professionalizeYourBusiness;

  /// No description provided for @configureCompanyProfile.
  ///
  /// In pt, this message translates to:
  /// **'Configure o perfil da sua empresa para emitir ordens de serviço profissionais agora mesmo.'**
  String get configureCompanyProfile;

  /// No description provided for @professionalOrders.
  ///
  /// In pt, this message translates to:
  /// **'Ordens Profissionais'**
  String get professionalOrders;

  /// No description provided for @createDigitalOrders.
  ///
  /// In pt, this message translates to:
  /// **'Crie OS digitais personalizadas.'**
  String get createDigitalOrders;

  /// No description provided for @customerManagement.
  ///
  /// In pt, this message translates to:
  /// **'Gestão de Clientes'**
  String get customerManagement;

  /// No description provided for @keepHistoryOrganized.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha histórico e contatos organizados.'**
  String get keepHistoryOrganized;

  /// No description provided for @configureMyBusiness.
  ///
  /// In pt, this message translates to:
  /// **'Configurar Meu Negócio'**
  String get configureMyBusiness;

  /// No description provided for @configureLater.
  ///
  /// In pt, this message translates to:
  /// **'Configurar Depois'**
  String get configureLater;

  /// No description provided for @errorCreatingCompany.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao criar empresa padrão'**
  String get errorCreatingCompany;

  /// No description provided for @chooseSegment.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o Ramo'**
  String get chooseSegment;

  /// No description provided for @selectSegmentPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Selecione o ramo de atuação para personalizar o sistema para você.'**
  String get selectSegmentPrompt;

  /// No description provided for @availableSegments.
  ///
  /// In pt, this message translates to:
  /// **'Segmentos Disponíveis'**
  String get availableSegments;

  /// No description provided for @noSegmentsAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum segmento disponível'**
  String get noSegmentsAvailable;

  /// No description provided for @errorLoadingSegments.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar segmentos'**
  String get errorLoadingSegments;

  /// No description provided for @specialties.
  ///
  /// In pt, this message translates to:
  /// **'Especialidades'**
  String get specialties;

  /// No description provided for @myCompany.
  ///
  /// In pt, this message translates to:
  /// **'Minha Empresa'**
  String get myCompany;

  /// No description provided for @retryAgain.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retryAgain;

  /// No description provided for @noResultsFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum resultado encontrado'**
  String get noResultsFound;

  /// No description provided for @unitValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor unitário'**
  String get unitValue;

  /// No description provided for @setAsCover.
  ///
  /// In pt, this message translates to:
  /// **'Definir como capa'**
  String get setAsCover;

  /// No description provided for @roleDescAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Acesso total. Configura a empresa, gerencia usuários e acessa todos os dados.'**
  String get roleDescAdmin;

  /// No description provided for @roleAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Administrador'**
  String get roleAdmin;

  /// No description provided for @roleDescSupervisor.
  ///
  /// In pt, this message translates to:
  /// **'Coordena equipes e equipamentos. Não visualiza valores financeiros.'**
  String get roleDescSupervisor;

  /// No description provided for @roleSupervisor.
  ///
  /// In pt, this message translates to:
  /// **'Supervisor'**
  String get roleSupervisor;

  /// No description provided for @roleDescManager.
  ///
  /// In pt, this message translates to:
  /// **'Foco em resultados. Visualiza faturamento e custos, mas não executa serviços.'**
  String get roleDescManager;

  /// No description provided for @roleManager.
  ///
  /// In pt, this message translates to:
  /// **'Gerente'**
  String get roleManager;

  /// No description provided for @roleDescConsultant.
  ///
  /// In pt, this message translates to:
  /// **'Cria orçamentos. Vê preços, mas acessa apenas suas próprias Ordens de Serviço.'**
  String get roleDescConsultant;

  /// No description provided for @roleConsultant.
  ///
  /// In pt, this message translates to:
  /// **'Consultor'**
  String get roleConsultant;

  /// No description provided for @roleDescTechnician.
  ///
  /// In pt, this message translates to:
  /// **'Executa serviços. Não vê preços e tem edição limitada após aprovação da OS.'**
  String get roleDescTechnician;

  /// No description provided for @roleTechnician.
  ///
  /// In pt, this message translates to:
  /// **'Técnico'**
  String get roleTechnician;

  /// No description provided for @noFeminine.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma'**
  String get noFeminine;

  /// No description provided for @registered.
  ///
  /// In pt, this message translates to:
  /// **'cadastrado'**
  String get registered;

  /// No description provided for @registeredFeminine.
  ///
  /// In pt, this message translates to:
  /// **'cadastrada'**
  String get registeredFeminine;

  /// No description provided for @errorLoading.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar'**
  String get errorLoading;

  /// No description provided for @tapPlusToAddYourFirst.
  ///
  /// In pt, this message translates to:
  /// **'Toque em + para adicionar seu primeiro'**
  String get tapPlusToAddYourFirst;

  /// No description provided for @tapPlusToAddYourFirstFeminine.
  ///
  /// In pt, this message translates to:
  /// **'Toque em + para adicionar sua primeira'**
  String get tapPlusToAddYourFirstFeminine;

  /// No description provided for @doYouWantToRemoveThe.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover o'**
  String get doYouWantToRemoveThe;

  /// No description provided for @doYouWantToRemoveTheFeminine.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover a'**
  String get doYouWantToRemoveTheFeminine;

  /// No description provided for @searchCollaborator.
  ///
  /// In pt, this message translates to:
  /// **'Buscar colaborador'**
  String get searchCollaborator;

  /// No description provided for @noCollaboratorFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum colaborador encontrado'**
  String get noCollaboratorFound;

  /// No description provided for @pending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get pending;

  /// No description provided for @inviteTo.
  ///
  /// In pt, this message translates to:
  /// **'Convite para'**
  String get inviteTo;

  /// No description provided for @invitePendingMessage.
  ///
  /// In pt, this message translates to:
  /// **'Este convite está pendente. O usuário verá o convite quando se cadastrar no sistema.'**
  String get invitePendingMessage;

  /// No description provided for @cancelInvite.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar Convite'**
  String get cancelInvite;

  /// No description provided for @confirmCancelInvite.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja cancelar o convite para'**
  String get confirmCancelInvite;

  /// No description provided for @yesCancel.
  ///
  /// In pt, this message translates to:
  /// **'Sim, Cancelar'**
  String get yesCancel;

  /// No description provided for @userWithoutName.
  ///
  /// In pt, this message translates to:
  /// **'Usuário sem nome'**
  String get userWithoutName;

  /// No description provided for @actionsFor.
  ///
  /// In pt, this message translates to:
  /// **'Ações para'**
  String get actionsFor;

  /// No description provided for @editPermission.
  ///
  /// In pt, this message translates to:
  /// **'Editar Permissão'**
  String get editPermission;

  /// No description provided for @removeFromCompany.
  ///
  /// In pt, this message translates to:
  /// **'Remover da Empresa'**
  String get removeFromCompany;

  /// No description provided for @selectProfile.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Perfil'**
  String get selectProfile;

  /// No description provided for @chooseCollaboratorRole.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o perfil de acesso do colaborador'**
  String get chooseCollaboratorRole;

  /// No description provided for @removeCollaborator.
  ///
  /// In pt, this message translates to:
  /// **'Remover Colaborador'**
  String get removeCollaborator;

  /// No description provided for @confirmRemoveFromOrganization.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja remover {name} da organização?'**
  String confirmRemoveFromOrganization(String name);

  /// No description provided for @emailNotProvided.
  ///
  /// In pt, this message translates to:
  /// **'Email não informado'**
  String get emailNotProvided;

  /// No description provided for @newCollaborator.
  ///
  /// In pt, this message translates to:
  /// **'Novo Colaborador'**
  String get newCollaborator;

  /// No description provided for @userInformation.
  ///
  /// In pt, this message translates to:
  /// **'Informações do Usuário'**
  String get userInformation;

  /// No description provided for @userWillReceiveInviteByEmail.
  ///
  /// In pt, this message translates to:
  /// **'O usuário receberá um convite por email.'**
  String get userWillReceiveInviteByEmail;

  /// No description provided for @emailPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'email@exemplo.com'**
  String get emailPlaceholder;

  /// No description provided for @collaboratorAdded.
  ///
  /// In pt, this message translates to:
  /// **'Colaborador Adicionado'**
  String get collaboratorAdded;

  /// No description provided for @collaboratorAddedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'O colaborador foi adicionado à empresa com sucesso.'**
  String get collaboratorAddedSuccess;

  /// No description provided for @inviteSent.
  ///
  /// In pt, this message translates to:
  /// **'Convite Enviado'**
  String get inviteSent;

  /// No description provided for @inviteCreatedMessage.
  ///
  /// In pt, this message translates to:
  /// **'O usuário ainda não está cadastrado no sistema. Um convite foi criado e aparecerá quando ele se cadastrar.'**
  String get inviteCreatedMessage;

  /// No description provided for @financialDashboard.
  ///
  /// In pt, this message translates to:
  /// **'Painel Financeiro'**
  String get financialDashboard;

  /// No description provided for @financial.
  ///
  /// In pt, this message translates to:
  /// **'Financeiro'**
  String get financial;

  /// No description provided for @financialAccessDenied.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para acessar o painel financeiro.\\n\\nApenas Administradores e Gerentes podem visualizar dados financeiros.'**
  String get financialAccessDenied;

  /// No description provided for @week.
  ///
  /// In pt, this message translates to:
  /// **'Semana'**
  String get week;

  /// No description provided for @month.
  ///
  /// In pt, this message translates to:
  /// **'Mês'**
  String get month;

  /// No description provided for @year.
  ///
  /// In pt, this message translates to:
  /// **'Ano'**
  String get year;

  /// No description provided for @currentMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês atual'**
  String get currentMonth;

  /// No description provided for @currentYear.
  ///
  /// In pt, this message translates to:
  /// **'Ano atual'**
  String get currentYear;

  /// No description provided for @tapToReturnToCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Toque para voltar ao atual'**
  String get tapToReturnToCurrent;

  /// No description provided for @selectPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Período'**
  String get selectPeriod;

  /// No description provided for @start.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get start;

  /// No description provided for @end.
  ///
  /// In pt, this message translates to:
  /// **'Fim'**
  String get end;

  /// No description provided for @billing.
  ///
  /// In pt, this message translates to:
  /// **'Faturamento'**
  String get billing;

  /// No description provided for @composition.
  ///
  /// In pt, this message translates to:
  /// **'Composição'**
  String get composition;

  /// No description provided for @customersReceived.
  ///
  /// In pt, this message translates to:
  /// **'Clientes - Recebido'**
  String get customersReceived;

  /// No description provided for @customersToReceive.
  ///
  /// In pt, this message translates to:
  /// **'Clientes - A Receber'**
  String get customersToReceive;

  /// No description provided for @customerWithoutName.
  ///
  /// In pt, this message translates to:
  /// **'Cliente sem nome'**
  String get customerWithoutName;

  /// No description provided for @noCustomerDataInPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados de clientes neste período'**
  String get noCustomerDataInPeriod;

  /// No description provided for @serviceWithoutName.
  ///
  /// In pt, this message translates to:
  /// **'Serviço sem nome'**
  String get serviceWithoutName;

  /// No description provided for @productWithoutName.
  ///
  /// In pt, this message translates to:
  /// **'Produto sem nome'**
  String get productWithoutName;

  /// No description provided for @noServiceDataInPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados de serviços neste período'**
  String get noServiceDataInPeriod;

  /// No description provided for @noProductDataInPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados de produtos neste período'**
  String get noProductDataInPeriod;

  /// No description provided for @seeLess.
  ///
  /// In pt, this message translates to:
  /// **'Ver menos'**
  String get seeLess;

  /// No description provided for @seeAllCount.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos ({count})'**
  String seeAllCount(int count);

  /// No description provided for @toReceiveLowerCase.
  ///
  /// In pt, this message translates to:
  /// **'A receber'**
  String get toReceiveLowerCase;

  /// No description provided for @errorGeneratingReport.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar relatório'**
  String get errorGeneratingReport;

  /// No description provided for @pendingPayment.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get pendingPayment;

  /// No description provided for @selectCountry.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar País'**
  String get selectCountry;

  /// No description provided for @chooseCompanySegment.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o ramo de atuação da empresa'**
  String get chooseCompanySegment;

  /// No description provided for @contacts.
  ///
  /// In pt, this message translates to:
  /// **'Contatos'**
  String get contacts;

  /// No description provided for @contactMethods.
  ///
  /// In pt, this message translates to:
  /// **'Meios de Contato'**
  String get contactMethods;

  /// No description provided for @howCustomersCanReachYou.
  ///
  /// In pt, this message translates to:
  /// **'Como seus clientes podem falar com você?'**
  String get howCustomersCanReachYou;

  /// No description provided for @preparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando...'**
  String get preparing;

  /// No description provided for @uploadingLogo.
  ///
  /// In pt, this message translates to:
  /// **'Enviando logo...'**
  String get uploadingLogo;

  /// No description provided for @creatingCompany.
  ///
  /// In pt, this message translates to:
  /// **'Criando empresa...'**
  String get creatingCompany;

  /// No description provided for @importingForms.
  ///
  /// In pt, this message translates to:
  /// **'Importando formulários...'**
  String get importingForms;

  /// No description provided for @creatingSampleData.
  ///
  /// In pt, this message translates to:
  /// **'Criando dados de exemplo...'**
  String get creatingSampleData;

  /// No description provided for @createSampleDataQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Deseja criar dados de exemplo?'**
  String get createSampleDataQuestion;

  /// No description provided for @sampleDataDescription.
  ///
  /// In pt, this message translates to:
  /// **'Podemos criar alguns dados de exemplo para você começar a usar o sistema imediatamente:'**
  String get sampleDataDescription;

  /// No description provided for @commonServicesForSegment.
  ///
  /// In pt, this message translates to:
  /// **'Serviços comuns do seu segmento'**
  String get commonServicesForSegment;

  /// No description provided for @mostUsedProducts.
  ///
  /// In pt, this message translates to:
  /// **'Produtos e peças mais utilizados'**
  String get mostUsedProducts;

  /// No description provided for @sampleEquipment.
  ///
  /// In pt, this message translates to:
  /// **'Equipamentos de exemplo'**
  String get sampleEquipment;

  /// No description provided for @sampleForms.
  ///
  /// In pt, this message translates to:
  /// **'Formulários de vistoria'**
  String get sampleForms;

  /// No description provided for @demoCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Cliente de demonstração'**
  String get demoCustomer;

  /// No description provided for @canEditOrDeleteAnytime.
  ///
  /// In pt, this message translates to:
  /// **'Você poderá editar ou excluir esses dados a qualquer momento.'**
  String get canEditOrDeleteAnytime;

  /// No description provided for @noStartFromScratch.
  ///
  /// In pt, this message translates to:
  /// **'Não, começar do zero'**
  String get noStartFromScratch;

  /// No description provided for @changeLogo.
  ///
  /// In pt, this message translates to:
  /// **'Alterar Logo'**
  String get changeLogo;

  /// No description provided for @companyNamePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Nome da Empresa'**
  String get companyNamePlaceholder;

  /// No description provided for @companyEmailPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'contato@empresa.com'**
  String get companyEmailPlaceholder;

  /// No description provided for @phonePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'(00) 00000-0000'**
  String get phonePlaceholder;

  /// No description provided for @fullAddress.
  ///
  /// In pt, this message translates to:
  /// **'Endereço completo'**
  String get fullAddress;

  /// No description provided for @websitePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'www.empresa.com.br'**
  String get websitePlaceholder;

  /// No description provided for @segment.
  ///
  /// In pt, this message translates to:
  /// **'Segmento'**
  String get segment;

  /// No description provided for @website.
  ///
  /// In pt, this message translates to:
  /// **'Site'**
  String get website;

  /// No description provided for @noName.
  ///
  /// In pt, this message translates to:
  /// **'Sem nome'**
  String get noName;

  /// No description provided for @errorSendingPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao Enviar Foto'**
  String get errorSendingPhoto;

  /// No description provided for @couldNotSendPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar a foto. Tente novamente.'**
  String get couldNotSendPhoto;

  /// No description provided for @errorSendingPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao Enviar Fotos'**
  String get errorSendingPhotos;

  /// No description provided for @couldNotSendPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar as fotos. Tente novamente.'**
  String get couldNotSendPhotos;

  /// No description provided for @requiredFields.
  ///
  /// In pt, this message translates to:
  /// **'Campos Obrigatórios'**
  String get requiredFields;

  /// No description provided for @pleaseFill.
  ///
  /// In pt, this message translates to:
  /// **'Por favor preencha:'**
  String get pleaseFill;

  /// No description provided for @couldNotCompleteForm.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir o procedimento. Tente novamente.'**
  String get couldNotCompleteForm;

  /// No description provided for @noPermissionReopenForm.
  ///
  /// In pt, this message translates to:
  /// **'Apenas Administradores, Gerentes e Supervisores podem reabrir procedimentos concluídos.'**
  String get noPermissionReopenForm;

  /// No description provided for @couldNotReopenForm.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível reabrir o procedimento. Tente novamente.'**
  String get couldNotReopenForm;

  /// No description provided for @formCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Procedimento concluído'**
  String get formCompleted;

  /// No description provided for @noPhotoAdded.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma foto adicionada'**
  String get noPhotoAdded;

  /// No description provided for @tapCameraIconToAdd.
  ///
  /// In pt, this message translates to:
  /// **'Toque no ícone da câmera para adicionar'**
  String get tapCameraIconToAdd;

  /// No description provided for @type.
  ///
  /// In pt, this message translates to:
  /// **'Digitar'**
  String get type;

  /// No description provided for @errorLoadingPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar foto'**
  String get errorLoadingPhoto;

  /// No description provided for @reopen.
  ///
  /// In pt, this message translates to:
  /// **'Reabrir'**
  String get reopen;

  /// No description provided for @addItems.
  ///
  /// In pt, this message translates to:
  /// **'Adicione itens'**
  String get addItems;

  /// No description provided for @pleaseAddAtLeastOneItem.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, adicione pelo menos um item ao procedimento.'**
  String get pleaseAddAtLeastOneItem;

  /// No description provided for @couldNotSaveForm.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar o procedimento.'**
  String get couldNotSaveForm;

  /// No description provided for @removeItem.
  ///
  /// In pt, this message translates to:
  /// **'Remover item'**
  String get removeItem;

  /// No description provided for @minOptions.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo de opções'**
  String get minOptions;

  /// No description provided for @pleaseEnterAtLeast2Options.
  ///
  /// In pt, this message translates to:
  /// **'Informe pelo menos 2 opções.'**
  String get pleaseEnterAtLeast2Options;

  /// No description provided for @selectItemType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo do Item'**
  String get selectItemType;

  /// No description provided for @selectResponseType.
  ///
  /// In pt, this message translates to:
  /// **'Selecione o tipo de resposta esperada'**
  String get selectResponseType;

  /// No description provided for @itemConfiguration.
  ///
  /// In pt, this message translates to:
  /// **'CONFIGURAÇÃO DO ITEM'**
  String get itemConfiguration;

  /// No description provided for @formInformation.
  ///
  /// In pt, this message translates to:
  /// **'INFORMAÇÕES'**
  String get formInformation;

  /// No description provided for @formConfiguration.
  ///
  /// In pt, this message translates to:
  /// **'CONFIGURAÇÕES'**
  String get formConfiguration;

  /// No description provided for @title.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get title;

  /// No description provided for @label.
  ///
  /// In pt, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @itemType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get itemType;

  /// No description provided for @optionsHeader.
  ///
  /// In pt, this message translates to:
  /// **'OPÇÕES'**
  String get optionsHeader;

  /// No description provided for @typeOneOptionPerLine.
  ///
  /// In pt, this message translates to:
  /// **'Digite uma opção por linha'**
  String get typeOneOptionPerLine;

  /// No description provided for @allowPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Permitir fotos'**
  String get allowPhotos;

  /// No description provided for @userCanAttachPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Usuário pode anexar fotos a este item'**
  String get userCanAttachPhotos;

  /// No description provided for @procedures.
  ///
  /// In pt, this message translates to:
  /// **'Procedimentos'**
  String get procedures;

  /// No description provided for @searchProcedure.
  ///
  /// In pt, this message translates to:
  /// **'Buscar procedimento'**
  String get searchProcedure;

  /// No description provided for @myProcedures.
  ///
  /// In pt, this message translates to:
  /// **'Meus Procedimentos'**
  String get myProcedures;

  /// No description provided for @globalProcedures.
  ///
  /// In pt, this message translates to:
  /// **'Procedimentos Globais'**
  String get globalProcedures;

  /// No description provided for @noProceduresRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum procedimento cadastrado'**
  String get noProceduresRegistered;

  /// No description provided for @noProceduresAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum procedimento disponível'**
  String get noProceduresAvailable;

  /// No description provided for @tapPlusToCreateFirst.
  ///
  /// In pt, this message translates to:
  /// **'Toque em + para criar seu primeiro procedimento.'**
  String get tapPlusToCreateFirst;

  /// No description provided for @fromCompany.
  ///
  /// In pt, this message translates to:
  /// **'Da Empresa'**
  String get fromCompany;

  /// No description provided for @global.
  ///
  /// In pt, this message translates to:
  /// **'Globais'**
  String get global;

  /// Contagem de itens com plural correto
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{item} other{itens}}'**
  String itemCount(int count);

  /// Mensagem de confirmação de importação de procedimento
  ///
  /// In pt, this message translates to:
  /// **'Deseja importar o procedimento \"{title}\" para sua empresa?\n\nVocê poderá editá-lo após a importação.'**
  String importConfirmationMessage(String title);

  /// No description provided for @errorLoadingProcedures.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar procedimentos'**
  String get errorLoadingProcedures;

  /// No description provided for @importProcedure.
  ///
  /// In pt, this message translates to:
  /// **'Importar Procedimento'**
  String get importProcedure;

  /// No description provided for @importForMyCompany.
  ///
  /// In pt, this message translates to:
  /// **'Importar para Minha Empresa'**
  String get importForMyCompany;

  /// No description provided for @couldNotImportProcedure.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível importar o procedimento. Tente novamente.'**
  String get couldNotImportProcedure;

  /// No description provided for @procedureImportedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Procedimento importado com sucesso!'**
  String get procedureImportedSuccessfully;

  /// No description provided for @closeDialog.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get closeDialog;

  /// No description provided for @companyLogo.
  ///
  /// In pt, this message translates to:
  /// **'Logo da Empresa'**
  String get companyLogo;

  /// No description provided for @information.
  ///
  /// In pt, this message translates to:
  /// **'INFORMAÇÕES'**
  String get information;

  /// No description provided for @pendingInvites.
  ///
  /// In pt, this message translates to:
  /// **'Convites Pendentes'**
  String get pendingInvites;

  /// No description provided for @youHaveBeenInvited.
  ///
  /// In pt, this message translates to:
  /// **'Você foi convidado para fazer parte de empresas no PraticOS!'**
  String get youHaveBeenInvited;

  /// No description provided for @noPendingInvites.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum convite pendente'**
  String get noPendingInvites;

  /// No description provided for @acceptInvite.
  ///
  /// In pt, this message translates to:
  /// **'Aceitar'**
  String get acceptInvite;

  /// No description provided for @rejectInvite.
  ///
  /// In pt, this message translates to:
  /// **'Recusar Convite'**
  String get rejectInvite;

  /// No description provided for @inviteAccepted.
  ///
  /// In pt, this message translates to:
  /// **'Convite Aceito'**
  String get inviteAccepted;

  /// No description provided for @youAreNowPartOf.
  ///
  /// In pt, this message translates to:
  /// **'Agora você faz parte de {company}!'**
  String youAreNowPartOf(String company);

  /// No description provided for @areYouSureReject.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja recusar o convite de {company}?'**
  String areYouSureReject(String company);

  /// No description provided for @or.
  ///
  /// In pt, this message translates to:
  /// **'ou'**
  String get or;

  /// No description provided for @createMyCompany.
  ///
  /// In pt, this message translates to:
  /// **'Criar Minha Empresa'**
  String get createMyCompany;

  /// No description provided for @reject.
  ///
  /// In pt, this message translates to:
  /// **'Recusar'**
  String get reject;

  /// No description provided for @invitedBy.
  ///
  /// In pt, this message translates to:
  /// **'Convidado por {name}'**
  String invitedBy(String name);

  /// No description provided for @roleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Cargo: {role}'**
  String roleLabel(String role);

  /// No description provided for @inviteExpired.
  ///
  /// In pt, this message translates to:
  /// **'Este convite expirou'**
  String get inviteExpired;

  /// No description provided for @inviteCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Este convite foi cancelado'**
  String get inviteCancelled;

  /// No description provided for @inviteNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Convite não encontrado'**
  String get inviteNotFound;

  /// No description provided for @inviteAlreadyUsed.
  ///
  /// In pt, this message translates to:
  /// **'Este convite já foi utilizado'**
  String get inviteAlreadyUsed;

  /// No description provided for @enterInviteCode.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código do convite'**
  String get enterInviteCode;

  /// No description provided for @enterCodeReceived.
  ///
  /// In pt, this message translates to:
  /// **'Digite o código que você recebeu para entrar na equipe'**
  String get enterCodeReceived;

  /// No description provided for @searchAnotherCode.
  ///
  /// In pt, this message translates to:
  /// **'Buscar outro código'**
  String get searchAnotherCode;

  /// No description provided for @joinAnotherCompany.
  ///
  /// In pt, this message translates to:
  /// **'Entrar em outra empresa'**
  String get joinAnotherCompany;

  /// No description provided for @shareInvite.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar Convite'**
  String get shareInvite;

  /// No description provided for @copyInviteLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar Link do Convite'**
  String get copyInviteLink;

  /// No description provided for @sendViaWhatsAppInvite.
  ///
  /// In pt, this message translates to:
  /// **'Enviar convite via WhatsApp'**
  String get sendViaWhatsAppInvite;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link do convite copiado!'**
  String get inviteLinkCopied;

  /// No description provided for @phoneOptional.
  ///
  /// In pt, this message translates to:
  /// **'Telefone (opcional)'**
  String get phoneOptional;

  /// No description provided for @emailOrPhone.
  ///
  /// In pt, this message translates to:
  /// **'Informe email ou telefone'**
  String get emailOrPhone;

  /// No description provided for @inviteExpiresIn.
  ///
  /// In pt, this message translates to:
  /// **'Convite válido por {days} dias'**
  String inviteExpiresIn(int days);

  /// No description provided for @markAsToReceive.
  ///
  /// In pt, this message translates to:
  /// **'Marcar como A Receber'**
  String get markAsToReceive;

  /// No description provided for @thisWillRemoveAllPayments.
  ///
  /// In pt, this message translates to:
  /// **'Isso irá remover todos os pagamentos e descontos registrados. Deseja continuar?'**
  String get thisWillRemoveAllPayments;

  /// No description provided for @attention.
  ///
  /// In pt, this message translates to:
  /// **'Atenção'**
  String get attention;

  /// No description provided for @almostThere.
  ///
  /// In pt, this message translates to:
  /// **'Quase lá!'**
  String get almostThere;

  /// No description provided for @yesCreateSampleData.
  ///
  /// In pt, this message translates to:
  /// **'Sim, criar dados de exemplo'**
  String get yesCreateSampleData;

  /// No description provided for @availableSpecialties.
  ///
  /// In pt, this message translates to:
  /// **'ESPECIALIDADES DISPONÍVEIS'**
  String get availableSpecialties;

  /// No description provided for @pleaseSelectAtLeastOneSpecialty.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, selecione pelo menos uma especialidade para continuar.'**
  String get pleaseSelectAtLeastOneSpecialty;

  /// No description provided for @selectSpecialtiesDescription.
  ///
  /// In pt, this message translates to:
  /// **'Selecione as especialidades da sua empresa.\nVocê pode escolher mais de uma.'**
  String get selectSpecialtiesDescription;

  /// No description provided for @selectAtLeastOneOption.
  ///
  /// In pt, this message translates to:
  /// **'Selecione ao menos uma opção'**
  String get selectAtLeastOneOption;

  /// No description provided for @continueWithCount.
  ///
  /// In pt, this message translates to:
  /// **'Continuar ({count} {count, plural, =1{selecionada} other{selecionadas}})'**
  String continueWithCount(int count);

  /// No description provided for @financialReport.
  ///
  /// In pt, this message translates to:
  /// **'Relatório Financeiro'**
  String get financialReport;

  /// No description provided for @totalBilling.
  ///
  /// In pt, this message translates to:
  /// **'Faturamento Total'**
  String get totalBilling;

  /// No description provided for @financialSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo Financeiro'**
  String get financialSummary;

  /// No description provided for @averageTicket.
  ///
  /// In pt, this message translates to:
  /// **'Ticket Médio'**
  String get averageTicket;

  /// No description provided for @customerRanking.
  ///
  /// In pt, this message translates to:
  /// **'Ranking de Clientes'**
  String get customerRanking;

  /// No description provided for @serviceRanking.
  ///
  /// In pt, this message translates to:
  /// **'Ranking de Serviços'**
  String get serviceRanking;

  /// No description provided for @productRanking.
  ///
  /// In pt, this message translates to:
  /// **'Ranking de Produtos'**
  String get productRanking;

  /// No description provided for @paidOrders.
  ///
  /// In pt, this message translates to:
  /// **'Ordens Pagas'**
  String get paidOrders;

  /// No description provided for @ordersToReceive.
  ///
  /// In pt, this message translates to:
  /// **'Ordens a Receber'**
  String get ordersToReceive;

  /// No description provided for @vehicle.
  ///
  /// In pt, this message translates to:
  /// **'Veículo'**
  String get vehicle;

  /// No description provided for @valueColumn.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get valueColumn;

  /// No description provided for @statusColumn.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get statusColumn;

  /// No description provided for @quantityShort.
  ///
  /// In pt, this message translates to:
  /// **'Qtd'**
  String get quantityShort;

  /// No description provided for @noOrdersInPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma ordem neste período'**
  String get noOrdersInPeriod;

  /// No description provided for @notInformed.
  ///
  /// In pt, this message translates to:
  /// **'Não informado'**
  String get notInformed;

  /// No description provided for @nOrdersCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{ordem} other{ordens}}'**
  String nOrdersCount(int count);

  /// No description provided for @nItemsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{item} other{itens}}'**
  String nItemsCount(int count);

  /// No description provided for @orderSingular.
  ///
  /// In pt, this message translates to:
  /// **'ordem'**
  String get orderSingular;

  /// No description provided for @orderPlural.
  ///
  /// In pt, this message translates to:
  /// **'ordens'**
  String get orderPlural;

  /// No description provided for @generatedAt.
  ///
  /// In pt, this message translates to:
  /// **'Gerado em {date}'**
  String generatedAt(String date);

  /// No description provided for @pageOf.
  ///
  /// In pt, this message translates to:
  /// **'Pagina {current} de {total}'**
  String pageOf(int current, int total);

  /// No description provided for @preparingReport.
  ///
  /// In pt, this message translates to:
  /// **'Preparando relatorio...'**
  String get preparingReport;

  /// No description provided for @appTagline.
  ///
  /// In pt, this message translates to:
  /// **'Sistema de Gestao de Ordens de Servico'**
  String get appTagline;

  /// No description provided for @receivedWithPercent.
  ///
  /// In pt, this message translates to:
  /// **'Recebido ({percent}%)'**
  String receivedWithPercent(String percent);

  /// No description provided for @toReceiveWithPercent.
  ///
  /// In pt, this message translates to:
  /// **'A Receber ({percent}%)'**
  String toReceiveWithPercent(String percent);

  /// No description provided for @generatedByPraticos.
  ///
  /// In pt, this message translates to:
  /// **'Gerado por PraticOS'**
  String get generatedByPraticos;

  /// No description provided for @serviceDescriptionColumn.
  ///
  /// In pt, this message translates to:
  /// **'DESCRICAO DO SERVICO'**
  String get serviceDescriptionColumn;

  /// No description provided for @descriptionColumn.
  ///
  /// In pt, this message translates to:
  /// **'DESCRICAO'**
  String get descriptionColumn;

  /// No description provided for @unitShort.
  ///
  /// In pt, this message translates to:
  /// **'UNIT.'**
  String get unitShort;

  /// No description provided for @alreadyPaid.
  ///
  /// In pt, this message translates to:
  /// **'Ja pago'**
  String get alreadyPaid;

  /// No description provided for @remainingBalance.
  ///
  /// In pt, this message translates to:
  /// **'SALDO RESTANTE'**
  String get remainingBalance;

  /// No description provided for @totalToPay.
  ///
  /// In pt, this message translates to:
  /// **'TOTAL A PAGAR'**
  String get totalToPay;

  /// No description provided for @photosAvailableDigitally.
  ///
  /// In pt, this message translates to:
  /// **'Fotos disponiveis no sistema digital'**
  String get photosAvailableDigitally;

  /// No description provided for @attachedPhotosCount.
  ///
  /// In pt, this message translates to:
  /// **'Fotos Anexadas ({count})'**
  String attachedPhotosCount(int count);

  /// No description provided for @photoRecord.
  ///
  /// In pt, this message translates to:
  /// **'REGISTRO FOTOGRAFICO'**
  String get photoRecord;

  /// No description provided for @partsAndProducts.
  ///
  /// In pt, this message translates to:
  /// **'PECAS E PRODUTOS'**
  String get partsAndProducts;

  /// No description provided for @nPhotosCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{foto} other{fotos}}'**
  String nPhotosCount(int count);

  /// No description provided for @notSelected.
  ///
  /// In pt, this message translates to:
  /// **'Nao selecionado'**
  String get notSelected;

  /// No description provided for @formLabelWithTitle.
  ///
  /// In pt, this message translates to:
  /// **'Formulario: {title}'**
  String formLabelWithTitle(String title);

  /// No description provided for @connectedChannels.
  ///
  /// In pt, this message translates to:
  /// **'Canais Conectados'**
  String get connectedChannels;

  /// No description provided for @linked.
  ///
  /// In pt, this message translates to:
  /// **'Vinculado'**
  String get linked;

  /// No description provided for @notLinked.
  ///
  /// In pt, this message translates to:
  /// **'Não vinculado'**
  String get notLinked;

  /// No description provided for @linkWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Vincular WhatsApp'**
  String get linkWhatsApp;

  /// No description provided for @linkWhatsAppDescription.
  ///
  /// In pt, this message translates to:
  /// **'Escaneie o QR code ou clique no botão para abrir o WhatsApp e enviar o código de vinculação ao bot PraticOS.'**
  String get linkWhatsAppDescription;

  /// No description provided for @linkExpiresIn.
  ///
  /// In pt, this message translates to:
  /// **'Expira em {time}'**
  String linkExpiresIn(String time);

  /// No description provided for @openWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Abrir WhatsApp'**
  String get openWhatsApp;

  /// No description provided for @whatsAppLinked.
  ///
  /// In pt, this message translates to:
  /// **'WhatsApp vinculado'**
  String get whatsAppLinked;

  /// No description provided for @whatsAppNotLinked.
  ///
  /// In pt, this message translates to:
  /// **'WhatsApp não vinculado'**
  String get whatsAppNotLinked;

  /// No description provided for @unlinkWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Desvincular WhatsApp'**
  String get unlinkWhatsApp;

  /// No description provided for @unlinkWhatsAppConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja desvincular seu WhatsApp?'**
  String get unlinkWhatsAppConfirm;

  /// No description provided for @whatsAppUnlinked.
  ///
  /// In pt, this message translates to:
  /// **'WhatsApp desvinculado com sucesso'**
  String get whatsAppUnlinked;

  /// No description provided for @errorGeneratingToken.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar código de vinculação'**
  String get errorGeneratingToken;

  /// No description provided for @errorCheckingStatus.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao verificar status'**
  String get errorCheckingStatus;

  /// No description provided for @errorUnlinking.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao desvincular'**
  String get errorUnlinking;

  /// No description provided for @scanQRCodeOrTapButton.
  ///
  /// In pt, this message translates to:
  /// **'Escaneie o QR code ou toque no botão abaixo'**
  String get scanQRCodeOrTapButton;

  /// No description provided for @linkYourWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Vincule seu WhatsApp'**
  String get linkYourWhatsApp;

  /// No description provided for @linkWhatsAppBenefit.
  ///
  /// In pt, this message translates to:
  /// **'Receba notificações e gerencie suas OS pelo WhatsApp'**
  String get linkWhatsAppBenefit;

  /// No description provided for @shareWithCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar com Cliente'**
  String get shareWithCustomer;

  /// No description provided for @shareLinkTitle.
  ///
  /// In pt, this message translates to:
  /// **'Link de Acompanhamento'**
  String get shareLinkTitle;

  /// No description provided for @shareLinkDescription.
  ///
  /// In pt, this message translates to:
  /// **'Envie este link para o cliente acompanhar a OS'**
  String get shareLinkDescription;

  /// No description provided for @linkValidFor.
  ///
  /// In pt, this message translates to:
  /// **'Link válido por {days} dias'**
  String linkValidFor(int days);

  /// No description provided for @canApprove.
  ///
  /// In pt, this message translates to:
  /// **'Pode aprovar'**
  String get canApprove;

  /// No description provided for @canComment.
  ///
  /// In pt, this message translates to:
  /// **'Pode comentar'**
  String get canComment;

  /// No description provided for @viewOnly.
  ///
  /// In pt, this message translates to:
  /// **'Apenas visualização'**
  String get viewOnly;

  /// No description provided for @copyLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar Link'**
  String get copyLink;

  /// No description provided for @sendViaWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Enviar via WhatsApp'**
  String get sendViaWhatsApp;

  /// No description provided for @shareLink.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar Link'**
  String get shareLink;

  /// No description provided for @linkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link copiado!'**
  String get linkCopied;

  /// No description provided for @generatingLink.
  ///
  /// In pt, this message translates to:
  /// **'Gerando link...'**
  String get generatingLink;

  /// No description provided for @errorGeneratingLink.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar link'**
  String get errorGeneratingLink;

  /// No description provided for @sharePermissions.
  ///
  /// In pt, this message translates to:
  /// **'Permissões do Link'**
  String get sharePermissions;

  /// No description provided for @shareLinkExpired.
  ///
  /// In pt, this message translates to:
  /// **'Este link expirou'**
  String get shareLinkExpired;

  /// No description provided for @shareLinkApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovado pelo cliente'**
  String get shareLinkApproved;

  /// No description provided for @shareLinkRejected.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitado pelo cliente'**
  String get shareLinkRejected;

  /// No description provided for @viewCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{visualização} other{visualizações}}'**
  String viewCount(int count);

  /// No description provided for @revokeLink.
  ///
  /// In pt, this message translates to:
  /// **'Revogar Link'**
  String get revokeLink;

  /// No description provided for @revokeLinkConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja revogar este link? O cliente não poderá mais acessar.'**
  String get revokeLinkConfirm;

  /// No description provided for @linkRevoked.
  ///
  /// In pt, this message translates to:
  /// **'Link revogado'**
  String get linkRevoked;

  /// No description provided for @activeLinks.
  ///
  /// In pt, this message translates to:
  /// **'Links Ativos'**
  String get activeLinks;

  /// No description provided for @noActiveLinks.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum link ativo'**
  String get noActiveLinks;

  /// No description provided for @noComments.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum comentário'**
  String get noComments;

  /// No description provided for @addComment.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar comentário'**
  String get addComment;

  /// No description provided for @commentPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu comentário...'**
  String get commentPlaceholder;

  /// No description provided for @commentAdded.
  ///
  /// In pt, this message translates to:
  /// **'Comentário adicionado'**
  String get commentAdded;

  /// No description provided for @commentFromCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Cliente'**
  String get commentFromCustomer;

  /// No description provided for @commentFromTeam.
  ///
  /// In pt, this message translates to:
  /// **'Equipe'**
  String get commentFromTeam;

  /// No description provided for @internalComment.
  ///
  /// In pt, this message translates to:
  /// **'Comentário interno'**
  String get internalComment;

  /// No description provided for @internalCommentHint.
  ///
  /// In pt, this message translates to:
  /// **'Visível apenas para a equipe'**
  String get internalCommentHint;

  /// No description provided for @publicComment.
  ///
  /// In pt, this message translates to:
  /// **'Comentário público'**
  String get publicComment;

  /// No description provided for @publicCommentHint.
  ///
  /// In pt, this message translates to:
  /// **'Visível para o cliente'**
  String get publicCommentHint;

  /// No description provided for @markAsInternal.
  ///
  /// In pt, this message translates to:
  /// **'Marcar como interno'**
  String get markAsInternal;

  /// No description provided for @sendComment.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get sendComment;

  /// No description provided for @approveQuoteAction.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar Orçamento'**
  String get approveQuoteAction;

  /// No description provided for @rejectQuoteAction.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitar Orçamento'**
  String get rejectQuoteAction;

  /// No description provided for @quoteApprovedByCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento aprovado pelo cliente'**
  String get quoteApprovedByCustomer;

  /// No description provided for @quoteRejectedByCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento rejeitado pelo cliente'**
  String get quoteRejectedByCustomer;

  /// No description provided for @rejectionReason.
  ///
  /// In pt, this message translates to:
  /// **'Motivo da rejeição'**
  String get rejectionReason;

  /// No description provided for @linkValidity.
  ///
  /// In pt, this message translates to:
  /// **'Validade do Link'**
  String get linkValidity;

  /// No description provided for @validFor.
  ///
  /// In pt, this message translates to:
  /// **'Válido por'**
  String get validFor;

  /// No description provided for @days.
  ///
  /// In pt, this message translates to:
  /// **'dias'**
  String get days;

  /// No description provided for @selectValidity.
  ///
  /// In pt, this message translates to:
  /// **'Selecione a validade'**
  String get selectValidity;

  /// No description provided for @usingExistingLink.
  ///
  /// In pt, this message translates to:
  /// **'Link ativo encontrado'**
  String get usingExistingLink;

  /// No description provided for @generateNewLink.
  ///
  /// In pt, this message translates to:
  /// **'Gerar novo'**
  String get generateNewLink;

  /// No description provided for @loadingExistingLinks.
  ///
  /// In pt, this message translates to:
  /// **'Verificando links existentes...'**
  String get loadingExistingLinks;

  /// No description provided for @advancedOptions.
  ///
  /// In pt, this message translates to:
  /// **'Opções avançadas'**
  String get advancedOptions;

  /// No description provided for @sendToCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Enviar para o cliente'**
  String get sendToCustomer;

  /// No description provided for @rating.
  ///
  /// In pt, this message translates to:
  /// **'Avaliação'**
  String get rating;

  /// No description provided for @ratings.
  ///
  /// In pt, this message translates to:
  /// **'Avaliações'**
  String get ratings;

  /// No description provided for @averageRating.
  ///
  /// In pt, this message translates to:
  /// **'Média das avaliações'**
  String get averageRating;

  /// No description provided for @totalRatings.
  ///
  /// In pt, this message translates to:
  /// **'Total de avaliações'**
  String get totalRatings;

  /// No description provided for @noRatingsYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma avaliação ainda'**
  String get noRatingsYet;

  /// No description provided for @rateService.
  ///
  /// In pt, this message translates to:
  /// **'Avalie nosso serviço'**
  String get rateService;

  /// No description provided for @rateSubmit.
  ///
  /// In pt, this message translates to:
  /// **'Enviar Avaliação'**
  String get rateSubmit;

  /// No description provided for @rateSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Obrigado pela sua avaliação!'**
  String get rateSuccess;

  /// No description provided for @ratingScore.
  ///
  /// In pt, this message translates to:
  /// **'{score}/5'**
  String ratingScore(int score);

  /// No description provided for @customerRating.
  ///
  /// In pt, this message translates to:
  /// **'Avaliação do Cliente'**
  String get customerRating;

  /// No description provided for @ratingWithStars.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{estrela} other{estrelas}}'**
  String ratingWithStars(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
