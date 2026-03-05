# ENGAGEMENT_REMINDERS.md

## Visao Geral

O sistema de Lembretes de Engajamento envia notificacoes locais para manter os usuarios engajados com o app. Sao notificacoes pre-agendadas no dispositivo, sem necessidade de backend ou servidor.

### Tipos de Lembrete

| Tipo | Descricao | Frequencia | Default |
|------|-----------|------------|---------|
| **Lembrete Diario** | Notificacao diaria as 9h para lembrar de abrir o app | Diario, 9h | Ativado |
| **Inatividade** | Lembretes progressivos quando o usuario nao abre o app | 3, 5 e 7 dias sem uso | Ativado |
| **OS Pendentes** | Alerta sobre OS em orcamento/aprovado ha mais de 7 dias | Diario, 10h (se houver OS) | Ativado |

Alem destes, existe o **Lembrete de Agendamento** (feature anterior), que notifica antes de uma OS agendada com tempo configuravel (15min, 30min, 1h, 2h). Este e gerenciado pelo `ReminderStore` e documentado separadamente.

## Arquitetura

### Componentes

```
EngagementReminderStore (MobX)
    | le/salva preferencias (SharedPreferences)
    v
EngagementScheduler (servico stateless)
    | consulta dados + agenda notificacoes
    v
NotificationService
    | agenda via FlutterLocalNotificationsPlugin
    v
Notificacao nativa (iOS/Android)
```

### Arquivos Envolvidos

| Arquivo | Responsabilidade |
|---------|-----------------|
| `lib/mobx/engagement_reminder_store.dart` | Store MobX para preferencias dos 3 tipos de lembrete |
| `lib/services/engagement_scheduler.dart` | Orquestra agendamento das notificacoes |
| `lib/services/notification_service.dart` | Servico de notificacoes locais (schedule/cancel) |
| `lib/screens/menu_navigation/settings.dart` | Tela de configuracoes com toggles para cada tipo |
| `lib/main.dart` | Inicializa o scheduler no app resume |

## Fluxo de Dados

### Ciclo de Vida

```
1. App abre / volta ao foreground
2. main.dart chama EngagementScheduler.onAppResumed()
3. Scheduler cancela TODAS as notificacoes de engajamento existentes
4. Para cada tipo habilitado, agenda novas notificacoes:
   - Daily: proximo dia as 9h
   - Inactivity: daqui a 3, 5 e 7 dias
   - Pending OS: consulta Firestore, agenda para amanha as 10h
5. Se o usuario abrir o app antes, o ciclo reinicia (step 1)
```

### Lembrete Diario

- Agendado para as **9h** do proximo dia
- Titulo: "Lembrete diario" / "Daily reminder" / "Recordatorio diario"
- Corpo: "Receba um lembrete todo dia as 9h"
- Reagendado a cada abertura do app (sempre proximo dia)

### Lembretes de Inatividade

Tres notificacoes progressivas agendadas a partir do ultimo uso:

| Dias | Titulo (pt) | Corpo (pt) |
|------|-------------|------------|
| 3 dias | Sentimos sua falta! | Voce nao abre o PraticOS ha 3 dias. Que tal registrar suas OS? |
| 5 dias | Suas OS estao esperando! | Ja faz 5 dias! Nao perca o controle das suas ordens de servico. |
| 7 dias | Nao deixe o PraticOS parado! | Faz 1 semana que voce nao abre o app. Volte e organize suas OS! |

- Se o usuario abrir o app antes do prazo, os lembretes sao cancelados e reagendados
- Funciona como "dead man's switch" — so dispara se o app NAO for aberto

### Lembrete de OS Pendentes

- Consulta Firestore por OS com status `quote` ou `approved` criadas ha mais de 7 dias
- Se houver OS pendentes, agenda notificacao para **amanha as 10h**
- Titulo: "OS pendentes precisam de atencao"
- Corpo: "Voce tem {count} OS paradas ha mais de 7 dias."

## Configuracoes do Usuario

### SharedPreferences

| Chave | Tipo | Default |
|-------|------|---------|
| `engagement_daily_enabled` | `bool` | `true` |
| `engagement_inactivity_enabled` | `bool` | `true` |
| `engagement_pending_os_enabled` | `bool` | `true` |

