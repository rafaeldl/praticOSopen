# Plano de Implementação i18n - PraticOS

## Visão Geral

Este documento descreve o plano para internacionalização (i18n) completa do app PraticOS e metadados de deploy Fastlane.

### Estado Atual

| Componente | Status |
|------------|--------|
| Pacote `intl` | ✅ Instalado |
| Flutter Localizations | ❌ Não configurado |
| Arquivos ARB | ❌ Não existem |
| SegmentConfigService | ✅ 64 labels padrão |
| Bootstrap 3 idiomas | ✅ pt-BR, en-US, es-ES |
| Strings no código | ❌ Hardcoded em português |
| Fastlane iOS metadata | ⚠️ Apenas pt-BR |
| Fastlane Android metadata | ⚠️ Apenas pt-BR |

### Idiomas Suportados

| Código | Idioma | Status |
|--------|--------|--------|
| pt-BR | Português (Brasil) | Principal |
| en-US | English (United States) | Secundário |
| es-ES | Español (España) | Secundário |

---

## Fase 1: Setup do Framework de Localização Flutter

### 1.1 Configurar Dependências

**Arquivo: `pubspec.yaml`**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:  # ADICIONAR
    sdk: flutter
  intl: ^0.20.2  # já existe

flutter:
  generate: true  # ADICIONAR - habilita geração de código
```

### 1.2 Criar Arquivo de Configuração l10n

**Arquivo: `l10n.yaml`** (criar na raiz do projeto)

```yaml
arb-dir: lib/l10n
template-arb-file: app_pt.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales:
  - pt_BR
  - en_US
  - es_ES
nullable-getter: false
```

### 1.3 Criar Estrutura de Diretórios

```
lib/
└── l10n/
    ├── app_pt.arb      # Português (template principal)
    ├── app_en.arb      # Inglês
    └── app_es.arb      # Espanhol
```

### 1.4 Configurar MaterialApp/CupertinoApp

**Arquivo: `lib/main.dart`**

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

CupertinoApp(
  // ... outras configurações
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('es', 'ES'),
  ],
  locale: _savedLocale, // Carregar do storage
)
```

---

## Fase 2: Criar Arquivos de Tradução (ARB)

### 2.1 Template Português (app_pt.arb)

