# Calendar / Agenda

Tela de calendário que exibe ordens de serviço agendadas, permitindo visualização por dia/mês e filtro por técnico.

## Visão Geral

A funcionalidade de Agenda permite que técnicos e gestores visualizem as OS agendadas em uma interface de calendário. O recurso distingue dois conceitos de data:

- **scheduledDate** — quando o serviço será realizado / visita agendada (alimenta o calendário)
- **dueDate** — prazo de entrega ao cliente (indicador de atraso, já existente)

| Segmento | scheduledDate | dueDate |
|----------|--------------|---------|
| Celular (balcão) | Opcional | Prazo de entrega |
| Mecânica | Agendamento de entrada | Prazo de entrega |
| HVAC/Instalação | Visita ao cliente | Prazo do projeto |

### Funcionalidades

- Calendário mensal com dot markers nos dias que possuem OS agendadas
- Lista de OS do dia selecionado, ordenadas por horário
- Filtro por técnico (visível para admin/manager/supervisor)
- RBAC integrado — técnico vê apenas suas OS, admin/supervisor vê todas
- OS com `scheduledDate` às 00:00 são exibidas como "Dia todo"
- Navegação direta para a OS ao tocar no item

## Arquitetura

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
├─────────────────────────────────────────────────────────────┤
│  AgendaScreen           NavigationController                 │
│  (Calendar + List) ←──  (Tab 2 - Agenda)                     │
└─────────────────────────────────────────────────────────────┘
                              ↓ Provider.of / Observer
┌─────────────────────────────────────────────────────────────┐
│                      State Management                        │
├─────────────────────────────────────────────────────────────┤
│  AgendaStore                  OrderStore                     │
│  (calendar state,        (scheduledDate field                │
│   month loading,          on order form)                     │
│   RBAC filtering)                                            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
├─────────────────────────────────────────────────────────────┤
│  TenantOrderRepository                                       │
│  - getOrdersByScheduledDateRange()                           │
│  - streamOrdersByScheduledDateRange()                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                        Firestore                             │
├─────────────────────────────────────────────────────────────┤
│  /companies/{companyId}/orders/{orderId}                     │
│    → scheduledDate: "2026-02-17T09:00:00.000" (ISO 8601)    │
└─────────────────────────────────────────────────────────────┘
```

### Arquivos Principais

| Componente | Arquivo | Descrição |
|------------|---------|-----------|
| **Model** | `lib/models/order.dart` | Campo `DateTime? scheduledDate` |
| **Store** | `lib/mobx/agenda_store.dart` | Estado do calendário (seleção, mês, filtros) |
| **Store** | `lib/mobx/order_store.dart` | Actions `setScheduledDate()` / `clearScheduledDate()` |
| **Store** | `lib/mobx/reminder_store.dart` | Preferência de lembrete (minutos antes) |
| **Service** | `lib/services/notification_service.dart` | Push notifications + lembretes locais agendados |
| **Repository** | `lib/repositories/tenant/tenant_order_repository.dart` | Queries por range de `scheduledDate` |
| **Screen** | `lib/screens/agenda/agenda_screen.dart` | Tela do calendário com lista de OS |
| **Navigation** | `lib/screens/menu_navigation/navigation_controller.dart` | Aba 2 (Agenda) |
| **Form** | `lib/screens/order_form.dart` | Picker de data+hora para `scheduledDate` |
| **Provider** | `lib/main.dart` | Registro do `AgendaStore` |

### Dependências Externas

- **table_calendar** (`^3.1.2`) — Widget de calendário com suporte a markers e seleção de dia
- **flutter_local_notifications** — Notificações locais agendadas (lembretes)
- **timezone** — Cálculos de fuso horário para agendamento de notificações
- **device_info_plus** — Identificação do dispositivo para tokens FCM

## Fluxo de Dados

### Carregamento da Agenda

```
1. AgendaScreen.didChangeDependencies()
   → agendaStore.loadMonth(DateTime.now())

2. AgendaStore.loadMonth(month)
   → repository.getOrdersByScheduledDateRange(companyId, startOfMonth, endOfMonth)
   → orders = resultado da query

3. AgendaStore.filteredOrders (computed)
   → Aplica RBAC via AuthorizationService.filterOrdersByPermission()
   → Aplica filtro de técnico (se selecionado)

