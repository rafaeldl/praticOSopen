# REMINDERS_AND_NOTICES.md

## Visão Geral

Como o app mostra que avisa: a dica ao marcar a visita, o texto do lembrete, o sino e o pedido de notificação. Nasceu dos testes de usuário de 01/11/2026, em que as personas concluíram que o app não avisava nada (issue #491).

## Arquitetura

| Peça | Papel |
|---|---|
| `lib/screens/order/reminder_hint.dart` | `reminderHintText` ("O app avisa 30 min antes.") e `ReminderHintRow`, com "Ajustar" |
| `lib/screens/order/order_extras.dart` | `OrderDateSheet.footer`: a dica embaixo da escolha da data |
| `lib/services/order_reminder_text.dart` | Título e corpo do lembrete, com hora, cliente e veículo ou aparelho |
| `lib/screens/order/new_order_offers.dart` | `askNotificationsOnce`, `offerChecklist` e `runNewOrderOffers` |
| `lib/screens/order/order_route.dart` | `openNewOrder` roda as ofertas depois do "✓" |
| `lib/mobx/notification_store.dart` | `permissionUndecided` e `permissionBlocked` |
| `lib/screens/notifications/notification_list_screen.dart` | Sino vazio explica o que aparece ali e leva a Lembretes |

## Fluxo de Dados

```
Marca a visita → OrderDateSheet mostra a dica
OS salva → setScheduledDate agenda o lembrete
OS nova → sem id até o "✓" → createItem(onCreated) → scheduleReminder
"✓" fecha a Nova OS → checklist (se couber) → pedido de notificação (1ª vez)
```

## Regras de Negócio

1. **A dica nunca promete o que não vai acontecer.** Mostra "Lembrete desligado." quando o ajuste é zero e "Os avisos estão desligados nos Ajustes do celular." quando o celular recusou. Na OS salva, só aparece para horário futuro.
2. **Lembrete da OS nova.** A OS só tem id depois do "✓", então o lembrete é agendado no `onCreated`. Antes disso ele só nascia ao abrir a Agenda.
3. **Pedido de notificação no iPhone.** Não sai mais depois do login. Sai depois de salvar a primeira OS ou de marcar uma visita numa OS salva, precedido de um aviso com um botão só, "Continuar", como a HIG pede para telas antes de um alerta. Quem já respondeu não vê nada. No Android continua como antes.
4. **Depois de salvar, uma interrupção por vez.** Quem aceita o checklist vai para a OS, e o pedido de notificação fica para a próxima.
5. **Checklist de entrada.** Oferecido só no ramo `automotive`, em OS com veículo, com id, sem contrato e para quem pode mexer em checklists. Depois de 3 "Agora não" seguidos a oferta para (`checklist_offer_declined` em `SharedPreferences`). Offline a OS não recebe id em 3 segundos, e a oferta não aparece.
6. **Próxima manutenção.** Ao concluir a OS, a pergunta segue o mesmo padrão de 3 recusas seguidas. Na Nova OS salva já concluída, ela toma o lugar do checklist. Ver `docs/DEVICE_NEXT_MAINTENANCE.md`.

## Exemplos de Uso

```dart
final text = OrderReminderText.of(order);
// title: "Agendamento às 14:00"
// body:  "OS 12 · Ana Souza · Onix 1.0"
```