```json
{
  "@@locale": "pt",

  "@@info": "=== NAVEGAÇÃO ===",
  "home": "Início",
  "orders": "Ordens de Serviço",
  "customers": "Clientes",
  "devices": "Equipamentos",
  "services": "Serviços",
  "products": "Produtos",
  "reports": "Relatórios",
  "settings": "Configurações",

  "@@info2": "=== AÇÕES COMUNS ===",
  "save": "Salvar",
  "cancel": "Cancelar",
  "delete": "Excluir",
  "edit": "Editar",
  "add": "Adicionar",
  "search": "Buscar",
  "filter": "Filtrar",
  "sort": "Ordenar",
  "refresh": "Atualizar",
  "close": "Fechar",
  "confirm": "Confirmar",
  "back": "Voltar",
  "next": "Próximo",
  "done": "Concluído",
  "loading": "Carregando...",

  "@@info3": "=== STATUS DE ORDENS ===",
  "statusAll": "Todos",
  "statusPending": "Pendente",
  "statusApproved": "Aprovado",
  "statusInProgress": "Em Andamento",
  "statusCompleted": "Concluído",
  "statusCancelled": "Cancelado",
  "statusQuote": "Orçamento",
  "statusDelivery": "Entrega",

  "@@info4": "=== PAGAMENTOS ===",
  "payments": "Pagamentos",
  "paid": "Pago",
  "pending": "Pendente",
  "toReceive": "A receber",
  "paymentMethod": "Forma de Pagamento",
  "cash": "Dinheiro",
  "creditCard": "Cartão de Crédito",
  "debitCard": "Cartão de Débito",
  "pix": "PIX",
  "bankTransfer": "Transferência",

  "@@info5": "=== FORMULÁRIOS ===",
  "requiredField": "Campo obrigatório",
  "invalidEmail": "E-mail inválido",
  "invalidPhone": "Telefone inválido",
  "selectOption": "Selecione uma opção",
  "noResults": "Nenhum resultado encontrado",
  "selectAtLeastOne": "Selecione ao menos uma opção",

  "@@info6": "=== FOTOS ===",
  "takePhoto": "Tirar Foto",
  "chooseFromGallery": "Escolher da Galeria",
  "changePhoto": "Alterar Foto",
  "removePhoto": "Remover Foto",
  "photos": "Fotos",

  "@@info7": "=== DATAS ===",
  "today": "Hoje",
  "yesterday": "Ontem",
  "tomorrow": "Amanhã",
  "thisWeek": "Esta Semana",
  "thisMonth": "Este Mês",
  "scheduledDate": "Data Agendada",
  "createdAt": "Criado em",
  "updatedAt": "Atualizado em",

  "@@info8": "=== CONFIRMAÇÕES ===",
  "confirmDelete": "Confirmar Exclusão",
  "confirmDeleteMessage": "Deseja realmente excluir este item?",
  "confirmCancel": "Confirmar Cancelamento",
  "confirmCancelMessage": "Deseja realmente cancelar?",
  "unsavedChanges": "Alterações não salvas",
  "unsavedChangesMessage": "Você tem alterações não salvas. Deseja sair mesmo assim?",
  "yes": "Sim",
  "no": "Não",

  "@@info9": "=== CLIENTES ===",
  "customer": "Cliente",
  "newCustomer": "Novo Cliente",
  "editCustomer": "Editar Cliente",
  "customerName": "Nome do Cliente",
  "phone": "Telefone",
  "email": "E-mail",
  "address": "Endereço",
  "notes": "Observações",

  "@@info10": "=== ORDENS DE SERVIÇO ===",
  "order": "Ordem de Serviço",
  "newOrder": "Nova OS",
  "editOrder": "Editar OS",
  "orderNumber": "Número da OS",
  "technician": "Técnico",
  "problem": "Problema Relatado",
  "solution": "Solução",
  "warranty": "Garantia",

  "@@info11": "=== EQUIPAMENTOS ===",
  "device": "Equipamento",
  "newDevice": "Novo Equipamento",
  "editDevice": "Editar Equipamento",
  "brand": "Marca",
  "model": "Modelo",
  "serialNumber": "Número de Série",
  "condition": "Condição",

  "@@info12": "=== VALORES ===",
  "total": "Total",
  "subtotal": "Subtotal",
  "discount": "Desconto",
  "price": "Preço",
  "quantity": "Quantidade",
  "value": "Valor",

  "@@info13": "=== MENSAGENS ===",
  "savedSuccessfully": "Salvo com sucesso",
  "deletedSuccessfully": "Excluído com sucesso",
  "errorOccurred": "Ocorreu um erro",
  "tryAgain": "Tente novamente",
  "noInternetConnection": "Sem conexão com a internet",

  "@@info14": "=== AUTENTICAÇÃO ===",
  "login": "Entrar",
  "logout": "Sair",
  "register": "Cadastrar",
  "forgotPassword": "Esqueci a senha",
  "password": "Senha",
  "confirmPassword": "Confirmar Senha",

  "@@info15": "=== ONBOARDING ===",
  "welcome": "Bem-vindo",
  "getStarted": "Começar",
  "selectSegment": "Selecione seu Segmento",
  "selectSpecialties": "Selecione suas Especialidades",
  "companyName": "Nome da Empresa",
  "setupComplete": "Configuração Concluída"
}
```

### 2.2 Arquivo Inglês (app_en.arb)

