// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get home => 'Inicio';

  @override
  String get orders => 'Órdenes de Servicio';

  @override
  String get customers => 'Clientes';

  @override
  String get devices => 'Equipos';

  @override
  String get services => 'Servicios';

  @override
  String get products => 'Productos';

  @override
  String get reports => 'Informes';

  @override
  String get settings => 'Configuración';

  @override
  String get profile => 'Perfil';

  @override
  String get company => 'Empresa';

  @override
  String get team => 'Equipo';

  @override
  String get collaborators => 'Colaboradores';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get add => 'Agregar';

  @override
  String get create => 'Crear';

  @override
  String get update => 'Actualizar';

  @override
  String get search => 'Buscar';

  @override
  String get searchOrAddNew => 'Buscar o añadir nuevo';

  @override
  String get filter => 'Filtrar';

  @override
  String get sort => 'Ordenar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get close => 'Cerrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get back => 'Volver';

  @override
  String get next => 'Siguiente';

  @override
  String get previous => 'Anterior';

  @override
  String get done => 'Hecho';

  @override
  String get finish => 'Finalizar';

  @override
  String get loading => 'Cargando...';

  @override
  String get send => 'Enviar';

  @override
  String get share => 'Compartir';

  @override
  String get copy => 'Copiar';

  @override
  String get print => 'Imprimir';

  @override
  String get preview => 'Vista previa';

  @override
  String get export => 'Exportar';

  @override
  String get import => 'Importar';

  @override
  String get select => 'Seleccionar';

  @override
  String get selectAll => 'Seleccionar Todo';

  @override
  String get clear => 'Limpiar';

  @override
  String get reset => 'Restablecer';

  @override
  String get apply => 'Aplicar';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get more => 'Más';

  @override
  String get less => 'Menos';

  @override
  String get details => 'Detalles';

  @override
  String get options => 'Opciones';

  @override
  String get actions => 'Acciones';

  @override
  String get status => 'Estado';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusApproved => 'Aprobado';

  @override
  String get statusInProgress => 'En Progreso';

  @override
  String get statusCompleted => 'Completado';

  @override
  String get statusCancelled => 'Cancelado';

  @override
  String get statusQuote => 'Presupuesto';

  @override
  String get payments => 'Pagos';

  @override
  String get payment => 'Pago';

  @override
  String get paid => 'Pagado';

  @override
  String get unpaid => 'No Pagado';

  @override
  String get toReceive => 'Por recibir';

  @override
  String get received => 'Recibido';

  @override
  String get pix => 'PIX';

  @override
  String get check => 'Cheque';

  @override
  String get installments => 'Cuotas';

  @override
  String get installment => 'Cuota';

  @override
  String get dueDate => 'Vencimiento';

  @override
  String get paymentCannotExceedBalance => 'El pago no puede exceder el saldo';

  @override
  String get discountCannotExceedBalance =>
      'El descuento no puede exceder el saldo';

  @override
  String get asaasTransactionCannotBeRemoved =>
      'Los pagos recibidos por Asaas no se pueden eliminar aquí. Para deshacerlo, reembolsa el cobro en Asaas.';

  @override
  String get paymentUpdateFailed =>
      'No se pudo guardar el pago. Verifica tu conexión e inténtalo de nuevo.';

  @override
  String get paymentRequiresConnection =>
      'Sin conexión. Inténtalo de nuevo cuando estés en línea.';

  @override
  String get history => 'Historial';

  @override
  String get valueMustBeGreaterThanZero => 'El valor debe ser mayor que cero';

  @override
  String confirmRemoveTransaction(String type, String amount) {
    return '¿Desea eliminar este $type de $amount?';
  }

  @override
  String get invalidEmail => 'Correo electrónico inválido';

  @override
  String get invalidPhone => 'Teléfono inválido';

  @override
  String get invalidFormat => 'Formato inválido';

  @override
  String get minimum => 'Mínimo';

  @override
  String get maximum => 'Máximo';

  @override
  String get characters => 'caracteres';

  @override
  String get noValuesRegistered => 'No hay valores registrados';

  @override
  String get typeAboveToAdd => 'Escriba arriba para agregar';

  @override
  String minLength(int count) {
    return 'Mínimo $count caracteres';
  }

  @override
  String maxLength(int count) {
    return 'Máximo $count caracteres';
  }

  @override
  String get takePhoto => 'Tomar Foto';

  @override
  String get chooseFromGallery => 'Elegir de la Galería';

  @override
  String get changePhoto => 'Cambiar Foto';

  @override
  String get removePhoto => 'Eliminar Foto';

  @override
  String get addPhoto => 'Agregar Foto';

  @override
  String get photos => 'fotos';

  @override
  String get photo => 'Foto';

  @override
  String get camera => 'Cámara';

  @override
  String get gallery => 'Galería';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get scheduledDate => 'Programado';

  @override
  String get updatedAt => 'Actualizado en';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get startDate => 'Fecha de inicio';

  @override
  String get endDate => 'Fecha de término';

  @override
  String get period => 'Período';

  @override
  String get confirmDelete => 'Confirmar Eliminación';

  @override
  String confirmDeleteMessageNamed(String name) {
    return '¿Realmente desea eliminar \"$name\"?';
  }

  @override
  String get confirmAction => 'Confirmar Acción';

  @override
  String get cannotUndo => 'Esta acción no se puede deshacer.';

  @override
  String get discard => 'Descartar';

  @override
  String get leave => 'Salir';

  @override
  String get stay => 'Quedarse';

  @override
  String get customer => 'Cliente';

  @override
  String get newCustomer => 'Nuevo Cliente';

  @override
  String get editCustomer => 'Editar Cliente';

  @override
  String get customerName => 'Nombre del Cliente';

  @override
  String get customerList => 'Lista de Clientes';

  @override
  String get addCustomer => 'Agregar Cliente';

  @override
  String get name => 'Nombre';

  @override
  String get fullName => 'Nombre Completo';

  @override
  String get phone => 'Teléfono';

  @override
  String get whatsapp => 'WhatsApp';

  @override
  String get email => 'Correo';

  @override
  String get address => 'Dirección';

  @override
  String get number => 'Número';

  @override
  String get city => 'Ciudad';

  @override
  String get state => 'Estado';

  @override
  String get country => 'País';

  @override
  String get notes => 'Notas';

  @override
  String get observation => 'Observación';

  @override
  String get description => 'Descripción';

  @override
  String get comments => 'Comentarios';

  @override
  String get document => 'Documento';

  @override
  String get cpfCnpj => 'CPF/CNPJ';

  @override
  String get order => 'Orden de Servicio';

  @override
  String get orderShort => 'OS';

  @override
  String get orderOverdue => 'Atrasada';

  @override
  String get newOrder => 'NUEVA';

  @override
  String get orderNumber => 'Número de Orden';

  @override
  String get orderList => 'Lista de Órdenes';

  @override
  String get addOrder => 'Agregar Orden';

  @override
  String get createOrder => 'Crear Orden';

  @override
  String get technician => 'Técnico';

  @override
  String get technicians => 'Técnicos';

  @override
  String get problem => 'Problema Reportado';

  @override
  String get warranty => 'Garantía';

  @override
  String get priority => 'Prioridad';

  @override
  String get device => 'Equipo';

  @override
  String get deviceCategory => 'Categoría';

  @override
  String get editDevice => 'Editar Equipo';

  @override
  String get deviceList => 'Lista de Equipos';

  @override
  String get addDevice => 'Agregar Equipo';

  @override
  String get brand => 'Marca';

  @override
  String get model => 'Modelo';

  @override
  String get serialNumber => 'Número de Serie';

  @override
  String get color => 'Color';

  @override
  String get condition => 'Condición';

  @override
  String get defects => 'Defectos';

  @override
  String get service => 'Servicio';

  @override
  String get editService => 'Editar Servicio';

  @override
  String get serviceList => 'Lista de Servicios';

  @override
  String get searchService => 'Buscar Servicio';

  @override
  String get addService => 'Agregar Servicio';

  @override
  String get product => 'Producto';

  @override
  String get editProduct => 'Editar Producto';

  @override
  String get productList => 'Lista de Productos';

  @override
  String get searchProduct => 'Buscar Producto';

  @override
  String get addProduct => 'Agregar Producto';

  @override
  String get barcode => 'Código de Barras';

  @override
  String get unit => 'Unidad';

  @override
  String get category => 'Categoría';

  @override
  String get categories => 'Categorías';

  @override
  String get total => 'Total';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Descuento';

  @override
  String get discountValue => 'Valor del Descuento';

  @override
  String get price => 'Precio';

  @override
  String get quantity => 'Cantidad';

  @override
  String get value => 'Valor';

  @override
  String get amount => 'Monto';

  @override
  String get tax => 'Impuesto';

  @override
  String get balance => 'Saldo';

  @override
  String get totalPaid => 'Total Pagado';

  @override
  String get remaining => 'Restante';

  @override
  String get change => 'Cambio';

  @override
  String get errorOccurred => 'Ocurrió un error';

  @override
  String get tryAgain => 'Intente de nuevo';

  @override
  String get noInternetConnection => 'Sin conexión a internet';

  @override
  String get permissionDenied => 'Permiso denegado';

  @override
  String get timeout => 'Tiempo agotado';

  @override
  String get login => 'Iniciar Sesión';

  @override
  String get logout => 'Cerrar Sesión';

  @override
  String get logoutConfirm => '¿Realmente desea cerrar sesión?';

  @override
  String get signIn => 'Iniciar Sesión';

  @override
  String get password => 'Contraseña';

  @override
  String get emailSent => 'Correo enviado';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get termsAndConditions => 'Términos y Condiciones';

  @override
  String get privacyPolicy => 'Política de Privacidad';

  @override
  String get companyName => 'Nombre de la Empresa';

  @override
  String get skip => 'Saltar';

  @override
  String get continue_ => 'Continuar';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar Idioma';

  @override
  String get english => 'Inglés';

  @override
  String get theme => 'Tema';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get markAllAsRead => 'Marcar todas';

  @override
  String get sound => 'Sonido';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Versión';

  @override
  String get support => 'Soporte';

  @override
  String get dashboard => 'Panel';

  @override
  String get analytics => 'Análisis';

  @override
  String get revenue => 'Ingresos';

  @override
  String get recentOrders => 'Órdenes recientes';

  @override
  String get role => 'Rol';

  @override
  String get noRole => 'Sin perfil';

  @override
  String get roles => 'Roles';

  @override
  String get owner => 'Propietario';

  @override
  String get admin => 'Administrador';

  @override
  String get manager => 'Gerente';

  @override
  String get viewer => 'Visualizador';

  @override
  String get permissions => 'Permisos';

  @override
  String get canCreate => 'Puede Crear';

  @override
  String get canEdit => 'Puede Editar';

  @override
  String get canDelete => 'Puede Eliminar';

  @override
  String get canView => 'Puede Ver';

  @override
  String get checklist => 'Checklist';

  @override
  String get checklists => 'Checklists';

  @override
  String get customerSignature => 'Firma del Cliente';

  @override
  String get required => 'Requerido';

  @override
  String get optional => 'Opcional';

  @override
  String get complete => 'Completar';

  @override
  String get answered => 'Respondido';

  @override
  String get notAnswered => 'No Respondido';

  @override
  String get quote => 'Presupuesto';

  @override
  String get quotes => 'Presupuestos';

  @override
  String expiresIn(int days) {
    return 'Expira en $days días';
  }

  @override
  String get expired => 'Expirado';

  @override
  String get inactive => 'Inactivo';

  @override
  String get enabled => 'Habilitado';

  @override
  String get disabled => 'Deshabilitado';

  @override
  String get visible => 'Visible';

  @override
  String get hidden => 'Oculto';

  @override
  String get public => 'Público';

  @override
  String get private => 'Privado';

  @override
  String get draft => 'Borrador';

  @override
  String get deleted => 'Eliminado';

  @override
  String get all => 'Todos';

  @override
  String get none => 'Ninguno';

  @override
  String get other => 'Otro';

  @override
  String get others => 'Otros';

  @override
  String get custom => 'Personalizado';

  @override
  String get old => 'Antiguo';

  @override
  String get recent => 'Reciente';

  @override
  String get byContinuingYouAgree => 'Al continuar, acepta nuestra';

  @override
  String get error => 'Error';

  @override
  String get companyNotFound => 'Empresa no encontrada';

  @override
  String get companyNoSegment => 'Empresa sin segmento definido';

  @override
  String get userNotFound => 'Usuario no encontrado';

  @override
  String get checkInboxResetPassword =>
      'Revise su bandeja de entrada para restablecer su contraseña.';

  @override
  String get user => 'Usuario';

  @override
  String get switchCompany => 'Cambiar Empresa';

  @override
  String get management => 'Gestión';

  @override
  String get integrations => 'Integraciones';

  @override
  String get integrationsEmpty => 'Aún no hay conexiones';

  @override
  String get integrationsNew => 'Nueva conexión';

  @override
  String get integrationsNameHint => 'Ej: Mi ChatGPT';

  @override
  String get integrationsUrlOnce =>
      'Copia esta URL ahora. No se mostrará de nuevo.';

  @override
  String get integrationsCopy => 'Copiar URL';

  @override
  String get integrationsRevoke => 'Desactivar conexión';

  @override
  String get integrationsRevokeConfirm =>
      '¿Revocar esta conexión? Quien use esta URL pierde el acceso.';

  @override
  String get integrationsNeverUsed => 'Nunca usada';

  @override
  String integrationsLastUsed(String date) {
    return 'Último uso el $date';
  }

  @override
  String get integrationsErrorForbidden =>
      'Solo el dueño o los administradores pueden gestionar integraciones.';

  @override
  String get integrationsErrorNotFound => 'Esta conexión ya no existe.';

  @override
  String get integrationsErrorGeneric =>
      'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get companyData => 'Datos de la Empresa';

  @override
  String get account => 'Cuenta';

  @override
  String get deleteAccount => 'Eliminar Cuenta';

  @override
  String get automatic => 'Automático';

  @override
  String get light => 'Claro';

  @override
  String get dark => 'Oscuro';

  @override
  String get selectCompany => 'Seleccionar Empresa';

  @override
  String get companyNoName => 'Empresa sin nombre';

  @override
  String get deleteAccountWarning =>
      'Esta acción es permanente y no se puede deshacer.\n\nTodos sus datos, incluyendo órdenes de servicio, clientes y configuraciones serán eliminados permanentemente.\n\n¿Está seguro que desea continuar?';

  @override
  String get finalConfirmation => 'Confirmación Final';

  @override
  String get lastChanceCancel =>
      'Esta es su última oportunidad de cancelar.\n\n¿Confirma la eliminación permanente de su cuenta?';

  @override
  String get permanentlyDelete => 'Eliminar Permanentemente';

  @override
  String get errorDeletingAccount => 'Error al Eliminar Cuenta';

  @override
  String get couldNotDeleteAccount => 'No se pudo eliminar su cuenta.';

  @override
  String get accountDeletionTakingLong =>
      'La eliminación puede tardar unos minutos. Inténtalo de nuevo en un momento.';

  @override
  String get requiresRecentLogin =>
      'Por seguridad, Firebase requiere un inicio de sesión reciente antes de eliminar la cuenta.\n\nPor favor:\n1. Cierre sesión de su cuenta\n2. Inicie sesión nuevamente\n3. Intente eliminar la cuenta inmediatamente después de iniciar sesión';

  @override
  String get noPermissionDelete =>
      'No tiene permiso para eliminar su cuenta. Intente de nuevo más tarde.';

  @override
  String get networkError =>
      'Error de conexión. Verifique su internet e intente de nuevo.';

  @override
  String get reauthenticationRequired => 'Re-autenticación Requerida';

  @override
  String get pleaseSignInAgainToDelete =>
      'Por razones de seguridad, necesita iniciar sesión nuevamente antes de eliminar su cuenta.';

  @override
  String get signInAgain => 'Iniciar Sesión Nuevamente';

  @override
  String get authenticated => 'Autenticado';

  @override
  String get reauthenticationFailed => 'Falló la Re-autenticación';

  @override
  String get couldNotReauthenticate => 'No se pudo autenticar nuevamente.';

  @override
  String get remove => 'Eliminar';

  @override
  String get noPermission => 'Sin Permiso';

  @override
  String get noPermissionToRemove =>
      'No tiene permiso para eliminar este elemento.';

  @override
  String get noSegmentsAvailable => 'Ningún segmento disponible';

  @override
  String get specialties => 'Especialidades';

  @override
  String get myCompany => 'Mi empresa';

  @override
  String get retryAgain => 'Intentar de nuevo';

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get unitValue => 'Valor unitario';

  @override
  String get setAsCover => 'Establecer como portada';

  @override
  String get roleDescAdmin =>
      'Acceso total. Configura la empresa, gestiona usuarios y accede a todos los datos.';

  @override
  String get roleAdmin => 'Administrador';

  @override
  String get roleDescSupervisor =>
      'Coordina equipos y equipos. No visualiza valores financieros.';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get roleDescManager =>
      'Enfoque en resultados. Visualiza facturación y costos, pero no ejecuta servicios.';

  @override
  String get roleManager => 'Gerente';

  @override
  String get roleDescConsultant =>
      'Crea presupuestos. Ve precios, pero accede solo a sus propias Órdenes de Servicio.';

  @override
  String get roleConsultant => 'Consultor';

  @override
  String get roleDescTechnician =>
      'Ejecuta servicios. No ve precios y tiene edición limitada tras la aprobación de la OS.';

  @override
  String get roleTechnician => 'Técnico';

  @override
  String get registered => 'registrado';

  @override
  String get errorLoading => 'Error al cargar';

  @override
  String get tapPlusToAddYourFirst => 'Toque + para agregar su primer';

  @override
  String get doYouWantToRemoveThe => '¿Desea eliminar el';

  @override
  String get pending => 'Pendiente';

  @override
  String get cancelInvite => 'Cancelar Invitación';

  @override
  String get userWithoutName => 'Usuario sin nombre';

  @override
  String get removeCollaborator => 'Eliminar Colaborador';

  @override
  String get emailNotProvided => 'Correo electrónico no proporcionado';

  @override
  String get emailPlaceholder => 'correo@ejemplo.com';

  @override
  String get collaboratorAdded => 'Colaborador Agregado';

  @override
  String get financial => 'Financiero';

  @override
  String get financialAccessDenied =>
      'No tiene permiso para acceder al panel financiero.\\n\\nSolo los Administradores y Gerentes pueden ver datos financieros.';

  @override
  String get week => 'Semana';

  @override
  String get month => 'Mes';

  @override
  String get year => 'Año';

  @override
  String get currentMonth => 'Mes actual';

  @override
  String get currentYear => 'Año actual';

  @override
  String get start => 'Inicio';

  @override
  String get end => 'Fin';

  @override
  String get billing => 'Facturación';

  @override
  String get composition => 'Composición';

  @override
  String get customersReceived => 'Clientes - Recibido';

  @override
  String get customersToReceive => 'Clientes - Por Recibir';

  @override
  String get customerWithoutName => 'Cliente sin nombre';

  @override
  String get serviceWithoutName => 'Servicio sin nombre';

  @override
  String get productWithoutName => 'Producto sin nombre';

  @override
  String get seeLess => 'Ver menos';

  @override
  String seeAllCount(int count) {
    return 'Ver todos ($count)';
  }

  @override
  String get errorGeneratingReport => 'Error al generar informe';

  @override
  String get pendingPayment => 'Pendiente';

  @override
  String get contacts => 'Contactos';

  @override
  String get preparing => 'Preparando...';

  @override
  String get changeLogo => 'Cambiar Logo';

  @override
  String get companyNamePlaceholder => 'Nombre de la Empresa';

  @override
  String get companyEmailPlaceholder => 'contacto@empresa.com';

  @override
  String get phonePlaceholder => '(00) 00000-0000';

  @override
  String get fullAddress => 'Dirección completa';

  @override
  String get websitePlaceholder => 'www.empresa.com';

  @override
  String get segment => 'Segmento';

  @override
  String get website => 'Sitio web';

  @override
  String get noName => 'Sin nombre';

  @override
  String get errorSendingPhoto => 'Error al Enviar Foto';

  @override
  String get couldNotSendPhoto =>
      'No se pudo enviar la foto. Intente de nuevo.';

  @override
  String get errorSendingPhotos => 'Error al Enviar Fotos';

  @override
  String get couldNotSendPhotos =>
      'No se pudieron enviar las fotos. Intente de nuevo.';

  @override
  String get requiredFields => 'Campos Requeridos';

  @override
  String get pleaseFill => 'Por favor complete:';

  @override
  String get couldNotCompleteForm =>
      'No se pudo completar el procedimiento. Intente de nuevo.';

  @override
  String get noPermissionReopenForm =>
      'Solo Administradores, Gerentes y Supervisores pueden reabrir procedimientos completados.';

  @override
  String get couldNotReopenForm =>
      'No se pudo reabrir el procedimiento. Intente de nuevo.';

  @override
  String get type => 'Escribir';

  @override
  String get errorLoadingPhoto => 'Error al cargar foto';

  @override
  String get reopen => 'Reabrir';

  @override
  String get typeOneOptionPerLine => 'Escriba una opción por línea';

  @override
  String get searchProcedure => 'Buscar procedimiento';

  @override
  String get noProceduresAvailable => 'No hay procedimientos disponibles';

  @override
  String get fromCompany => 'De la empresa';

  @override
  String get global => 'Globales';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'elementos',
      one: 'elemento',
    );
    return '$count $_temp0';
  }

  @override
  String importConfirmationMessage(String title) {
    return '¿Desea importar el procedimiento \"$title\" a su empresa?\n\nPodrá editarlo después de la importación.';
  }

  @override
  String get errorLoadingProcedures => 'Error al cargar procedimientos';

  @override
  String get importProcedure => 'Importar Procedimiento';

  @override
  String get importForMyCompany => 'Importar a Mi Empresa';

  @override
  String get couldNotImportProcedure =>
      'No se pudo importar el procedimiento. Intente de nuevo.';

  @override
  String get procedureImportedSuccessfully =>
      '¡Procedimiento importado con éxito!';

  @override
  String get closeDialog => 'Cerrar';

  @override
  String get companyLogo => 'Logo de la Empresa';

  @override
  String get information => 'INFORMACIÓN';

  @override
  String get pendingInvites => 'Invitaciones Pendientes';

  @override
  String get noPendingInvites => 'Sin invitaciones pendientes';

  @override
  String get acceptInvite => 'Aceptar';

  @override
  String get rejectInvite => 'Rechazar Invitación';

  @override
  String get inviteAccepted => 'Invitación Aceptada';

  @override
  String youAreNowPartOf(String company) {
    return '¡Ahora es parte de $company!';
  }

  @override
  String areYouSureReject(String company) {
    return '¿Está seguro de que desea rechazar la invitación de $company?';
  }

  @override
  String get or => 'o';

  @override
  String get reject => 'Rechazar';

  @override
  String invitedBy(String name) {
    return 'Invitado por $name';
  }

  @override
  String roleLabel(String role) {
    return 'Cargo: $role';
  }

  @override
  String get inviteExpired => 'Esta invitación ha expirado';

  @override
  String get inviteCancelled => 'Esta invitación fue cancelada';

  @override
  String get inviteNotFound => 'Invitación no encontrada';

  @override
  String get inviteAlreadyUsed => 'Esta invitación ya fue utilizada';

  @override
  String get enterInviteCode => 'Ingrese el código de invitación';

  @override
  String get enterCodeReceived =>
      'Ingrese el código que recibió para unirse al equipo';

  @override
  String get searchAnotherCode => 'Buscar otro código';

  @override
  String get inviteCodeCopied => '¡Código de invitación copiado!';

  @override
  String get emailOrPhone => 'Ingrese email o teléfono';

  @override
  String get thisWillRemoveAllPayments =>
      'Esto eliminará todos los pagos y descuentos registrados. ¿Desea continuar?';

  @override
  String get attention => 'Atención';

  @override
  String get financialReport => 'Informe financiero';

  @override
  String get totalBilling => 'Facturación Total';

  @override
  String get financialSummary => 'Resumen Financiero';

  @override
  String get averageTicket => 'Promedio por orden';

  @override
  String get customerRanking => 'Ranking de Clientes';

  @override
  String get serviceRanking => 'Ranking de Servicios';

  @override
  String get productRanking => 'Ranking de Productos';

  @override
  String get paidOrders => 'Órdenes Pagadas';

  @override
  String get ordersToReceive => 'Órdenes por Cobrar';

  @override
  String get vehicle => 'Vehículo';

  @override
  String get valueColumn => 'Valor';

  @override
  String get statusColumn => 'Estado';

  @override
  String get quantityShort => 'Cant';

  @override
  String get noOrdersInPeriod => 'Sin órdenes en este período';

  @override
  String get notInformed => 'No informado';

  @override
  String nOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'órdenes',
      one: 'orden',
    );
    return '$count $_temp0';
  }

  @override
  String nItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ítems',
      one: 'ítem',
    );
    return '$count $_temp0';
  }

  @override
  String get orderSingular => 'orden';

  @override
  String get orderPlural => 'ordenes';

  @override
  String generatedAt(String date) {
    return 'Generado el $date';
  }

  @override
  String pageOf(int current, int total) {
    return 'Pagina $current de $total';
  }

  @override
  String get preparingReport => 'Preparando informe...';

  @override
  String get appTagline => 'Sistema de Gestion de Ordenes de Servicio';

  @override
  String receivedWithPercent(String percent) {
    return 'Recibido ($percent%)';
  }

  @override
  String toReceiveWithPercent(String percent) {
    return 'Por Recibir ($percent%)';
  }

  @override
  String get generatedByPraticos => 'Generado por PraticOS';

  @override
  String get serviceDescriptionColumn => 'DESCRIPCION DEL SERVICIO';

  @override
  String get descriptionColumn => 'DESCRIPCION';

  @override
  String get unitShort => 'UNIT.';

  @override
  String get alreadyPaid => 'Ya pagado';

  @override
  String get remainingBalance => 'SALDO RESTANTE';

  @override
  String get totalToPay => 'TOTAL A PAGAR';

  @override
  String get photosAvailableDigitally =>
      'Fotos disponibles en el sistema digital';

  @override
  String attachedPhotosCount(int count) {
    return 'Fotos Adjuntas ($count)';
  }

  @override
  String get photoRecord => 'REGISTRO FOTOGRAFICO';

  @override
  String get partsAndProducts => 'PIEZAS Y PRODUCTOS';

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
  String get notSelected => 'No seleccionado';

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
      'Escanea el código QR o toca el botón para abrir WhatsApp y enviar el código de vinculación al bot PraticOS.';

  @override
  String linkExpiresIn(String time) {
    return 'Expira en $time';
  }

  @override
  String get openWhatsApp => 'Abrir WhatsApp';

  @override
  String get errorGeneratingToken => 'Error al generar código de vinculación';

  @override
  String get copyLink => 'Copiar Enlace';

  @override
  String get shareLink => 'Compartir Enlace';

  @override
  String get linkCopied => '¡Enlace copiado!';

  @override
  String viewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'visualizaciones',
      one: 'visualización',
    );
    return '$count $_temp0';
  }

  @override
  String get commentPlaceholder => 'Escribe tu comentario...';

  @override
  String get commentFromCustomer => 'Cliente';

  @override
  String get commentFromTeam => 'Equipo';

  @override
  String get rejectionReason => 'Motivo del rechazo';

  @override
  String get days => 'días';

  @override
  String get rating => 'Calificación';

  @override
  String get ratings => 'Calificaciones';

  @override
  String get noRatingsYet => 'Sin calificaciones aún';

  @override
  String get notNow => 'Ahora no';

  @override
  String get connectWhatsApp => 'Conecta tu WhatsApp';

  @override
  String get connectWhatsAppBannerDescription =>
      'Recibe notificaciones, gestiona órdenes de servicio y envía actualizaciones a clientes por WhatsApp.';

  @override
  String get whatsappOnboardingTitle => 'Conecta tu WhatsApp';

  @override
  String get whatsappOnboardingSubtitle =>
      'Aprovecha al máximo PraticOS conectando tu WhatsApp';

  @override
  String get whatsappBenefitNotifications =>
      'Recibe notificaciones de nuevas órdenes de servicio';

  @override
  String get whatsappBenefitManage =>
      'Gestiona órdenes de servicio directamente por chat';

  @override
  String get whatsappBenefitClients => 'Envía actualizaciones a clientes';

  @override
  String get linkNow => 'Vincular ahora';

  @override
  String get maybeLater => 'Quizás después';

  @override
  String inviteWhatsAppMessage(String code) {
    return '¡Has sido invitado al equipo en PraticOS!\n\nCódigo de invitación: $code\n\nDescarga la app:\niOS: https://apps.apple.com/br/app/praticos/id1534604555\nAndroid: https://play.google.com/store/apps/details?id=br.com.rafsoft.praticos';
  }

  @override
  String get cannotRemoveOnlyAdmin =>
      'No es posible eliminar al único administrador de la empresa. Promueva a otro colaborador a administrador primero.';

  @override
  String get cannotChangeOnlyAdminRole =>
      'No es posible cambiar el perfil del único administrador. Promueva a otro colaborador a administrador primero.';

  @override
  String get cannotRemoveSelf =>
      'No puede eliminarse a sí mismo de la empresa.';

  @override
  String get invalidInviteCompanyNotFound =>
      'Invitación inválida: empresa no encontrada.';

  @override
  String get duplicateInviteTitle => 'Invitación Existente';

  @override
  String get duplicateInviteMessage =>
      'Ya existe una invitación pendiente para este correo/teléfono.';

  @override
  String get resendExistingInvite => 'Reenviar Existente';

  @override
  String get cancelAndCreateNew => 'Cancelar y Crear Nueva';

  @override
  String get agenda => 'Agenda';

  @override
  String get noScheduledOrders => 'No hay OS programadas para este día';

  @override
  String get allTeam => 'Todo el equipo';

  @override
  String get allDay => 'Todo el día';

  @override
  String get scheduleReminder => 'Recordatorio de cita';

  @override
  String get reminderDisabled => 'Desactivado';

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
  String get inviteWhatsAppSuccessTitle => 'Colaborador Invitado';

  @override
  String inviteWhatsAppSuccessMessage(String name) {
    return '$name recibirá la invitación automáticamente al contactar al bot PraticOS en WhatsApp.';
  }

  @override
  String get serviceLocation => 'Ubicación del Servicio';

  @override
  String get openInMaps => 'Abrir en Mapa';

  @override
  String get addressPlaceholder => 'Calle, número, barrio, ciudad';

  @override
  String get sendWhatsApp => 'Enviar WhatsApp';

  @override
  String inviteWhatsAppBotMessage(String company) {
    return '¡Hola! Has sido agregado al equipo de $company en PraticOS. Envía un \"hola\" al bot para comenzar: https://wa.me/5548988794742';
  }

  @override
  String get removeDevice => 'Eliminar Dispositivo';

  @override
  String get generalNoDevice => 'General';

  @override
  String get selectDeviceFor => '¿Para cuál dispositivo?';

  @override
  String deviceCount(int count) {
    return '$count dispositivos';
  }

  @override
  String get features => 'Funcionalidades';

  @override
  String get contracts => 'Contratos';

  @override
  String get noContracts => 'Ningún contrato';

  @override
  String get recurringContract => 'Contrato recurrente';

  @override
  String get contractNextDue => 'Próxima generación';

  @override
  String generatedOrdersCount(int count) {
    return 'OS generadas ($count)';
  }

  @override
  String get selectDate => 'Seleccionar fecha';

  @override
  String get deviceStatusActive => 'Activo';

  @override
  String get deviceStatusMaintenance => 'En mantenimiento';

  @override
  String get deviceStatusInactive => 'Inactivo';

  @override
  String get deviceStatusDecommissioned => 'Desactivado';

  @override
  String get noOrderHistory => 'Ninguna orden de servicio registrada';

  @override
  String get configure => 'Configurar';

  @override
  String get interval => 'Intervalo';

  @override
  String get indefinite => 'Indefinido';

  @override
  String get noOrdersDueOnDate => 'Ninguna OS con vencimiento en este día';

  @override
  String get documents => 'Documentos';

  @override
  String get addDocument => 'Agregar Documento';

  @override
  String get receipt => 'Comprobante';

  @override
  String get invoice => 'Factura';

  @override
  String get contract => 'Contrato';

  @override
  String get deleteDocument => 'Eliminar Documento';

  @override
  String get confirmDeleteDocument =>
      '¿Está seguro que desea eliminar este documento?';

  @override
  String get documentAdded => 'Documento agregado';

  @override
  String get openDocument => 'Abrir';

  @override
  String get fromFiles => 'Archivos';

  @override
  String get errorUploadingDocument => 'Error al enviar documento';

  @override
  String get engagementReminders => 'Recordatorios';

  @override
  String get dailyNotificationTitle => '¡Buenos días!';

  @override
  String get dailyNotificationBody => 'Registre las OS del día en PraticOS';

  @override
  String get inactivity3dTitle => '¡Te extrañamos!';

  @override
  String get inactivity3dBody =>
      'No abres PraticOS hace 3 días. ¿Qué tal registrar tus OS?';

  @override
  String get inactivity5dTitle => '¡Tus OS te esperan!';

  @override
  String get inactivity5dBody =>
      '¡Ya pasaron 5 días! No pierdas el control de tus órdenes de servicio.';

  @override
  String get inactivity7dTitle => '¡No dejes PraticOS parado!';

  @override
  String get inactivity7dBody =>
      'Hace 1 semana que no abres la app. ¡Vuelve y organiza tus OS!';

  @override
  String get pendingOsNotificationTitle => 'OS pendientes necesitan atención';

  @override
  String pendingOsNotificationBody(int count) {
    return 'Tienes $count OS detenidas hace más de 7 días.';
  }

  @override
  String get termsOfService => 'Términos y Condiciones';

  @override
  String get termsOfServicePlaceholder =>
      'Ej: Equipos no retirados en 90 días podrán ser descartados...';

  @override
  String get useDefaultTerms => 'Usar texto predeterminado del segmento';

  @override
  String get pdfTermsAndConditions => 'Terminos y Condiciones';

  @override
  String get pdfCompanySignature => 'Responsable';

  @override
  String get pdfClientSignature => 'Cliente';

  @override
  String get pdfTechnician => 'Tecnico';

  @override
  String get pdfCreatedDate => 'Creada';

  @override
  String get pdfCompletedDate => 'Completada';

  @override
  String get pdfIssuedDate => 'Emitida';

  @override
  String get pdfServicesSubtotal => 'Subtotal Servicios';

  @override
  String get pdfPartsSubtotal => 'Subtotal Repuestos';

  @override
  String get pdfPaid => 'Pagado';

  @override
  String get pdfUnitValue => 'Valor Unit.';

  @override
  String get pdfServiceType => 'Servicio';

  @override
  String get pdfProductType => 'Repuesto';

  @override
  String get pdfItemType => 'Tipo';

  @override
  String get pdfSummary => 'Resumen';

  @override
  String get pdfGeneral => 'General';

  @override
  String get pdfTrackOnline => 'Seguimiento online';

  @override
  String get pdfTrackOnlineDescription =>
      'Escanee el codigo QR para rastrear esta orden de servicio';

  @override
  String get pdfEquipment => 'Equipo';

  @override
  String get upgrade => 'Actualizar plan';

  @override
  String get formTemplates => 'formularios';

  @override
  String featureGateNearLimit(int count, String feature) {
    return 'Quedan $count $feature';
  }

  @override
  String featureGateLimitReached(String feature) {
    return 'Límite de $feature alcanzado';
  }

  @override
  String featureGateUpgradeSuggestion(String plan) {
    return 'Actualiza al plan $plan para más';
  }

  @override
  String featureGateUsageInfo(int current, int limit) {
    return 'Usado $current de $limit';
  }

  @override
  String get featureGateLimitModalTitle => 'Límite alcanzado';

  @override
  String get subscription => 'Suscripción';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get restorePurchasesSuccess => 'Compras restauradas con éxito';

  @override
  String get restorePurchasesError =>
      'Error al restaurar compras. Inténtelo de nuevo.';

  @override
  String get success => 'Éxito';

  @override
  String get free => 'Gratis';

  @override
  String renewsOn(String date) {
    return 'Renueva el $date';
  }

  @override
  String get manageInStore => 'Gestionar en tienda de apps';

  @override
  String get restore => 'Restaurar';

  @override
  String get currentPlan => 'Plan actual';

  @override
  String featureLimitReached(String feature) {
    return 'Ha alcanzado el límite de $feature';
  }

  @override
  String get photoLimitReachedMessage =>
      'Has alcanzado el límite de fotos de este mes.';

  @override
  String get photoLimitUpgradeHint => 'Mejora tu plan para agregar más fotos.';

  @override
  String get viewPlans => 'Ver planes';

  @override
  String get askAdminToChangePlanTitle => 'Habla con el administrador';

  @override
  String get askAdminToChangePlan =>
      'Pide al administrador de la empresa que cambie el plan.';

  @override
  String get subscriptionUnavailable =>
      'Las suscripciones no están disponibles ahora. Inténtalo de nuevo más tarde.';

  @override
  String get restorePurchasesNothingFound =>
      'No se encontró ninguna suscripción activa en esta cuenta de la tienda.';

  @override
  String get planLimitUpgradeHint =>
      'Suscríbete a un plan para aumentar este límite.';

  @override
  String get deleteAccountStoreSubscriptionWarning =>
      'Eliminar la cuenta no cancela la suscripción de App Store o Google Play. Cancélala antes en los ajustes de la tienda para que no se te cobre de nuevo.';

  @override
  String get asaasConnected => 'Conectado';

  @override
  String get asaasDisconnected => 'No conectado';

  @override
  String get asaasConnectTitle => 'Conectar cuenta Asaas';

  @override
  String get asaasConnectStep1 =>
      '1. En el panel de Asaas, abre Integraciones > Claves de API.';

  @override
  String get asaasConnectStep2 => '2. Genera una nueva clave y cópiala.';

  @override
  String get asaasConnectStep3 => '3. Pega la clave abajo y toca Conectar.';

  @override
  String get asaasOpenPanel => 'Abrir panel de Asaas';

  @override
  String get asaasOpenSandboxPanel => 'Abrir panel de prueba (sandbox)';

  @override
  String get asaasApiKey => 'Clave de API';

  @override
  String get asaasApiKeyPlaceholder => 'Pega la clave aquí';

  @override
  String get asaasApiKeyHint =>
      'La clave se guarda cifrada en el servidor y no vuelve a mostrarse en la app.';

  @override
  String get asaasConnect => 'Conectar';

  @override
  String get asaasAccount => 'Cuenta';

  @override
  String get asaasEnvironment => 'Entorno';

  @override
  String get asaasEnvironmentSandbox => 'Prueba';

  @override
  String get asaasEnvironmentProduction => 'Producción';

  @override
  String get asaasDisconnect => 'Desconectar';

  @override
  String get asaasDisconnectConfirm =>
      '¿Desconectar la cuenta Asaas? Los cobros abiertos siguen en Asaas, pero los pagos dejarán de actualizar la orden.';

  @override
  String get asaasErrorInvalidKey =>
      'Clave de API inválida. Revísala e inténtalo de nuevo.';

  @override
  String get asaasErrorForbidden => 'No tienes permiso para esta acción.';

  @override
  String get asaasErrorNotConnected =>
      'Conecta la cuenta Asaas en Configuración > Integraciones.';

  @override
  String get asaasErrorExceedsBalance =>
      'El monto es mayor que el saldo de la orden.';

  @override
  String get asaasErrorTaxIdRequired => 'Ingresa el CPF o CNPJ del cliente.';

  @override
  String get asaasErrorCustomerRequired =>
      'Agrega un cliente a la orden antes de cobrar.';

  @override
  String get asaasErrorGeneric => 'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get invalidTaxId => 'CPF o CNPJ inválido';

  @override
  String get chargeValue => 'Monto';

  @override
  String chargeBalanceHint(String value) {
    return 'Saldo de la orden: $value';
  }

  @override
  String get chargeSingleHint => 'El cliente elige Pix, boleto o tarjeta.';

  @override
  String chargeInstallmentOption(int count, String value) {
    return '${count}x de $value';
  }

  @override
  String get chargeDueDate => 'Vencimiento';

  @override
  String get chargeTaxIdHint =>
      'Asaas exige CPF o CNPJ. Se guarda en el registro del cliente.';

  @override
  String get chargeStatusPending => 'Esperando pago';

  @override
  String get chargeStatusOverdue => 'Vencido';

  @override
  String get chargeStatusPaid => 'Pagado';

  @override
  String get chargeStatusCanceled => 'Cancelado';

  @override
  String get chargeStatusRefunded => 'Reembolsado';

  @override
  String get chargeCancelConfirm =>
      'El cliente ya no podrá pagar con este enlace.';

  @override
  String get chargeKeep => 'Mantener';

  @override
  String get chargeReplaceTitle => 'Ya hay un cobro abierto';

  @override
  String get chargeReplaceConfirm =>
      'Generar un nuevo cobro cancela el anterior en Asaas.';

  @override
  String get chargeReplace => 'Generar nuevo';

  @override
  String get asaasErrorInstallmentsInProgress =>
      'Este plan de cuotas ya tiene cuotas pagadas. Espera a que termine o reembolsa en Asaas.';

  @override
  String get asaasErrorCustomerChargeOpen =>
      'Esta OS ya está en un link de cobro de varias OS del cliente. Cancela ese link en Recibir del cliente.';

  @override
  String get asaasErrorChargeSuperseded =>
      'Otro link para estas OS se creó al mismo tiempo y es el que vale. Míralo en la OS o en el cliente.';

  @override
  String get asaasErrorPreviousLinkCanceled =>
      'Un link anterior se canceló, pero el nuevo no se creó. Envía un link nuevo.';

  @override
  String get asaasErrorOrderNotPayable =>
      'Presupuestos y OS canceladas no se pueden cobrar.';

  @override
  String get asaasErrorOrderCanceled =>
      'Esta orden está cancelada y no se puede cobrar.';

  @override
  String get asaasErrorInvalidDueDate =>
      'Fecha de vencimiento inválida. Elige hoy o una fecha futura.';

  @override
  String get asaasErrorInvalidInstallmentCount =>
      'Número de cuotas inválido. Elige de 2 a 12.';

  @override
  String get asaasErrorChargeNotOpen => 'Este cobro ya no está abierto.';

  @override
  String get asaasErrorValidation =>
      'Asaas rechazó los datos del cobro. Revisa el CPF/CNPJ y el correo del cliente.';

  @override
  String get asaasErrorUnavailable =>
      'Asaas no está disponible en este momento. Inténtalo de nuevo en unos instantes.';

  @override
  String get listLoadError =>
      'No se pudo cargar. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get pickCustomerTitle => '¿Quién es el cliente?';

  @override
  String get searchCustomerPlaceholder => 'Buscar por nombre, teléfono o placa';

  @override
  String plateValue(String plate) {
    return 'Placa $plate';
  }

  @override
  String get customerNamePlaceholder => 'Ej.: Ana Ribeiro';

  @override
  String get customerNameRequired => 'Escribe el nombre del cliente';

  @override
  String get customerPhoneLabel => 'Teléfono o WhatsApp';

  @override
  String get customerPhoneHint =>
      'Se usa para enviar el presupuesto y el aviso de listo.';

  @override
  String get moreCustomerData => 'Más datos (correo, documento, dirección)';

  @override
  String get openInMap => 'Abrir en el mapa';

  @override
  String get callAction => 'Llamar';

  @override
  String newOrderFor(String name) {
    return 'Nueva orden para $name';
  }

  @override
  String devicesOfCustomer(String devices, String name) {
    return '$devices de $name';
  }

  @override
  String get totalSpent => 'Total gastado';

  @override
  String deleteCustomerTitle(String name) {
    return '¿Borrar a $name?';
  }

  @override
  String get deleteCustomerKeepsOrders => 'Las órdenes siguen guardadas.';

  @override
  String get deleteAction => 'Borrar';

  @override
  String get noCustomersYet => 'Aún no tienes clientes';

  @override
  String get addFirstCustomer => 'Registrar el primer cliente';

  @override
  String noCustomerMatching(String query) {
    return 'Ningún cliente con “$query”';
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
      other: '$count órdenes abiertas',
      one: '1 orden abierta',
    );
    return '$_temp0';
  }

  @override
  String lateOrdersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count órdenes atrasadas',
      one: '1 orden atrasada',
    );
    return '$_temp0';
  }

  @override
  String get customerActions => 'Más acciones del cliente';

  @override
  String get customerLookupError =>
      'No se pudo cargar los clientes. Inténtalo de nuevo.';

  @override
  String get catalogTitle => 'Catálogo';

  @override
  String get catalogNewService => 'Nuevo servicio';

  @override
  String get catalogNewProduct => 'Nuevo producto';

  @override
  String get saveServiceButton => 'Guardar servicio';

  @override
  String get saveProductButton => 'Guardar producto';

  @override
  String get serviceNameHint => 'Ej.: Cambio de aceite';

  @override
  String get productNameHint => 'Ej.: Filtro de aceite';

  @override
  String get serviceNameRequired => 'Escribe el nombre del servicio';

  @override
  String get productNameRequired => 'Escribe el nombre del producto';

  @override
  String get catalogPriceLabel => 'Precio';

  @override
  String get catalogPriceHint =>
      'Puedes dejarlo en blanco y acordar el precio en cada OS.';

  @override
  String get addServicePhoto => 'Foto del servicio';

  @override
  String get addProductPhoto => 'Foto del producto';

  @override
  String get catalogNoPrice => 'sin valor';

  @override
  String get catalogEmptyServices => 'Aún no tienes servicios';

  @override
  String get catalogEmptyServicesHint =>
      'Registra los que más haces para armar la OS más rápido.';

  @override
  String get catalogEmptyProducts => 'Aún no tienes productos';

  @override
  String get catalogEmptyProductsHint =>
      'Registra los que más usas para armar la OS más rápido.';

  @override
  String catalogNoMatch(String query) {
    return 'Nada con “$query”';
  }

  @override
  String catalogDeleteTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get catalogDeleteMessage =>
      'Sale del catálogo. Las OS que ya lo usan siguen guardadas.';

  @override
  String get deleteServiceAction => 'Borrar servicio';

  @override
  String get deleteProductAction => 'Borrar producto';

  @override
  String get catalogItemActions => 'Más acciones del ítem';

  @override
  String get pickServiceTitle => '¿Qué servicio?';

  @override
  String get pickProductTitle => '¿Qué producto?';

  @override
  String get catalogLoadError =>
      'No se pudo cargar el catálogo. Inténtalo de nuevo.';

  @override
  String newEntity(String entity) {
    return 'Nuevo $entity';
  }

  @override
  String get photoAndMoreData => 'Foto y más datos';

  @override
  String fieldRequiredHint(String field) {
    return 'Completa el campo $field';
  }

  @override
  String useValue(String value) {
    return 'Usar “$value”';
  }

  @override
  String get newOrderAction => 'Nueva OS';

  @override
  String get deviceActions => 'Más acciones';

  @override
  String deleteDeviceTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get deleteDeviceKeepsOrders => 'Las OS siguen guardadas.';

  @override
  String get deviceDetailsLabel => 'Datos';

  @override
  String orderNewTitle(String order) {
    return 'Nueva $order';
  }

  @override
  String orderNumberTitle(String order, String number) {
    return '$order $number';
  }

  @override
  String get orderItemsSection => 'Qué se va a hacer';

  @override
  String get orderItemSearchPlaceholder => 'Buscar servicio o pieza';

  @override
  String get orderCreateItemError => 'No se pudo crear. Inténtelo de nuevo.';

  @override
  String get orderCatalogEmpty =>
      'Su catálogo está vacío. Escriba el nombre en la búsqueda para crear.';

  @override
  String get orderMostUsed => 'Más usados';

  @override
  String get orderAllItems => 'Todos';

  @override
  String get orderItemKindService => 'servicio';

  @override
  String get orderItemKindProduct => 'producto';

  @override
  String orderItemQuantityValue(String count) {
    return '$count unidades';
  }

  @override
  String get orderItemPrice => 'Precio';

  @override
  String get orderItemPriceHint =>
      'Puede dejarlo en blanco: el ítem queda sin valor y fuera del total.';

  @override
  String get orderItemQuantity => 'Cantidad';

  @override
  String get orderItemLess => 'Uno menos';

  @override
  String get orderItemMore => 'Uno más';

  @override
  String get orderItemRemove => 'Quitar de la OS';

  @override
  String get orderTotalLabel => 'Total';

  @override
  String orderRemainingToReceive(String amount) {
    return 'Falta cobrar $amount';
  }

  @override
  String get orderFullyPaid => 'Todo pagado';

  @override
  String get orderSaveNeedsCustomer => 'Elija el cliente para guardar.';

  @override
  String get orderDiscardTitle => '¿Salir sin guardar?';

  @override
  String get orderDiscardMessage => 'Lo que completó se perderá.';

  @override
  String get orderKeepEditing => 'Seguir editando';

  @override
  String orderPickDevice(String device) {
    return 'Elegir $device';
  }

  @override
  String get orderTalkAction => 'Decir qué hacer';

  @override
  String orderNextStepReceive(String amount) {
    return 'Cobrar $amount';
  }

  @override
  String orderMenuAddTo(String order) {
    return 'Agregar a la $order';
  }

  @override
  String get orderMenuSendToCustomer => 'Enviar al cliente';

  @override
  String orderMenuCancel(String order) {
    return 'Cancelar $order';
  }

  @override
  String orderMenuDelete(String order) {
    return 'Eliminar $order';
  }

  @override
  String get orderAddDueDate => 'Fecha de entrega';

  @override
  String orderAddAnotherDevice(String device) {
    return 'Otro $device';
  }

  @override
  String orderCancelConfirmTitle(String order) {
    return '¿Cancelar $order?';
  }

  @override
  String get orderCancelConfirmMessage =>
      'Pasa a las canceladas y se puede reabrir.';

  @override
  String orderDeleteConfirmTitle(String order) {
    return '¿Eliminar $order?';
  }

  @override
  String get orderDeleteConfirmMessage => 'No se puede deshacer.';

  @override
  String get orderPhotosSection => 'Fotos';

  @override
  String orderUnpricedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ítems sin valor, fuera del total',
      one: '1 ítem sin valor, fuera del total',
    );
    return '$_temp0';
  }

  @override
  String orderPendingChecklists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan terminar $count checklists',
      one: 'Falta terminar 1 checklist',
    );
    return '$_temp0';
  }

  @override
  String get orderMoreActions => 'Más acciones';

  @override
  String get filterOpen => 'Abiertas';

  @override
  String get filterAll => 'Todas';

  @override
  String get filterMine => 'Mías';

  @override
  String get nextVisitLabel => 'Ahora';

  @override
  String homeWithYouToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contigo hoy',
      one: '1 contigo hoy',
    );
    return '$_temp0';
  }

  @override
  String homeWithYou(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contigo',
      one: '1 contigo',
    );
    return '$_temp0';
  }

  @override
  String nextVisit(String customer, String time) {
    return 'Siguiente: $customer, a las $time.';
  }

  @override
  String nextVisitDevice(String customer, String device, String time) {
    return 'Siguiente: $customer, $device, a las $time.';
  }

  @override
  String openOrderNumber(String number) {
    return 'Abrir OS $number';
  }

  @override
  String get noOrdersWithYou => 'Ninguna OS contigo.';

  @override
  String homeOpenCount(int count) {
    return '$count abiertas';
  }

  @override
  String get seeAllOrders => 'Ver todas';

  @override
  String notificationsA11y(int count) {
    return 'Avisos, $count nuevos';
  }

  @override
  String get howItWorks => 'Cómo funciona';

  @override
  String get firstOrderLabel => 'Empieza aquí';

  @override
  String get homeNoOrdersYet => 'Ninguna todavía';

  @override
  String get howItWorksStep1 => '1. Anota lo que se va a hacer';

  @override
  String get howItWorksStep1Detail => 'cliente y servicios';

  @override
  String howItWorksStep1DetailDevice(String device) {
    return 'cliente, $device y servicios';
  }

  @override
  String get howItWorksStep2 => '2. Envía el presupuesto';

  @override
  String get howItWorksStep2Detail => 'por WhatsApp, con un enlace';

  @override
  String get howItWorksStep3 => '3. Cobra y entrega';

  @override
  String get howItWorksStep3Detail => 'la app recuerda quién falta pagar';

  @override
  String get searchNotFoundLoaded => 'No lo encontré en las OS cargadas.';

  @override
  String get searchOlder => 'Buscar en las más antiguas';

  @override
  String get noOpenOrders => 'Ninguna OS abierta.';

  @override
  String get noOrdersInView => 'Nada por aquí.';

  @override
  String get loadOrdersError => 'No se pudieron cargar las OS.';

  @override
  String orderLateMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada hace $count meses',
      one: 'Atrasada hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String orderLateYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada hace $count años',
      one: 'Atrasada hace 1 año',
    );
    return '$_temp0';
  }

  @override
  String orderLateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Atrasada $count días',
      one: 'Atrasada 1 día',
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
  String get yourAccount => 'Tu cuenta';

  @override
  String get yourCompany => 'Tu empresa';

  @override
  String get catalog => 'Catálogo';

  @override
  String get planTitle => 'Plan';

  @override
  String get advancedTitle => 'Avanzado';

  @override
  String get deleteMyAccount => 'Eliminar mi cuenta';

  @override
  String get howYouWork => 'Cómo trabajas';

  @override
  String get valuesAndBilling => 'Valores y cobros';

  @override
  String get valuesAndBillingHint =>
      'Precios en la OS, cobros y pestaña Finanzas';

  @override
  String get valuesAndBillingOffTitle => '¿Desactivar valores y cobros?';

  @override
  String get valuesAndBillingOffMessage =>
      'Precios, totales, cobros y la pestaña Finanzas desaparecen para todo el equipo. No se borra nada: los valores vuelven si lo activas de nuevo. Los enlaces de pago ya enviados siguen siendo válidos.';

  @override
  String get valuesAndBillingOffAction => 'Desactivar';

  @override
  String get valuesAndBillingSaveError =>
      'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get joinWithInviteCode => 'Entrar con código de invitación';

  @override
  String get followsPhoneSettings =>
      'El idioma y la apariencia siguen los ajustes del iPhone.';

  @override
  String get invitePerson => 'Invitar persona';

  @override
  String get inviteWhoLabel => 'Nombre (opcional)';

  @override
  String get inviteWhoPlaceholder => 'Ej.: Lucas Silva';

  @override
  String get inviteEmailLabel => 'Correo electrónico';

  @override
  String get inviteEmailHint =>
      'La persona entra con este correo y la invitación aparece sola.';

  @override
  String get inviteWhatsAppLabel => 'WhatsApp (opcional)';

  @override
  String get inviteRoleLabel => 'Qué puede hacer';

  @override
  String get inviteRoleQuestion => '¿Qué puede hacer?';

  @override
  String get createInvite => 'Crear invitación';

  @override
  String get userWillReceiveInviteByWhatsAppHint =>
      'Después envías el código a este número o por otra app.';

  @override
  String get financialLoadError => 'No se pudo cargar las finanzas.';

  @override
  String financialEmptyMonth(String month) {
    return 'Ninguna orden en $month.';
  }

  @override
  String get financialToReceive => 'Falta cobrar';

  @override
  String financialOrderSince(int number, String date) {
    return 'Orden $number · desde $date';
  }

  @override
  String financialOrdersSince(int count, String date) {
    return '$count órdenes · desde $date';
  }

  @override
  String get financialOtherPeriod => 'Otro período';

  @override
  String get financialPreviousMonth => 'Mes anterior';

  @override
  String get financialNextMonth => 'Mes siguiente';

  @override
  String financialNextStep(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clientes',
      one: '1 cliente',
    );
    return 'Falta cobrar $amount de $_temp0';
  }

  @override
  String financialOldestDebt(String name, String amount, String date) {
    return '$name debe desde hace más tiempo: $amount desde $date.';
  }

  @override
  String financialSendChargeTo(String name) {
    return 'Enviar cobro a $name';
  }

  @override
  String financialPickOrderTitle(String name) {
    return 'Órdenes abiertas de $name';
  }

  @override
  String financialOrderOption(int number, String amount, String date) {
    return 'Orden $number · $amount · desde $date';
  }

  @override
  String get receiveTitle => 'Cobrar';

  @override
  String get receiveMissing => 'Falta por cobrar';

  @override
  String get receiveAllDone => 'Todo cobrado';

  @override
  String receiveButton(String amount) {
    return 'Recibí $amount';
  }

  @override
  String get receiveAttachReceipt => 'Adjuntar comprobante';

  @override
  String get receiveAlreadyReceived => 'Ya cobrado';

  @override
  String get receiveWithReceipt => 'con comprobante';

  @override
  String get receiveNoReceipt => 'sin comprobante';

  @override
  String get receiveViaPix => 'Pix por enlace';

  @override
  String get receiveViaBoleto => 'Boleto por enlace';

  @override
  String get receiveViaCard => 'Tarjeta por enlace';

  @override
  String get receiveViaLink => 'Por enlace';

  @override
  String get receiveGiveDiscount => 'Dar descuento';

  @override
  String get receiveUndoPayments => 'Deshacer pagos';

  @override
  String receiveDiscountNewTotal(String from, String to) {
    return 'El total pasa de $from a $to';
  }

  @override
  String get receiveViewReceipt => 'Ver comprobante';

  @override
  String get receiveRemovePayment => 'Quitar este pago';

  @override
  String receiveRecordedBy(String name, String date) {
    return 'Anotado por $name el $date';
  }

  @override
  String receiveRecordedAuto(String date) {
    return 'La app lo anotó sola el $date';
  }

  @override
  String get receiveMoreOptions => 'Más opciones';

  @override
  String get receiveRemoveReceipt => 'Quitar comprobante';

  @override
  String get receiveWhen => 'Cuándo';

  @override
  String receiveCustomerTitle(String name) {
    return 'Recibir de $name';
  }

  @override
  String receiveCustomerOwes(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS',
      one: '1 OS',
    );
    return 'Debe $amount en $_temp0';
  }

  @override
  String get receiveCustomerAmountLabel => 'Cuánto recibió';

  @override
  String get receiveCustomerHowItGoes => 'Cómo queda';

  @override
  String get receiveCustomerOldestFirst =>
      'El valor va primero a las OS más antiguas.';

  @override
  String receiveCustomerSettles(int number, String amount) {
    return 'OS $number · se salda con $amount';
  }

  @override
  String receiveCustomerPartial(int number, String amount, String left) {
    return 'OS $number · recibe $amount, quedan $left';
  }

  @override
  String receiveCustomerUntouched(int number, String amount) {
    return 'OS $number · sigue $amount';
  }

  @override
  String receiveCustomerTooMuch(String total) {
    return 'Supera lo que debe ($total).';
  }

  @override
  String get receiveCustomerZero => 'Escriba cuánto recibió.';

  @override
  String receiveCustomerDone(String amount, String name) {
    return 'Recibido $amount de $name';
  }

  @override
  String get receiveCustomerUploadFailed =>
      'No se pudo enviar el comprobante. Revise la conexión e intente de nuevo.';

  @override
  String get receiveCustomerSendCharge => 'Enviar cobro';

  @override
  String receiveCustomerChargeIntro(String name, int count, String numbers) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'las OS $numbers',
      one: 'la OS $numbers',
    );
    return '$name recibe un solo enlace para pagar $_temp0 con Pix, boleto o tarjeta.';
  }

  @override
  String receiveCustomerChargeOwedHint(String value) {
    return 'Pendiente en esas OS: $value';
  }

  @override
  String receiveCustomerOpenCharge(String amount) {
    return 'Enlace abierto de $amount';
  }

  @override
  String receiveCustomerOpenChargeDetail(String numbers, String date) {
    return 'OS $numbers · vence $date';
  }

  @override
  String get receiveCustomerChargeMenu => 'Acciones del enlace';

  @override
  String get receiveCustomerShareCharge => 'Enviar el enlace de nuevo';

  @override
  String receiveCustomerChargeCancelTitle(String amount) {
    return '¿Cancelar el enlace de $amount?';
  }

  @override
  String get receiveCustomerChargeCanceled => 'Enlace cancelado';

  @override
  String receiveCustomerOthersTitle(String name) {
    return 'Otras OS de $name';
  }

  @override
  String get receiveCustomerOthersNote =>
      'Hechas por otra persona. Para incluirlas, toque Elegir las OS.';

  @override
  String get receiveCustomerOffline =>
      'Sin internet. Para recibir en OS de otra persona necesita estar conectado.';

  @override
  String get receiveCustomerChooseOrders => 'Elegir las OS';

  @override
  String get receiveCustomerPickTitle => '¿Qué OS está pagando?';

  @override
  String receiveCustomerPickRow(int number) {
    return 'OS $number';
  }

  @override
  String receiveCustomerPickSubtitle(String amount, String date) {
    return 'Falta $amount · $date';
  }

  @override
  String get receiveCustomerChosenOnly =>
      'El valor va solo a las OS elegidas, primero la más antigua.';

  @override
  String receiveCustomerTooMuchChosen(String total) {
    return 'Supera lo que falta en estas OS ($total).';
  }

  @override
  String get receiptTitle => 'Cobro';

  @override
  String receiptRowSettled(int number, String amount) {
    return 'OS $number · $amount · saldada';
  }

  @override
  String receiptRowOpen(int number, String amount, String left) {
    return 'OS $number · $amount · falta $left';
  }

  @override
  String receiptSendTo(String name) {
    return 'Enviar recibo a $name';
  }

  @override
  String get receiptSend => 'Enviar recibo';

  @override
  String get receiptActions => 'Más opciones del cobro';

  @override
  String get receiptUndo => 'Deshacer cobro';

  @override
  String receiptUndoTitle(String amount) {
    return '¿Deshacer el cobro de $amount?';
  }

  @override
  String receiptUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OS',
      one: '1 OS',
    );
    return 'El valor sale de $_temp0 y vuelve a faltar cobrar.';
  }

  @override
  String get receiptUndone => 'Cobro deshecho';

  @override
  String get receiptCanceled => 'Este cobro fue deshecho.';

  @override
  String get receiptPartOfGroup =>
      'Este pago es parte de un cobro de varias OS. Para deshacerlo, abra el cobro.';

  @override
  String get receiptOpen => 'Abrir cobro';

  @override
  String get receiptsSection => 'Cobros';

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
  String get receiptNotFound => 'No encontramos este cobro.';

  @override
  String get pdfReceiptTitle => 'Recibo';

  @override
  String pdfReceiptNumber(String number) {
    return 'N.º $number';
  }

  @override
  String pdfReceiptSentence(String name, String amount, String date) {
    return 'Recibimos de $name la cantidad de $amount el $date.';
  }

  @override
  String get pdfReceiptOrderColumn => 'OS';

  @override
  String get pdfReceiptPaidColumn => 'Pagado ahora';

  @override
  String get pdfReceiptOpenColumn => 'Aún falta';

  @override
  String get pdfReceiptDescriptionColumn => 'Descripción';

  @override
  String get pdfReceiptTotal => 'Total recibido';

  @override
  String pdfReceiptRemaining(String amount) {
    return 'Falta cobrar $amount de estas OS.';
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
  String get loginTitle => 'Entra para empezar';

  @override
  String get loginSubtitle =>
      'Tus órdenes quedan guardadas y tu equipo ve las mismas.';

  @override
  String get loginWithEmailLink => 'Entrar con correo y contraseña';

  @override
  String get errorSignInAppleFriendly =>
      'No se pudo entrar con Apple. Inténtalo de nuevo.';

  @override
  String get errorSignInGoogleFriendly =>
      'No se pudo entrar con Google. Inténtalo de nuevo.';

  @override
  String get forgotPasswordQuestion => '¿Olvidaste tu contraseña?';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get onboardingSegmentTitle => 'Tu rubro';

  @override
  String get onboardingInviteCode => 'Recibí un código de invitación';

  @override
  String get onboardingSegmentsError =>
      'No se pudieron cargar los rubros. Revisa la conexión.';

  @override
  String get onboardingSpecialtiesTitle => 'Especialidades';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingBusinessTitle => 'Tu negocio';

  @override
  String get onboardingBusinessName => '¿Cómo se llama tu negocio?';

  @override
  String get onboardingBusinessNamePlaceholder => 'Ej.: Taller de Pepe';

  @override
  String get onboardingBusinessNameRequired =>
      'Escribe el nombre de tu negocio.';

  @override
  String get onboardingPhoneLabel => 'Teléfono (opcional)';

  @override
  String get onboardingPhoneHint =>
      'Aparece en el presupuesto que recibe el cliente.';

  @override
  String get onboardingSamplesInfo =>
      'Pondremos algunas órdenes de ejemplo para que veas cómo queda. Las borras cuando quieras.';

  @override
  String get onboardingCreate => 'Crear mi PraticOS';

  @override
  String get onboardingStartWithoutSamples => 'Empezar sin ejemplos';

  @override
  String get onboardingPreparing => 'Preparando tu PraticOS…';

  @override
  String get onboardingCreateError =>
      'No se pudo terminar. Revisa la conexión e inténtalo de nuevo.';

  @override
  String get receivedWhichOrder => '¿En qué OS?';

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
    return '$photos y $pdfs';
  }

  @override
  String receivedSavedInOrder(String number, String summary) {
    return 'Guardado en la OS $number · $summary';
  }

  @override
  String get receivedSaveFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get receivedOpenOrder => 'Abrir la OS';

  @override
  String get inviteGenericError =>
      'No se pudo completar. Revisa tu internet e inténtalo de nuevo.';

  @override
  String get inviteLoadError =>
      'No se pudieron cargar las invitaciones. Revisa tu internet.';

  @override
  String inviteTitleOne(String company) {
    return '$company te invitó al equipo';
  }

  @override
  String inviteInvitedByAs(String name, String role) {
    return 'Invitado por $name · entras como $role';
  }

  @override
  String inviteEntersAs(String role) {
    return 'Entras como $role';
  }

  @override
  String get inviteJoinTeam => 'Entrar al equipo';

  @override
  String get inviteDecline => 'Rechazar invitación';

  @override
  String get inviteHaveAnotherCode => 'Tengo otro código';

  @override
  String get inviteCreateOwnCompany => 'Crear mi propia empresa';

  @override
  String get inviteCodePlaceholder => 'Ej.: 7K2P9QXA';

  @override
  String get segmentLoadError =>
      'No se pudo abrir tu empresa. Revisa tu internet e inténtalo de nuevo.';

  @override
  String get orderAssistantAddPhoto => 'Sacar otra foto';

  @override
  String get orderAssistantTakePhoto => 'Sacar una foto';

  @override
  String orderAssistantCustomerGuess(String name) {
    return 'Escuché “$name”. Toca para elegir el cliente';
  }

  @override
  String orderAssistantDeviceGuess(String device) {
    return '“$device” no está registrado';
  }

  @override
  String get orderAssistantErrorDisabled =>
      'El asistente aún no está disponible para tu empresa.';

  @override
  String orderAssistantErrorQuota(String limit) {
    return 'Ya usaste las $limit solicitudes del asistente de este mes. Puedes seguir completando a mano.';
  }

  @override
  String get orderAssistantErrorUnavailable =>
      'No se pudo leer ahora. Intenta de nuevo o completa a mano.';

  @override
  String get orderAssistantNothingFound =>
      'No encontré qué agregar. Intenta de nuevo o completa a mano.';

  @override
  String get reportPreviousPeriod => 'Período anterior';

  @override
  String get reportNextPeriod => 'Período siguiente';

  @override
  String get orderAddChecklist => 'Checklist';

  @override
  String get orderAddComment => 'Comentario';

  @override
  String get orderAddAddress => 'Dirección del servicio';

  @override
  String get orderAddSchedule => 'Agendar día y hora';

  @override
  String get orderAddDiscount => 'Descuento';

  @override
  String orderChecklistMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count preguntas',
      one: 'Falta 1 pregunta',
    );
    return '$_temp0';
  }

  @override
  String get orderAddressChange => 'Cambiar dirección';

  @override
  String get orderAddressRemove => 'Quitar dirección';

  @override
  String get orderScheduleRemove => 'Quitar agenda';

  @override
  String orderContractSummary(String frequency, String date) {
    return '$frequency · próxima el $date';
  }

  @override
  String get orderUploading => 'Enviando…';

  @override
  String otherDevicesSection(String devices) {
    return 'Otros $devices';
  }

  @override
  String accumulatedDeleteConfirm(String value) {
    return '¿Borrar “$value”?';
  }

  @override
  String accumulatedUse(String value) {
    return 'Usar “$value”';
  }

  @override
  String get accumulatedLeaveBlank => 'Dejar en blanco';

  @override
  String get moreSectionCompany => 'Empresa';

  @override
  String get moreSectionRecords => 'Registros';

  @override
  String get moreSectionYou => 'Tú';

  @override
  String get moreCompanySubtitle => 'Datos en la OS, rubro y funciones';

  @override
  String moreCatalogSubtitle(String products) {
    return 'Servicios y $products';
  }

  @override
  String planHeaderRenews(String plan, String date) {
    return '$plan · se renueva el $date';
  }

  @override
  String planHeaderValidUntil(String plan, String date) {
    return '$plan · válido hasta el $date';
  }

  @override
  String planHeaderCourtesy(String plan, String date) {
    return '$plan · cortesía hasta el $date';
  }

  @override
  String planHeaderPaymentIssue(String plan) {
    return '$plan · problema con el pago';
  }

  @override
  String get planLimitLabel => 'Límite del plan';

  @override
  String planLimitTeam(String used, String limit) {
    return 'El equipo ya tiene $used de $limit personas. Para invitar a alguien más, cambia de plan.';
  }

  @override
  String planLimitPhotos(String used, String limit) {
    return 'Ya usaste $used de $limit fotos este mes. Para sacar más, cambia de plan.';
  }

  @override
  String planLimitChecklists(String used, String limit) {
    return 'Ya tienes $used de $limit checklists. Para crear otro, cambia de plan.';
  }

  @override
  String get planUsageSection => 'Lo que estás usando';

  @override
  String get planUsageTeam => 'Personas en el equipo';

  @override
  String get planUsagePhotos => 'Fotos este mes';

  @override
  String get planUsageChecklists => 'Checklists';

  @override
  String planUsageOf(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String get planUsageAtLimit => 'En el límite';

  @override
  String get planUsageAtLimitInvites => 'En el límite · cuenta la invitación';

  @override
  String get planUsageNearLimit => 'Casi en el límite';

  @override
  String get planUsageUnlimited => 'Sin límite';

  @override
  String get companyShownOnOrder => 'Aparece en la orden del cliente';

  @override
  String get companyNameLogoContact => 'Nombre, logo y contacto';

  @override
  String get customerTerms => 'Términos para el cliente';

  @override
  String get customerTermsHint => 'Garantía y condiciones';

  @override
  String get segmentRow => 'Rubro';

  @override
  String get segmentRowHint => 'Cambia los servicios y checklists listos';

  @override
  String get moreCompanyData => 'Más datos (correo, sitio, país)';

  @override
  String get addLogo => 'Poner logo';

  @override
  String get changeLogoLink => 'Cambiar logo';

  @override
  String get pickSegmentTitle => '¿Cuál es tu rubro?';

  @override
  String get pickSpecialtiesTitle => '¿Qué atiendes?';

  @override
  String get specialtiesNone => 'Ninguna marcada';

  @override
  String get pickCountryTitle => '¿Qué país?';

  @override
  String get companyNameRequired => 'Escribe el nombre de la empresa';

  @override
  String get schedulingRow => 'Agenda';

  @override
  String get schedulingRowHint => 'Marcar día y hora de las órdenes';

  @override
  String get fieldServiceRow => 'Atención en el lugar del cliente';

  @override
  String get fieldServiceRowHint => 'Dirección del cliente en la orden';

  @override
  String get contractsRowHint => 'Órdenes que se repiten solas';

  @override
  String deviceControlRow(String devices) {
    return 'Control de $devices';
  }

  @override
  String get deviceControlRowHint => 'Historial y lista completa';

  @override
  String get companySettingSaveError =>
      'No se pudo guardar. Revisa la conexión e intenta de nuevo.';

  @override
  String customerSpentValue(String value) {
    return 'gastó $value';
  }

  @override
  String customerOwesValue(String value) {
    return 'Falta cobrar $value';
  }

  @override
  String askOrderForCustomer(String name) {
    return '¿Abrir una OS para $name?';
  }

  @override
  String askOrderForDevice(String device) {
    return '¿Abrir una OS para este $device?';
  }

  @override
  String addAnotherDevice(String device) {
    return 'Agregar otro $device';
  }

  @override
  String get latestOrders => 'Últimas OS';

  @override
  String ordersOfDevice(String device) {
    return 'OS de este $device';
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
  String get deviceOwnerPrefix => 'de ';

  @override
  String get financialReportShort => 'Informe';

  @override
  String financialReceivedIn(String month) {
    return 'Recibido en $month';
  }

  @override
  String financialReceivedSub(int count) {
    return '$count OS · ver todas';
  }

  @override
  String get financialSendReportPdf => 'Enviar informe en PDF';

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
    return 'Orden $number';
  }

  @override
  String get receiveAmountHint => '¿Recibió solo una parte? Cambie el valor.';

  @override
  String get orderAddContractMonthly => 'Repetir cada mes (contrato)';

  @override
  String get ratingsSubtitle => 'Lo que opinaron los clientes';

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
      other: 'valoraciones',
      one: 'valoración',
    );
    return 'promedio de $count $_temp0';
  }

  @override
  String ratingCommentOrder(String comment, int number) {
    return '“$comment” · Orden $number';
  }

  @override
  String ratingNoCommentOrder(int number) {
    return 'Sin comentario · Orden $number';
  }

  @override
  String get remindersSubtitle => 'Valen solo en este celular';

  @override
  String get reminderBeforeTitle => 'Antes de la hora marcada';

  @override
  String get reminderDailyTitle => 'Resumen del día a las 9h';

  @override
  String get reminderDailySubtitle => 'Qué hay para hoy';

  @override
  String get reminderPendingTitle => 'OS paradas';

  @override
  String get reminderPendingSubtitle =>
      'Presupuestos sin respuesta hace 7 días';

  @override
  String get reminderInactivityTitle => 'Si paso días sin abrir la app';

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
  String get catalogSubtitle => 'Lo que pones en las OS';

  @override
  String catalogKindWithCount(String kind, int count) {
    return '$kind ($count)';
  }

  @override
  String get catalogTip =>
      'Consejo: puedes registrar directo en la OS, escribiendo el nombre en la búsqueda.';

  @override
  String get teamTitle => 'Equipo';

  @override
  String teamSummary(String people, String invites) {
    return '$people y $invites';
  }

  @override
  String teamPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String teamInvitesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones',
      one: '1 invitación',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteWaitingLabel => 'Invitación esperando';

  @override
  String teamInviteWaitingText(String name, String expiry) {
    return '$name todavía no entró. $expiry';
  }

  @override
  String teamInviteExpiresInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'La invitación vence en $count días.',
      one: 'La invitación vence en 1 día.',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteExpiresToday => 'La invitación vence hoy.';

  @override
  String get teamInviteExpired => 'La invitación venció.';

  @override
  String get teamResendInvite => 'Reenviar invitación';

  @override
  String get teamWaitingSection => 'Esperando entrar';

  @override
  String get teamMembersSection => 'En el equipo';

  @override
  String teamInviteSent(String expiry) {
    return 'Invitación enviada · $expiry';
  }

  @override
  String teamInviteDueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vence en $count días',
      one: 'vence en 1 día',
    );
    return '$_temp0';
  }

  @override
  String get teamInviteDueToday => 'vence hoy';

  @override
  String get teamInviteDueExpired => 'venció';

  @override
  String teamYou(String name) {
    return '$name (tú)';
  }

  @override
  String get teamInviteAnother => 'Invitar a otra persona';

  @override
  String get teamInviteFirst => 'Invitar a una persona';

  @override
  String get roleShortAdmin => 've y cambia todo';

  @override
  String get roleShortSupervisor => 'coordina el equipo, no ve precios';

  @override
  String get roleShortManager => 've facturación y costos';

  @override
  String get roleShortConsultant => 'hace presupuestos, ve solo sus órdenes';

  @override
  String get roleShortTechnician => 'hace los servicios, no ve precios';

  @override
  String get checklistsTitle => 'Checklists';

  @override
  String get checklistsSubtitle =>
      'Preguntas que el técnico responde en la orden';

  @override
  String get checklistsYours => 'Tus checklists';

  @override
  String get checklistsReady => 'Listos para usar';

  @override
  String checklistQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preguntas',
      one: '1 pregunta',
    );
    return '$_temp0';
  }

  @override
  String get checklistWithPhotos => 'con fotos';

  @override
  String get checklistOff => 'Desactivado';

  @override
  String get checklistUse => 'Usar';

  @override
  String get checklistNew => 'Nuevo checklist';

  @override
  String get checklistsEmpty =>
      'Aún no hay checklists. Crea uno o usa uno listo.';

  @override
  String get noticesTitle => 'Avisos';

  @override
  String noticesNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevos',
      one: '1 nuevo',
    );
    return '$_temp0';
  }

  @override
  String get noticesMarkAllRead => 'Marcar todos como leídos';

  @override
  String get noticesSectionNew => 'Nuevos';

  @override
  String get noticesSectionBefore => 'Antes';

  @override
  String get noticesEmpty => 'Aún no hay avisos.';

  @override
  String get timeAgoNow => 'ahora';

  @override
  String timeAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String contractsSubtitle(String order) {
    return '$order que se repiten solas';
  }

  @override
  String get contractsTabActive => 'Activos';

  @override
  String get contractsTabEnded => 'Terminados';

  @override
  String contractEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count días',
      one: 'Todos los días',
    );
    return '$_temp0';
  }

  @override
  String contractEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count semanas',
      one: 'Todas las semanas',
    );
    return '$_temp0';
  }

  @override
  String contractEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count meses',
      one: 'Todos los meses',
    );
    return '$_temp0';
  }

  @override
  String contractEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count años',
      one: 'Todos los años',
    );
    return '$_temp0';
  }

  @override
  String contractNextOrderOn(String date, String order) {
    return 'Próxima $order el $date';
  }

  @override
  String contractEndedOn(String date) {
    return 'Terminado el $date';
  }

  @override
  String get contractEnded => 'Terminado';

  @override
  String get contractsEmptyEnded => 'No hay contratos terminados.';

  @override
  String contractsFooterHint(String order) {
    return 'Los contratos nacen dentro de una $order: activa “Repetir esta $order”.';
  }

  @override
  String get orderAddResponsible => 'Responsable';

  @override
  String get orderResponsibleRemove => 'Quitar responsable';

  @override
  String get filterDone => 'Terminadas';

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
  String get homeSearchHint => 'Buscar OS o cliente';

  @override
  String homeSearchHintDevice(String device) {
    return 'Buscar OS, cliente o $device';
  }

  @override
  String remainingToReceive(String amount) {
    return 'falta cobrar $amount';
  }

  @override
  String get firstOrderTapPlus =>
      'Toca + para crear tu primera OS. Toma menos de un minuto.';

  @override
  String profileButtonA11y(String company) {
    return '$company: clientes, catálogo, equipo y ajustes';
  }

  @override
  String get orderAssistantPhoto => 'Foto';

  @override
  String get orderAssistantTalkShort => 'Hablar';

  @override
  String get orderCustomerRequestTitle => 'Lo que pidió el cliente';

  @override
  String get orderCustomerRequestPlaceholder => 'Ej.: ruido al frenar';

  @override
  String get orderDeliverySection => 'Entrega';

  @override
  String get orderDueLabel => 'Listo el';

  @override
  String get orderDueNone => 'Sin fecha';

  @override
  String get orderMoreOptions => 'Más opciones';

  @override
  String get orderMoreOptionsHint => 'Estado, visita, responsable, lugar';

  @override
  String get orderStatusLabel => 'Estado';

  @override
  String get orderScheduleLabel => 'Visita';

  @override
  String get orderAddressLabel => 'Lugar';

  @override
  String get speechHint => 'Di el cliente, el vehículo y lo que se va a hacer.';

  @override
  String get speechListening => 'Escuchando…';

  @override
  String get speechFill => 'Completar la OS';

  @override
  String get speechUnavailable =>
      'El micrófono no está permitido. Permítelo en Ajustes o escribe el servicio.';

  @override
  String get orderAddItemRow => 'Agregar servicio o pieza';

  @override
  String get orderPickCustomerRow => 'Elegir cliente';

  @override
  String get newOrderButton => 'Nueva OS';

  @override
  String get orderAssistantFilled => 'Completé lo marcado. Revísalo y guarda.';

  @override
  String get orderAssistantUndo => 'Deshacer';

  @override
  String orderNotifyNote(String status, String name) {
    return '$status. ¿Avisar a $name?';
  }

  @override
  String get orderNotifyFallbackName => 'el cliente';

  @override
  String get orderNotifyAction => 'Avisar';

  @override
  String get orderAssistantReadingPhotos => 'Leyendo las fotos…';

  @override
  String get orderAssistantReadingSpeech => 'Leyendo lo que dijiste…';

  @override
  String get orderAssistantMarked => 'Completado por la IA';

  @override
  String get speechCancel => 'Cancelar';

  @override
  String get speechStopAndFill => 'Detener y completar la OS';

  @override
  String get speechTypeHint =>
      'Escribe el cliente, el vehículo y lo que se hará';

  @override
  String get speechNothingHeard =>
      'No escuché nada. Toca Hablar e inténtalo de nuevo.';

  @override
  String get orderServicesAndParts => 'Servicios y piezas';

  @override
  String get orderItemKindPart => 'pieza';

  @override
  String get orderActionApproveQuote => 'Aprobar presupuesto';

  @override
  String get orderActionStartService => 'Empezar el servicio';

  @override
  String get orderActionMarkReady => 'Marcar como lista';

  @override
  String orderDuePhrase(String when) {
    return 'Lista $when';
  }

  @override
  String orderDueLatePhrase(String when) {
    return 'Debía estar lista $when';
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
  String get orderCommentYou => 'Tú';

  @override
  String get orderMenuChangeStatus => 'Cambiar el estado';

  @override
  String get orderMenuViewPdf => 'Ver PDF';

  @override
  String get orderMenuCopyLink => 'Copiar enlace';

  @override
  String get orderPlaceOfService => 'Lugar de atención';

  @override
  String get orderAssistantApplied =>
      'Agregué a la OS lo que está marcado. Revísalo.';

  @override
  String orderAssistantWhichLine(String name) {
    return '¿Cuál $name?';
  }

  @override
  String get orderAssistantChanged => 'Cambié la OS como pediste. Revísala.';

  @override
  String orderAssistantWhichCustomer(String name) {
    return '¿Cuál $name?';
  }

  @override
  String orderAssistantRegisterNewCustomer(String name) {
    return 'Registrar a $name como cliente nuevo';
  }

  @override
  String get orderAssistantOtherCustomer => 'Otro cliente';

  @override
  String get orderAssistantNewCustomer => 'nuevo';

  @override
  String orderAssistantWhichDevice(String name) {
    return '¿Cuál $name?';
  }

  @override
  String orderAssistantRegisterNewDevice(String name) {
    return 'Registrar $name';
  }

  @override
  String orderAssistantOtherDevice(String label) {
    return 'Otro $label';
  }

  @override
  String get orderAssistantNewDevice => 'nuevo';

  @override
  String get pickerCustomerTitle => '¿Qué cliente?';

  @override
  String pickerDeviceTitle(String device) {
    return '¿Qué $device?';
  }

  @override
  String pickerDeviceSubtitle(String name) {
    return 'de $name';
  }

  @override
  String get pickerItemTitle => '¿Qué se va a hacer?';

  @override
  String get pickerChecklistTitle => '¿Qué checklist?';

  @override
  String get pickerStatusTitle => '¿Cuál es la situación?';

  @override
  String get pickerAssigneeTitle => '¿Quién es el responsable?';

  @override
  String pickerDevicesTitle(String devices) {
    return '¿En cuáles $devices?';
  }

  @override
  String get pickerNewCustomer => 'Nuevo cliente';

  @override
  String pickerNewDevice(String device) {
    return 'Nuevo $device';
  }

  @override
  String get pickerNewItem => 'Nuevo servicio o pieza';

  @override
  String get pickerNewChecklist => 'Nuevo checklist';

  @override
  String pickerRegister(String query) {
    return 'Registrar “$query”';
  }

  @override
  String pickerNoDeviceWith(String device, String query) {
    return 'Ningún $device con “$query”.';
  }

  @override
  String pickerNoItemWith(String query) {
    return 'Ningún servicio o pieza con “$query”. Regístrelo y entra directo en la OS.';
  }

  @override
  String pickerNoMatch(String query) {
    return 'Nada con “$query”.';
  }

  @override
  String get pickerRecent => 'Recientes';

  @override
  String get pickerAll => 'Todos';

  @override
  String get pickerSearch => 'Buscar';

  @override
  String pickerNoDevice(String device) {
    return 'Ningún $device';
  }

  @override
  String get formMoreData => 'Más datos';

  @override
  String get customerSaveNeedsName => 'Escribe el nombre para guardar.';

  @override
  String get customerMoreDataHint => 'Correo, documento fiscal, dirección';

  @override
  String deviceSaveNeedsField(String field) {
    return 'Completa el campo $field para guardar.';
  }

  @override
  String deviceMoreDataHint(String brand, String category) {
    return 'Foto, $brand y $category';
  }

  @override
  String get catalogMoreDataHintFields => 'Foto y otros campos';

  @override
  String get inviteSaveNeedsContact =>
      'Escribe el correo o el WhatsApp para guardar.';

  @override
  String get checklistNamePlaceholder => 'Ej.: Inspección de entrada';

  @override
  String get checklistQuestionsTitle => 'Preguntas';

  @override
  String get checklistAddQuestion => 'Agregar pregunta';

  @override
  String get checklistSaveNeedsNameAndQuestion =>
      'Escribe el nombre y agrega una pregunta para guardar.';

  @override
  String get checklistSaveNeedsQuestion => 'Agrega una pregunta para guardar.';

  @override
  String get checklistNameLabel => 'Nombre del checklist';

  @override
  String get checklistSave => 'Guardar checklist';

  @override
  String get checklistSaveError =>
      'No se pudo guardar el checklist. Inténtalo de nuevo.';

  @override
  String get checklistStopUsing => 'No usar en la empresa';

  @override
  String get checklistUseAgain => 'Volver a usar';

  @override
  String get checklistDelete => 'Borrar checklist';

  @override
  String get checklistDeleteTitle => '¿Borrar este checklist?';

  @override
  String checklistDeleteMessage(String name) {
    return '“$name” sale de la lista y ya no aparece en las OS nuevas.';
  }

  @override
  String get checklistQuestionNew => 'Nueva pregunta';

  @override
  String get checklistQuestion => 'Pregunta';

  @override
  String get checklistQuestionPlaceholder => 'Ej.: ¿Los neumáticos están bien?';

  @override
  String get checklistAnswerType => 'Tipo de respuesta';

  @override
  String get checklistOptions => 'Opciones';

  @override
  String get checklistOptionsPlaceholder => 'Ej.: Bueno\nRegular\nMalo';

  @override
  String get checklistQuestionRequiredHint => 'No deja terminar sin responder';

  @override
  String get checklistQuestionAllowPhotos => 'Puede poner foto';

  @override
  String get checklistQuestionDelete => 'Borrar pregunta';

  @override
  String get checklistQuestionNeedsLabel =>
      'Escribe la pregunta para continuar.';

  @override
  String get checklistQuestionNeedsOptions =>
      'Escribe al menos 2 opciones, una por línea.';

  @override
  String get checklistQuestionRequiredShort => 'obligatoria';

  @override
  String get checklistQuestionWithPhoto => 'con foto';

  @override
  String get formItemTypeText => 'Texto';

  @override
  String get formItemTypeNumber => 'Número';

  @override
  String get formItemTypeBoolean => 'Sí o no';

  @override
  String get formItemTypeSelect => 'Elegir una opción';

  @override
  String get formItemTypeChecklist => 'Elegir varias opciones';

  @override
  String get formItemTypePhoto => 'Solo foto';

  @override
  String get pickerNewItemKind => '¿Qué vas a registrar?';

  @override
  String get pickerNewItemServiceHint => 'Mano de obra que haces';

  @override
  String get pickerNewItemProductHint => 'Pieza o material que vendes';

  @override
  String receiveSubtitleWithDiscount(
    String customer,
    String total,
    String discount,
  ) {
    return '$customer · total $total · descuento $discount';
  }

  @override
  String receiveSubtitleNoCustomerWithDiscount(String total, String discount) {
    return 'total $total · descuento $discount';
  }

  @override
  String chargeSendLinkTo(String customer) {
    return 'Enviar a $customer un enlace para pagar';
  }

  @override
  String get chargeSendLink => 'Enviar un enlace para pagar';

  @override
  String chargeLinkSentOn(String date) {
    return 'Enlace enviado el $date';
  }

  @override
  String get chargeLinkSent => 'Enlace enviado';

  @override
  String chargeLinkExpiredOn(String date) {
    return 'El enlace venció el $date';
  }

  @override
  String chargeNotPaidYet(String customer, String value) {
    return '$customer todavía no pagó los $value.';
  }

  @override
  String chargeNotPaidYetNoCustomer(String value) {
    return 'Los $value todavía no se pagaron.';
  }

  @override
  String chargeLinkValidUntil(String date) {
    return 'El enlace vale hasta el $date.';
  }

  @override
  String get chargeRemindWhatsApp => 'Recordar también por WhatsApp';

  @override
  String get chargeReceivedOtherWay => 'Cobré de otra forma';

  @override
  String get chargeLinkSection => 'Enlace para pagar';

  @override
  String get chargePaymentLink => 'Enlace de pago';

  @override
  String chargeWaitingFor(String customer) {
    return 'Esperando que $customer pague';
  }

  @override
  String get chargeWaitingPayment => 'Esperando el pago';

  @override
  String chargeExpiredOn(String date) {
    return 'Venció el $date';
  }

  @override
  String chargeMethodsUntil(String date) {
    return 'Pix, boleto o tarjeta · hasta el $date';
  }

  @override
  String chargeInstallmentsUntil(int count, String date) {
    return '${count}x con tarjeta · hasta el $date';
  }

  @override
  String chargeInstallmentsPaid(int paid, int count) {
    return '$paid de $count cuotas pagadas';
  }

  @override
  String chargeUntilReplaced(String date) {
    return 'hasta el $date · el enlace nuevo cancela este';
  }

  @override
  String get chargeOrderChanged => 'La OS cambió de valor';

  @override
  String chargeNowMissing(String remaining, String value) {
    return 'Ahora falta $remaining, pero el enlace todavía cobra $value.';
  }

  @override
  String chargeGenerateNew(String value) {
    return 'Generar un enlace nuevo de $value';
  }

  @override
  String chargeKeepLink(String value) {
    return 'Mantener el enlace de $value';
  }

  @override
  String get chargeSendAgainWhatsApp => 'Enviar de nuevo por WhatsApp';

  @override
  String get chargeCopyLink => 'Copiar el enlace';

  @override
  String get chargeLinkCopied => 'Enlace copiado';

  @override
  String get chargeCancelLink => 'Cancelar el enlace';

  @override
  String get chargeLinkTitle => 'Enlace de pago';

  @override
  String chargeLinkIntro(String name) {
    return '$name recibe el enlace y paga con Pix, boleto o tarjeta.';
  }

  @override
  String get chargeLinkIntroNoName =>
      'El cliente recibe el enlace y paga con Pix, boleto o tarjeta.';

  @override
  String get chargeSplitQuestion => '¿En cuotas con tarjeta?';

  @override
  String get chargeSplitOnCard => 'En cuotas con tarjeta';

  @override
  String get chargeSplitNo => 'No';

  @override
  String get profileEditTitle => 'Tu perfil';

  @override
  String get profileChangePhoto => 'Cambiar foto';

  @override
  String profileSignedInAs(String email) {
    return 'Entras con $email';
  }

  @override
  String get profileNameRequired => 'Escribe tu nombre';

  @override
  String get profileNamePlaceholder => 'Ej.: Juan Pérez';

  @override
  String get financialWhichOrder => '¿Qué OS?';

  @override
  String get reportThisWeek => 'Esta semana';

  @override
  String get reportThisMonth => 'Este mes';

  @override
  String get reportThisYear => 'Este año';

  @override
  String get reportPickDates => 'Elegir fechas';

  @override
  String get reportSeeOtherPeriod => 'Ver otro período';

  @override
  String get reportStarts => 'Empieza';

  @override
  String get reportEnds => 'Termina';

  @override
  String get reportWhichPeriod => '¿Qué período?';

  @override
  String get agendaShowMonth => 'Ver el mes';

  @override
  String get agendaShowWeek => 'Ver la semana';

  @override
  String agendaWhose(String name) {
    return 'De quién: $name';
  }

  @override
  String get agendaWhoseTitle => '¿De quién mostrar?';

  @override
  String agendaOnlyOf(String name) {
    return 'Solo de $name';
  }

  @override
  String get agendaShowAll => 'Mostrar todos';

  @override
  String agendaWithPerson(String name) {
    return 'con $name';
  }

  @override
  String agendaDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agendados',
      one: '1 agendado',
    );
    return '$_temp0';
  }

  @override
  String agendaDayHasOrders(String day) {
    return '$day, tiene servicio agendado';
  }

  @override
  String get agendaPreviousWeek => 'Semana anterior';

  @override
  String get agendaNextWeek => 'Semana siguiente';

  @override
  String get agendaPreviousMonth => 'Mes anterior';

  @override
  String get agendaNextMonth => 'Mes siguiente';

  @override
  String noticeCommented(String name, String text) {
    return '$name comentó: “$text”';
  }

  @override
  String noticePaymentReceived(String amount) {
    return 'Pago de $amount recibido';
  }

  @override
  String get contractNew => 'Nuevo contrato';

  @override
  String get orderRepeatRow => 'Repetir';

  @override
  String contractsEmptyAdd(String order) {
    return 'Toca + para crear una $order que se repite sola.';
  }

  @override
  String get contractRepeats => 'Se repite';

  @override
  String get contractRepeatsTitle => '¿Cada cuánto?';

  @override
  String get contractStarts => 'Empieza';

  @override
  String get contractEnds => 'Termina';

  @override
  String get contractNeverEnds => 'Nunca';

  @override
  String get contractNoEndDate => 'Sin fecha de fin';

  @override
  String contractAutoCreate(String order) {
    return 'Crear la $order sola';
  }

  @override
  String contractAutoCreateHint(String order) {
    return 'Activado, la $order nueva aparece sola en la fecha. Desactivado, solo recibes el aviso.';
  }

  @override
  String get contractRemind => 'Avisar antes';

  @override
  String get contractRemindTitle => '¿Con cuánta anticipación avisar?';

  @override
  String contractRemindDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días antes',
      one: '1 día antes',
      zero: 'El mismo día',
    );
    return '$_temp0';
  }

  @override
  String get onboardingSegmentHint =>
      'Así la app ya viene con los servicios y checklists de tu trabajo.';

  @override
  String get onboardingSpecialtiesHint =>
      'Marca lo que tenga sentido. Puedes cambiarlo después.';

  @override
  String get emailLoginTitle => 'Entrar con correo';

  @override
  String get emailLoginEmailRequired => 'Escribe tu correo.';

  @override
  String get emailLoginEmailInvalid =>
      'Ese correo no parece correcto. Revísalo.';

  @override
  String get emailLoginPasswordRequired => 'Escribe tu contraseña.';

  @override
  String get emailLoginWrongCredentials =>
      'El correo o la contraseña no coinciden. Revísalos e intenta de nuevo.';

  @override
  String get emailLoginNoInternet =>
      'Sin internet. Revisa la conexión e intenta de nuevo.';

  @override
  String get emailLoginTooManyAttempts =>
      'Demasiados intentos. Espera un poco e intenta de nuevo.';

  @override
  String get emailLoginGenericError => 'No se pudo entrar. Intenta de nuevo.';

  @override
  String get emailLoginSigningIn => 'Entrando…';

  @override
  String get resetPasswordTitle => 'Cambiar la contraseña';

  @override
  String get resetPasswordMessage => 'Te enviaremos un enlace a tu correo.';

  @override
  String get resetPasswordError =>
      'No se pudo enviar el correo. Revisa la dirección e intenta de nuevo.';

  @override
  String get inviteTitleMany => 'Recibiste invitaciones';

  @override
  String get inviteManyHint =>
      'Toca una invitación para verla y unirte al equipo.';

  @override
  String get inviteCodeTitle => '¿Cuál es el código de la invitación?';

  @override
  String checklistRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count',
      one: 'Falta 1',
      zero: 'Todo respondido',
    );
    return '$_temp0';
  }

  @override
  String get checklistQuestionNext => 'Siguiente';

  @override
  String get checklistQuestionDone => 'Listo';

  @override
  String get checklistSkipForNow => 'Omitir por ahora';

  @override
  String get checklistPreviousQuestion => 'Volver a la anterior';

  @override
  String get checklistQuestionRequired => 'Obligatoria';

  @override
  String get checklistPickFromGallery => 'Elegir de la galería';

  @override
  String get checklistTextPlaceholder => 'Escribe aquí';

  @override
  String get checklistStart => 'Empezar';

  @override
  String get checklistFinish => 'Terminar checklist';

  @override
  String get checklistFinishAnyway => 'Terminar de todos modos';

  @override
  String get checklistStatusDone => 'Completo';

  @override
  String get checklistNoAnswer => 'Sin respuesta';

  @override
  String checklistPhotoPosition(int current, int total) {
    return '$current de $total';
  }

  @override
  String get shareTitle => 'Enviar al cliente';

  @override
  String shareCanAll(String name, String order) {
    return '$name abre la $order desde el enlace, aprueba y comenta.';
  }

  @override
  String shareCanApprove(String name, String order) {
    return '$name abre la $order desde el enlace y aprueba.';
  }

  @override
  String shareCanComment(String name, String order) {
    return '$name abre la $order desde el enlace y comenta.';
  }

  @override
  String shareCanView(String name, String order) {
    return '$name abre la $order desde el enlace.';
  }

  @override
  String get shareTheCustomer => 'El cliente';

  @override
  String shareValidUntil(String date) {
    return 'Vale hasta el $date.';
  }

  @override
  String get shareSendWhatsApp => 'Enviar por WhatsApp';

  @override
  String get shareSendLink => 'Enviar el enlace';

  @override
  String get shareSendOtherWay => 'Enviar de otra forma';

  @override
  String get shareCopyLink => 'Copiar el enlace';

  @override
  String get shareLinkCopied => 'Enlace copiado';

  @override
  String get sharePreparing => 'Preparando el enlace…';

  @override
  String get shareError => 'No se pudo crear el enlace.';

  @override
  String get shareValidity => 'Cambiar la validez';

  @override
  String get shareValidityTitle => '¿Por cuánto tiempo vale?';

  @override
  String shareValidityDays(int count) {
    return '$count días';
  }

  @override
  String get sharePermissionsTitle => '¿Qué puede hacer el cliente?';

  @override
  String get sharePermAll => 'Ver, aprobar y comentar';

  @override
  String get sharePermApprove => 'Ver y aprobar';

  @override
  String get sharePermComment => 'Ver y comentar';

  @override
  String get sharePermView => 'Solo ver';

  @override
  String get shareNewLink => 'Generar enlace nuevo';

  @override
  String get shareRevoke => 'Desactivar el enlace';

  @override
  String shareRevokeConfirm(String order) {
    return 'El cliente ya no podrá abrir la $order con este enlace.';
  }

  @override
  String get shareMenu => 'Opciones del enlace';

  @override
  String get orderItemNotesPlaceholder => 'Algo más sobre este ítem';

  @override
  String get orderItemRemoveTitle => '¿Quitar de la OS?';

  @override
  String orderItemRemoveMessage(String name) {
    return '\"$name\" sale de la OS y del total.';
  }

  @override
  String get orderItemQuantityInvalid => 'Pon al menos 1.';

  @override
  String orderPhotoShareText(String order) {
    return 'Foto de la $order';
  }

  @override
  String get orderPhotoShareError =>
      'No se pudo compartir la foto. Inténtalo de nuevo.';

  @override
  String get orderPhotoDeleteTitle => '¿Borrar esta foto?';

  @override
  String get orderPhotoDeleted => 'Foto borrada';

  @override
  String get orderPhotoDeleteError =>
      'No se pudo borrar la foto. Inténtalo de nuevo.';

  @override
  String get orderPhotoCoverSet => 'Foto definida como portada';

  @override
  String get orderDocumentTypeTitle => '¿Qué documento es este?';

  @override
  String get shareWhatCanDo => 'Qué puede hacer el cliente';

  @override
  String get orderPhotoDelete => 'Borrar foto';

  @override
  String get contractStopRepeating => 'Dejar de repetir';

  @override
  String get contractStopRepeatingTitle => '¿Dejar de repetir?';

  @override
  String get contractStopRepeatingMessage =>
      'No se crearán más OS. Las que ya existen se mantienen.';

  @override
  String get commentsEmpty => 'Nadie ha comentado todavía.';

  @override
  String get commentsTeamOnly => 'Solo el equipo lo ve';

  @override
  String get commentsCustomerSees =>
      'El cliente también lo ve, en el enlace de la OS';

  @override
  String get commentsCustomerHidden => 'El cliente no lo ve';

  @override
  String get commentTeamOnlyTag => 'solo el equipo';

  @override
  String get commentSendError => 'No se pudo enviar. Inténtalo de nuevo.';

  @override
  String get inviteSheetTitle => 'Invitación al equipo';

  @override
  String inviteShareSentence(int days) {
    return 'Envía este código para que la persona entre al equipo. Vale por $days días.';
  }

  @override
  String get inviteShareButton => 'Compartir invitación';

  @override
  String get inviteSendWhatsApp => 'Enviar por WhatsApp';

  @override
  String get inviteCopyCode => 'Copiar código';

  @override
  String get inviteMenu => 'Más opciones de la invitación';

  @override
  String get teamCancelInvite => 'Cancelar invitación';

  @override
  String teamCancelInviteQuestion(String name) {
    return '¿Cancelar la invitación de $name?';
  }

  @override
  String get teamCancelInviteMessage => 'El código dejará de funcionar.';

  @override
  String get teamKeepInvite => 'Mantener invitación';

  @override
  String get teamInviteCanceled => 'Invitación cancelada';

  @override
  String teamInviteExpiredQuestion(String name) {
    return 'La invitación de $name venció';
  }

  @override
  String get teamInviteExpiredMessage =>
      'El código ya no funciona. Invita de nuevo para enviar un código nuevo.';

  @override
  String get teamInviteAgain => 'Invitar de nuevo';

  @override
  String teamMemberRoleQuestion(String name) {
    return '¿Qué puede hacer $name?';
  }

  @override
  String get teamRemoveMember => 'Quitar del equipo';

  @override
  String teamRemoveMemberQuestion(String name) {
    return '¿Quitar a $name del equipo?';
  }

  @override
  String get teamRemoveMemberMessage =>
      'La persona pierde el acceso a las OS de la empresa.';

  @override
  String get teamRoleChanged => 'Rol cambiado';

  @override
  String teamMemberRemoved(String name) {
    return '$name salió del equipo';
  }

  @override
  String get integrationsAiSection => 'ChatGPT y Claude';

  @override
  String get integrationsEmptyLine =>
      'Ninguna conexión todavía. Toca + para conectar PraticOS a ChatGPT o Claude.';

  @override
  String get integrationsRevoked => 'Conexión revocada';

  @override
  String get asaasConnectHeadline =>
      'Conecta la cuenta Asaas para recibir Pix, boleto y tarjeta por la OS.';

  @override
  String get asaasConnectedHeadline =>
      'Los pagos por Asaas se registran en la OS solos.';

  @override
  String get asaasConnecting => 'Conectando…';

  @override
  String get asaasConnectedToast => 'Cuenta Asaas conectada';

  @override
  String get asaasDisconnectedToast => 'Cuenta Asaas desconectada';

  @override
  String get asaasMenu => 'Más opciones de Asaas';

  @override
  String get nfseErrorAsaasValidation =>
      'Asaas rechazó los datos de la factura. Revisa el documento y la dirección del cliente y la configuración fiscal.';

  @override
  String get nfseErrorNotEnabled =>
      'La factura de servicio no está activada para esta empresa.';

  @override
  String get nfseErrorNotReady =>
      'Falta configurar la factura. Mira en Integraciones, Asaas.';

  @override
  String get nfseErrorOrderNotAllowed =>
      'Esta orden no puede tener factura: es presupuesto o fue cancelada.';

  @override
  String get nfseErrorNoServices =>
      'Esta orden no tiene servicios con valor. Solo los servicios van en la factura.';

  @override
  String get nfseErrorOrderHasInvoice =>
      'Esta orden ya tiene factura. Cancélala antes de emitir otra.';

  @override
  String get nfseErrorOrderNotOfCustomer =>
      'Todas las órdenes de la factura deben ser del mismo cliente.';

  @override
  String get nfseErrorNotFound =>
      'No encontramos esta factura. Actualiza la pantalla.';

  @override
  String get nfseErrorNotCancelable =>
      'Esta factura no se puede cancelar ahora.';

  @override
  String get nfseErrorCancelNotSupported =>
      'Este municipio no permite cancelar la factura desde aquí. Cancélala en el sitio del municipio.';

  @override
  String get nfseErrorInvalidDate =>
      'La fecha de la factura no puede ser anterior a hoy.';

  @override
  String get nfseErrorInvalidFiscalInfo =>
      'Asaas no aceptó los datos fiscales. Revísalos con tu contador.';

  @override
  String get nfseErrorReconnectNeeded =>
      'Vuelve a conectar Asaas para emitir facturas.';

  @override
  String get nfseErrorSetupNeeded =>
      'La cuenta de Asaas cambió. Configura la factura de nuevo.';

  @override
  String get nfseErrorOtherAccount =>
      'Esta factura es de otra cuenta de Asaas. Cancélala allí.';

  @override
  String get nfseConflictNotice =>
      'Factura emitida fuera de PraticOS, revísala en Asaas.';

  @override
  String get nfseStatusWaiting => 'Esperando al municipio';

  @override
  String nfseStatusScheduledFor(String date) {
    return 'Se emitirá el $date';
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
  String get nfseStatusCancelDenied => 'Cancelación rechazada';

  @override
  String get nfseStatusCanceled => 'Cancelada';

  @override
  String get nfseStatusError => 'Rechazada por el municipio';

  @override
  String get nfseRowTitle => 'Factura de servicio';

  @override
  String get nfseIssueAction => 'Emitir factura de servicio';

  @override
  String get nfseIssueSeveralAction => 'Emitir una factura con varias órdenes';

  @override
  String get nfseValueLabel => 'Valor de la factura';

  @override
  String get nfseOnlyServicesNote =>
      'Solo los servicios van en la factura. Piezas y productos quedan fuera.';

  @override
  String get nfseDiscountNote =>
      'El descuento se repartió entre servicios y piezas.';

  @override
  String nfseOrderLine(String number, String value) {
    return 'Orden $number · $value';
  }

  @override
  String get nfseDescriptionLabel => 'Lo que dice la factura';

  @override
  String get nfseDateLabel => 'Fecha de la factura';

  @override
  String get nfseServiceRow => 'Servicio municipal';

  @override
  String get nfseTaxIdHint =>
      'La factura necesita el documento fiscal del cliente. Se guarda en su ficha.';

  @override
  String get nfseTaxIdMissing => 'Falta el documento fiscal del cliente';

  @override
  String get nfseNothingToIssue =>
      'Nada que emitir: la factura quedaría sin valor';

  @override
  String nfseAlreadyIssued(String numbers) {
    return 'La orden $numbers ya tiene factura';
  }

  @override
  String get nfseSent => 'Factura enviada al municipio';

  @override
  String nfseSeveralIntro(int count, String name, String numbers) {
    return 'Una factura para $count órdenes de $name: $numbers.';
  }

  @override
  String get nfseNotReadyTitle => 'Falta configurar la factura';

  @override
  String get nfseNotReadyAdmin =>
      'Antes de la primera factura, completa los datos fiscales de la empresa y el servicio de la factura.';

  @override
  String get nfseNotReadyOther =>
      'Pide al dueño de la empresa que configure la factura en Integraciones, Asaas.';

  @override
  String get nfseSetupAction => 'Configurar';

  @override
  String get nfsePickOrdersTitle => '¿Qué órdenes van en la factura?';

  @override
  String nfsePickOrderSubtitle(String value, String date) {
    return 'Servicios $value · $date';
  }

  @override
  String get nfseNoOrdersToPick =>
      'Ninguna orden de este cliente puede tener factura ahora';

  @override
  String get nfseHeadWaiting =>
      'El municipio todavía está revisando la factura.';

  @override
  String nfseHeadScheduled(String date) {
    return 'La factura va al municipio el $date.';
  }

  @override
  String get nfseHeadIssued => 'La factura fue emitida.';

  @override
  String get nfseHeadError =>
      'El municipio rechazó la factura. Revisa los datos fiscales y la ficha del cliente y emítela de nuevo.';

  @override
  String get nfseHeadCanceling => 'El municipio está cancelando la factura.';

  @override
  String get nfseHeadCancelDenied =>
      'El municipio no aceptó cancelar la factura. Sigue siendo válida.';

  @override
  String get nfseHeadCanceled => 'La factura fue cancelada.';

  @override
  String get nfseReasonLabel => 'Motivo dado por el municipio';

  @override
  String get nfseNumberLabel => 'Número';

  @override
  String get nfseOrdersLabel => 'Órdenes en la factura';

  @override
  String get nfseOpenPdf => 'Abrir PDF de la factura';

  @override
  String get nfseOpenXml => 'Abrir XML de la factura';

  @override
  String get nfseMenu => 'Más opciones de la factura';

  @override
  String get nfseCancelAction => 'Cancelar factura';

  @override
  String nfseCancelQuestion(String value) {
    return '¿Cancelar la factura de $value?';
  }

  @override
  String get nfseCancelMessage =>
      'El municipio recibe el pedido y la factura deja de valer. El pago de la orden queda igual.';

  @override
  String get nfseKeep => 'Mantener factura';

  @override
  String get nfseCancelRequested => 'Pedido de cancelación enviado';

  @override
  String get nfseCancelAtCityTitle => 'Cancela en el sitio del municipio';

  @override
  String get nfseCancelAtCityMessage =>
      'Este municipio no permite cancelar la factura desde aquí. Cancélala en su sitio y luego márcalo aquí.';

  @override
  String get nfseCanceledAtCity => 'Ya la cancelé en el municipio';

  @override
  String get nfseCanceledToast => 'Factura cancelada';

  @override
  String get nfseSetupReady => 'Lista para emitir';

  @override
  String get nfseSetupMissingShort => 'Falta configurar';

  @override
  String get nfseSetupHeadReady =>
      'Todo listo. La factura se emite desde la orden, en “…”.';

  @override
  String nfseSetupHeadMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count pasos para emitir facturas.',
      one: 'Falta 1 paso para emitir facturas.',
    );
    return '$_temp0';
  }

  @override
  String get nfseSetupFiscalInfo => 'Datos fiscales de la empresa';

  @override
  String get nfseSetupCityAccess => 'Acceso al municipio';

  @override
  String get nfseSetupService => 'Servicio de la factura';

  @override
  String get nfseSetupDone => 'Listo';

  @override
  String get nfseSetupTodo => 'Falta';

  @override
  String get nfseSetupNext => 'Configurar lo que falta';

  @override
  String get nfseCityAccessCertificate =>
      'El municipio pide el certificado digital de la empresa. Envíalo en el panel de Asaas, en Facturas.';

  @override
  String get nfseCityAccessPassword =>
      'El municipio pide el usuario y la contraseña de su sitio. Ingrésalos en el panel de Asaas, en Facturas.';

  @override
  String get nfseCityAccessToken =>
      'El municipio pide un código de acceso. Ingrésalo en el panel de Asaas, en Facturas.';

  @override
  String get nfseCityAccessFirst =>
      'Completa primero los datos fiscales: así sabremos qué pide el municipio.';

  @override
  String get nfseCityAccessNone => 'Este municipio no pide acceso extra.';

  @override
  String get nfseOpenAsaasPanel => 'Abrir el panel de Asaas';

  @override
  String get nfseCheckAgain => 'Ya lo envié, revisar de nuevo';

  @override
  String get nfseNoCancelNote =>
      'Este municipio no permite cancelar desde la app: se cancela en su sitio.';

  @override
  String get nfseFiscalNote =>
      'Estos datos quedan en Asaas y van en todas las facturas. Si tienes dudas, pregunta a tu contador.';

  @override
  String get nfseFiscalEmail => 'Correo que recibe las facturas';

  @override
  String get nfseFiscalMunicipalInscription => 'Inscripción municipal';

  @override
  String get nfseFiscalSimples => 'Empresa del Simples Nacional';

  @override
  String get nfseFiscalCnae => 'CNAE (si tu contador lo pide)';

  @override
  String get nfseFiscalSpecialRegime => 'Régimen especial';

  @override
  String get nfseFiscalSpecialRegimeQuestion => '¿Cuál es el régimen especial?';

  @override
  String get nfseFiscalServiceListItem => 'Ítem de la lista de servicios';

  @override
  String get nfseFiscalEmailMissing => 'Escribe un correo válido para guardar.';

  @override
  String get nfseFiscalSaved => 'Datos fiscales guardados';

  @override
  String get nfseServicePickTitle => '¿Qué servicio prestas?';

  @override
  String get nfseServiceSearch => 'Busca por nombre, ej.: mantenimiento';

  @override
  String get nfseServiceSearchEmpty =>
      'Nada encontrado. Prueba otra palabra o escribe el código.';

  @override
  String get nfseServiceTypeCode => 'Escribir el código';

  @override
  String get nfseServiceCode => 'Código del servicio en el municipio';

  @override
  String get nfseServiceName => 'Nombre del servicio';

  @override
  String get nfseServiceMissing => 'Elige el servicio municipal para guardar.';

  @override
  String get nfseIss => 'ISS (%)';

  @override
  String get nfseRetainIss => 'El cliente retiene el ISS';

  @override
  String get nfseOtherTaxes => 'Otros impuestos (%)';

  @override
  String get nfseTaxesNote =>
      'Usa lo que indiquen el municipio y tu contador. Deja 0 donde no aplica.';

  @override
  String get nfseTemplateLabel => 'Texto de la factura';

  @override
  String nfseTemplateHint(Object os, Object servicos) {
    return '$servicos se convierte en los servicios y $os en los números de las órdenes.';
  }

  @override
  String get nfseServiceSaved => 'Servicio de la factura guardado';

  @override
  String get nfseAutoIssueRow => 'Emitir la factura';

  @override
  String get nfseAutoIssueQuestion => '¿Cuándo emitir la factura?';

  @override
  String get nfseAutoIssueManual => 'Solo cuando yo la pida';

  @override
  String get nfseAutoIssuePaid => 'Cuando la OS esté pagada';

  @override
  String get nfseAutoIssueCompleted => 'Cuando la OS esté concluida';

  @override
  String get nfseAutoIssueManualHint =>
      'La emites desde el menú de la OS o del cliente.';

  @override
  String get nfseAutoIssuePaidHint =>
      'Sale sola cuando el cliente termina de pagar la OS.';

  @override
  String get nfseAutoIssueCompletedHint =>
      'Sale sola cuando la OS se concluye, antes de cobrar.';

  @override
  String get nfseHeadAutoError =>
      'La factura no salió sola. Corrige el motivo de abajo y emítela desde el menú de la OS.';

  @override
  String get nfseAutoReasonLabel => 'Por qué no salió';

  @override
  String get nfseAutoErrorTaxId =>
      'El cliente no tiene documento fiscal registrado.';
}
