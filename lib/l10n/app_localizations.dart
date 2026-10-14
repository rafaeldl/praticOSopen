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

  /// No description provided for @status.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get status;

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
  /// **'Falta receber'**
  String get toReceive;

  /// No description provided for @received.
  ///
  /// In pt, this message translates to:
  /// **'Recebido'**
  String get received;

  /// No description provided for @pix.
  ///
  /// In pt, this message translates to:
  /// **'PIX'**
  String get pix;

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

  /// No description provided for @asaasTransactionCannotBeRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Pagamentos recebidos pelo Asaas não podem ser removidos aqui. Para desfazer, estorne a cobrança no Asaas.'**
  String get asaasTransactionCannotBeRemoved;

  /// No description provided for @paymentUpdateFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar o pagamento. Verifique sua conexão e tente novamente.'**
  String get paymentUpdateFailed;

  /// No description provided for @paymentRequiresConnection.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Tente de novo quando estiver online.'**
  String get paymentRequiresConnection;

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

  /// Mensagem de confirmação para remover transação
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover este {type} de {amount}?'**
  String confirmRemoveTransaction(String type, String amount);

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

  /// No description provided for @addPhotoOrAttachment.
  ///
  /// In pt, this message translates to:
  /// **'Foto / Anexo'**
  String get addPhotoOrAttachment;

  /// No description provided for @photos.
  ///
  /// In pt, this message translates to:
  /// **'fotos'**
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

  /// No description provided for @scheduledDate.
  ///
  /// In pt, this message translates to:
  /// **'Agendado'**
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

  /// No description provided for @startDate.
  ///
  /// In pt, this message translates to:
  /// **'Data de início'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In pt, this message translates to:
  /// **'Data de término'**
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

  /// No description provided for @confirmDeleteMessageNamed.
  ///
  /// In pt, this message translates to:
  /// **'Deseja realmente excluir \"{name}\"?'**
  String confirmDeleteMessageNamed(String name);

  /// No description provided for @confirmAction.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Ação'**
  String get confirmAction;

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
  /// **'Novo cliente'**
  String get newCustomer;

  /// No description provided for @editCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Editar cliente'**
  String get editCustomer;

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

  /// No description provided for @fullName.
  ///
  /// In pt, this message translates to:
  /// **'Nome Completo'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In pt, this message translates to:
  /// **'Telefone'**
  String get phone;

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

  /// No description provided for @address.
  ///
  /// In pt, this message translates to:
  /// **'Endereço'**
  String get address;

  /// No description provided for @number.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get number;

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

  /// No description provided for @orderOverdue.
  ///
  /// In pt, this message translates to:
  /// **'Atrasada'**
  String get orderOverdue;

  /// No description provided for @newOrder.
  ///
  /// In pt, this message translates to:
  /// **'NOVA'**
  String get newOrder;

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

  /// No description provided for @problem.
  ///
  /// In pt, this message translates to:
  /// **'Problema Relatado'**
  String get problem;

  /// No description provided for @warranty.
  ///
  /// In pt, this message translates to:
  /// **'Garantia'**
  String get warranty;

  /// No description provided for @priority.
  ///
  /// In pt, this message translates to:
  /// **'Prioridade'**
  String get priority;

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

  /// No description provided for @editDevice.
  ///
  /// In pt, this message translates to:
  /// **'Editar Equipamento'**
  String get editDevice;

  /// No description provided for @deviceList.
  ///
  /// In pt, this message translates to:
  /// **'Lista de Equipamentos'**
  String get deviceList;

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

  /// No description provided for @defects.
  ///
  /// In pt, this message translates to:
  /// **'Defeitos'**
  String get defects;

  /// No description provided for @service.
  ///
  /// In pt, this message translates to:
  /// **'Serviço'**
  String get service;

  /// No description provided for @editService.
  ///
  /// In pt, this message translates to:
  /// **'Editar Serviço'**
  String get editService;

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

  /// No description provided for @addService.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Serviço'**
  String get addService;

  /// No description provided for @product.
  ///
  /// In pt, this message translates to:
  /// **'Produto'**
  String get product;

  /// No description provided for @editProduct.
  ///
  /// In pt, this message translates to:
  /// **'Editar Produto'**
  String get editProduct;

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

  /// No description provided for @addProduct.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Produto'**
  String get addProduct;

  /// No description provided for @barcode.
  ///
  /// In pt, this message translates to:
  /// **'Código de Barras'**
  String get barcode;

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

  /// No description provided for @noInternetConnection.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet'**
  String get noInternetConnection;

  /// No description provided for @permissionDenied.
  ///
  /// In pt, this message translates to:
  /// **'Permissão negada'**
  String get permissionDenied;

  /// No description provided for @timeout.
  ///
  /// In pt, this message translates to:
  /// **'Tempo esgotado'**
  String get timeout;

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

  /// No description provided for @signIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get signIn;

  /// No description provided for @password.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get password;

  /// No description provided for @emailSent.
  ///
  /// In pt, this message translates to:
  /// **'E-mail enviado'**
  String get emailSent;

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

  /// No description provided for @companyName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da Empresa'**
  String get companyName;

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

  /// No description provided for @english.
  ///
  /// In pt, this message translates to:
  /// **'Inglês'**
  String get english;

  /// No description provided for @theme.
  ///
  /// In pt, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @notifications.
  ///
  /// In pt, this message translates to:
  /// **'Notificações'**
  String get notifications;

  /// No description provided for @markAllAsRead.
  ///
  /// In pt, this message translates to:
  /// **'Marcar todas'**
  String get markAllAsRead;

  /// No description provided for @sound.
  ///
  /// In pt, this message translates to:
  /// **'Som'**
  String get sound;

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

  /// No description provided for @support.
  ///
  /// In pt, this message translates to:
  /// **'Suporte'**
  String get support;

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

  /// No description provided for @recentOrders.
  ///
  /// In pt, this message translates to:
  /// **'OS recentes'**
  String get recentOrders;

  /// No description provided for @role.
  ///
  /// In pt, this message translates to:
  /// **'Função'**
  String get role;

  /// No description provided for @noRole.
  ///
  /// In pt, this message translates to:
  /// **'Sem perfil'**
  String get noRole;

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

  /// No description provided for @customerSignature.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura do Cliente'**
  String get customerSignature;

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

  /// No description provided for @custom.
  ///
  /// In pt, this message translates to:
  /// **'Personalizado'**
  String get custom;

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

  /// No description provided for @userNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Usuário não encontrado'**
  String get userNotFound;

  /// No description provided for @checkInboxResetPassword.
  ///
  /// In pt, this message translates to:
  /// **'Verifique sua caixa de entrada para redefinir sua senha.'**
  String get checkInboxResetPassword;

  /// No description provided for @user.
  ///
  /// In pt, this message translates to:
  /// **'Usuário'**
  String get user;

  /// No description provided for @switchCompany.
  ///
  /// In pt, this message translates to:
  /// **'Trocar Empresa'**
  String get switchCompany;

  /// No description provided for @management.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciamento'**
  String get management;

  /// No description provided for @integrations.
  ///
  /// In pt, this message translates to:
  /// **'Integrações'**
  String get integrations;

  /// No description provided for @integrationsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Conecte o PraticOS ao ChatGPT e ao Claude'**
  String get integrationsSubtitle;

  /// No description provided for @integrationsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conexão ainda'**
  String get integrationsEmpty;

  /// No description provided for @integrationsNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova conexão'**
  String get integrationsNew;

  /// No description provided for @integrationsNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Meu ChatGPT'**
  String get integrationsNameHint;

  /// No description provided for @integrationsUrlOnce.
  ///
  /// In pt, this message translates to:
  /// **'Copie esta URL agora. Ela não será exibida novamente.'**
  String get integrationsUrlOnce;

  /// No description provided for @integrationsCopy.
  ///
  /// In pt, this message translates to:
  /// **'Copiar URL'**
  String get integrationsCopy;

  /// No description provided for @integrationsRevoke.
  ///
  /// In pt, this message translates to:
  /// **'Revogar'**
  String get integrationsRevoke;

  /// No description provided for @integrationsRevokeConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Revogar esta conexão? Quem estiver usando esta URL perde o acesso.'**
  String get integrationsRevokeConfirm;

  /// No description provided for @integrationsNeverUsed.
  ///
  /// In pt, this message translates to:
  /// **'Nunca usada'**
  String get integrationsNeverUsed;

  /// No description provided for @integrationsLastUsed.
  ///
  /// In pt, this message translates to:
  /// **'Último uso em {date}'**
  String integrationsLastUsed(String date);

  /// No description provided for @integrationsErrorForbidden.
  ///
  /// In pt, this message translates to:
  /// **'Apenas o dono ou administradores podem gerenciar integrações.'**
  String get integrationsErrorForbidden;

  /// No description provided for @integrationsErrorNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Esta conexão não existe mais.'**
  String get integrationsErrorNotFound;

  /// No description provided for @integrationsErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir. Tente novamente.'**
  String get integrationsErrorGeneric;

  /// No description provided for @companyData.
  ///
  /// In pt, this message translates to:
  /// **'Dados da Empresa'**
  String get companyData;

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

  /// No description provided for @accountDeletionTakingLong.
  ///
  /// In pt, this message translates to:
  /// **'A exclusão pode levar alguns minutos. Tente de novo em instantes.'**
  String get accountDeletionTakingLong;

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

  /// No description provided for @noSegmentsAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum segmento disponível'**
  String get noSegmentsAvailable;

  /// No description provided for @specialties.
  ///
  /// In pt, this message translates to:
  /// **'Especialidades'**
  String get specialties;

  /// No description provided for @myCompany.
  ///
  /// In pt, this message translates to:
  /// **'Minha empresa'**
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

  /// No description provided for @registered.
  ///
  /// In pt, this message translates to:
  /// **'cadastrado'**
  String get registered;

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

  /// No description provided for @doYouWantToRemoveThe.
  ///
  /// In pt, this message translates to:
  /// **'Deseja remover o'**
  String get doYouWantToRemoveThe;

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

  /// No description provided for @contacts.
  ///
  /// In pt, this message translates to:
  /// **'Contatos'**
  String get contacts;

  /// No description provided for @preparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando...'**
  String get preparing;

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

  /// No description provided for @typeOneOptionPerLine.
  ///
  /// In pt, this message translates to:
  /// **'Digite uma opção por linha'**
  String get typeOneOptionPerLine;

  /// No description provided for @searchProcedure.
  ///
  /// In pt, this message translates to:
  /// **'Buscar procedimento'**
  String get searchProcedure;

  /// No description provided for @noProceduresAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum procedimento disponível'**
  String get noProceduresAvailable;

  /// No description provided for @fromCompany.
  ///
  /// In pt, this message translates to:
  /// **'Da empresa'**
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

  /// No description provided for @shareInvite.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar Convite'**
  String get shareInvite;

  /// No description provided for @copyInviteCode.
  ///
  /// In pt, this message translates to:
  /// **'Copiar Código do Convite'**
  String get copyInviteCode;

  /// No description provided for @sendViaWhatsAppInvite.
  ///
  /// In pt, this message translates to:
  /// **'Enviar convite via WhatsApp'**
  String get sendViaWhatsAppInvite;

  /// No description provided for @inviteCodeCopied.
  ///
  /// In pt, this message translates to:
  /// **'Código do convite copiado!'**
  String get inviteCodeCopied;

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

  /// No description provided for @financialReport.
  ///
  /// In pt, this message translates to:
  /// **'Relatório financeiro'**
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
  /// **'Média por OS'**
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
  /// **'{count} OS'**
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

  /// No description provided for @linked.
  ///
  /// In pt, this message translates to:
  /// **'Vinculado'**
  String get linked;

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

  /// No description provided for @errorGeneratingToken.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar código de vinculação'**
  String get errorGeneratingToken;

  /// No description provided for @shareWithCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar com Cliente'**
  String get shareWithCustomer;

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

  /// No description provided for @viewCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} {count, plural, =1{visualização} other{visualizações}}'**
  String viewCount(int count);

  /// No description provided for @noComments.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum comentário'**
  String get noComments;

  /// No description provided for @commentPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu comentário...'**
  String get commentPlaceholder;

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

  /// No description provided for @publicComment.
  ///
  /// In pt, this message translates to:
  /// **'Comentário público'**
  String get publicComment;

  /// No description provided for @rejectionReason.
  ///
  /// In pt, this message translates to:
  /// **'Motivo da rejeição'**
  String get rejectionReason;

  /// No description provided for @days.
  ///
  /// In pt, this message translates to:
  /// **'dias'**
  String get days;

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

  /// No description provided for @noRatingsYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma avaliação ainda'**
  String get noRatingsYet;

  /// No description provided for @notifyCustomerQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Notificar cliente?'**
  String get notifyCustomerQuestion;

  /// No description provided for @notifyCustomerDescription.
  ///
  /// In pt, this message translates to:
  /// **'Deseja enviar a atualização para {customerName} via WhatsApp?'**
  String notifyCustomerDescription(String customerName);

  /// No description provided for @notNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get notNow;

  /// No description provided for @statusUpdateApproved.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento aprovado!'**
  String get statusUpdateApproved;

  /// No description provided for @statusUpdateProgress.
  ///
  /// In pt, this message translates to:
  /// **'Serviço em andamento!'**
  String get statusUpdateProgress;

  /// No description provided for @statusUpdateDone.
  ///
  /// In pt, this message translates to:
  /// **'Serviço concluído!'**
  String get statusUpdateDone;

  /// No description provided for @connectWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Conecte seu WhatsApp'**
  String get connectWhatsApp;

  /// No description provided for @connectWhatsAppBannerDescription.
  ///
  /// In pt, this message translates to:
  /// **'Receba notificações, gerencie OS e envie atualizações para clientes pelo WhatsApp.'**
  String get connectWhatsAppBannerDescription;

  /// No description provided for @whatsappOnboardingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conecte seu WhatsApp'**
  String get whatsappOnboardingTitle;

  /// No description provided for @whatsappOnboardingSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Aproveite ao máximo o PraticOS conectando seu WhatsApp'**
  String get whatsappOnboardingSubtitle;

  /// No description provided for @whatsappBenefitNotifications.
  ///
  /// In pt, this message translates to:
  /// **'Receba notificações de novas OS'**
  String get whatsappBenefitNotifications;

  /// No description provided for @whatsappBenefitManage.
  ///
  /// In pt, this message translates to:
  /// **'Gerencie OS diretamente pelo chat'**
  String get whatsappBenefitManage;

  /// No description provided for @whatsappBenefitClients.
  ///
  /// In pt, this message translates to:
  /// **'Envie atualizações para clientes'**
  String get whatsappBenefitClients;

  /// No description provided for @linkNow.
  ///
  /// In pt, this message translates to:
  /// **'Vincular agora'**
  String get linkNow;

  /// No description provided for @maybeLater.
  ///
  /// In pt, this message translates to:
  /// **'Talvez depois'**
  String get maybeLater;

  /// No description provided for @inviteWhatsAppMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você foi convidado para a equipe no PraticOS!\n\nCódigo do convite: {code}\n\nBaixe o app:\niOS: https://apps.apple.com/br/app/praticos/id1534604555\nAndroid: https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos'**
  String inviteWhatsAppMessage(String code);

  /// No description provided for @cannotRemoveOnlyAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Não é possível remover o único administrador da empresa. Promova outro colaborador a administrador antes de remover este.'**
  String get cannotRemoveOnlyAdmin;

  /// No description provided for @cannotChangeOnlyAdminRole.
  ///
  /// In pt, this message translates to:
  /// **'Não é possível alterar o perfil do único administrador. Promova outro colaborador a administrador antes de alterar este.'**
  String get cannotChangeOnlyAdminRole;

  /// No description provided for @cannotRemoveSelf.
  ///
  /// In pt, this message translates to:
  /// **'Você não pode remover a si mesmo da empresa.'**
  String get cannotRemoveSelf;

  /// No description provided for @invalidInviteCompanyNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Convite inválido: empresa não encontrada.'**
  String get invalidInviteCompanyNotFound;

  /// No description provided for @shareInviteAction.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar Convite'**
  String get shareInviteAction;

  /// No description provided for @duplicateInviteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Convite Existente'**
  String get duplicateInviteTitle;

  /// No description provided for @duplicateInviteMessage.
  ///
  /// In pt, this message translates to:
  /// **'Já existe um convite pendente para este email/telefone.'**
  String get duplicateInviteMessage;

  /// No description provided for @resendExistingInvite.
  ///
  /// In pt, this message translates to:
  /// **'Reenviar Existente'**
  String get resendExistingInvite;

  /// No description provided for @cancelAndCreateNew.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar e Criar Novo'**
  String get cancelAndCreateNew;

  /// No description provided for @agenda.
  ///
  /// In pt, this message translates to:
  /// **'Agenda'**
  String get agenda;

  /// No description provided for @noScheduledOrders.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS agendada para este dia'**
  String get noScheduledOrders;

  /// No description provided for @allTeam.
  ///
  /// In pt, this message translates to:
  /// **'Toda a equipe'**
  String get allTeam;

  /// No description provided for @allDay.
  ///
  /// In pt, this message translates to:
  /// **'Dia todo'**
  String get allDay;

  /// No description provided for @scheduleReminder.
  ///
  /// In pt, this message translates to:
  /// **'Lembrete de agendamento'**
  String get scheduleReminder;

  /// No description provided for @reminderDisabled.
  ///
  /// In pt, this message translates to:
  /// **'Desativado'**
  String get reminderDisabled;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min antes'**
  String reminderMinutesBefore(int minutes);

  /// No description provided for @reminderHourBefore.
  ///
  /// In pt, this message translates to:
  /// **'1 hora antes'**
  String get reminderHourBefore;

  /// No description provided for @reminderHoursBefore.
  ///
  /// In pt, this message translates to:
  /// **'{hours} horas antes'**
  String reminderHoursBefore(int hours);

  /// No description provided for @inviteWhatsAppSuccessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Colaborador Convidado'**
  String get inviteWhatsAppSuccessTitle;

  /// No description provided for @inviteWhatsAppSuccessMessage.
  ///
  /// In pt, this message translates to:
  /// **'{name} receberá o convite automaticamente ao entrar em contato com o bot PraticOS no WhatsApp.'**
  String inviteWhatsAppSuccessMessage(String name);

  /// No description provided for @serviceLocation.
  ///
  /// In pt, this message translates to:
  /// **'Local do Atendimento'**
  String get serviceLocation;

  /// No description provided for @openInMaps.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no Mapa'**
  String get openInMaps;

  /// No description provided for @addressPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Rua, número, bairro, cidade'**
  String get addressPlaceholder;

  /// No description provided for @sendWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Enviar WhatsApp'**
  String get sendWhatsApp;

  /// No description provided for @inviteWhatsAppBotMessage.
  ///
  /// In pt, this message translates to:
  /// **'Olá! Você foi adicionado à equipe da {company} no PraticOS. Mande um \"oi\" para o bot para começar: https://wa.me/5548988794742'**
  String inviteWhatsAppBotMessage(String company);

  /// No description provided for @removeDevice.
  ///
  /// In pt, this message translates to:
  /// **'Remover Equipamento'**
  String get removeDevice;

  /// No description provided for @generalNoDevice.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get generalNoDevice;

  /// No description provided for @selectDeviceFor.
  ///
  /// In pt, this message translates to:
  /// **'Para qual equipamento?'**
  String get selectDeviceFor;

  /// No description provided for @deviceCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} equipamentos'**
  String deviceCount(int count);

  /// No description provided for @confirmRemoveDevice.
  ///
  /// In pt, this message translates to:
  /// **'Remover \"{name}\" desta OS?'**
  String confirmRemoveDevice(String name);

  /// No description provided for @removeDeviceKeepItems.
  ///
  /// In pt, this message translates to:
  /// **'Manter itens'**
  String get removeDeviceKeepItems;

  /// No description provided for @removeDeviceAndItems.
  ///
  /// In pt, this message translates to:
  /// **'Remover tudo'**
  String get removeDeviceAndItems;

  /// No description provided for @removeDeviceHasItems.
  ///
  /// In pt, this message translates to:
  /// **'\"{name}\" possui {count} itens associados. O que deseja fazer?'**
  String removeDeviceHasItems(String name, String count);

  /// No description provided for @features.
  ///
  /// In pt, this message translates to:
  /// **'Funcionalidades'**
  String get features;

  /// No description provided for @contracts.
  ///
  /// In pt, this message translates to:
  /// **'Contratos'**
  String get contracts;

  /// No description provided for @noContracts.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum contrato'**
  String get noContracts;

  /// No description provided for @activateContract.
  ///
  /// In pt, this message translates to:
  /// **'Ativar contrato recorrente'**
  String get activateContract;

  /// No description provided for @deactivateContract.
  ///
  /// In pt, this message translates to:
  /// **'Desativar contrato recorrente'**
  String get deactivateContract;

  /// No description provided for @deactivateContractConfirm.
  ///
  /// In pt, this message translates to:
  /// **'A geração automática de OS será interrompida.'**
  String get deactivateContractConfirm;

  /// No description provided for @recurringContract.
  ///
  /// In pt, this message translates to:
  /// **'Contrato recorrente'**
  String get recurringContract;

  /// No description provided for @automaticGeneration.
  ///
  /// In pt, this message translates to:
  /// **'Geração automática'**
  String get automaticGeneration;

  /// No description provided for @contractNextDue.
  ///
  /// In pt, this message translates to:
  /// **'Próxima geração'**
  String get contractNextDue;

  /// No description provided for @generatedOrdersCount.
  ///
  /// In pt, this message translates to:
  /// **'OS geradas ({count})'**
  String generatedOrdersCount(int count);

  /// No description provided for @selectDate.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar data'**
  String get selectDate;

  /// No description provided for @deviceStatusActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativo'**
  String get deviceStatusActive;

  /// No description provided for @deviceStatusMaintenance.
  ///
  /// In pt, this message translates to:
  /// **'Em manutenção'**
  String get deviceStatusMaintenance;

  /// No description provided for @deviceStatusInactive.
  ///
  /// In pt, this message translates to:
  /// **'Inativo'**
  String get deviceStatusInactive;

  /// No description provided for @deviceStatusDecommissioned.
  ///
  /// In pt, this message translates to:
  /// **'Desativado'**
  String get deviceStatusDecommissioned;

  /// No description provided for @noOrderHistory.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma ordem de serviço registrada'**
  String get noOrderHistory;

  /// No description provided for @configure.
  ///
  /// In pt, this message translates to:
  /// **'Configurar'**
  String get configure;

  /// No description provided for @frequency.
  ///
  /// In pt, this message translates to:
  /// **'Frequência'**
  String get frequency;

  /// No description provided for @interval.
  ///
  /// In pt, this message translates to:
  /// **'Intervalo'**
  String get interval;

  /// No description provided for @indefinite.
  ///
  /// In pt, this message translates to:
  /// **'Indefinido'**
  String get indefinite;

  /// No description provided for @noOrdersDueOnDate.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS com vencimento neste dia'**
  String get noOrdersDueOnDate;

  /// No description provided for @documents.
  ///
  /// In pt, this message translates to:
  /// **'Documentos'**
  String get documents;

  /// No description provided for @addDocument.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Documento'**
  String get addDocument;

  /// No description provided for @receipt.
  ///
  /// In pt, this message translates to:
  /// **'Comprovante'**
  String get receipt;

  /// No description provided for @invoice.
  ///
  /// In pt, this message translates to:
  /// **'Nota Fiscal'**
  String get invoice;

  /// No description provided for @contract.
  ///
  /// In pt, this message translates to:
  /// **'Contrato'**
  String get contract;

  /// No description provided for @deleteDocument.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Documento'**
  String get deleteDocument;

  /// No description provided for @confirmDeleteDocument.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza que deseja excluir este documento?'**
  String get confirmDeleteDocument;

  /// No description provided for @uploadingDocument.
  ///
  /// In pt, this message translates to:
  /// **'Enviando documento...'**
  String get uploadingDocument;

  /// No description provided for @documentAdded.
  ///
  /// In pt, this message translates to:
  /// **'Documento adicionado'**
  String get documentAdded;

  /// No description provided for @documentDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Documento excluído'**
  String get documentDeleted;

  /// No description provided for @openDocument.
  ///
  /// In pt, this message translates to:
  /// **'Abrir'**
  String get openDocument;

  /// No description provided for @fromFiles.
  ///
  /// In pt, this message translates to:
  /// **'Arquivos'**
  String get fromFiles;

  /// No description provided for @errorUploadingDocument.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao enviar documento'**
  String get errorUploadingDocument;

  /// No description provided for @engagementReminders.
  ///
  /// In pt, this message translates to:
  /// **'Lembretes'**
  String get engagementReminders;

  /// No description provided for @dailyNotificationTitle.
  ///
  /// In pt, this message translates to:
  /// **'Bom dia!'**
  String get dailyNotificationTitle;

  /// No description provided for @dailyNotificationBody.
  ///
  /// In pt, this message translates to:
  /// **'Registre as OS do dia no PraticOS'**
  String get dailyNotificationBody;

  /// No description provided for @inactivity3dTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sentimos sua falta!'**
  String get inactivity3dTitle;

  /// No description provided for @inactivity3dBody.
  ///
  /// In pt, this message translates to:
  /// **'Você não abre o PraticOS há 3 dias. Que tal registrar suas OS?'**
  String get inactivity3dBody;

  /// No description provided for @inactivity5dTitle.
  ///
  /// In pt, this message translates to:
  /// **'Suas OS estão esperando!'**
  String get inactivity5dTitle;

  /// No description provided for @inactivity5dBody.
  ///
  /// In pt, this message translates to:
  /// **'Já faz 5 dias! Não perca o controle das suas ordens de serviço.'**
  String get inactivity5dBody;

  /// No description provided for @inactivity7dTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não deixe o PraticOS parado!'**
  String get inactivity7dTitle;

  /// No description provided for @inactivity7dBody.
  ///
  /// In pt, this message translates to:
  /// **'Faz 1 semana que você não abre o app. Volte e organize suas OS!'**
  String get inactivity7dBody;

  /// No description provided for @pendingOsNotificationTitle.
  ///
  /// In pt, this message translates to:
  /// **'OS pendentes precisam de atenção'**
  String get pendingOsNotificationTitle;

  /// No description provided for @pendingOsNotificationBody.
  ///
  /// In pt, this message translates to:
  /// **'Você tem {count} OS paradas há mais de 7 dias.'**
  String pendingOsNotificationBody(int count);

  /// No description provided for @termsOfService.
  ///
  /// In pt, this message translates to:
  /// **'Termos e Condições'**
  String get termsOfService;

  /// No description provided for @termsOfServicePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Equipamentos não retirados em 90 dias poderão ser descartados...'**
  String get termsOfServicePlaceholder;

  /// No description provided for @useDefaultTerms.
  ///
  /// In pt, this message translates to:
  /// **'Usar texto padrão do segmento'**
  String get useDefaultTerms;

  /// No description provided for @pdfTermsAndConditions.
  ///
  /// In pt, this message translates to:
  /// **'Termos e Condicoes'**
  String get pdfTermsAndConditions;

  /// No description provided for @pdfCompanySignature.
  ///
  /// In pt, this message translates to:
  /// **'Responsavel'**
  String get pdfCompanySignature;

  /// No description provided for @pdfClientSignature.
  ///
  /// In pt, this message translates to:
  /// **'Cliente'**
  String get pdfClientSignature;

  /// No description provided for @pdfTechnician.
  ///
  /// In pt, this message translates to:
  /// **'Tecnico'**
  String get pdfTechnician;

  /// No description provided for @pdfCreatedDate.
  ///
  /// In pt, this message translates to:
  /// **'Criada'**
  String get pdfCreatedDate;

  /// No description provided for @pdfCompletedDate.
  ///
  /// In pt, this message translates to:
  /// **'Concluida'**
  String get pdfCompletedDate;

  /// No description provided for @pdfIssuedDate.
  ///
  /// In pt, this message translates to:
  /// **'Emitida'**
  String get pdfIssuedDate;

  /// No description provided for @pdfServicesSubtotal.
  ///
  /// In pt, this message translates to:
  /// **'Subtotal Servicos'**
  String get pdfServicesSubtotal;

  /// No description provided for @pdfPartsSubtotal.
  ///
  /// In pt, this message translates to:
  /// **'Subtotal Pecas'**
  String get pdfPartsSubtotal;

  /// No description provided for @pdfPaid.
  ///
  /// In pt, this message translates to:
  /// **'Pago'**
  String get pdfPaid;

  /// No description provided for @pdfUnitValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor Unit.'**
  String get pdfUnitValue;

  /// No description provided for @pdfServiceType.
  ///
  /// In pt, this message translates to:
  /// **'Servico'**
  String get pdfServiceType;

  /// No description provided for @pdfProductType.
  ///
  /// In pt, this message translates to:
  /// **'Peca'**
  String get pdfProductType;

  /// No description provided for @pdfItemType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get pdfItemType;

  /// No description provided for @pdfSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo'**
  String get pdfSummary;

  /// No description provided for @pdfGeneral.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get pdfGeneral;

  /// No description provided for @pdfTrackOnline.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe online'**
  String get pdfTrackOnline;

  /// No description provided for @pdfTrackOnlineDescription.
  ///
  /// In pt, this message translates to:
  /// **'Escaneie o QR Code para acompanhar esta ordem de servico'**
  String get pdfTrackOnlineDescription;

  /// No description provided for @pdfEquipment.
  ///
  /// In pt, this message translates to:
  /// **'Equipamento'**
  String get pdfEquipment;

  /// No description provided for @upgrade.
  ///
  /// In pt, this message translates to:
  /// **'Fazer upgrade'**
  String get upgrade;

  /// No description provided for @formTemplates.
  ///
  /// In pt, this message translates to:
  /// **'formulários'**
  String get formTemplates;

  /// No description provided for @featureGateNearLimit.
  ///
  /// In pt, this message translates to:
  /// **'Restam {count} {feature}'**
  String featureGateNearLimit(int count, String feature);

  /// No description provided for @featureGateLimitReached.
  ///
  /// In pt, this message translates to:
  /// **'Limite de {feature} atingido'**
  String featureGateLimitReached(String feature);

  /// No description provided for @featureGateUpgradeSuggestion.
  ///
  /// In pt, this message translates to:
  /// **'Faça upgrade para o plano {plan} para mais'**
  String featureGateUpgradeSuggestion(String plan);

  /// No description provided for @featureGateUsageInfo.
  ///
  /// In pt, this message translates to:
  /// **'Usado {current} de {limit}'**
  String featureGateUsageInfo(int current, int limit);

  /// No description provided for @featureGateLimitModalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limite atingido'**
  String get featureGateLimitModalTitle;

  /// No description provided for @subscription.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura'**
  String get subscription;

  /// No description provided for @manageSubscription.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciar assinatura'**
  String get manageSubscription;

  /// No description provided for @restorePurchases.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar compras'**
  String get restorePurchases;

  /// No description provided for @restorePurchasesSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Compras restauradas com sucesso'**
  String get restorePurchasesSuccess;

  /// No description provided for @restorePurchasesError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao restaurar compras. Tente novamente.'**
  String get restorePurchasesError;

  /// No description provided for @success.
  ///
  /// In pt, this message translates to:
  /// **'Sucesso'**
  String get success;

  /// No description provided for @free.
  ///
  /// In pt, this message translates to:
  /// **'Gratuito'**
  String get free;

  /// No description provided for @renewsOn.
  ///
  /// In pt, this message translates to:
  /// **'Renova em {date}'**
  String renewsOn(String date);

  /// No description provided for @manageInStore.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciar na loja de aplicativos'**
  String get manageInStore;

  /// No description provided for @restore.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar'**
  String get restore;

  /// No description provided for @currentPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual'**
  String get currentPlan;

  /// No description provided for @featureLimitReached.
  ///
  /// In pt, this message translates to:
  /// **'Você atingiu o limite de {feature}'**
  String featureLimitReached(String feature);

  /// No description provided for @photoLimitReachedMessage.
  ///
  /// In pt, this message translates to:
  /// **'Você atingiu o limite de fotos deste mês.'**
  String get photoLimitReachedMessage;

  /// No description provided for @photoLimitUpgradeHint.
  ///
  /// In pt, this message translates to:
  /// **'Faça upgrade para adicionar mais fotos.'**
  String get photoLimitUpgradeHint;

  /// No description provided for @viewPlans.
  ///
  /// In pt, this message translates to:
  /// **'Ver planos'**
  String get viewPlans;

  /// No description provided for @askAdminToChangePlanTitle.
  ///
  /// In pt, this message translates to:
  /// **'Fale com o administrador'**
  String get askAdminToChangePlanTitle;

  /// No description provided for @askAdminToChangePlan.
  ///
  /// In pt, this message translates to:
  /// **'Peça ao administrador da empresa para mudar de plano.'**
  String get askAdminToChangePlan;

  /// No description provided for @subscriptionUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'As assinaturas não estão disponíveis agora. Tente novamente mais tarde.'**
  String get subscriptionUnavailable;

  /// No description provided for @restorePurchasesNothingFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma assinatura ativa foi encontrada nesta conta da loja.'**
  String get restorePurchasesNothingFound;

  /// No description provided for @planLimitUpgradeHint.
  ///
  /// In pt, this message translates to:
  /// **'Assine um plano para aumentar este limite.'**
  String get planLimitUpgradeHint;

  /// No description provided for @deleteAccountStoreSubscriptionWarning.
  ///
  /// In pt, this message translates to:
  /// **'Excluir a conta não cancela a assinatura da App Store ou do Google Play. Cancele antes nos ajustes da loja para não ser cobrado de novo.'**
  String get deleteAccountStoreSubscriptionWarning;

  /// No description provided for @asaasConnected.
  ///
  /// In pt, this message translates to:
  /// **'Conectado'**
  String get asaasConnected;

  /// No description provided for @asaasDisconnected.
  ///
  /// In pt, this message translates to:
  /// **'Não conectado'**
  String get asaasDisconnected;

  /// No description provided for @asaasConnectTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conectar conta Asaas'**
  String get asaasConnectTitle;

  /// No description provided for @asaasConnectIntro.
  ///
  /// In pt, this message translates to:
  /// **'Receba por Pix, boleto ou cartão na conta Asaas da sua empresa. Quando o pagamento é confirmado, a OS dá baixa sozinha.'**
  String get asaasConnectIntro;

  /// No description provided for @asaasConnectStep1.
  ///
  /// In pt, this message translates to:
  /// **'1. No painel do Asaas, abra Integrações > Chaves de API.'**
  String get asaasConnectStep1;

  /// No description provided for @asaasConnectStep2.
  ///
  /// In pt, this message translates to:
  /// **'2. Gere uma nova chave e copie.'**
  String get asaasConnectStep2;

  /// No description provided for @asaasConnectStep3.
  ///
  /// In pt, this message translates to:
  /// **'3. Cole a chave abaixo e toque em Conectar.'**
  String get asaasConnectStep3;

  /// No description provided for @asaasOpenPanel.
  ///
  /// In pt, this message translates to:
  /// **'Abrir painel do Asaas'**
  String get asaasOpenPanel;

  /// No description provided for @asaasOpenSandboxPanel.
  ///
  /// In pt, this message translates to:
  /// **'Abrir painel de teste (sandbox)'**
  String get asaasOpenSandboxPanel;

  /// No description provided for @asaasApiKey.
  ///
  /// In pt, this message translates to:
  /// **'Chave de API'**
  String get asaasApiKey;

  /// No description provided for @asaasApiKeyPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Cole a chave aqui'**
  String get asaasApiKeyPlaceholder;

  /// No description provided for @asaasApiKeyHint.
  ///
  /// In pt, this message translates to:
  /// **'A chave fica guardada com criptografia no servidor e não aparece de novo no app.'**
  String get asaasApiKeyHint;

  /// No description provided for @asaasConnect.
  ///
  /// In pt, this message translates to:
  /// **'Conectar'**
  String get asaasConnect;

  /// No description provided for @asaasAccount.
  ///
  /// In pt, this message translates to:
  /// **'Conta'**
  String get asaasAccount;

  /// No description provided for @asaasEnvironment.
  ///
  /// In pt, this message translates to:
  /// **'Ambiente'**
  String get asaasEnvironment;

  /// No description provided for @asaasEnvironmentSandbox.
  ///
  /// In pt, this message translates to:
  /// **'Teste'**
  String get asaasEnvironmentSandbox;

  /// No description provided for @asaasEnvironmentProduction.
  ///
  /// In pt, this message translates to:
  /// **'Produção'**
  String get asaasEnvironmentProduction;

  /// No description provided for @asaasDisconnect.
  ///
  /// In pt, this message translates to:
  /// **'Desconectar'**
  String get asaasDisconnect;

  /// No description provided for @asaasDisconnectConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Desconectar a conta Asaas? As cobranças em aberto continuam no Asaas, mas os pagamentos deixam de dar baixa na OS.'**
  String get asaasDisconnectConfirm;

  /// No description provided for @asaasErrorInvalidKey.
  ///
  /// In pt, this message translates to:
  /// **'Chave de API inválida. Confira e tente de novo.'**
  String get asaasErrorInvalidKey;

  /// No description provided for @asaasErrorForbidden.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para esta ação.'**
  String get asaasErrorForbidden;

  /// No description provided for @asaasErrorNotConnected.
  ///
  /// In pt, this message translates to:
  /// **'Conecte a conta Asaas em Configurações > Integrações.'**
  String get asaasErrorNotConnected;

  /// No description provided for @asaasErrorExceedsBalance.
  ///
  /// In pt, this message translates to:
  /// **'O valor é maior que o saldo da OS.'**
  String get asaasErrorExceedsBalance;

  /// No description provided for @asaasErrorTaxIdRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe o CPF ou CNPJ do cliente.'**
  String get asaasErrorTaxIdRequired;

  /// No description provided for @asaasErrorCustomerRequired.
  ///
  /// In pt, this message translates to:
  /// **'Adicione um cliente à OS antes de cobrar.'**
  String get asaasErrorCustomerRequired;

  /// No description provided for @asaasErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir. Tente novamente.'**
  String get asaasErrorGeneric;

  /// No description provided for @invalidTaxId.
  ///
  /// In pt, this message translates to:
  /// **'CPF ou CNPJ inválido'**
  String get invalidTaxId;

  /// No description provided for @chargeValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get chargeValue;

  /// No description provided for @chargeBalanceHint.
  ///
  /// In pt, this message translates to:
  /// **'Saldo da OS: {value}'**
  String chargeBalanceHint(String value);

  /// No description provided for @chargeSingleHint.
  ///
  /// In pt, this message translates to:
  /// **'O cliente escolhe Pix, boleto ou cartão.'**
  String get chargeSingleHint;

  /// No description provided for @chargeInstallmentOption.
  ///
  /// In pt, this message translates to:
  /// **'{count}x de {value}'**
  String chargeInstallmentOption(int count, String value);

  /// No description provided for @chargeDueDate.
  ///
  /// In pt, this message translates to:
  /// **'Vencimento'**
  String get chargeDueDate;

  /// No description provided for @chargeTaxIdHint.
  ///
  /// In pt, this message translates to:
  /// **'O Asaas exige CPF ou CNPJ. Ele fica salvo no cadastro do cliente.'**
  String get chargeTaxIdHint;

  /// No description provided for @chargeStatusPending.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando pagamento'**
  String get chargeStatusPending;

  /// No description provided for @chargeStatusOverdue.
  ///
  /// In pt, this message translates to:
  /// **'Vencida'**
  String get chargeStatusOverdue;

  /// No description provided for @chargeStatusPaid.
  ///
  /// In pt, this message translates to:
  /// **'Paga'**
  String get chargeStatusPaid;

  /// No description provided for @chargeStatusCanceled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelada'**
  String get chargeStatusCanceled;

  /// No description provided for @chargeStatusRefunded.
  ///
  /// In pt, this message translates to:
  /// **'Estornada'**
  String get chargeStatusRefunded;

  /// No description provided for @chargeCancelConfirm.
  ///
  /// In pt, this message translates to:
  /// **'O cliente não vai mais conseguir pagar por esse link.'**
  String get chargeCancelConfirm;

  /// No description provided for @chargeKeep.
  ///
  /// In pt, this message translates to:
  /// **'Manter'**
  String get chargeKeep;

  /// No description provided for @chargeReplaceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Já existe uma cobrança em aberto'**
  String get chargeReplaceTitle;

  /// No description provided for @chargeReplaceConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Gerar uma nova cobrança cancela a anterior no Asaas.'**
  String get chargeReplaceConfirm;

  /// No description provided for @chargeReplace.
  ///
  /// In pt, this message translates to:
  /// **'Gerar nova'**
  String get chargeReplace;

  /// No description provided for @asaasErrorInstallmentsInProgress.
  ///
  /// In pt, this message translates to:
  /// **'Este parcelamento já tem parcelas pagas. Aguarde terminar ou estorne no Asaas.'**
  String get asaasErrorInstallmentsInProgress;

  /// No description provided for @asaasErrorOrderCanceled.
  ///
  /// In pt, this message translates to:
  /// **'Esta OS está cancelada e não pode receber cobrança.'**
  String get asaasErrorOrderCanceled;

  /// No description provided for @asaasErrorInvalidDueDate.
  ///
  /// In pt, this message translates to:
  /// **'Data de vencimento inválida. Escolha hoje ou uma data futura.'**
  String get asaasErrorInvalidDueDate;

  /// No description provided for @asaasErrorInvalidInstallmentCount.
  ///
  /// In pt, this message translates to:
  /// **'Número de parcelas inválido. Escolha de 2 a 12.'**
  String get asaasErrorInvalidInstallmentCount;

  /// No description provided for @asaasErrorChargeNotOpen.
  ///
  /// In pt, this message translates to:
  /// **'Esta cobrança não está mais em aberto.'**
  String get asaasErrorChargeNotOpen;

  /// No description provided for @asaasErrorValidation.
  ///
  /// In pt, this message translates to:
  /// **'O Asaas recusou os dados da cobrança. Confira o CPF/CNPJ e o e-mail do cliente.'**
  String get asaasErrorValidation;

  /// No description provided for @asaasErrorUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'O Asaas está indisponível no momento. Tente novamente em instantes.'**
  String get asaasErrorUnavailable;

  /// No description provided for @listLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar. Verifique a internet e tente de novo.'**
  String get listLoadError;

  /// No description provided for @pickCustomerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quem é o cliente?'**
  String get pickCustomerTitle;

  /// No description provided for @searchCustomerPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Buscar por nome, telefone ou placa'**
  String get searchCustomerPlaceholder;

  /// No description provided for @plateValue.
  ///
  /// In pt, this message translates to:
  /// **'Placa {plate}'**
  String plateValue(String plate);

  /// No description provided for @customerNamePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Ana Ribeiro'**
  String get customerNamePlaceholder;

  /// No description provided for @customerNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite o nome do cliente'**
  String get customerNameRequired;

  /// No description provided for @customerPhoneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Telefone ou WhatsApp'**
  String get customerPhoneLabel;

  /// No description provided for @customerPhoneHint.
  ///
  /// In pt, this message translates to:
  /// **'Usado para mandar o orçamento e o aviso de pronto.'**
  String get customerPhoneHint;

  /// No description provided for @moreCustomerData.
  ///
  /// In pt, this message translates to:
  /// **'Mais dados (e-mail, CPF ou CNPJ, endereço)'**
  String get moreCustomerData;

  /// No description provided for @openInMap.
  ///
  /// In pt, this message translates to:
  /// **'Abrir no mapa'**
  String get openInMap;

  /// No description provided for @callAction.
  ///
  /// In pt, this message translates to:
  /// **'Ligar'**
  String get callAction;

  /// No description provided for @newOrderFor.
  ///
  /// In pt, this message translates to:
  /// **'Nova OS para {name}'**
  String newOrderFor(String name);

  /// No description provided for @devicesOfCustomer.
  ///
  /// In pt, this message translates to:
  /// **'{devices} de {name}'**
  String devicesOfCustomer(String devices, String name);

  /// No description provided for @totalSpent.
  ///
  /// In pt, this message translates to:
  /// **'Total gasto'**
  String get totalSpent;

  /// No description provided for @deleteCustomerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar {name}?'**
  String deleteCustomerTitle(String name);

  /// No description provided for @deleteCustomerKeepsOrders.
  ///
  /// In pt, this message translates to:
  /// **'As OS continuam salvas.'**
  String get deleteCustomerKeepsOrders;

  /// No description provided for @deleteAction.
  ///
  /// In pt, this message translates to:
  /// **'Apagar'**
  String get deleteAction;

  /// No description provided for @noCustomersYet.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não tem clientes'**
  String get noCustomersYet;

  /// No description provided for @addFirstCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Cadastrar o primeiro cliente'**
  String get addFirstCustomer;

  /// No description provided for @noCustomerMatching.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cliente com “{query}”'**
  String noCustomerMatching(String query);

  /// No description provided for @customersCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 cliente} other{{count} clientes}}'**
  String customersCount(int count);

  /// No description provided for @openOrdersCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 OS em aberto} other{{count} OS em aberto}}'**
  String openOrdersCount(int count);

  /// No description provided for @lateOrdersCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 OS atrasada} other{{count} OS atrasadas}}'**
  String lateOrdersCount(int count);

  /// No description provided for @customerActions.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações do cliente'**
  String get customerActions;

  /// No description provided for @customerLookupError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar os clientes. Tente de novo.'**
  String get customerLookupError;

  /// No description provided for @catalogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo'**
  String get catalogTitle;

  /// No description provided for @catalogNewService.
  ///
  /// In pt, this message translates to:
  /// **'Novo serviço'**
  String get catalogNewService;

  /// No description provided for @catalogNewProduct.
  ///
  /// In pt, this message translates to:
  /// **'Novo produto'**
  String get catalogNewProduct;

  /// No description provided for @saveServiceButton.
  ///
  /// In pt, this message translates to:
  /// **'Salvar serviço'**
  String get saveServiceButton;

  /// No description provided for @saveProductButton.
  ///
  /// In pt, this message translates to:
  /// **'Salvar produto'**
  String get saveProductButton;

  /// No description provided for @serviceNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Troca de óleo'**
  String get serviceNameHint;

  /// No description provided for @productNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Filtro de óleo'**
  String get productNameHint;

  /// No description provided for @serviceNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite o nome do serviço'**
  String get serviceNameRequired;

  /// No description provided for @productNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite o nome do produto'**
  String get productNameRequired;

  /// No description provided for @catalogPriceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Preço'**
  String get catalogPriceLabel;

  /// No description provided for @catalogPriceHint.
  ///
  /// In pt, this message translates to:
  /// **'Pode deixar em branco e combinar o preço em cada OS.'**
  String get catalogPriceHint;

  /// No description provided for @addServicePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Foto do serviço'**
  String get addServicePhoto;

  /// No description provided for @addProductPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Foto do produto'**
  String get addProductPhoto;

  /// No description provided for @catalogNoPrice.
  ///
  /// In pt, this message translates to:
  /// **'sem valor'**
  String get catalogNoPrice;

  /// No description provided for @catalogEmptyServices.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não tem serviços'**
  String get catalogEmptyServices;

  /// No description provided for @catalogEmptyServicesHint.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre os que você mais faz para montar a OS mais rápido.'**
  String get catalogEmptyServicesHint;

  /// No description provided for @catalogEmptyProducts.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não tem produtos'**
  String get catalogEmptyProducts;

  /// No description provided for @catalogEmptyProductsHint.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre os que você mais usa para montar a OS mais rápido.'**
  String get catalogEmptyProductsHint;

  /// No description provided for @catalogNoMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nada com “{query}”'**
  String catalogNoMatch(String query);

  /// No description provided for @catalogDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar {name}?'**
  String catalogDeleteTitle(String name);

  /// No description provided for @catalogDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'Ele sai do catálogo. As OS que já usam continuam salvas.'**
  String get catalogDeleteMessage;

  /// No description provided for @deleteServiceAction.
  ///
  /// In pt, this message translates to:
  /// **'Apagar serviço'**
  String get deleteServiceAction;

  /// No description provided for @deleteProductAction.
  ///
  /// In pt, this message translates to:
  /// **'Apagar produto'**
  String get deleteProductAction;

  /// No description provided for @catalogItemActions.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações do item'**
  String get catalogItemActions;

  /// No description provided for @pickServiceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual serviço?'**
  String get pickServiceTitle;

  /// No description provided for @pickProductTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual produto?'**
  String get pickProductTitle;

  /// No description provided for @catalogLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar o catálogo. Tente de novo.'**
  String get catalogLoadError;

  /// No description provided for @newEntity.
  ///
  /// In pt, this message translates to:
  /// **'Novo {entity}'**
  String newEntity(String entity);

  /// No description provided for @photoAndMoreData.
  ///
  /// In pt, this message translates to:
  /// **'Foto e mais dados'**
  String get photoAndMoreData;

  /// No description provided for @fieldRequiredHint.
  ///
  /// In pt, this message translates to:
  /// **'Preencha o campo {field}'**
  String fieldRequiredHint(String field);

  /// No description provided for @useValue.
  ///
  /// In pt, this message translates to:
  /// **'Usar “{value}”'**
  String useValue(String value);

  /// No description provided for @newOrderAction.
  ///
  /// In pt, this message translates to:
  /// **'Nova OS'**
  String get newOrderAction;

  /// No description provided for @deviceActions.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações'**
  String get deviceActions;

  /// No description provided for @deleteDeviceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar {name}?'**
  String deleteDeviceTitle(String name);

  /// No description provided for @deleteDeviceKeepsOrders.
  ///
  /// In pt, this message translates to:
  /// **'As OS continuam salvas.'**
  String get deleteDeviceKeepsOrders;

  /// No description provided for @deviceDetailsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Dados'**
  String get deviceDetailsLabel;

  /// No description provided for @newOrderScreenSetting.
  ///
  /// In pt, this message translates to:
  /// **'Nova tela da OS'**
  String get newOrderScreenSetting;

  /// No description provided for @newOrderScreenSettingHint.
  ///
  /// In pt, this message translates to:
  /// **'Desligue para voltar à tela antiga da OS.'**
  String get newOrderScreenSettingHint;

  /// No description provided for @orderNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova {order}'**
  String orderNewTitle(String order);

  /// No description provided for @orderNumberTitle.
  ///
  /// In pt, this message translates to:
  /// **'{order} {number}'**
  String orderNumberTitle(String order, String number);

  /// No description provided for @orderItemsSection.
  ///
  /// In pt, this message translates to:
  /// **'O que vai ser feito'**
  String get orderItemsSection;

  /// No description provided for @orderItemSearchPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Buscar serviço ou peça'**
  String get orderItemSearchPlaceholder;

  /// No description provided for @orderCreateItemError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para criar. Tente de novo.'**
  String get orderCreateItemError;

  /// No description provided for @orderCatalogEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Seu catálogo está vazio. Digite o nome na busca para criar.'**
  String get orderCatalogEmpty;

  /// No description provided for @orderMostUsed.
  ///
  /// In pt, this message translates to:
  /// **'Mais usados'**
  String get orderMostUsed;

  /// No description provided for @orderAllItems.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get orderAllItems;

  /// No description provided for @orderItemKindService.
  ///
  /// In pt, this message translates to:
  /// **'serviço'**
  String get orderItemKindService;

  /// No description provided for @orderItemKindProduct.
  ///
  /// In pt, this message translates to:
  /// **'produto'**
  String get orderItemKindProduct;

  /// No description provided for @orderItemQuantityValue.
  ///
  /// In pt, this message translates to:
  /// **'{count} unidades'**
  String orderItemQuantityValue(String count);

  /// No description provided for @orderItemPrice.
  ///
  /// In pt, this message translates to:
  /// **'Preço'**
  String get orderItemPrice;

  /// No description provided for @orderItemPriceHint.
  ///
  /// In pt, this message translates to:
  /// **'Pode deixar em branco: o item fica sem valor e fora do total.'**
  String get orderItemPriceHint;

  /// No description provided for @orderItemQuantity.
  ///
  /// In pt, this message translates to:
  /// **'Quantidade'**
  String get orderItemQuantity;

  /// No description provided for @orderItemLess.
  ///
  /// In pt, this message translates to:
  /// **'Menos um'**
  String get orderItemLess;

  /// No description provided for @orderItemMore.
  ///
  /// In pt, this message translates to:
  /// **'Mais um'**
  String get orderItemMore;

  /// No description provided for @orderItemRemove.
  ///
  /// In pt, this message translates to:
  /// **'Tirar da OS'**
  String get orderItemRemove;

  /// No description provided for @orderTotalLabel.
  ///
  /// In pt, this message translates to:
  /// **'Total'**
  String get orderTotalLabel;

  /// No description provided for @orderRemainingToReceive.
  ///
  /// In pt, this message translates to:
  /// **'Falta receber {amount}'**
  String orderRemainingToReceive(String amount);

  /// No description provided for @orderFullyPaid.
  ///
  /// In pt, this message translates to:
  /// **'Tudo pago'**
  String get orderFullyPaid;

  /// No description provided for @orderSaveNeedsCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o cliente para salvar.'**
  String get orderSaveNeedsCustomer;

  /// No description provided for @orderDiscardTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sair sem salvar?'**
  String get orderDiscardTitle;

  /// No description provided for @orderDiscardMessage.
  ///
  /// In pt, this message translates to:
  /// **'O que você preencheu vai ser perdido.'**
  String get orderDiscardMessage;

  /// No description provided for @orderKeepEditing.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get orderKeepEditing;

  /// No description provided for @orderPickDevice.
  ///
  /// In pt, this message translates to:
  /// **'Escolher {device}'**
  String orderPickDevice(String device);

  /// No description provided for @orderTalkAction.
  ///
  /// In pt, this message translates to:
  /// **'Falar o que fazer'**
  String get orderTalkAction;

  /// No description provided for @orderNextStepReceive.
  ///
  /// In pt, this message translates to:
  /// **'Receber {amount}'**
  String orderNextStepReceive(String amount);

  /// No description provided for @orderMenuAddTo.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar à {order}'**
  String orderMenuAddTo(String order);

  /// No description provided for @orderMenuSendToCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Mandar para o cliente'**
  String get orderMenuSendToCustomer;

  /// No description provided for @orderMenuCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar {order}'**
  String orderMenuCancel(String order);

  /// No description provided for @orderMenuDelete.
  ///
  /// In pt, this message translates to:
  /// **'Apagar {order}'**
  String orderMenuDelete(String order);

  /// No description provided for @orderAddDueDate.
  ///
  /// In pt, this message translates to:
  /// **'Data de entrega'**
  String get orderAddDueDate;

  /// No description provided for @orderAddAnotherDevice.
  ///
  /// In pt, this message translates to:
  /// **'Outro {device}'**
  String orderAddAnotherDevice(String device);

  /// No description provided for @orderCancelConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar {order}?'**
  String orderCancelConfirmTitle(String order);

  /// No description provided for @orderCancelConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Ela vai para as canceladas e pode ser reaberta.'**
  String get orderCancelConfirmMessage;

  /// No description provided for @orderDeleteConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar {order}?'**
  String orderDeleteConfirmTitle(String order);

  /// No description provided for @orderDeleteConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Não dá para desfazer.'**
  String get orderDeleteConfirmMessage;

  /// No description provided for @orderPhotosSection.
  ///
  /// In pt, this message translates to:
  /// **'Fotos'**
  String get orderPhotosSection;

  /// No description provided for @orderUnpricedCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 item sem valor, fora do total} other{{count} itens sem valor, fora do total}}'**
  String orderUnpricedCount(int count);

  /// No description provided for @orderPendingChecklists.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Falta terminar 1 checklist} other{Faltam terminar {count} checklists}}'**
  String orderPendingChecklists(int count);

  /// No description provided for @orderMoreActions.
  ///
  /// In pt, this message translates to:
  /// **'Mais ações'**
  String get orderMoreActions;

  /// No description provided for @filterOpen.
  ///
  /// In pt, this message translates to:
  /// **'Em aberto'**
  String get filterOpen;

  /// No description provided for @filterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todas'**
  String get filterAll;

  /// No description provided for @filterMine.
  ///
  /// In pt, this message translates to:
  /// **'Minhas'**
  String get filterMine;

  /// No description provided for @nextVisitLabel.
  ///
  /// In pt, this message translates to:
  /// **'Agora'**
  String get nextVisitLabel;

  /// No description provided for @homeWithYouToday.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 com você hoje} other{{count} com você hoje}}'**
  String homeWithYouToday(int count);

  /// No description provided for @homeWithYou.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 com você} other{{count} com você}}'**
  String homeWithYou(int count);

  /// No description provided for @nextVisit.
  ///
  /// In pt, this message translates to:
  /// **'Próximo: {customer}, às {time}.'**
  String nextVisit(String customer, String time);

  /// No description provided for @nextVisitDevice.
  ///
  /// In pt, this message translates to:
  /// **'Próximo: {customer}, {device}, às {time}.'**
  String nextVisitDevice(String customer, String device, String time);

  /// No description provided for @openOrderNumber.
  ///
  /// In pt, this message translates to:
  /// **'Abrir OS {number}'**
  String openOrderNumber(String number);

  /// No description provided for @noOrdersWithYou.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS com você.'**
  String get noOrdersWithYou;

  /// No description provided for @homeOpenCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} em aberto'**
  String homeOpenCount(int count);

  /// No description provided for @seeAllOrders.
  ///
  /// In pt, this message translates to:
  /// **'Ver todas'**
  String get seeAllOrders;

  /// No description provided for @notificationsA11y.
  ///
  /// In pt, this message translates to:
  /// **'Avisos, {count} novos'**
  String notificationsA11y(int count);

  /// No description provided for @howItWorks.
  ///
  /// In pt, this message translates to:
  /// **'Como funciona'**
  String get howItWorks;

  /// No description provided for @firstOrderLabel.
  ///
  /// In pt, this message translates to:
  /// **'Comece por aqui'**
  String get firstOrderLabel;

  /// No description provided for @homeNoOrdersYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma ainda'**
  String get homeNoOrdersYet;

  /// No description provided for @howItWorksStep1.
  ///
  /// In pt, this message translates to:
  /// **'1. Anote o que vai ser feito'**
  String get howItWorksStep1;

  /// No description provided for @howItWorksStep1Detail.
  ///
  /// In pt, this message translates to:
  /// **'cliente e serviços'**
  String get howItWorksStep1Detail;

  /// No description provided for @howItWorksStep1DetailDevice.
  ///
  /// In pt, this message translates to:
  /// **'cliente, {device} e serviços'**
  String howItWorksStep1DetailDevice(String device);

  /// No description provided for @howItWorksStep2.
  ///
  /// In pt, this message translates to:
  /// **'2. Mande o orçamento'**
  String get howItWorksStep2;

  /// No description provided for @howItWorksStep2Detail.
  ///
  /// In pt, this message translates to:
  /// **'pelo WhatsApp, com um link'**
  String get howItWorksStep2Detail;

  /// No description provided for @howItWorksStep3.
  ///
  /// In pt, this message translates to:
  /// **'3. Receba e entregue'**
  String get howItWorksStep3;

  /// No description provided for @howItWorksStep3Detail.
  ///
  /// In pt, this message translates to:
  /// **'o app lembra quem falta pagar'**
  String get howItWorksStep3Detail;

  /// No description provided for @searchNotFoundLoaded.
  ///
  /// In pt, this message translates to:
  /// **'Não achei nas OS carregadas.'**
  String get searchNotFoundLoaded;

  /// No description provided for @searchOlder.
  ///
  /// In pt, this message translates to:
  /// **'Buscar nas mais antigas'**
  String get searchOlder;

  /// No description provided for @noOpenOrders.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS em aberto.'**
  String get noOpenOrders;

  /// No description provided for @noOrdersInView.
  ///
  /// In pt, this message translates to:
  /// **'Nada por aqui.'**
  String get noOrdersInView;

  /// No description provided for @loadOrdersError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar as OS.'**
  String get loadOrdersError;

  /// No description provided for @orderLateMonths.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Atrasada há 1 mês} other{Atrasada há {count} meses}}'**
  String orderLateMonths(int count);

  /// No description provided for @orderLateYears.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Atrasada há 1 ano} other{Atrasada há {count} anos}}'**
  String orderLateYears(int count);

  /// No description provided for @orderLateDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Atrasada 1 dia} other{Atrasada {count} dias}}'**
  String orderLateDays(int count);

  /// No description provided for @orderStatusDue.
  ///
  /// In pt, this message translates to:
  /// **'{status} · entrega {date}'**
  String orderStatusDue(String status, String date);

  /// No description provided for @orderRowNumber.
  ///
  /// In pt, this message translates to:
  /// **'OS {number}'**
  String orderRowNumber(String number);

  /// No description provided for @yourAccount.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta'**
  String get yourAccount;

  /// No description provided for @yourCompany.
  ///
  /// In pt, this message translates to:
  /// **'Sua empresa'**
  String get yourCompany;

  /// No description provided for @catalog.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo'**
  String get catalog;

  /// No description provided for @planTitle.
  ///
  /// In pt, this message translates to:
  /// **'Plano'**
  String get planTitle;

  /// No description provided for @advancedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Avançado'**
  String get advancedTitle;

  /// No description provided for @deleteMyAccount.
  ///
  /// In pt, this message translates to:
  /// **'Apagar minha conta'**
  String get deleteMyAccount;

  /// No description provided for @howYouWork.
  ///
  /// In pt, this message translates to:
  /// **'Como você trabalha'**
  String get howYouWork;

  /// No description provided for @valuesAndBilling.
  ///
  /// In pt, this message translates to:
  /// **'Valores e cobrança'**
  String get valuesAndBilling;

  /// No description provided for @valuesAndBillingHint.
  ///
  /// In pt, this message translates to:
  /// **'Preços na OS, receber e aba Financeiro'**
  String get valuesAndBillingHint;

  /// No description provided for @valuesAndBillingOffTitle.
  ///
  /// In pt, this message translates to:
  /// **'Desligar valores e cobrança?'**
  String get valuesAndBillingOffTitle;

  /// No description provided for @valuesAndBillingOffMessage.
  ///
  /// In pt, this message translates to:
  /// **'Preços, total, receber e a aba Financeiro somem para toda a equipe. Nada é apagado: os valores voltam se você religar. Links de pagamento já enviados continuam valendo.'**
  String get valuesAndBillingOffMessage;

  /// No description provided for @valuesAndBillingOffAction.
  ///
  /// In pt, this message translates to:
  /// **'Desligar'**
  String get valuesAndBillingOffAction;

  /// No description provided for @valuesAndBillingSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para salvar. Confira a internet e tente de novo.'**
  String get valuesAndBillingSaveError;

  /// No description provided for @joinWithInviteCode.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com código de convite'**
  String get joinWithInviteCode;

  /// No description provided for @followsPhoneSettings.
  ///
  /// In pt, this message translates to:
  /// **'O idioma e a aparência seguem o ajuste do iPhone.'**
  String get followsPhoneSettings;

  /// No description provided for @invitePerson.
  ///
  /// In pt, this message translates to:
  /// **'Convidar pessoa'**
  String get invitePerson;

  /// No description provided for @inviteWhoLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome (opcional)'**
  String get inviteWhoLabel;

  /// No description provided for @inviteWhoPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Lucas Silva'**
  String get inviteWhoPlaceholder;

  /// No description provided for @inviteEmailLabel.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get inviteEmailLabel;

  /// No description provided for @inviteEmailHint.
  ///
  /// In pt, this message translates to:
  /// **'A pessoa entra com este e-mail e o convite aparece sozinho.'**
  String get inviteEmailHint;

  /// No description provided for @inviteWhatsAppLabel.
  ///
  /// In pt, this message translates to:
  /// **'WhatsApp (opcional)'**
  String get inviteWhatsAppLabel;

  /// No description provided for @inviteRoleLabel.
  ///
  /// In pt, this message translates to:
  /// **'O que pode fazer'**
  String get inviteRoleLabel;

  /// No description provided for @inviteRoleQuestion.
  ///
  /// In pt, this message translates to:
  /// **'O que pode fazer?'**
  String get inviteRoleQuestion;

  /// No description provided for @createInvite.
  ///
  /// In pt, this message translates to:
  /// **'Criar convite'**
  String get createInvite;

  /// No description provided for @cancelAndInviteAgain.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar e convidar de novo'**
  String get cancelAndInviteAgain;

  /// No description provided for @inviteExpiredMessage.
  ///
  /// In pt, this message translates to:
  /// **'Este convite venceu. Cancele e convide de novo.'**
  String get inviteExpiredMessage;

  /// No description provided for @userWillReceiveInviteByWhatsAppHint.
  ///
  /// In pt, this message translates to:
  /// **'Depois você manda o código por esse número ou por outro app.'**
  String get userWillReceiveInviteByWhatsAppHint;

  /// No description provided for @financialLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar o financeiro.'**
  String get financialLoadError;

  /// No description provided for @financialEmptyMonth.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma OS em {month}.'**
  String financialEmptyMonth(String month);

  /// No description provided for @financialToReceive.
  ///
  /// In pt, this message translates to:
  /// **'Falta receber'**
  String get financialToReceive;

  /// No description provided for @financialOrderSince.
  ///
  /// In pt, this message translates to:
  /// **'OS {number} · desde {date}'**
  String financialOrderSince(int number, String date);

  /// No description provided for @financialOrdersSince.
  ///
  /// In pt, this message translates to:
  /// **'{count} OS · desde {date}'**
  String financialOrdersSince(int count, String date);

  /// No description provided for @financialOtherPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Outro período'**
  String get financialOtherPeriod;

  /// No description provided for @financialPreviousMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês anterior'**
  String get financialPreviousMonth;

  /// No description provided for @financialNextMonth.
  ///
  /// In pt, this message translates to:
  /// **'Próximo mês'**
  String get financialNextMonth;

  /// No description provided for @financialNextStep.
  ///
  /// In pt, this message translates to:
  /// **'Falta receber {amount} de {count, plural, =1{1 cliente} other{{count} clientes}}'**
  String financialNextStep(String amount, int count);

  /// No description provided for @financialOldestDebt.
  ///
  /// In pt, this message translates to:
  /// **'{name} deve há mais tempo: {amount} desde {date}.'**
  String financialOldestDebt(String name, String amount, String date);

  /// No description provided for @financialSendChargeTo.
  ///
  /// In pt, this message translates to:
  /// **'Mandar cobrança para {name}'**
  String financialSendChargeTo(String name);

  /// No description provided for @financialPickOrderTitle.
  ///
  /// In pt, this message translates to:
  /// **'OS em aberto de {name}'**
  String financialPickOrderTitle(String name);

  /// No description provided for @financialOrderOption.
  ///
  /// In pt, this message translates to:
  /// **'OS {number} · {amount} · desde {date}'**
  String financialOrderOption(int number, String amount, String date);

  /// No description provided for @receiveTitle.
  ///
  /// In pt, this message translates to:
  /// **'Receber'**
  String get receiveTitle;

  /// No description provided for @receiveMissing.
  ///
  /// In pt, this message translates to:
  /// **'Falta receber'**
  String get receiveMissing;

  /// No description provided for @receiveAllDone.
  ///
  /// In pt, this message translates to:
  /// **'Tudo recebido'**
  String get receiveAllDone;

  /// No description provided for @receiveButton.
  ///
  /// In pt, this message translates to:
  /// **'Recebi {amount}'**
  String receiveButton(String amount);

  /// No description provided for @receiveAttachReceipt.
  ///
  /// In pt, this message translates to:
  /// **'Anexar comprovante'**
  String get receiveAttachReceipt;

  /// No description provided for @receiveAlreadyReceived.
  ///
  /// In pt, this message translates to:
  /// **'Já recebido'**
  String get receiveAlreadyReceived;

  /// No description provided for @receiveWithReceipt.
  ///
  /// In pt, this message translates to:
  /// **'com comprovante'**
  String get receiveWithReceipt;

  /// No description provided for @receiveNoReceipt.
  ///
  /// In pt, this message translates to:
  /// **'sem comprovante'**
  String get receiveNoReceipt;

  /// No description provided for @receiveViaPix.
  ///
  /// In pt, this message translates to:
  /// **'Pix pelo link'**
  String get receiveViaPix;

  /// No description provided for @receiveViaBoleto.
  ///
  /// In pt, this message translates to:
  /// **'Boleto pelo link'**
  String get receiveViaBoleto;

  /// No description provided for @receiveViaCard.
  ///
  /// In pt, this message translates to:
  /// **'Cartão pelo link'**
  String get receiveViaCard;

  /// No description provided for @receiveViaLink.
  ///
  /// In pt, this message translates to:
  /// **'Pelo link'**
  String get receiveViaLink;

  /// No description provided for @receiveGiveDiscount.
  ///
  /// In pt, this message translates to:
  /// **'Dar desconto'**
  String get receiveGiveDiscount;

  /// No description provided for @receiveUndoPayments.
  ///
  /// In pt, this message translates to:
  /// **'Desfazer pagamentos'**
  String get receiveUndoPayments;

  /// No description provided for @receiveDiscountNewTotal.
  ///
  /// In pt, this message translates to:
  /// **'O total passa de {from} para {to}'**
  String receiveDiscountNewTotal(String from, String to);

  /// No description provided for @receiveViewReceipt.
  ///
  /// In pt, this message translates to:
  /// **'Ver comprovante'**
  String get receiveViewReceipt;

  /// No description provided for @receiveRemovePayment.
  ///
  /// In pt, this message translates to:
  /// **'Remover este pagamento'**
  String get receiveRemovePayment;

  /// No description provided for @receiveRecordedBy.
  ///
  /// In pt, this message translates to:
  /// **'Anotado por {name} em {date}'**
  String receiveRecordedBy(String name, String date);

  /// No description provided for @receiveRecordedAuto.
  ///
  /// In pt, this message translates to:
  /// **'O app anotou sozinho em {date}'**
  String receiveRecordedAuto(String date);

  /// No description provided for @receiveMoreOptions.
  ///
  /// In pt, this message translates to:
  /// **'Mais opções'**
  String get receiveMoreOptions;

  /// No description provided for @receiveRemoveReceipt.
  ///
  /// In pt, this message translates to:
  /// **'Tirar comprovante'**
  String get receiveRemoveReceipt;

  /// No description provided for @loginTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entre para começar'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Suas OS ficam salvas e a equipe vê as mesmas.'**
  String get loginSubtitle;

  /// No description provided for @loginWithEmailLink.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com e-mail e senha'**
  String get loginWithEmailLink;

  /// No description provided for @errorSignInAppleFriendly.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para entrar com a Apple. Tente de novo.'**
  String get errorSignInAppleFriendly;

  /// No description provided for @errorSignInGoogleFriendly.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para entrar com o Google. Tente de novo.'**
  String get errorSignInGoogleFriendly;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Esqueceu a senha?'**
  String get forgotPasswordQuestion;

  /// No description provided for @showPassword.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar senha'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In pt, this message translates to:
  /// **'Ocultar senha'**
  String get hidePassword;

  /// No description provided for @onboardingSegmentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu ramo'**
  String get onboardingSegmentTitle;

  /// No description provided for @onboardingInviteCode.
  ///
  /// In pt, this message translates to:
  /// **'Recebi um código de convite'**
  String get onboardingInviteCode;

  /// No description provided for @onboardingSegmentsError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar os ramos. Confira a internet.'**
  String get onboardingSegmentsError;

  /// No description provided for @onboardingSpecialtiesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Especialidades'**
  String get onboardingSpecialtiesTitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get onboardingContinue;

  /// No description provided for @onboardingBusinessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu negócio'**
  String get onboardingBusinessTitle;

  /// No description provided for @onboardingBusinessName.
  ///
  /// In pt, this message translates to:
  /// **'Como se chama o seu negócio?'**
  String get onboardingBusinessName;

  /// No description provided for @onboardingBusinessNamePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Oficina do Zé'**
  String get onboardingBusinessNamePlaceholder;

  /// No description provided for @onboardingBusinessNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Diga o nome do seu negócio.'**
  String get onboardingBusinessNameRequired;

  /// No description provided for @onboardingPhoneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Telefone (opcional)'**
  String get onboardingPhoneLabel;

  /// No description provided for @onboardingPhoneHint.
  ///
  /// In pt, this message translates to:
  /// **'Aparece no orçamento que o cliente recebe.'**
  String get onboardingPhoneHint;

  /// No description provided for @onboardingSamplesInfo.
  ///
  /// In pt, this message translates to:
  /// **'Vamos colocar umas OS de exemplo para você ver como fica. Você apaga quando quiser.'**
  String get onboardingSamplesInfo;

  /// No description provided for @onboardingCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar meu PraticOS'**
  String get onboardingCreate;

  /// No description provided for @onboardingStartWithoutSamples.
  ///
  /// In pt, this message translates to:
  /// **'Começar sem exemplos'**
  String get onboardingStartWithoutSamples;

  /// No description provided for @onboardingPreparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando seu PraticOS…'**
  String get onboardingPreparing;

  /// No description provided for @onboardingCreateError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para terminar. Confira a internet e tente de novo.'**
  String get onboardingCreateError;

  /// No description provided for @receivedWhichOrder.
  ///
  /// In pt, this message translates to:
  /// **'Em qual OS?'**
  String get receivedWhichOrder;

  /// No description provided for @receivedPhotosCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 foto} other{{count} fotos}}'**
  String receivedPhotosCount(int count);

  /// No description provided for @receivedPdfsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 PDF} other{{count} PDFs}}'**
  String receivedPdfsCount(int count);

  /// No description provided for @receivedSummaryBoth.
  ///
  /// In pt, this message translates to:
  /// **'{photos} e {pdfs}'**
  String receivedSummaryBoth(String photos, String pdfs);

  /// No description provided for @receivedSavedInOrder.
  ///
  /// In pt, this message translates to:
  /// **'Guardado na OS {number} · {summary}'**
  String receivedSavedInOrder(String number, String summary);

  /// No description provided for @receivedSaveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para guardar. Tente de novo.'**
  String get receivedSaveFailed;

  /// No description provided for @receivedOpenOrder.
  ///
  /// In pt, this message translates to:
  /// **'Abrir a OS'**
  String get receivedOpenOrder;

  /// No description provided for @inviteGenericError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para concluir. Confira a internet e tente de novo.'**
  String get inviteGenericError;

  /// No description provided for @inviteLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para carregar os convites. Confira a internet.'**
  String get inviteLoadError;

  /// No description provided for @inviteTitleOne.
  ///
  /// In pt, this message translates to:
  /// **'{company} chamou você para a equipe'**
  String inviteTitleOne(String company);

  /// No description provided for @inviteInvitedByAs.
  ///
  /// In pt, this message translates to:
  /// **'Convidado por {name} · você entra como {role}'**
  String inviteInvitedByAs(String name, String role);

  /// No description provided for @inviteEntersAs.
  ///
  /// In pt, this message translates to:
  /// **'Você entra como {role}'**
  String inviteEntersAs(String role);

  /// No description provided for @inviteJoinTeam.
  ///
  /// In pt, this message translates to:
  /// **'Entrar na equipe'**
  String get inviteJoinTeam;

  /// No description provided for @inviteDecline.
  ///
  /// In pt, this message translates to:
  /// **'Recusar convite'**
  String get inviteDecline;

  /// No description provided for @inviteHaveAnotherCode.
  ///
  /// In pt, this message translates to:
  /// **'Tenho outro código'**
  String get inviteHaveAnotherCode;

  /// No description provided for @inviteCreateOwnCompany.
  ///
  /// In pt, this message translates to:
  /// **'Criar minha própria empresa'**
  String get inviteCreateOwnCompany;

  /// No description provided for @inviteCodePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: 7K2P9QXA'**
  String get inviteCodePlaceholder;

  /// No description provided for @segmentLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para abrir a sua empresa. Confira a internet e tente de novo.'**
  String get segmentLoadError;

  /// No description provided for @orderAssistantAddPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Tirar outra foto'**
  String get orderAssistantAddPhoto;

  /// No description provided for @orderAssistantTakePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Tirar foto'**
  String get orderAssistantTakePhoto;

  /// No description provided for @orderAssistantCustomerGuess.
  ///
  /// In pt, this message translates to:
  /// **'Ouvi “{name}”. Toque para escolher o cliente'**
  String orderAssistantCustomerGuess(String name);

  /// No description provided for @orderAssistantDeviceGuess.
  ///
  /// In pt, this message translates to:
  /// **'“{device}” não está no cadastro'**
  String orderAssistantDeviceGuess(String device);

  /// No description provided for @orderAssistantErrorDisabled.
  ///
  /// In pt, this message translates to:
  /// **'O assistente ainda não está liberado para a sua empresa.'**
  String get orderAssistantErrorDisabled;

  /// No description provided for @orderAssistantErrorQuota.
  ///
  /// In pt, this message translates to:
  /// **'Você já usou os {limit} pedidos do assistente deste mês. Dá para continuar preenchendo à mão.'**
  String orderAssistantErrorQuota(String limit);

  /// No description provided for @orderAssistantErrorUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para ler agora. Tente de novo ou preencha à mão.'**
  String get orderAssistantErrorUnavailable;

  /// No description provided for @orderAssistantNothingFound.
  ///
  /// In pt, this message translates to:
  /// **'Não achei o que pôr. Tente de novo ou preencha à mão.'**
  String get orderAssistantNothingFound;

  /// No description provided for @reportPreviousPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Período anterior'**
  String get reportPreviousPeriod;

  /// No description provided for @reportNextPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Próximo período'**
  String get reportNextPeriod;

  /// No description provided for @orderAddChecklist.
  ///
  /// In pt, this message translates to:
  /// **'Checklist'**
  String get orderAddChecklist;

  /// No description provided for @orderAddMedia.
  ///
  /// In pt, this message translates to:
  /// **'Fotos ou documento'**
  String get orderAddMedia;

  /// No description provided for @orderAddComment.
  ///
  /// In pt, this message translates to:
  /// **'Comentário'**
  String get orderAddComment;

  /// No description provided for @orderAddAddress.
  ///
  /// In pt, this message translates to:
  /// **'Endereço do atendimento'**
  String get orderAddAddress;

  /// No description provided for @orderAddSchedule.
  ///
  /// In pt, this message translates to:
  /// **'Agendar dia e hora'**
  String get orderAddSchedule;

  /// No description provided for @orderAddDiscount.
  ///
  /// In pt, this message translates to:
  /// **'Desconto'**
  String get orderAddDiscount;

  /// No description provided for @orderChecklistMissing.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Falta 1 pergunta} other{Faltam {count} perguntas}}'**
  String orderChecklistMissing(int count);

  /// No description provided for @orderAddressChange.
  ///
  /// In pt, this message translates to:
  /// **'Mudar endereço'**
  String get orderAddressChange;

  /// No description provided for @orderAddressRemove.
  ///
  /// In pt, this message translates to:
  /// **'Tirar endereço'**
  String get orderAddressRemove;

  /// No description provided for @orderScheduleRemove.
  ///
  /// In pt, this message translates to:
  /// **'Tirar agendamento'**
  String get orderScheduleRemove;

  /// No description provided for @orderContractSummary.
  ///
  /// In pt, this message translates to:
  /// **'{frequency} · próxima em {date}'**
  String orderContractSummary(String frequency, String date);

  /// No description provided for @orderUploading.
  ///
  /// In pt, this message translates to:
  /// **'Enviando…'**
  String get orderUploading;

  /// No description provided for @otherDevicesSection.
  ///
  /// In pt, this message translates to:
  /// **'Outros {devices}'**
  String otherDevicesSection(String devices);

  /// No description provided for @accumulatedDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Apagar “{value}”?'**
  String accumulatedDeleteConfirm(String value);

  /// No description provided for @accumulatedUse.
  ///
  /// In pt, this message translates to:
  /// **'Usar “{value}”'**
  String accumulatedUse(String value);

  /// No description provided for @accumulatedLeaveBlank.
  ///
  /// In pt, this message translates to:
  /// **'Deixar em branco'**
  String get accumulatedLeaveBlank;

  /// No description provided for @moreSectionCompany.
  ///
  /// In pt, this message translates to:
  /// **'Empresa'**
  String get moreSectionCompany;

  /// No description provided for @moreSectionRecords.
  ///
  /// In pt, this message translates to:
  /// **'Cadastros'**
  String get moreSectionRecords;

  /// No description provided for @moreSectionYou.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get moreSectionYou;

  /// No description provided for @moreCompanySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Dados na OS, ramo e recursos'**
  String get moreCompanySubtitle;

  /// No description provided for @moreCatalogSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Serviços e {products}'**
  String moreCatalogSubtitle(String products);

  /// No description provided for @planHeaderRenews.
  ///
  /// In pt, this message translates to:
  /// **'{plan} · renova em {date}'**
  String planHeaderRenews(String plan, String date);

  /// No description provided for @planHeaderValidUntil.
  ///
  /// In pt, this message translates to:
  /// **'{plan} · válido até {date}'**
  String planHeaderValidUntil(String plan, String date);

  /// No description provided for @planHeaderCourtesy.
  ///
  /// In pt, this message translates to:
  /// **'{plan} · cortesia até {date}'**
  String planHeaderCourtesy(String plan, String date);

  /// No description provided for @planHeaderPaymentIssue.
  ///
  /// In pt, this message translates to:
  /// **'{plan} · problema no pagamento'**
  String planHeaderPaymentIssue(String plan);

  /// No description provided for @planLimitLabel.
  ///
  /// In pt, this message translates to:
  /// **'Limite do plano'**
  String get planLimitLabel;

  /// No description provided for @planLimitTeam.
  ///
  /// In pt, this message translates to:
  /// **'A equipe já tem {used} de {limit} pessoas. Para chamar mais alguém, mude de plano.'**
  String planLimitTeam(String used, String limit);

  /// No description provided for @planLimitPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Já foram {used} de {limit} fotos este mês. Para tirar mais, mude de plano.'**
  String planLimitPhotos(String used, String limit);

  /// No description provided for @planLimitChecklists.
  ///
  /// In pt, this message translates to:
  /// **'Você já tem {used} de {limit} checklists. Para criar outro, mude de plano.'**
  String planLimitChecklists(String used, String limit);

  /// No description provided for @planUsageSection.
  ///
  /// In pt, this message translates to:
  /// **'O que você está usando'**
  String get planUsageSection;

  /// No description provided for @planUsageTeam.
  ///
  /// In pt, this message translates to:
  /// **'Pessoas na equipe'**
  String get planUsageTeam;

  /// No description provided for @planUsagePhotos.
  ///
  /// In pt, this message translates to:
  /// **'Fotos este mês'**
  String get planUsagePhotos;

  /// No description provided for @planUsageChecklists.
  ///
  /// In pt, this message translates to:
  /// **'Checklists'**
  String get planUsageChecklists;

  /// No description provided for @planUsageOf.
  ///
  /// In pt, this message translates to:
  /// **'{used} de {limit}'**
  String planUsageOf(String used, String limit);

  /// No description provided for @planUsageAtLimit.
  ///
  /// In pt, this message translates to:
  /// **'No limite'**
  String get planUsageAtLimit;

  /// No description provided for @planUsageAtLimitInvites.
  ///
  /// In pt, this message translates to:
  /// **'No limite · conta o convite'**
  String get planUsageAtLimitInvites;

  /// No description provided for @planUsageNearLimit.
  ///
  /// In pt, this message translates to:
  /// **'Quase no limite'**
  String get planUsageNearLimit;

  /// No description provided for @planUsageUnlimited.
  ///
  /// In pt, this message translates to:
  /// **'Sem limite'**
  String get planUsageUnlimited;

  /// No description provided for @companyShownOnOrder.
  ///
  /// In pt, this message translates to:
  /// **'Aparece na OS do cliente'**
  String get companyShownOnOrder;

  /// No description provided for @companyNameLogoContact.
  ///
  /// In pt, this message translates to:
  /// **'Nome, logo e contato'**
  String get companyNameLogoContact;

  /// No description provided for @customerTerms.
  ///
  /// In pt, this message translates to:
  /// **'Termos para o cliente'**
  String get customerTerms;

  /// No description provided for @customerTermsHint.
  ///
  /// In pt, this message translates to:
  /// **'Garantia e condições'**
  String get customerTermsHint;

  /// No description provided for @segmentRow.
  ///
  /// In pt, this message translates to:
  /// **'Ramo'**
  String get segmentRow;

  /// No description provided for @segmentRowHint.
  ///
  /// In pt, this message translates to:
  /// **'Muda serviços e checklists prontos'**
  String get segmentRowHint;

  /// No description provided for @moreCompanyData.
  ///
  /// In pt, this message translates to:
  /// **'Mais dados (e-mail, site, país)'**
  String get moreCompanyData;

  /// No description provided for @addLogo.
  ///
  /// In pt, this message translates to:
  /// **'Pôr logo'**
  String get addLogo;

  /// No description provided for @changeLogoLink.
  ///
  /// In pt, this message translates to:
  /// **'Trocar logo'**
  String get changeLogoLink;

  /// No description provided for @pickSegmentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual é o seu ramo?'**
  String get pickSegmentTitle;

  /// No description provided for @pickSpecialtiesTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que você atende?'**
  String get pickSpecialtiesTitle;

  /// No description provided for @specialtiesNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma marcada'**
  String get specialtiesNone;

  /// No description provided for @pickCountryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual é o país?'**
  String get pickCountryTitle;

  /// No description provided for @companyNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o nome da empresa'**
  String get companyNameRequired;

  /// No description provided for @schedulingRow.
  ///
  /// In pt, this message translates to:
  /// **'Agenda'**
  String get schedulingRow;

  /// No description provided for @schedulingRowHint.
  ///
  /// In pt, this message translates to:
  /// **'Marcar dia e hora das OS'**
  String get schedulingRowHint;

  /// No description provided for @fieldServiceRow.
  ///
  /// In pt, this message translates to:
  /// **'Atendimento no local do cliente'**
  String get fieldServiceRow;

  /// No description provided for @fieldServiceRowHint.
  ///
  /// In pt, this message translates to:
  /// **'Endereço do cliente na OS'**
  String get fieldServiceRowHint;

  /// No description provided for @contractsRowHint.
  ///
  /// In pt, this message translates to:
  /// **'OS que se repetem sozinhas'**
  String get contractsRowHint;

  /// No description provided for @deviceControlRow.
  ///
  /// In pt, this message translates to:
  /// **'Controle de {devices}'**
  String deviceControlRow(String devices);

  /// No description provided for @deviceControlRowHint.
  ///
  /// In pt, this message translates to:
  /// **'Histórico e lista completa'**
  String get deviceControlRowHint;

  /// No description provided for @companySettingSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para salvar. Confira a internet e tente de novo.'**
  String get companySettingSaveError;

  /// No description provided for @customerSpentValue.
  ///
  /// In pt, this message translates to:
  /// **'gastou {value}'**
  String customerSpentValue(String value);

  /// No description provided for @customerOwesValue.
  ///
  /// In pt, this message translates to:
  /// **'Falta receber {value}'**
  String customerOwesValue(String value);

  /// No description provided for @askOrderForCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Abrir uma OS para {name}?'**
  String askOrderForCustomer(String name);

  /// No description provided for @askOrderForDevice.
  ///
  /// In pt, this message translates to:
  /// **'Abrir uma OS para este {device}?'**
  String askOrderForDevice(String device);

  /// No description provided for @addAnotherDevice.
  ///
  /// In pt, this message translates to:
  /// **'Cadastrar outro {device}'**
  String addAnotherDevice(String device);

  /// No description provided for @latestOrders.
  ///
  /// In pt, this message translates to:
  /// **'Últimas OS'**
  String get latestOrders;

  /// No description provided for @ordersOfDevice.
  ///
  /// In pt, this message translates to:
  /// **'OS deste {device}'**
  String ordersOfDevice(String device);

  /// No description provided for @orderCountShort.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 OS} other{{count} OS}}'**
  String orderCountShort(int count);

  /// No description provided for @deviceOwnerPrefix.
  ///
  /// In pt, this message translates to:
  /// **'da '**
  String get deviceOwnerPrefix;

  /// No description provided for @financialReportShort.
  ///
  /// In pt, this message translates to:
  /// **'Relatório'**
  String get financialReportShort;

  /// No description provided for @financialReceivedIn.
  ///
  /// In pt, this message translates to:
  /// **'Recebido em {month}'**
  String financialReceivedIn(String month);

  /// No description provided for @financialReceivedSub.
  ///
  /// In pt, this message translates to:
  /// **'{count} OS · ver todas'**
  String financialReceivedSub(int count);

  /// No description provided for @financialSendReportPdf.
  ///
  /// In pt, this message translates to:
  /// **'Mandar relatório em PDF'**
  String get financialSendReportPdf;

  /// No description provided for @receiveSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'{customer} · total {total}'**
  String receiveSubtitle(String customer, String total);

  /// No description provided for @receiveSubtitleNoCustomer.
  ///
  /// In pt, this message translates to:
  /// **'total {total}'**
  String receiveSubtitleNoCustomer(String total);

  /// No description provided for @receiveOrderLink.
  ///
  /// In pt, this message translates to:
  /// **'OS {number}'**
  String receiveOrderLink(int number);

  /// No description provided for @receiveAmountHint.
  ///
  /// In pt, this message translates to:
  /// **'Recebeu só uma parte? Mude o valor.'**
  String get receiveAmountHint;

  /// No description provided for @orderAddContractMonthly.
  ///
  /// In pt, this message translates to:
  /// **'Repetir todo mês (contrato)'**
  String get orderAddContractMonthly;

  /// No description provided for @ratingsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'O que os clientes acharam'**
  String get ratingsSubtitle;

  /// No description provided for @ratingsLatest.
  ///
  /// In pt, this message translates to:
  /// **'Últimas'**
  String get ratingsLatest;

  /// No description provided for @ratingScoreOf.
  ///
  /// In pt, this message translates to:
  /// **'{score} de 5'**
  String ratingScoreOf(String score);

  /// No description provided for @ratingsAverageOf.
  ///
  /// In pt, this message translates to:
  /// **'média de {count} {count, plural, =1{avaliação} other{avaliações}}'**
  String ratingsAverageOf(int count);

  /// No description provided for @ratingCommentOrder.
  ///
  /// In pt, this message translates to:
  /// **'“{comment}” · OS {number}'**
  String ratingCommentOrder(String comment, int number);

  /// No description provided for @ratingNoCommentOrder.
  ///
  /// In pt, this message translates to:
  /// **'Sem comentário · OS {number}'**
  String ratingNoCommentOrder(int number);

  /// No description provided for @remindersSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Valem só neste celular'**
  String get remindersSubtitle;

  /// No description provided for @reminderBeforeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Antes do horário marcado'**
  String get reminderBeforeTitle;

  /// No description provided for @reminderDailyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resumo do dia às 9h'**
  String get reminderDailyTitle;

  /// No description provided for @reminderDailySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'O que tem para hoje'**
  String get reminderDailySubtitle;

  /// No description provided for @reminderPendingTitle.
  ///
  /// In pt, this message translates to:
  /// **'OS paradas'**
  String get reminderPendingTitle;

  /// No description provided for @reminderPendingSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Orçamentos sem resposta há 7 dias'**
  String get reminderPendingSubtitle;

  /// No description provided for @reminderInactivityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Se eu ficar dias sem abrir o app'**
  String get reminderInactivityTitle;

  /// No description provided for @reminderMinutesValue.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min'**
  String reminderMinutesValue(int minutes);

  /// No description provided for @reminderHoursValue.
  ///
  /// In pt, this message translates to:
  /// **'{hours} {hours, plural, =1{hora} other{horas}}'**
  String reminderHoursValue(int hours);

  /// No description provided for @catalogSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'O que você coloca nas OS'**
  String get catalogSubtitle;

  /// No description provided for @catalogKindWithCount.
  ///
  /// In pt, this message translates to:
  /// **'{kind} ({count})'**
  String catalogKindWithCount(String kind, int count);

  /// No description provided for @catalogTip.
  ///
  /// In pt, this message translates to:
  /// **'Dica: dá para cadastrar direto na OS, digitando o nome na busca.'**
  String get catalogTip;

  /// No description provided for @teamTitle.
  ///
  /// In pt, this message translates to:
  /// **'Equipe'**
  String get teamTitle;

  /// No description provided for @teamSummary.
  ///
  /// In pt, this message translates to:
  /// **'{people} e {invites}'**
  String teamSummary(String people, String invites);

  /// No description provided for @teamPeopleCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 pessoa} other{{count} pessoas}}'**
  String teamPeopleCount(int count);

  /// No description provided for @teamInvitesCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 convite} other{{count} convites}}'**
  String teamInvitesCount(int count);

  /// No description provided for @teamInviteWaitingLabel.
  ///
  /// In pt, this message translates to:
  /// **'Convite esperando'**
  String get teamInviteWaitingLabel;

  /// No description provided for @teamInviteWaitingText.
  ///
  /// In pt, this message translates to:
  /// **'{name} ainda não entrou. {expiry}'**
  String teamInviteWaitingText(String name, String expiry);

  /// No description provided for @teamInviteExpiresInDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{O convite vence em 1 dia.} other{O convite vence em {count} dias.}}'**
  String teamInviteExpiresInDays(int count);

  /// No description provided for @teamInviteExpiresToday.
  ///
  /// In pt, this message translates to:
  /// **'O convite vence hoje.'**
  String get teamInviteExpiresToday;

  /// No description provided for @teamInviteExpired.
  ///
  /// In pt, this message translates to:
  /// **'O convite venceu.'**
  String get teamInviteExpired;

  /// No description provided for @teamResendInvite.
  ///
  /// In pt, this message translates to:
  /// **'Reenviar convite'**
  String get teamResendInvite;

  /// No description provided for @teamWaitingSection.
  ///
  /// In pt, this message translates to:
  /// **'Esperando entrar'**
  String get teamWaitingSection;

  /// No description provided for @teamMembersSection.
  ///
  /// In pt, this message translates to:
  /// **'Na equipe'**
  String get teamMembersSection;

  /// No description provided for @teamInviteSent.
  ///
  /// In pt, this message translates to:
  /// **'Convite enviado · {expiry}'**
  String teamInviteSent(String expiry);

  /// No description provided for @teamInviteDueInDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{vence em 1 dia} other{vence em {count} dias}}'**
  String teamInviteDueInDays(int count);

  /// No description provided for @teamInviteDueToday.
  ///
  /// In pt, this message translates to:
  /// **'vence hoje'**
  String get teamInviteDueToday;

  /// No description provided for @teamInviteDueExpired.
  ///
  /// In pt, this message translates to:
  /// **'venceu'**
  String get teamInviteDueExpired;

  /// No description provided for @teamYou.
  ///
  /// In pt, this message translates to:
  /// **'{name} (você)'**
  String teamYou(String name);

  /// No description provided for @teamInviteAnother.
  ///
  /// In pt, this message translates to:
  /// **'Convidar outra pessoa'**
  String get teamInviteAnother;

  /// No description provided for @teamInviteFirst.
  ///
  /// In pt, this message translates to:
  /// **'Convidar uma pessoa'**
  String get teamInviteFirst;

  /// No description provided for @roleShortAdmin.
  ///
  /// In pt, this message translates to:
  /// **'vê e muda tudo'**
  String get roleShortAdmin;

  /// No description provided for @roleShortSupervisor.
  ///
  /// In pt, this message translates to:
  /// **'coordena a equipe, não vê preços'**
  String get roleShortSupervisor;

  /// No description provided for @roleShortManager.
  ///
  /// In pt, this message translates to:
  /// **'vê faturamento e custos'**
  String get roleShortManager;

  /// No description provided for @roleShortConsultant.
  ///
  /// In pt, this message translates to:
  /// **'faz orçamentos, vê só as suas OS'**
  String get roleShortConsultant;

  /// No description provided for @roleShortTechnician.
  ///
  /// In pt, this message translates to:
  /// **'faz os serviços, não vê preços'**
  String get roleShortTechnician;

  /// No description provided for @checklistsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Checklists'**
  String get checklistsTitle;

  /// No description provided for @checklistsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Perguntas que o técnico responde na OS'**
  String get checklistsSubtitle;

  /// No description provided for @checklistsYours.
  ///
  /// In pt, this message translates to:
  /// **'Seus checklists'**
  String get checklistsYours;

  /// No description provided for @checklistsReady.
  ///
  /// In pt, this message translates to:
  /// **'Prontos para usar'**
  String get checklistsReady;

  /// No description provided for @checklistQuestions.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 pergunta} other{{count} perguntas}}'**
  String checklistQuestions(int count);

  /// No description provided for @checklistWithPhotos.
  ///
  /// In pt, this message translates to:
  /// **'com fotos'**
  String get checklistWithPhotos;

  /// No description provided for @checklistOff.
  ///
  /// In pt, this message translates to:
  /// **'Desligado'**
  String get checklistOff;

  /// No description provided for @checklistUse.
  ///
  /// In pt, this message translates to:
  /// **'Usar'**
  String get checklistUse;

  /// No description provided for @checklistNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo checklist'**
  String get checklistNew;

  /// No description provided for @checklistsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum checklist ainda. Crie um ou use um pronto.'**
  String get checklistsEmpty;

  /// No description provided for @noticesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Avisos'**
  String get noticesTitle;

  /// No description provided for @noticesNewCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 novo} other{{count} novos}}'**
  String noticesNewCount(int count);

  /// No description provided for @noticesMarkAllRead.
  ///
  /// In pt, this message translates to:
  /// **'Marcar todos como lidos'**
  String get noticesMarkAllRead;

  /// No description provided for @noticesSectionNew.
  ///
  /// In pt, this message translates to:
  /// **'Novos'**
  String get noticesSectionNew;

  /// No description provided for @noticesSectionBefore.
  ///
  /// In pt, this message translates to:
  /// **'Antes'**
  String get noticesSectionBefore;

  /// No description provided for @noticesEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum aviso por enquanto.'**
  String get noticesEmpty;

  /// No description provided for @timeAgoNow.
  ///
  /// In pt, this message translates to:
  /// **'agora'**
  String get timeAgoNow;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{há 1 minuto} other{há {count} minutos}}'**
  String timeAgoMinutes(int count);

  /// No description provided for @timeAgoHours.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{há 1 hora} other{há {count} horas}}'**
  String timeAgoHours(int count);

  /// No description provided for @timeAgoDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{há 1 dia} other{há {count} dias}}'**
  String timeAgoDays(int count);

  /// No description provided for @contractsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'{order} que se repetem sozinhas'**
  String contractsSubtitle(String order);

  /// No description provided for @contractsTabActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativos'**
  String get contractsTabActive;

  /// No description provided for @contractsTabEnded.
  ///
  /// In pt, this message translates to:
  /// **'Encerrados'**
  String get contractsTabEnded;

  /// No description provided for @contractEveryDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Todo dia} other{A cada {count} dias}}'**
  String contractEveryDays(int count);

  /// No description provided for @contractEveryWeeks.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Toda semana} other{A cada {count} semanas}}'**
  String contractEveryWeeks(int count);

  /// No description provided for @contractEveryMonths.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Todo mês} other{A cada {count} meses}}'**
  String contractEveryMonths(int count);

  /// No description provided for @contractEveryYears.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{Todo ano} other{A cada {count} anos}}'**
  String contractEveryYears(int count);

  /// No description provided for @contractNextOrderOn.
  ///
  /// In pt, this message translates to:
  /// **'Próxima {order} em {date}'**
  String contractNextOrderOn(String date, String order);

  /// No description provided for @contractEndedOn.
  ///
  /// In pt, this message translates to:
  /// **'Encerrado em {date}'**
  String contractEndedOn(String date);

  /// No description provided for @contractEnded.
  ///
  /// In pt, this message translates to:
  /// **'Encerrado'**
  String get contractEnded;

  /// No description provided for @contractsEmptyEnded.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum contrato encerrado.'**
  String get contractsEmptyEnded;

  /// No description provided for @contractsFooterHint.
  ///
  /// In pt, this message translates to:
  /// **'Contratos nascem dentro de uma {order}: ligue “Repetir esta {order}”.'**
  String contractsFooterHint(String order);

  /// No description provided for @orderAddResponsible.
  ///
  /// In pt, this message translates to:
  /// **'Responsável'**
  String get orderAddResponsible;

  /// No description provided for @orderResponsibleRemove.
  ///
  /// In pt, this message translates to:
  /// **'Tirar responsável'**
  String get orderResponsibleRemove;

  /// No description provided for @filterDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluídas'**
  String get filterDone;

  /// No description provided for @homeLateCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 atrasada} other{{count} atrasadas}}'**
  String homeLateCount(int count);

  /// No description provided for @homeSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar OS ou cliente'**
  String get homeSearchHint;

  /// No description provided for @homeSearchHintDevice.
  ///
  /// In pt, this message translates to:
  /// **'Buscar OS, cliente ou {device}'**
  String homeSearchHintDevice(String device);

  /// No description provided for @remainingToReceive.
  ///
  /// In pt, this message translates to:
  /// **'falta receber {amount}'**
  String remainingToReceive(String amount);

  /// No description provided for @firstOrderTapPlus.
  ///
  /// In pt, this message translates to:
  /// **'Toque no + para criar sua primeira OS. Leva menos de um minuto.'**
  String get firstOrderTapPlus;

  /// No description provided for @profileButtonA11y.
  ///
  /// In pt, this message translates to:
  /// **'{company}: clientes, catálogo, equipe e ajustes'**
  String profileButtonA11y(String company);

  /// No description provided for @orderAssistantPhoto.
  ///
  /// In pt, this message translates to:
  /// **'Foto'**
  String get orderAssistantPhoto;

  /// No description provided for @orderAssistantTalkShort.
  ///
  /// In pt, this message translates to:
  /// **'Falar'**
  String get orderAssistantTalkShort;

  /// No description provided for @orderCustomerRequestTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que o cliente pediu'**
  String get orderCustomerRequestTitle;

  /// No description provided for @orderCustomerRequestPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: barulho ao frear'**
  String get orderCustomerRequestPlaceholder;

  /// No description provided for @orderDeliverySection.
  ///
  /// In pt, this message translates to:
  /// **'Entrega'**
  String get orderDeliverySection;

  /// No description provided for @orderDueLabel.
  ///
  /// In pt, this message translates to:
  /// **'Fica pronto'**
  String get orderDueLabel;

  /// No description provided for @orderDueNone.
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get orderDueNone;

  /// No description provided for @orderMoreOptions.
  ///
  /// In pt, this message translates to:
  /// **'Mais opções'**
  String get orderMoreOptions;

  /// No description provided for @orderMoreOptionsHint.
  ///
  /// In pt, this message translates to:
  /// **'Situação, visita, responsável, local'**
  String get orderMoreOptionsHint;

  /// No description provided for @orderStatusLabel.
  ///
  /// In pt, this message translates to:
  /// **'Situação'**
  String get orderStatusLabel;

  /// No description provided for @orderScheduleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Visita'**
  String get orderScheduleLabel;

  /// No description provided for @orderAddressLabel.
  ///
  /// In pt, this message translates to:
  /// **'Local'**
  String get orderAddressLabel;

  /// No description provided for @speechHint.
  ///
  /// In pt, this message translates to:
  /// **'Fale o cliente, o veículo e o que vai ser feito.'**
  String get speechHint;

  /// No description provided for @speechListening.
  ///
  /// In pt, this message translates to:
  /// **'Ouvindo…'**
  String get speechListening;

  /// No description provided for @speechFill.
  ///
  /// In pt, this message translates to:
  /// **'Preencher a OS'**
  String get speechFill;

  /// No description provided for @speechUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'O microfone não está liberado. Libere em Ajustes ou digite o serviço.'**
  String get speechUnavailable;

  /// No description provided for @orderAddItemRow.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar serviço ou peça'**
  String get orderAddItemRow;

  /// No description provided for @orderPickCustomerRow.
  ///
  /// In pt, this message translates to:
  /// **'Escolher cliente'**
  String get orderPickCustomerRow;

  /// No description provided for @newOrderButton.
  ///
  /// In pt, this message translates to:
  /// **'Nova OS'**
  String get newOrderButton;

  /// No description provided for @orderAssistantFilled.
  ///
  /// In pt, this message translates to:
  /// **'Preenchi o que está marcado. Confira e salve.'**
  String get orderAssistantFilled;

  /// No description provided for @orderAssistantUndo.
  ///
  /// In pt, this message translates to:
  /// **'Desfazer'**
  String get orderAssistantUndo;

  /// No description provided for @orderAssistantReadingPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Lendo as fotos…'**
  String get orderAssistantReadingPhotos;

  /// No description provided for @orderAssistantReadingSpeech.
  ///
  /// In pt, this message translates to:
  /// **'Lendo o que você falou…'**
  String get orderAssistantReadingSpeech;

  /// No description provided for @orderAssistantMarked.
  ///
  /// In pt, this message translates to:
  /// **'Preenchido pela IA'**
  String get orderAssistantMarked;

  /// No description provided for @speechCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar fala'**
  String get speechCancel;

  /// No description provided for @speechStopAndFill.
  ///
  /// In pt, this message translates to:
  /// **'Parar e preencher a OS'**
  String get speechStopAndFill;

  /// No description provided for @speechTypeHint.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o cliente, o veículo e o que vai ser feito'**
  String get speechTypeHint;

  /// No description provided for @speechNothingHeard.
  ///
  /// In pt, this message translates to:
  /// **'Não ouvi nada. Toque em Falar e tente de novo.'**
  String get speechNothingHeard;

  /// No description provided for @orderServicesAndParts.
  ///
  /// In pt, this message translates to:
  /// **'Serviços e peças'**
  String get orderServicesAndParts;

  /// No description provided for @orderItemKindPart.
  ///
  /// In pt, this message translates to:
  /// **'peça'**
  String get orderItemKindPart;

  /// No description provided for @orderActionApproveQuote.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar orçamento'**
  String get orderActionApproveQuote;

  /// No description provided for @orderActionStartService.
  ///
  /// In pt, this message translates to:
  /// **'Começar serviço'**
  String get orderActionStartService;

  /// No description provided for @orderActionMarkReady.
  ///
  /// In pt, this message translates to:
  /// **'Marcar como pronta'**
  String get orderActionMarkReady;

  /// No description provided for @orderDuePhrase.
  ///
  /// In pt, this message translates to:
  /// **'Fica pronto {when}'**
  String orderDuePhrase(String when);

  /// No description provided for @orderDueLatePhrase.
  ///
  /// In pt, this message translates to:
  /// **'Era para ficar pronto {when}'**
  String orderDueLatePhrase(String when);

  /// No description provided for @orderDayAtTime.
  ///
  /// In pt, this message translates to:
  /// **'{day}, {time}'**
  String orderDayAtTime(String day, String time);

  /// No description provided for @orderChecklistProgress.
  ///
  /// In pt, this message translates to:
  /// **'{answered} de {total} respondidas'**
  String orderChecklistProgress(int answered, int total);

  /// No description provided for @orderCommentYou.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get orderCommentYou;

  /// No description provided for @orderMenuChangeStatus.
  ///
  /// In pt, this message translates to:
  /// **'Mudar a situação'**
  String get orderMenuChangeStatus;

  /// No description provided for @orderMenuViewPdf.
  ///
  /// In pt, this message translates to:
  /// **'Ver PDF'**
  String get orderMenuViewPdf;

  /// No description provided for @orderMenuCopyLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar link'**
  String get orderMenuCopyLink;

  /// No description provided for @orderPlaceOfService.
  ///
  /// In pt, this message translates to:
  /// **'Local do atendimento'**
  String get orderPlaceOfService;

  /// No description provided for @orderAssistantApplied.
  ///
  /// In pt, this message translates to:
  /// **'Coloquei na OS o que está marcado. Confira.'**
  String get orderAssistantApplied;

  /// No description provided for @pickerCustomerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual cliente?'**
  String get pickerCustomerTitle;

  /// No description provided for @pickerDeviceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual {device}?'**
  String pickerDeviceTitle(String device);

  /// No description provided for @pickerDeviceSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'de {name}'**
  String pickerDeviceSubtitle(String name);

  /// No description provided for @pickerItemTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que vai ser feito?'**
  String get pickerItemTitle;

  /// No description provided for @pickerChecklistTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual checklist?'**
  String get pickerChecklistTitle;

  /// No description provided for @pickerStatusTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual a situação?'**
  String get pickerStatusTitle;

  /// No description provided for @pickerAssigneeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quem é o responsável?'**
  String get pickerAssigneeTitle;

  /// No description provided for @pickerDevicesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Em quais {devices}?'**
  String pickerDevicesTitle(String devices);

  /// No description provided for @pickerNewCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Novo cliente'**
  String get pickerNewCustomer;

  /// No description provided for @pickerNewDevice.
  ///
  /// In pt, this message translates to:
  /// **'Novo {device}'**
  String pickerNewDevice(String device);

  /// No description provided for @pickerNewItem.
  ///
  /// In pt, this message translates to:
  /// **'Novo serviço ou peça'**
  String get pickerNewItem;

  /// No description provided for @pickerNewChecklist.
  ///
  /// In pt, this message translates to:
  /// **'Novo checklist'**
  String get pickerNewChecklist;

  /// No description provided for @pickerRegister.
  ///
  /// In pt, this message translates to:
  /// **'Cadastrar “{query}”'**
  String pickerRegister(String query);

  /// No description provided for @pickerNoDeviceWith.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum {device} com “{query}”.'**
  String pickerNoDeviceWith(String device, String query);

  /// No description provided for @pickerNoItemWith.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum serviço ou peça com “{query}”. Cadastre e ele já entra na OS.'**
  String pickerNoItemWith(String query);

  /// No description provided for @pickerNoMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nada com “{query}”.'**
  String pickerNoMatch(String query);

  /// No description provided for @pickerRecent.
  ///
  /// In pt, this message translates to:
  /// **'Recentes'**
  String get pickerRecent;

  /// No description provided for @pickerAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get pickerAll;

  /// No description provided for @pickerSearch.
  ///
  /// In pt, this message translates to:
  /// **'Buscar'**
  String get pickerSearch;

  /// No description provided for @pickerNoDevice.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum {device}'**
  String pickerNoDevice(String device);

  /// No description provided for @formMoreData.
  ///
  /// In pt, this message translates to:
  /// **'Mais dados'**
  String get formMoreData;

  /// No description provided for @customerSaveNeedsName.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o nome para salvar.'**
  String get customerSaveNeedsName;

  /// No description provided for @customerMoreDataHint.
  ///
  /// In pt, this message translates to:
  /// **'E-mail, CPF ou CNPJ, endereço'**
  String get customerMoreDataHint;

  /// No description provided for @deviceSaveNeedsField.
  ///
  /// In pt, this message translates to:
  /// **'Preencha o campo {field} para salvar.'**
  String deviceSaveNeedsField(String field);

  /// No description provided for @deviceMoreDataHint.
  ///
  /// In pt, this message translates to:
  /// **'Foto, {brand} e {category}'**
  String deviceMoreDataHint(String brand, String category);

  /// No description provided for @catalogMoreDataHintFields.
  ///
  /// In pt, this message translates to:
  /// **'Foto e outros campos'**
  String get catalogMoreDataHintFields;

  /// No description provided for @inviteSaveNeedsContact.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o e-mail ou o WhatsApp para salvar.'**
  String get inviteSaveNeedsContact;

  /// No description provided for @checklistNamePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Vistoria de entrada'**
  String get checklistNamePlaceholder;

  /// No description provided for @checklistQuestionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Perguntas'**
  String get checklistQuestionsTitle;

  /// No description provided for @checklistAddQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar pergunta'**
  String get checklistAddQuestion;

  /// No description provided for @checklistSaveNeedsNameAndQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o nome e adicione uma pergunta para salvar.'**
  String get checklistSaveNeedsNameAndQuestion;

  /// No description provided for @checklistSaveNeedsQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Adicione uma pergunta para salvar.'**
  String get checklistSaveNeedsQuestion;

  /// No description provided for @checklistNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome do checklist'**
  String get checklistNameLabel;

  /// No description provided for @checklistSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar checklist'**
  String get checklistSave;

  /// No description provided for @checklistSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para salvar o checklist. Tente de novo.'**
  String get checklistSaveError;

  /// No description provided for @checklistStopUsing.
  ///
  /// In pt, this message translates to:
  /// **'Não usar na empresa'**
  String get checklistStopUsing;

  /// No description provided for @checklistUseAgain.
  ///
  /// In pt, this message translates to:
  /// **'Voltar a usar'**
  String get checklistUseAgain;

  /// No description provided for @checklistDelete.
  ///
  /// In pt, this message translates to:
  /// **'Apagar checklist'**
  String get checklistDelete;

  /// No description provided for @checklistDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar este checklist?'**
  String get checklistDeleteTitle;

  /// No description provided for @checklistDeleteMessage.
  ///
  /// In pt, this message translates to:
  /// **'“{name}” sai da lista e não aparece mais nas OS novas.'**
  String checklistDeleteMessage(String name);

  /// No description provided for @checklistQuestionNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova pergunta'**
  String get checklistQuestionNew;

  /// No description provided for @checklistQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Pergunta'**
  String get checklistQuestion;

  /// No description provided for @checklistQuestionPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Os pneus estão bons?'**
  String get checklistQuestionPlaceholder;

  /// No description provided for @checklistAnswerType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de resposta'**
  String get checklistAnswerType;

  /// No description provided for @checklistOptions.
  ///
  /// In pt, this message translates to:
  /// **'Opções'**
  String get checklistOptions;

  /// No description provided for @checklistOptionsPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Bom\nRegular\nRuim'**
  String get checklistOptionsPlaceholder;

  /// No description provided for @checklistQuestionRequiredHint.
  ///
  /// In pt, this message translates to:
  /// **'Não deixa concluir sem responder'**
  String get checklistQuestionRequiredHint;

  /// No description provided for @checklistQuestionAllowPhotos.
  ///
  /// In pt, this message translates to:
  /// **'Pode pôr foto'**
  String get checklistQuestionAllowPhotos;

  /// No description provided for @checklistQuestionDelete.
  ///
  /// In pt, this message translates to:
  /// **'Apagar pergunta'**
  String get checklistQuestionDelete;

  /// No description provided for @checklistQuestionNeedsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Escreva a pergunta para continuar.'**
  String get checklistQuestionNeedsLabel;

  /// No description provided for @checklistQuestionNeedsOptions.
  ///
  /// In pt, this message translates to:
  /// **'Escreva pelo menos 2 opções, uma por linha.'**
  String get checklistQuestionNeedsOptions;

  /// No description provided for @checklistQuestionRequiredShort.
  ///
  /// In pt, this message translates to:
  /// **'obrigatória'**
  String get checklistQuestionRequiredShort;

  /// No description provided for @checklistQuestionWithPhoto.
  ///
  /// In pt, this message translates to:
  /// **'com foto'**
  String get checklistQuestionWithPhoto;

  /// No description provided for @formItemTypeText.
  ///
  /// In pt, this message translates to:
  /// **'Texto'**
  String get formItemTypeText;

  /// No description provided for @formItemTypeNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número'**
  String get formItemTypeNumber;

  /// No description provided for @formItemTypeBoolean.
  ///
  /// In pt, this message translates to:
  /// **'Sim ou não'**
  String get formItemTypeBoolean;

  /// No description provided for @formItemTypeSelect.
  ///
  /// In pt, this message translates to:
  /// **'Escolher uma opção'**
  String get formItemTypeSelect;

  /// No description provided for @formItemTypeChecklist.
  ///
  /// In pt, this message translates to:
  /// **'Escolher várias opções'**
  String get formItemTypeChecklist;

  /// No description provided for @formItemTypePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Só foto'**
  String get formItemTypePhoto;

  /// No description provided for @pickerNewItemKind.
  ///
  /// In pt, this message translates to:
  /// **'O que vai cadastrar?'**
  String get pickerNewItemKind;

  /// No description provided for @pickerNewItemServiceHint.
  ///
  /// In pt, this message translates to:
  /// **'Mão de obra que você faz'**
  String get pickerNewItemServiceHint;

  /// No description provided for @pickerNewItemProductHint.
  ///
  /// In pt, this message translates to:
  /// **'Peça ou material que você vende'**
  String get pickerNewItemProductHint;

  /// No description provided for @receiveSubtitleWithDiscount.
  ///
  /// In pt, this message translates to:
  /// **'{customer} · total {total} · desconto {discount}'**
  String receiveSubtitleWithDiscount(
    String customer,
    String total,
    String discount,
  );

  /// No description provided for @receiveSubtitleNoCustomerWithDiscount.
  ///
  /// In pt, this message translates to:
  /// **'total {total} · desconto {discount}'**
  String receiveSubtitleNoCustomerWithDiscount(String total, String discount);

  /// No description provided for @chargeSendLinkTo.
  ///
  /// In pt, this message translates to:
  /// **'Mandar link para {customer} pagar'**
  String chargeSendLinkTo(String customer);

  /// No description provided for @chargeSendLink.
  ///
  /// In pt, this message translates to:
  /// **'Mandar link para pagar'**
  String get chargeSendLink;

  /// No description provided for @chargeLinkSentOn.
  ///
  /// In pt, this message translates to:
  /// **'Link mandado em {date}'**
  String chargeLinkSentOn(String date);

  /// No description provided for @chargeLinkSent.
  ///
  /// In pt, this message translates to:
  /// **'Link mandado'**
  String get chargeLinkSent;

  /// No description provided for @chargeLinkExpiredOn.
  ///
  /// In pt, this message translates to:
  /// **'O link venceu em {date}'**
  String chargeLinkExpiredOn(String date);

  /// No description provided for @chargeNotPaidYet.
  ///
  /// In pt, this message translates to:
  /// **'{customer} ainda não pagou os {value}.'**
  String chargeNotPaidYet(String customer, String value);

  /// No description provided for @chargeNotPaidYetNoCustomer.
  ///
  /// In pt, this message translates to:
  /// **'Os {value} ainda não foram pagos.'**
  String chargeNotPaidYetNoCustomer(String value);

  /// No description provided for @chargeLinkValidUntil.
  ///
  /// In pt, this message translates to:
  /// **'O link vale até {date}.'**
  String chargeLinkValidUntil(String date);

  /// No description provided for @chargeRemindWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Lembrar pelo WhatsApp também'**
  String get chargeRemindWhatsApp;

  /// No description provided for @chargeReceivedOtherWay.
  ///
  /// In pt, this message translates to:
  /// **'Recebi de outro jeito'**
  String get chargeReceivedOtherWay;

  /// No description provided for @chargeLinkSection.
  ///
  /// In pt, this message translates to:
  /// **'Link para pagar'**
  String get chargeLinkSection;

  /// No description provided for @chargePaymentLink.
  ///
  /// In pt, this message translates to:
  /// **'Link de pagamento'**
  String get chargePaymentLink;

  /// No description provided for @chargeWaitingFor.
  ///
  /// In pt, this message translates to:
  /// **'Esperando {customer} pagar'**
  String chargeWaitingFor(String customer);

  /// No description provided for @chargeWaitingPayment.
  ///
  /// In pt, this message translates to:
  /// **'Esperando o pagamento'**
  String get chargeWaitingPayment;

  /// No description provided for @chargeExpiredOn.
  ///
  /// In pt, this message translates to:
  /// **'Venceu em {date}'**
  String chargeExpiredOn(String date);

  /// No description provided for @chargeMethodsUntil.
  ///
  /// In pt, this message translates to:
  /// **'Pix, boleto ou cartão · até {date}'**
  String chargeMethodsUntil(String date);

  /// No description provided for @chargeInstallmentsUntil.
  ///
  /// In pt, this message translates to:
  /// **'{count}x no cartão · até {date}'**
  String chargeInstallmentsUntil(int count, String date);

  /// No description provided for @chargeInstallmentsPaid.
  ///
  /// In pt, this message translates to:
  /// **'{paid} de {count} parcelas pagas'**
  String chargeInstallmentsPaid(int paid, int count);

  /// No description provided for @chargeUntilReplaced.
  ///
  /// In pt, this message translates to:
  /// **'até {date} · o link novo cancela este'**
  String chargeUntilReplaced(String date);

  /// No description provided for @chargeOrderChanged.
  ///
  /// In pt, this message translates to:
  /// **'A OS mudou de valor'**
  String get chargeOrderChanged;

  /// No description provided for @chargeNowMissing.
  ///
  /// In pt, this message translates to:
  /// **'Agora falta {remaining}, mas o link ainda cobra {value}.'**
  String chargeNowMissing(String remaining, String value);

  /// No description provided for @chargeGenerateNew.
  ///
  /// In pt, this message translates to:
  /// **'Gerar link novo de {value}'**
  String chargeGenerateNew(String value);

  /// No description provided for @chargeKeepLink.
  ///
  /// In pt, this message translates to:
  /// **'Manter o link de {value}'**
  String chargeKeepLink(String value);

  /// No description provided for @chargeSendAgainWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Mandar de novo pelo WhatsApp'**
  String get chargeSendAgainWhatsApp;

  /// No description provided for @chargeCopyLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar o link'**
  String get chargeCopyLink;

  /// No description provided for @chargeLinkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link copiado'**
  String get chargeLinkCopied;

  /// No description provided for @chargeCancelLink.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar o link'**
  String get chargeCancelLink;

  /// No description provided for @chargeLinkTitle.
  ///
  /// In pt, this message translates to:
  /// **'Link para pagar'**
  String get chargeLinkTitle;

  /// No description provided for @chargeLinkIntro.
  ///
  /// In pt, this message translates to:
  /// **'{name} recebe o link e paga por Pix, boleto ou cartão.'**
  String chargeLinkIntro(String name);

  /// No description provided for @chargeLinkIntroNoName.
  ///
  /// In pt, this message translates to:
  /// **'O cliente recebe o link e paga por Pix, boleto ou cartão.'**
  String get chargeLinkIntroNoName;

  /// No description provided for @chargeSplitQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Parcelar no cartão?'**
  String get chargeSplitQuestion;

  /// No description provided for @chargeSplitOnCard.
  ///
  /// In pt, this message translates to:
  /// **'Parcelar no cartão'**
  String get chargeSplitOnCard;

  /// No description provided for @chargeSplitNo.
  ///
  /// In pt, this message translates to:
  /// **'Não'**
  String get chargeSplitNo;

  /// No description provided for @profileEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu perfil'**
  String get profileEditTitle;

  /// No description provided for @profileChangePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Trocar foto'**
  String get profileChangePhoto;

  /// No description provided for @profileSignedInAs.
  ///
  /// In pt, this message translates to:
  /// **'Você entra com {email}'**
  String profileSignedInAs(String email);

  /// No description provided for @profileNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu nome'**
  String get profileNameRequired;

  /// No description provided for @profileNamePlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: João da Silva'**
  String get profileNamePlaceholder;

  /// No description provided for @financialWhichOrder.
  ///
  /// In pt, this message translates to:
  /// **'Qual OS?'**
  String get financialWhichOrder;

  /// No description provided for @reportThisWeek.
  ///
  /// In pt, this message translates to:
  /// **'Esta semana'**
  String get reportThisWeek;

  /// No description provided for @reportThisMonth.
  ///
  /// In pt, this message translates to:
  /// **'Este mês'**
  String get reportThisMonth;

  /// No description provided for @reportThisYear.
  ///
  /// In pt, this message translates to:
  /// **'Este ano'**
  String get reportThisYear;

  /// No description provided for @reportPickDates.
  ///
  /// In pt, this message translates to:
  /// **'Escolher datas'**
  String get reportPickDates;

  /// No description provided for @reportSeeOtherPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Ver outro período'**
  String get reportSeeOtherPeriod;

  /// No description provided for @reportStarts.
  ///
  /// In pt, this message translates to:
  /// **'Começa'**
  String get reportStarts;

  /// No description provided for @reportEnds.
  ///
  /// In pt, this message translates to:
  /// **'Termina'**
  String get reportEnds;

  /// No description provided for @reportWhichPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Que período?'**
  String get reportWhichPeriod;

  /// No description provided for @agendaShowMonth.
  ///
  /// In pt, this message translates to:
  /// **'Ver o mês'**
  String get agendaShowMonth;

  /// No description provided for @agendaShowWeek.
  ///
  /// In pt, this message translates to:
  /// **'Ver a semana'**
  String get agendaShowWeek;

  /// No description provided for @agendaWhose.
  ///
  /// In pt, this message translates to:
  /// **'De quem: {name}'**
  String agendaWhose(String name);

  /// No description provided for @agendaWhoseTitle.
  ///
  /// In pt, this message translates to:
  /// **'De quem mostrar?'**
  String get agendaWhoseTitle;

  /// No description provided for @agendaOnlyOf.
  ///
  /// In pt, this message translates to:
  /// **'Só de {name}'**
  String agendaOnlyOf(String name);

  /// No description provided for @agendaShowAll.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar todos'**
  String get agendaShowAll;

  /// No description provided for @agendaWithPerson.
  ///
  /// In pt, this message translates to:
  /// **'com {name}'**
  String agendaWithPerson(String name);

  /// No description provided for @agendaDayCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 marcado} other{{count} marcados}}'**
  String agendaDayCount(int count);

  /// No description provided for @agendaDayHasOrders.
  ///
  /// In pt, this message translates to:
  /// **'{day}, tem serviço marcado'**
  String agendaDayHasOrders(String day);

  /// No description provided for @agendaPreviousWeek.
  ///
  /// In pt, this message translates to:
  /// **'Semana anterior'**
  String get agendaPreviousWeek;

  /// No description provided for @agendaNextWeek.
  ///
  /// In pt, this message translates to:
  /// **'Próxima semana'**
  String get agendaNextWeek;

  /// No description provided for @agendaPreviousMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês anterior'**
  String get agendaPreviousMonth;

  /// No description provided for @agendaNextMonth.
  ///
  /// In pt, this message translates to:
  /// **'Próximo mês'**
  String get agendaNextMonth;

  /// No description provided for @noticeCommented.
  ///
  /// In pt, this message translates to:
  /// **'{name} comentou: “{text}”'**
  String noticeCommented(String name, String text);

  /// No description provided for @noticePaymentReceived.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento de {amount} recebido'**
  String noticePaymentReceived(String amount);

  /// No description provided for @contractNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo contrato'**
  String get contractNew;

  /// No description provided for @orderRepeatRow.
  ///
  /// In pt, this message translates to:
  /// **'Repetir'**
  String get orderRepeatRow;

  /// No description provided for @contractsEmptyAdd.
  ///
  /// In pt, this message translates to:
  /// **'Toque em + para criar uma {order} que se repete sozinha.'**
  String contractsEmptyAdd(String order);

  /// No description provided for @contractRepeats.
  ///
  /// In pt, this message translates to:
  /// **'Repete'**
  String get contractRepeats;

  /// No description provided for @contractRepeatsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Com que frequência?'**
  String get contractRepeatsTitle;

  /// No description provided for @contractStarts.
  ///
  /// In pt, this message translates to:
  /// **'Começa'**
  String get contractStarts;

  /// No description provided for @contractEnds.
  ///
  /// In pt, this message translates to:
  /// **'Termina'**
  String get contractEnds;

  /// No description provided for @contractNeverEnds.
  ///
  /// In pt, this message translates to:
  /// **'Nunca'**
  String get contractNeverEnds;

  /// No description provided for @contractNoEndDate.
  ///
  /// In pt, this message translates to:
  /// **'Sem data para terminar'**
  String get contractNoEndDate;

  /// No description provided for @contractAutoCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar a {order} sozinha'**
  String contractAutoCreate(String order);

  /// No description provided for @contractAutoCreateHint.
  ///
  /// In pt, this message translates to:
  /// **'Ligado, a {order} nova aparece sozinha na data. Desligado, você só recebe o aviso.'**
  String contractAutoCreateHint(String order);

  /// No description provided for @contractRemind.
  ///
  /// In pt, this message translates to:
  /// **'Avisar antes'**
  String get contractRemind;

  /// No description provided for @contractRemindTitle.
  ///
  /// In pt, this message translates to:
  /// **'Avisar quanto tempo antes?'**
  String get contractRemindTitle;

  /// No description provided for @contractRemindDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{No dia} =1{1 dia antes} other{{count} dias antes}}'**
  String contractRemindDays(int count);

  /// No description provided for @onboardingSegmentHint.
  ///
  /// In pt, this message translates to:
  /// **'Assim o app já vem com os serviços e checklists do seu trabalho.'**
  String get onboardingSegmentHint;

  /// No description provided for @onboardingSpecialtiesHint.
  ///
  /// In pt, this message translates to:
  /// **'Marque o que fizer sentido. Dá para mudar depois.'**
  String get onboardingSpecialtiesHint;

  /// No description provided for @emailLoginTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com e-mail'**
  String get emailLoginTitle;

  /// No description provided for @emailLoginEmailRequired.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o seu e-mail.'**
  String get emailLoginEmailRequired;

  /// No description provided for @emailLoginEmailInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Esse e-mail não parece certo. Confira.'**
  String get emailLoginEmailInvalid;

  /// No description provided for @emailLoginPasswordRequired.
  ///
  /// In pt, this message translates to:
  /// **'Escreva a sua senha.'**
  String get emailLoginPasswordRequired;

  /// No description provided for @emailLoginWrongCredentials.
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou senha não conferem. Confira e tente de novo.'**
  String get emailLoginWrongCredentials;

  /// No description provided for @emailLoginNoInternet.
  ///
  /// In pt, this message translates to:
  /// **'Sem internet. Confira a conexão e tente de novo.'**
  String get emailLoginNoInternet;

  /// No description provided for @emailLoginTooManyAttempts.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Espere um pouco e tente de novo.'**
  String get emailLoginTooManyAttempts;

  /// No description provided for @emailLoginGenericError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para entrar. Tente de novo.'**
  String get emailLoginGenericError;

  /// No description provided for @emailLoginSigningIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get emailLoginSigningIn;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In pt, this message translates to:
  /// **'Trocar a senha'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordMessage.
  ///
  /// In pt, this message translates to:
  /// **'Vamos mandar um link para o seu e-mail.'**
  String get resetPasswordMessage;

  /// No description provided for @resetPasswordError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para mandar o e-mail. Confira o endereço e tente de novo.'**
  String get resetPasswordError;

  /// No description provided for @inviteTitleMany.
  ///
  /// In pt, this message translates to:
  /// **'Você recebeu convites'**
  String get inviteTitleMany;

  /// No description provided for @inviteManyHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque num convite para ver e entrar na equipe.'**
  String get inviteManyHint;

  /// No description provided for @inviteCodeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual é o código do convite?'**
  String get inviteCodeTitle;

  /// No description provided for @checklistRemaining.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Tudo respondido} =1{Falta 1} other{Faltam {count}}}'**
  String checklistRemaining(int count);

  /// No description provided for @checklistQuestionNext.
  ///
  /// In pt, this message translates to:
  /// **'Próxima'**
  String get checklistQuestionNext;

  /// No description provided for @checklistQuestionDone.
  ///
  /// In pt, this message translates to:
  /// **'Pronto'**
  String get checklistQuestionDone;

  /// No description provided for @checklistSkipForNow.
  ///
  /// In pt, this message translates to:
  /// **'Pular por agora'**
  String get checklistSkipForNow;

  /// No description provided for @checklistPreviousQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Voltar à anterior'**
  String get checklistPreviousQuestion;

  /// No description provided for @checklistQuestionRequired.
  ///
  /// In pt, this message translates to:
  /// **'Obrigatória'**
  String get checklistQuestionRequired;

  /// No description provided for @checklistPickFromGallery.
  ///
  /// In pt, this message translates to:
  /// **'Escolher da galeria'**
  String get checklistPickFromGallery;

  /// No description provided for @checklistTextPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Escreva aqui'**
  String get checklistTextPlaceholder;

  /// No description provided for @checklistStart.
  ///
  /// In pt, this message translates to:
  /// **'Começar'**
  String get checklistStart;

  /// No description provided for @checklistFinish.
  ///
  /// In pt, this message translates to:
  /// **'Concluir checklist'**
  String get checklistFinish;

  /// No description provided for @checklistFinishAnyway.
  ///
  /// In pt, this message translates to:
  /// **'Concluir assim mesmo'**
  String get checklistFinishAnyway;

  /// No description provided for @checklistStatusDone.
  ///
  /// In pt, this message translates to:
  /// **'Completo'**
  String get checklistStatusDone;

  /// No description provided for @checklistNoAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Sem resposta'**
  String get checklistNoAnswer;

  /// No description provided for @checklistPhotoPosition.
  ///
  /// In pt, this message translates to:
  /// **'{current} de {total}'**
  String checklistPhotoPosition(int current, int total);

  /// No description provided for @shareTitle.
  ///
  /// In pt, this message translates to:
  /// **'Mandar para o cliente'**
  String get shareTitle;

  /// No description provided for @shareCanAll.
  ///
  /// In pt, this message translates to:
  /// **'{name} abre a {order} pelo link, aprova e comenta.'**
  String shareCanAll(String name, String order);

  /// No description provided for @shareCanApprove.
  ///
  /// In pt, this message translates to:
  /// **'{name} abre a {order} pelo link e aprova.'**
  String shareCanApprove(String name, String order);

  /// No description provided for @shareCanComment.
  ///
  /// In pt, this message translates to:
  /// **'{name} abre a {order} pelo link e comenta.'**
  String shareCanComment(String name, String order);

  /// No description provided for @shareCanView.
  ///
  /// In pt, this message translates to:
  /// **'{name} abre a {order} pelo link.'**
  String shareCanView(String name, String order);

  /// No description provided for @shareTheCustomer.
  ///
  /// In pt, this message translates to:
  /// **'O cliente'**
  String get shareTheCustomer;

  /// No description provided for @shareValidUntil.
  ///
  /// In pt, this message translates to:
  /// **'Vale até {date}.'**
  String shareValidUntil(String date);

  /// No description provided for @shareSendWhatsApp.
  ///
  /// In pt, this message translates to:
  /// **'Mandar pelo WhatsApp'**
  String get shareSendWhatsApp;

  /// No description provided for @shareSendLink.
  ///
  /// In pt, this message translates to:
  /// **'Mandar o link'**
  String get shareSendLink;

  /// No description provided for @shareSendOtherWay.
  ///
  /// In pt, this message translates to:
  /// **'Mandar de outro jeito'**
  String get shareSendOtherWay;

  /// No description provided for @shareCopyLink.
  ///
  /// In pt, this message translates to:
  /// **'Copiar o link'**
  String get shareCopyLink;

  /// No description provided for @shareLinkCopied.
  ///
  /// In pt, this message translates to:
  /// **'Link copiado'**
  String get shareLinkCopied;

  /// No description provided for @sharePreparing.
  ///
  /// In pt, this message translates to:
  /// **'Preparando o link…'**
  String get sharePreparing;

  /// No description provided for @shareError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para criar o link.'**
  String get shareError;

  /// No description provided for @shareValidity.
  ///
  /// In pt, this message translates to:
  /// **'Mudar a validade'**
  String get shareValidity;

  /// No description provided for @shareValidityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vale por quanto tempo?'**
  String get shareValidityTitle;

  /// No description provided for @shareValidityDays.
  ///
  /// In pt, this message translates to:
  /// **'{count} dias'**
  String shareValidityDays(int count);

  /// No description provided for @sharePermissionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que o cliente pode fazer?'**
  String get sharePermissionsTitle;

  /// No description provided for @sharePermAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver, aprovar e comentar'**
  String get sharePermAll;

  /// No description provided for @sharePermApprove.
  ///
  /// In pt, this message translates to:
  /// **'Ver e aprovar'**
  String get sharePermApprove;

  /// No description provided for @sharePermComment.
  ///
  /// In pt, this message translates to:
  /// **'Ver e comentar'**
  String get sharePermComment;

  /// No description provided for @sharePermView.
  ///
  /// In pt, this message translates to:
  /// **'Só ver'**
  String get sharePermView;

  /// No description provided for @shareNewLink.
  ///
  /// In pt, this message translates to:
  /// **'Gerar link novo'**
  String get shareNewLink;

  /// No description provided for @shareRevoke.
  ///
  /// In pt, this message translates to:
  /// **'Desativar o link'**
  String get shareRevoke;

  /// No description provided for @shareRevokeConfirm.
  ///
  /// In pt, this message translates to:
  /// **'O cliente não vai mais conseguir abrir a {order} por este link.'**
  String shareRevokeConfirm(String order);

  /// No description provided for @shareMenu.
  ///
  /// In pt, this message translates to:
  /// **'Opções do link'**
  String get shareMenu;

  /// No description provided for @orderItemNotesPlaceholder.
  ///
  /// In pt, this message translates to:
  /// **'Algo a mais sobre este item'**
  String get orderItemNotesPlaceholder;

  /// No description provided for @orderItemRemoveTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tirar da OS?'**
  String get orderItemRemoveTitle;

  /// No description provided for @orderItemRemoveMessage.
  ///
  /// In pt, this message translates to:
  /// **'\"{name}\" sai da OS e do total.'**
  String orderItemRemoveMessage(String name);

  /// No description provided for @orderItemQuantityInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Coloque pelo menos 1.'**
  String get orderItemQuantityInvalid;

  /// No description provided for @orderPhotoShareText.
  ///
  /// In pt, this message translates to:
  /// **'Foto da {order}'**
  String orderPhotoShareText(String order);

  /// No description provided for @orderPhotoShareError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para compartilhar a foto. Tente de novo.'**
  String get orderPhotoShareError;

  /// No description provided for @orderPhotoDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Apagar esta foto?'**
  String get orderPhotoDeleteTitle;

  /// No description provided for @orderPhotoDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Foto apagada'**
  String get orderPhotoDeleted;

  /// No description provided for @orderPhotoDeleteError.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para apagar a foto. Tente de novo.'**
  String get orderPhotoDeleteError;

  /// No description provided for @orderPhotoCoverSet.
  ///
  /// In pt, this message translates to:
  /// **'Foto definida como capa'**
  String get orderPhotoCoverSet;

  /// No description provided for @orderPhotoUploading.
  ///
  /// In pt, this message translates to:
  /// **'Enviando foto...'**
  String get orderPhotoUploading;

  /// No description provided for @orderDocumentTypeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Que documento é este?'**
  String get orderDocumentTypeTitle;

  /// No description provided for @shareWhatCanDo.
  ///
  /// In pt, this message translates to:
  /// **'O que o cliente pode fazer'**
  String get shareWhatCanDo;

  /// No description provided for @orderPhotoDelete.
  ///
  /// In pt, this message translates to:
  /// **'Apagar foto'**
  String get orderPhotoDelete;

  /// No description provided for @contractStopRepeating.
  ///
  /// In pt, this message translates to:
  /// **'Parar de repetir'**
  String get contractStopRepeating;

  /// No description provided for @contractStopRepeatingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Parar de repetir?'**
  String get contractStopRepeatingTitle;

  /// No description provided for @contractStopRepeatingMessage.
  ///
  /// In pt, this message translates to:
  /// **'As próximas OS não serão mais criadas. As que já existem continuam.'**
  String get contractStopRepeatingMessage;
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