```json
{
  "@@locale": "en",

  "home": "Home",
  "orders": "Service Orders",
  "customers": "Customers",
  "devices": "Devices",
  "services": "Services",
  "products": "Products",
  "reports": "Reports",
  "settings": "Settings",

  "save": "Save",
  "cancel": "Cancel",
  "delete": "Delete",
  "edit": "Edit",
  "add": "Add",
  "search": "Search",
  "filter": "Filter",
  "sort": "Sort",
  "refresh": "Refresh",
  "close": "Close",
  "confirm": "Confirm",
  "back": "Back",
  "next": "Next",
  "done": "Done",
  "loading": "Loading...",

  "statusAll": "All",
  "statusPending": "Pending",
  "statusApproved": "Approved",
  "statusInProgress": "In Progress",
  "statusCompleted": "Completed",
  "statusCancelled": "Cancelled",
  "statusQuote": "Quote",
  "statusDelivery": "Delivery",

  "payments": "Payments",
  "paid": "Paid",
  "pending": "Pending",
  "toReceive": "Receivable",
  "paymentMethod": "Payment Method",
  "cash": "Cash",
  "creditCard": "Credit Card",
  "debitCard": "Debit Card",
  "pix": "PIX",
  "bankTransfer": "Bank Transfer",

  "requiredField": "Required field",
  "invalidEmail": "Invalid email",
  "invalidPhone": "Invalid phone",
  "selectOption": "Select an option",
  "noResults": "No results found",
  "selectAtLeastOne": "Select at least one option",

  "takePhoto": "Take Photo",
  "chooseFromGallery": "Choose from Gallery",
  "changePhoto": "Change Photo",
  "removePhoto": "Remove Photo",
  "photos": "Photos",

  "today": "Today",
  "yesterday": "Yesterday",
  "tomorrow": "Tomorrow",
  "thisWeek": "This Week",
  "thisMonth": "This Month",
  "scheduledDate": "Scheduled Date",
  "createdAt": "Created at",
  "updatedAt": "Updated at",

  "confirmDelete": "Confirm Deletion",
  "confirmDeleteMessage": "Do you really want to delete this item?",
  "confirmCancel": "Confirm Cancellation",
  "confirmCancelMessage": "Do you really want to cancel?",
  "unsavedChanges": "Unsaved Changes",
  "unsavedChangesMessage": "You have unsaved changes. Do you want to leave anyway?",
  "yes": "Yes",
  "no": "No",

  "customer": "Customer",
  "newCustomer": "New Customer",
  "editCustomer": "Edit Customer",
  "customerName": "Customer Name",
  "phone": "Phone",
  "email": "Email",
  "address": "Address",
  "notes": "Notes",

  "order": "Service Order",
  "newOrder": "New Order",
  "editOrder": "Edit Order",
  "orderNumber": "Order Number",
  "technician": "Technician",
  "problem": "Reported Problem",
  "solution": "Solution",
  "warranty": "Warranty",

  "device": "Device",
  "newDevice": "New Device",
  "editDevice": "Edit Device",
  "brand": "Brand",
  "model": "Model",
  "serialNumber": "Serial Number",
  "condition": "Condition",

  "total": "Total",
  "subtotal": "Subtotal",
  "discount": "Discount",
  "price": "Price",
  "quantity": "Quantity",
  "value": "Value",

  "savedSuccessfully": "Saved successfully",
  "deletedSuccessfully": "Deleted successfully",
  "errorOccurred": "An error occurred",
  "tryAgain": "Try again",
  "noInternetConnection": "No internet connection",

  "login": "Sign In",
  "logout": "Sign Out",
  "register": "Sign Up",
  "forgotPassword": "Forgot Password",
  "password": "Password",
  "confirmPassword": "Confirm Password",

  "welcome": "Welcome",
  "getStarted": "Get Started",
  "selectSegment": "Select your Segment",
  "selectSpecialties": "Select your Specialties",
  "companyName": "Company Name",
  "setupComplete": "Setup Complete"
}
```

### 2.3 Arquivo Espanhol (app_es.arb)