4. AgendaStore.eventMarkers (computed)
   → Conta OS por dia → Map<DateTime, int> para dots no calendário

5. AgendaStore.ordersForSelectedDate (computed)
   → Filtra por dia selecionado
   → Ordena: OS com horário primeiro, "dia todo" (00:00) por último
```

### Agendamento de OS (Formulário)

```
1. Usuário toca em "Data Agendada" no formulário de OS
2. CupertinoDatePicker (dateAndTime, minuteInterval: 1)
3. orderStore.setScheduledDate(date)
   → order.scheduledDate = date
   → scheduledDate = FormatService().formatDateTime(date)
4. Ao salvar → Firestore armazena como ISO 8601 string
5. NotificationService.scheduleOrderReminder() agenda lembrete local
```

### Prazo de Entrega (dueDate) com Horário

```
1. Usuário toca em "Prazo de Entrega" no formulário de OS
2. CupertinoDatePicker (dateAndTime, minuteInterval: 1)
3. orderStore.setDueDate(date)
   → order.dueDate = date
4. Ao salvar → Firestore armazena como ISO 8601 string
```

> **Nota:** O picker de `dueDate` foi atualizado para incluir seleção de horário
> (modo `dateAndTime`), permitindo prazos de entrega com hora específica.

## AgendaStore

### Observables

| Observable | Tipo | Descrição |
|-----------|------|-----------|
| `selectedDate` | `DateTime` | Dia selecionado (default: hoje) |
| `focusedMonth` | `DateTime` | Mês visível no calendário |
| `orders` | `ObservableList<Order?>` | OS do mês com `scheduledDate` |
| `selectedTechnicianId` | `String?` | Filtro por técnico (null = todos) |
| `isLoading` | `bool` | Indicador de carregamento |

### Computeds

| Computed | Retorno | Descrição |
|----------|---------|-----------|
| `ordersForSelectedDate` | `List<Order?>` | OS do dia selecionado, ordenadas por hora |
| `eventMarkers` | `Map<DateTime, int>` | Contagem de OS por dia (para dots) |
| `filteredOrders` | `List<Order?>` | OS filtradas por RBAC + técnico |

### Actions

| Action | Descrição |
|--------|-----------|
| `loadMonth(DateTime)` | Busca OS do mês via repository |
| `selectDate(DateTime)` | Muda dia selecionado; carrega novo mês se necessário |
| `setTechnicianFilter(String?)` | Define filtro por técnico |

## Regras de Negócio

1. **Somente OS com `scheduledDate`** aparecem no calendário — OS com apenas `dueDate` não são exibidas
2. **RBAC**: Técnicos veem apenas suas OS; admin/manager/supervisor veem todas
3. **Filtro de técnico**: Disponível apenas para admin, manager e supervisor
4. **Horário**: Picker permite seleção de qualquer minuto (`minuteInterval: 1`)
5. **Dia todo**: OS agendadas com hora 00:00 são exibidas como "Dia todo" e aparecem no final da lista
6. **Navegação**: Mudar de mês no calendário carrega automaticamente os dados do novo mês
7. **Ambos os campos são opcionais**: Cada negócio usa `scheduledDate`, `dueDate`, ou ambos conforme fizer sentido

## Navegação

A Agenda é a 3ª aba (index 2) na barra de navegação:

```
Home(0) → Clientes(1) → Agenda(2) → Financeiro(3) → Mais(4)
```

- Ícone: `CupertinoIcons.calendar` / `CupertinoIcons.calendar_today` (ativo)
- Label: `context.l10n.agenda`

## i18n

| Chave | pt | en | es |
|-------|----|----|-----|
| `agenda` | Agenda | Schedule | Agenda |
| `scheduledDate` | Data Agendada | Scheduled Date | Fecha Programada |
| `noScheduledOrders` | Nenhuma OS agendada para este dia | No orders scheduled for this day | No hay OS programadas para este día |
| `allTeam` | Toda a Equipe | All Team | Todo el Equipo |
| `filterByTechnician` | Filtrar por técnico | Filter by technician | Filtrar por técnico |
| `allDay` | Dia todo | All day | Todo el día |
| `clearSchedule` | Remover agendamento | Clear schedule | Quitar programación |

## Status Colors

Os dots de status na lista de OS seguem este mapa de cores:

| Status | Cor |
|--------|-----|
| `quote` | `CupertinoColors.systemOrange` |
| `approved` | `CupertinoColors.systemBlue` |
| `progress` | `CupertinoColors.systemPurple` |
| `done` | `CupertinoColors.systemGreen` |
| `canceled` | `CupertinoColors.systemRed` |
| Default | `CupertinoColors.systemGrey` |

## ReminderStore

Gerencia a preferência de lembrete do usuário (quantos minutos antes do agendamento disparar uma notificação).

### Observables

| Observable | Tipo | Descrição |
|-----------|------|-----------|
| `reminderMinutes` | `int` | Minutos de antecedência (default: 30) |

### Opções Válidas

```dart
static const validOptions = [0, 15, 30, 60, 120];
// 0 = desativado, 15min, 30min, 1h, 2h
```

### Actions

| Action | Descrição |
|--------|-----------|
| `_loadPreference()` | Carrega preferência salva do `SharedPreferences` na inicialização |
| `setReminderMinutes(int)` | Atualiza minutos e persiste em `SharedPreferences` |

### Persistência

- Chave: armazenado em `SharedPreferences` (local ao dispositivo)
- O valor é passado para `NotificationService.scheduleOrderReminder()` ao agendar lembretes

## NotificationService

Serviço singleton que gerencia push notifications (FCM) e lembretes locais agendados.

### Canais de Notificação (Android)

| Canal | ID | Descrição |
|-------|----|-----------|
| Ordens | `orders_channel` | Push notifications de OS (aprovação, comentário, etc.) |
| Lembretes | `reminders_channel` | Notificações locais de lembrete agendado |

### Métodos Principais

| Método | Descrição |
|--------|-----------|
| `initialize()` | Inicializa FCM, notificações locais e handlers |
| `requestPermission()` | Solicita permissão de notificação (iOS) |
| `registerToken(userId)` | Registra token FCM do dispositivo no Firestore |
| `unregisterToken(userId)` | Remove token FCM ao fazer logout |
| `scheduleOrderReminder(...)` | Agenda lembrete local para uma OS |
| `cancelOrderReminder(orderId)` | Cancela lembrete agendado de uma OS |

### scheduleOrderReminder

```dart
Future<void> scheduleOrderReminder({
  required String orderId,
  required String title,
  required String body,
  required DateTime scheduledDate,
  required int minutesBefore,
  String? companyId,
})
```

- Calcula `scheduledDate - minutesBefore` usando timezone local
- Usa `zonedSchedule()` com `AndroidScheduleMode.inexactAllowWhileIdle`
- Ignora se `minutesBefore <= 0` ou se o horário do lembrete já passou
- O `companyId` é incluído no payload para navegação ao tocar na notificação

### Callback

- `onNotificationTap` — recebe `orderId` e `companyId` ao tocar na notificação, permitindo navegação direta para a OS

## Permissões Android

Permissões adicionadas em `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Push notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Notificações agendadas (Android 12+) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