### Tela de Configuracoes

Em **Configuracoes > Lembretes**, cada tipo tem um toggle (CupertinoSwitch) independente:
- Lembrete diario
- Lembrete de inatividade
- Lembrete de OS pendentes

Ao desativar, a notificacao correspondente e cancelada imediatamente.

## Gestao de IDs de Notificacao

IDs fixos para evitar conflitos:

| Tipo | ID(s) | Constante |
|------|-------|-----------|
| Daily | `1000000` | `dailyReminderId` |
| Inactivity 3d | `1000001` | `inactivity3dId` |
| Inactivity 5d | `1000002` | `inactivity5dId` |
| Inactivity 7d | `1000003` | `inactivity7dId` |
| Pending OS | `1000010` a `1000014` | `_pendingOsBaseId` + offset |

## Canais de Notificacao (Android)

| Canal | ID | Nome |
|-------|----|------|
| Ordens de Servico | `orders_channel` | Ordens de Servico |
| Lembretes | `reminders_channel` | Lembretes |

Os lembretes de engajamento usam o canal `reminders_channel`.

## i18n

### Chaves de UI (Configuracoes)

| Chave | Exemplo (pt-BR) |
|-------|-----------------|
| `engagementReminders` | Lembretes |
| `dailyReminderTitle` | Lembrete diario |
| `dailyReminderDescription` | Receba um lembrete todo dia as 9h |
| `inactivityReminderTitle` | Lembrete de inatividade |
| `inactivityReminderDescription` | Receba lembretes quando nao usar o app |
| `pendingOsReminderTitle` | Lembrete de OS pendentes |
| `pendingOsReminderDescription` | Receba lembretes sobre OS paradas |

### Chaves de Notificacao

| Chave | Exemplo (pt-BR) |
|-------|-----------------|
| `inactivity3dTitle` | Sentimos sua falta! |
| `inactivity3dBody` | Voce nao abre o PraticOS ha 3 dias... |
| `inactivity5dTitle` | Suas OS estao esperando! |
| `inactivity5dBody` | Ja faz 5 dias!... |
| `inactivity7dTitle` | Nao deixe o PraticOS parado! |
| `inactivity7dBody` | Faz 1 semana que voce nao abre o app... |
| `pendingOsNotificationTitle` | OS pendentes precisam de atencao |
| `pendingOsNotificationBody` | Voce tem {count} OS paradas ha mais de 7 dias. |

## Plataformas

### iOS
- Usa `UNUserNotificationCenter`
- Requer permissao do usuario (solicitada no primeiro uso)
- `presentAlert`, `presentBadge`, `presentSound` habilitados

### Android
- Canal dedicado `reminders_channel`
- `AndroidScheduleMode.inexactAllowWhileIdle` para funcionar em modo economia
- Compativel com Doze mode

## Exemplos de Uso

### Inicializar o scheduler (main.dart)

```dart
final engagementStore = EngagementReminderStore();
final scheduler = EngagementScheduler(
  store: engagementStore,
  strings: EngagementStrings(
    dailyTitle: context.l10n.dailyReminderTitle,
    dailyBody: context.l10n.dailyReminderDescription,
    inactivity3dTitle: context.l10n.inactivity3dTitle,
    inactivity3dBody: context.l10n.inactivity3dBody,
    inactivity5dTitle: context.l10n.inactivity5dTitle,
    inactivity5dBody: context.l10n.inactivity5dBody,
    inactivity7dTitle: context.l10n.inactivity7dTitle,
    inactivity7dBody: context.l10n.inactivity7dBody,
    pendingOsTitle: context.l10n.pendingOsNotificationTitle,
    pendingOsBody: (count) => context.l10n.pendingOsNotificationBody(count),
  ),
);

// Chamar sempre que o app voltar ao foreground
scheduler.onAppResumed();
```

### Toggle individual na UI

```dart
Observer(builder: (_) {
  return CupertinoSwitch(
    value: engagementStore.dailyEnabled,
    onChanged: (value) {
      engagementStore.setDailyEnabled(value);
      if (!value) {
        NotificationService.instance.cancelDailyReminder();
      }
    },
  );
});
```