```json
{
  "@@locale": "es",

  "home": "Inicio",
  "orders": "Órdenes de Servicio",
  "customers": "Clientes",
  "devices": "Equipos",
  "services": "Servicios",
  "products": "Productos",
  "reports": "Informes",
  "settings": "Configuración",

  "save": "Guardar",
  "cancel": "Cancelar",
  "delete": "Eliminar",
  "edit": "Editar",
  "add": "Agregar",
  "search": "Buscar",
  "filter": "Filtrar",
  "sort": "Ordenar",
  "refresh": "Actualizar",
  "close": "Cerrar",
  "confirm": "Confirmar",
  "back": "Volver",
  "next": "Siguiente",
  "done": "Hecho",
  "loading": "Cargando...",

  "statusAll": "Todos",
  "statusPending": "Pendiente",
  "statusApproved": "Aprobado",
  "statusInProgress": "En Progreso",
  "statusCompleted": "Completado",
  "statusCancelled": "Cancelado",
  "statusQuote": "Presupuesto",
  "statusDelivery": "Entrega",

  "payments": "Pagos",
  "paid": "Pagado",
  "pending": "Pendiente",
  "toReceive": "Por Cobrar",
  "paymentMethod": "Método de Pago",
  "cash": "Efectivo",
  "creditCard": "Tarjeta de Crédito",
  "debitCard": "Tarjeta de Débito",
  "pix": "PIX",
  "bankTransfer": "Transferencia Bancaria",

  "requiredField": "Campo obligatorio",
  "invalidEmail": "Correo inválido",
  "invalidPhone": "Teléfono inválido",
  "selectOption": "Seleccione una opción",
  "noResults": "No se encontraron resultados",
  "selectAtLeastOne": "Seleccione al menos una opción",

  "takePhoto": "Tomar Foto",
  "chooseFromGallery": "Elegir de la Galería",
  "changePhoto": "Cambiar Foto",
  "removePhoto": "Eliminar Foto",
  "photos": "Fotos",

  "today": "Hoy",
  "yesterday": "Ayer",
  "tomorrow": "Mañana",
  "thisWeek": "Esta Semana",
  "thisMonth": "Este Mes",
  "scheduledDate": "Fecha Programada",
  "createdAt": "Creado en",
  "updatedAt": "Actualizado en",

  "confirmDelete": "Confirmar Eliminación",
  "confirmDeleteMessage": "¿Realmente desea eliminar este elemento?",
  "confirmCancel": "Confirmar Cancelación",
  "confirmCancelMessage": "¿Realmente desea cancelar?",
  "unsavedChanges": "Cambios no guardados",
  "unsavedChangesMessage": "Tiene cambios no guardados. ¿Desea salir de todos modos?",
  "yes": "Sí",
  "no": "No",

  "customer": "Cliente",
  "newCustomer": "Nuevo Cliente",
  "editCustomer": "Editar Cliente",
  "customerName": "Nombre del Cliente",
  "phone": "Teléfono",
  "email": "Correo",
  "address": "Dirección",
  "notes": "Notas",

  "order": "Orden de Servicio",
  "newOrder": "Nueva Orden",
  "editOrder": "Editar Orden",
  "orderNumber": "Número de Orden",
  "technician": "Técnico",
  "problem": "Problema Reportado",
  "solution": "Solución",
  "warranty": "Garantía",

  "device": "Equipo",
  "newDevice": "Nuevo Equipo",
  "editDevice": "Editar Equipo",
  "brand": "Marca",
  "model": "Modelo",
  "serialNumber": "Número de Serie",
  "condition": "Condición",

  "total": "Total",
  "subtotal": "Subtotal",
  "discount": "Descuento",
  "price": "Precio",
  "quantity": "Cantidad",
  "value": "Valor",

  "savedSuccessfully": "Guardado exitosamente",
  "deletedSuccessfully": "Eliminado exitosamente",
  "errorOccurred": "Ocurrió un error",
  "tryAgain": "Intentar de nuevo",
  "noInternetConnection": "Sin conexión a internet",

  "login": "Iniciar Sesión",
  "logout": "Cerrar Sesión",
  "register": "Registrarse",
  "forgotPassword": "Olvidé mi contraseña",
  "password": "Contraseña",
  "confirmPassword": "Confirmar Contraseña",

  "welcome": "Bienvenido",
  "getStarted": "Comenzar",
  "selectSegment": "Seleccione su Segmento",
  "selectSpecialties": "Seleccione sus Especialidades",
  "companyName": "Nombre de la Empresa",
  "setupComplete": "Configuración Completa"
}
```

---