<!-- Re-agendar notificações após reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### Boot Receivers

O manifest registra `ScheduledNotificationBootReceiver` e `ScheduledNotificationReceiver` que escutam:
- `BOOT_COMPLETED` — reboot do dispositivo
- `MY_PACKAGE_REPLACED` — atualização do app
- `QUICKBOOT_POWERON` — quick boot (HTC)

Isso garante que lembretes locais são re-agendados automaticamente após reboot ou atualização do app.

## Integração com Settings

Na tela de Configurações, o usuário pode definir o tempo de antecedência dos lembretes:

```
Configurações > Lembretes > Tempo de antecedência
  → Opções: Desativado, 15min, 30min, 1h, 2h
  → Valor salvo no ReminderStore (SharedPreferences)
```

O valor selecionado é utilizado como `minutesBefore` ao agendar lembretes para novas OS ou ao editar OS existentes.

## Armazenamento

- `scheduledDate` é armazenado como string ISO 8601 local (ex: `"2026-02-17T09:00:00.000"`)
- `dueDate` também suporta horário (modo `dateAndTime` no picker)
- Serialização: `DateTime.toIso8601String()` / `DateTime.parse()` via json_serializable
- Range queries funcionam por comparação lexicográfica — consistente para hora local
- Conversão Timestamp→ISO string no repository (mesmo padrão de `dueDate`)