## Fase 3: Integração com Sistema Existente

### 3.1 Criar LocaleStore (MobX)

**Arquivo: `lib/mobx/locale_store.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_store.g.dart';

class LocaleStore = _LocaleStore with _$LocaleStore;

abstract class _LocaleStore with Store {
  static const String _localeKey = 'app_locale';

  static const Map<String, Locale> supportedLocales = {
    'pt-BR': Locale('pt', 'BR'),
    'en-US': Locale('en', 'US'),
    'es-ES': Locale('es', 'ES'),
  };

  @observable
  Locale currentLocale = const Locale('pt', 'BR');

  @observable
  bool isLoaded = false;

  @action
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null && supportedLocales.containsKey(savedLocale)) {
      currentLocale = supportedLocales[savedLocale]!;
    } else {
      // Detectar do sistema
      currentLocale = _detectSystemLocale();
    }
    isLoaded = true;
  }

  @action
  Future<void> setLocale(String localeCode) async {
    if (supportedLocales.containsKey(localeCode)) {
      currentLocale = supportedLocales[localeCode]!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, localeCode);

      // Atualizar SegmentConfigService
      SegmentConfigProvider.instance.setLocale(localeCode);
    }
  }

  Locale _detectSystemLocale() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode;

    if (languageCode == 'pt') return const Locale('pt', 'BR');
    if (languageCode == 'es') return const Locale('es', 'ES');
    return const Locale('en', 'US');
  }

  String get currentLocaleCode {
    return '${currentLocale.languageCode}-${currentLocale.countryCode}';
  }
}
```

### 3.2 Sincronizar com SegmentConfigService

O `SegmentConfigService` já tem suporte a locale. Precisamos integrar:

```dart
// Em SegmentConfigProvider
void setLocale(String locale) {
  _currentLocale = locale;
  // Recarregar labels se necessário
}
```

### 3.3 Criar Extension para Acesso Fácil

**Arquivo: `lib/extensions/context_extensions.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

**Uso nas telas:**

```dart
// Antes (hardcoded)
Text('Tirar Foto')

// Depois (i18n)
Text(context.l10n.takePhoto)
```

---

## Fase 4: Migração de Strings

### 4.1 Estratégia de Migração

**Ordem de prioridade:**

1. **Telas de navegação principal** (home, menu)
2. **Formulários e ações comuns** (save, cancel, delete)
3. **Mensagens de erro e validação**
4. **Telas específicas** (orders, customers, devices)
5. **Diálogos e sheets**

### 4.2 Padrão de Migração

```dart
// ANTES
CupertinoActionSheetAction(
  child: const Text('Tirar Foto'),
  onPressed: () => _takePhoto(),
),

// DEPOIS
CupertinoActionSheetAction(
  child: Text(context.l10n.takePhoto),
  onPressed: () => _takePhoto(),
),
```

### 4.3 Arquivos a Migrar (Prioridade)

| Arquivo | Strings | Prioridade |
|---------|---------|------------|
| `screens/menu_navigation/home.dart` | ~15 | Alta |
| `screens/order_form_screen.dart` | ~30 | Alta |
| `screens/customer_form_screen.dart` | ~20 | Alta |
| `screens/device_form_screen.dart` | ~15 | Alta |
| `screens/payment_management_screen.dart` | ~20 | Média |
| `widgets/common_dialogs.dart` | ~10 | Média |
| Outras telas | ~50 | Baixa |

---

## Fase 5: Fastlane Metadata Multi-idioma

### 5.1 Estrutura de Diretórios iOS

```
ios/fastlane/metadata/
├── pt-BR/          # ✅ Existente
│   ├── name.txt
│   ├── subtitle.txt
│   ├── description.txt
│   ├── keywords.txt
│   ├── promotional_text.txt
│   └── release_notes.txt
├── en-US/          # 🆕 Criar
│   ├── name.txt
│   ├── subtitle.txt
│   ├── description.txt
│   ├── keywords.txt
│   ├── promotional_text.txt
│   └── release_notes.txt
└── es-ES/          # 🆕 Criar
    ├── name.txt
    ├── subtitle.txt
    ├── description.txt
    ├── keywords.txt
    ├── promotional_text.txt
    └── release_notes.txt
```

### 5.2 Estrutura de Diretórios Android

```
android/fastlane/metadata/android/
├── pt-BR/          # ✅ Existente
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   └── changelogs/
├── en-US/          # 🆕 Criar
│   ├── title.txt
│   ├── short_description.txt
│   ├── full_description.txt
│   └── changelogs/
└── es-ES/          # 🆕 Criar
    ├── title.txt
    ├── short_description.txt
    ├── full_description.txt
    └── changelogs/
```

### 5.3 Conteúdo Traduzido

#### iOS en-US/description.txt

```
PraticOS is a complete service order management system designed for technical service companies, repair shops, and service providers.

MAIN FEATURES:

📋 SERVICE ORDER MANAGEMENT
• Create, edit, and track service orders
• Multiple statuses: quote, approved, in progress, completed
• Photo attachment for before/after documentation
• History and notes per order

👥 CUSTOMER MANAGEMENT
• Complete customer database
• Contact and address information
• Service history per customer
• Quick search and filtering

🔧 DEVICE/EQUIPMENT TRACKING
• Register customer devices
• Brand, model, and serial number
• Condition tracking
• Link devices to service orders

💰 FINANCIAL CONTROL
• Payment tracking and management
• Multiple payment methods
• Financial reports
• Receivables and payables overview

📊 REPORTS & ANALYTICS
• Dashboard with key metrics
• Service order reports
• Financial summaries
• Export capabilities

✨ ADDITIONAL FEATURES
• Multi-user support with roles
• Dark mode
• Offline capability
• Cloud sync with Firebase

Perfect for:
• Electronics repair shops
• Appliance service centers
• IT support companies
• General maintenance services
• Any technical service business

Download now and streamline your service order management!
```

#### iOS es-ES/description.txt

```
PraticOS es un sistema completo de gestión de órdenes de servicio diseñado para empresas de servicio técnico, talleres de reparación y proveedores de servicios.

CARACTERÍSTICAS PRINCIPALES:

📋 GESTIÓN DE ÓRDENES DE SERVICIO
• Crear, editar y rastrear órdenes de servicio
• Múltiples estados: presupuesto, aprobado, en progreso, completado
• Adjuntar fotos para documentación antes/después
• Historial y notas por orden

👥 GESTIÓN DE CLIENTES
• Base de datos completa de clientes
• Información de contacto y dirección
• Historial de servicios por cliente
• Búsqueda y filtrado rápido

🔧 SEGUIMIENTO DE EQUIPOS
• Registrar equipos de clientes
• Marca, modelo y número de serie
• Seguimiento de condición
• Vincular equipos a órdenes de servicio

💰 CONTROL FINANCIERO
• Seguimiento y gestión de pagos
• Múltiples métodos de pago
• Informes financieros
• Resumen de cuentas por cobrar y pagar

📊 INFORMES Y ANÁLISIS
• Panel con métricas clave
• Informes de órdenes de servicio
• Resúmenes financieros
• Capacidades de exportación

✨ CARACTERÍSTICAS ADICIONALES
• Soporte multiusuario con roles
• Modo oscuro
• Capacidad offline
• Sincronización en la nube con Firebase

Perfecto para:
• Talleres de reparación de electrónicos
• Centros de servicio de electrodomésticos
• Empresas de soporte IT
• Servicios de mantenimiento general
• Cualquier negocio de servicio técnico

¡Descarga ahora y optimiza la gestión de tus órdenes de servicio!
```

### 5.4 Keywords por Idioma

**pt-BR/keywords.txt:**
```
ordem de serviço,orçamento,gestão,OS,assistência técnica,reparo,conserto,cliente,equipamento,serviço,controle,financeiro
```

**en-US/keywords.txt:**
```
service order,quote,management,work order,repair shop,technical service,customer,device,equipment,tracking,financial,business
```

**es-ES/keywords.txt:**
```
orden de servicio,presupuesto,gestión,servicio técnico,reparación,taller,cliente,equipo,seguimiento,control,financiero,negocio
```

---

## Fase 6: Automatização CI/CD

### 6.1 Script de Validação de Traduções

**Arquivo: `scripts/validate_translations.dart`**

```dart
import 'dart:convert';
import 'dart:io';

void main() {
  final templateFile = File('lib/l10n/app_pt.arb');
  final template = jsonDecode(templateFile.readAsStringSync()) as Map;

  final locales = ['en', 'es'];
  var hasErrors = false;

  for (final locale in locales) {
    final file = File('lib/l10n/app_$locale.arb');
    if (!file.existsSync()) {
      print('❌ Missing: app_$locale.arb');
      hasErrors = true;
      continue;
    }

    final translations = jsonDecode(file.readAsStringSync()) as Map;

    for (final key in template.keys) {
      if (key.startsWith('@@')) continue;
      if (!translations.containsKey(key)) {
        print('❌ Missing key in $locale: $key');
        hasErrors = true;
      }
    }
  }

  exit(hasErrors ? 1 : 0);
}
```

### 6.2 GitHub Action para Validação

**Arquivo: `.github/workflows/validate-i18n.yml`**

```yaml
name: Validate Translations

on:
  pull_request:
    paths:
      - 'lib/l10n/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart scripts/validate_translations.dart
```

---

## Checklist de Implementação

### Fase 1: Setup (Estimativa: 2-3h)
- [ ] Adicionar `flutter_localizations` ao pubspec.yaml
- [ ] Criar `l10n.yaml`
- [ ] Criar diretório `lib/l10n/`
- [ ] Criar `app_pt.arb` (template)
- [ ] Criar `app_en.arb`
- [ ] Criar `app_es.arb`
- [ ] Executar `flutter gen-l10n`
- [ ] Configurar MaterialApp/CupertinoApp com delegates

### Fase 2: Integração (Estimativa: 2-3h)
- [ ] Criar `LocaleStore`
- [ ] Executar build_runner
- [ ] Integrar com `SegmentConfigService`
- [ ] Criar extension `context.l10n`
- [ ] Adicionar seletor de idioma em Settings

### Fase 3: Migração de Strings (Estimativa: 8-10h)
- [ ] Migrar `home.dart`
- [ ] Migrar `order_form_screen.dart`
- [ ] Migrar `customer_form_screen.dart`
- [ ] Migrar `device_form_screen.dart`
- [ ] Migrar `payment_management_screen.dart`
- [ ] Migrar widgets comuns
- [ ] Migrar diálogos e sheets
- [ ] Migrar mensagens de erro

### Fase 4: Fastlane Metadata (Estimativa: 3-4h)
- [ ] Criar `ios/fastlane/metadata/en-US/`
- [ ] Criar `ios/fastlane/metadata/es-ES/`
- [ ] Traduzir description, keywords, etc. (iOS)
- [ ] Criar `android/fastlane/metadata/android/en-US/`
- [ ] Criar `android/fastlane/metadata/android/es-ES/`
- [ ] Traduzir title, descriptions (Android)
- [ ] Testar upload de metadata

### Fase 5: Validação e Testes (Estimativa: 2-3h)
- [ ] Criar script de validação
- [ ] Adicionar GitHub Action
- [ ] Testar app em cada idioma
- [ ] Validar formatação de datas/números
- [ ] Testar troca de idioma em runtime

---

## Comandos Úteis

```bash
# Gerar arquivos de localização
fvm flutter gen-l10n

# Verificar strings faltantes (após criar script)
dart scripts/validate_translations.dart

# Build com verificação
fvm flutter build ios --release
fvm flutter build appbundle --release

# Upload metadata iOS
cd ios && bundle exec fastlane deliver --skip_binary_upload

# Upload metadata Android
cd android && bundle exec fastlane supply --skip_upload_apk
```

---

## Referências

- [Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [Fastlane Deliver (iOS)](https://docs.fastlane.tools/actions/deliver/)
- [Fastlane Supply (Android)](https://docs.fastlane.tools/actions/supply/)
- [intl Package](https://pub.dev/packages/intl)
